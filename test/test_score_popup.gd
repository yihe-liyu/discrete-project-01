extends GutTest
## 吃道具得分浮字：Item.collect 发 GameEvents.item_score；ScorePopupLayer 原位显示 +
## 上浮渐隐后回池。金色只给「过收点线」和「记忆释放强收（force_collect）」，靠近吸附/撞上为白。

const ITEM_SCENE = preload("res://scenes/item.tscn")
## Item._auto_collect_line 默认值（自机 y 小于它 = 过收点线）
const LINE := 256.0


## 轻量假自机：EntityRegistry.get_player_resources() 走 player.get("resources")。
class FakePlayer extends Node2D:
	var resources: PlayerResources
	var is_focused: bool = false


## 建道具 + 假自机（player_y 决定是否过收点线），不收取。
func _pickup(type: int, player_y: float = 700.0) -> Dictionary:
	var reg := EntityRegistry.new()
	var player := FakePlayer.new()
	player.resources = PlayerResources.new()
	add_child_autofree(player)
	player.global_position = Vector2(448.0, player_y)
	reg.bind_player(player)
	var item: Item = ITEM_SCENE.instantiate()
	add_child_autofree(item)
	item.entity_registry = reg
	item.setup(type, Vector2(10, 20))
	return {item = item, player = player, resources = player.resources}


## 捕获一次 item_score；返回 [[score, pos, is_highlight], ...]。
func _collect(item: Item) -> Array:
	var got: Array = []
	var cb := func(score: int, pos: Vector2, is_highlight: bool) -> void: got.append([score, pos, is_highlight])
	GameEvents.item_score.connect(cb)
	item.collect()
	GameEvents.item_score.disconnect(cb)
	return got


func test_power_item_grants_power_and_score() -> void:
	var r: Dictionary = _pickup(Item.Type.POWER)
	var got: Array = _collect(r.item)
	assert_eq(r.resources.power_raw, 1, "P 点应 +1 火力")
	assert_eq(r.resources.current_score, Item.POWER_SCORE, "P 点应 +POWER_SCORE 分")
	assert_eq(got[0][0], Item.POWER_SCORE, "浮字数值 = POWER_SCORE")
	assert_eq(got[0][1], Vector2(10, 20), "浮字位置 = 吃掉位置")
	assert_false(got[0][2], "撞上吃 = 非金色")


func test_point_item_grants_max_point_value() -> void:
	var r: Dictionary = _pickup(Item.Type.POINT)
	var got: Array = _collect(r.item)
	assert_eq(r.resources.current_score, 10000, "点的分 = 吃掉前的 max_point")
	assert_eq(r.resources.max_point, 10010, "max_point 应 +10")
	assert_eq(got[0][0], 10000, "浮字数值 = max_point")


func test_force_collect_is_highlight() -> void:
	var r: Dictionary = _pickup(Item.Type.POWER)
	r.item.force_collect()
	var got: Array = _collect(r.item)
	assert_true(got[0][2], "记忆释放强收 → 金色")


func test_cross_line_is_highlight() -> void:
	var r: Dictionary = _pickup(Item.Type.POINT, LINE - 100.0)   # 自机在收点线之上
	r.item._physics_process(1.0 / 60.0)
	var got: Array = _collect(r.item)
	assert_true(got[0][2], "过收点线 → 金色")


func test_proximity_is_not_highlight() -> void:
	var r: Dictionary = _pickup(Item.Type.POINT, 700.0)
	r.item.global_position = Vector2(448.0, 660.0)   # 在自机附近(40px)但没收点线，且在屏内
	r.item._physics_process(1.0 / 60.0)
	var got: Array = _collect(r.item)
	assert_false(got[0][2], "靠近吸附 → 白色")


func test_reused_item_does_not_inherit_highlight() -> void:
	var r: Dictionary = _pickup(Item.Type.POWER)
	r.item.force_collect()
	_collect(r.item)                                  # 金色收掉
	r.item.setup(Item.Type.POINT, Vector2(10, 20))    # 池复用（ItemPool.spawn 走的入口）
	var got: Array = _collect(r.item)
	assert_false(got[0][2], "池复用的道具不应继承上一轮的金色标记")


func test_popup_layer_shows_and_recycles() -> void:
	var layer := ScorePopupLayer.new()
	add_child_autofree(layer)
	GameEvents.item_score.emit(1234, Vector2(50, 60), false)
	assert_eq(layer._pool.size(), 1, "应取到一个浮字实例")
	var ns: NumberSprite = layer._pool[0]
	assert_eq(ns.value, 1234, "浮字数值")
	assert_eq(ns.position, Vector2(50, 60), "浮字位置")
	assert_true(ns.visible, "播放中应可见")
	await get_tree().create_timer(ScorePopupLayer.FADE_TIME + 0.15).timeout
	assert_false(ns.visible, "渐隐结束后应隐藏（回池）")
	GameEvents.item_score.emit(5, Vector2.ZERO, false)
	assert_same(ns, layer._pool[0], "应复用同一实例，不新建")


func test_highlight_is_gold_and_plain_is_white() -> void:
	var layer := ScorePopupLayer.new()
	add_child_autofree(layer)
	layer.show_score(100, Vector2(1, 2), true)
	assert_eq(layer._pool[0].modulate, ScorePopupLayer.HIGHLIGHT_COLOR, "过线/强收 → 金色")
	# 等金色那条回池，再复用同一实例验证非高亮是白
	await get_tree().create_timer(ScorePopupLayer.FADE_TIME + 0.15).timeout
	layer.show_score(100, Vector2(3, 4), false)
	assert_eq(layer._pool[0].modulate, Color.WHITE, "靠近/撞上 → 白色")


func test_font_scale_scales_popup() -> void:
	var layer := ScorePopupLayer.new()
	add_child_autofree(layer)
	layer.font_scale = 2.0
	layer.show_score(10, Vector2.ZERO, false)
	assert_eq(layer._pool[0].scale, Vector2(2.0, 2.0), "字号倍率应作用在浮字上")

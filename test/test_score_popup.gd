extends GutTest
## 吃道具得分浮字：Item.collect 发 GameEvents.item_score，ScorePopupLayer 在吃掉位置
## 显示本次得分 + 上浮渐隐后回池。

const ITEM_SCENE = preload("res://scenes/item.tscn")


## 轻量假自机：EntityRegistry.get_player_resources() 走 player.get("resources")。
class FakePlayer extends Node2D:
	var resources: PlayerResources


func _pickup(type: int) -> Dictionary:
	var reg := EntityRegistry.new()
	var player := FakePlayer.new()
	player.resources = PlayerResources.new()
	add_child_autofree(player)
	reg.bind_player(player)
	var item: Item = ITEM_SCENE.instantiate()
	add_child_autofree(item)
	item.entity_registry = reg
	item.setup(type, Vector2(10, 20))
	var got: Array = []
	var cb := func(score: int, pos: Vector2) -> void: got.append([score, pos])
	GameEvents.item_score.connect(cb)
	item.collect()
	GameEvents.item_score.disconnect(cb)
	return {resources = player.resources, got = got}


func test_power_item_grants_power_and_score() -> void:
	var r: Dictionary = _pickup(Item.Type.POWER)
	var res: PlayerResources = r.resources
	assert_eq(res.power_raw, 1, "P 点应 +1 火力")
	assert_eq(res.current_score, Item.POWER_SCORE, "P 点应 +POWER_SCORE 分")
	assert_eq(r.got.size(), 1, "应发射一次 item_score")
	assert_eq(r.got[0][0], Item.POWER_SCORE, "浮字数值 = POWER_SCORE")
	assert_eq(r.got[0][1], Vector2(10, 20), "浮字位置 = 吃掉位置")


func test_point_item_grants_max_point_value() -> void:
	var r: Dictionary = _pickup(Item.Type.POINT)
	var res: PlayerResources = r.resources
	assert_eq(res.current_score, 10000, "点的分 = 吃掉前的 max_point")
	assert_eq(res.max_point, 10010, "max_point 应 +10")
	assert_eq(r.got[0][0], 10000, "浮字数值 = max_point")


func test_popup_layer_shows_and_recycles() -> void:
	var layer := ScorePopupLayer.new()
	add_child_autofree(layer)
	GameEvents.item_score.emit(1234, Vector2(50, 60))
	assert_eq(layer._pool.size(), 1, "应取到一个浮字实例")
	var ns: NumberSprite = layer._pool[0]
	assert_eq(ns.value, 1234, "浮字数值")
	assert_eq(ns.position, Vector2(50, 60), "浮字位置")
	assert_true(ns.visible, "播放中应可见")
	await get_tree().create_timer(ScorePopupLayer.FADE_TIME + 0.15).timeout
	assert_false(ns.visible, "渐隐结束后应隐藏（回池）")
	GameEvents.item_score.emit(5, Vector2.ZERO)
	assert_same(ns, layer._pool[0], "应复用同一实例，不新建")

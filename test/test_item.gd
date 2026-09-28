extends GutTest
## 道具系统测试：掉落收集/类型效果/防重复

var _player_resources: PlayerResources
var _entity_registry: EntityRegistry
var _player: Player

func before_each():
	_player_resources = PlayerResources.new()
	_player_resources.reset_all()
	_entity_registry = EntityRegistry.new()
	_player = Player.new()
	_player.resources = _player_resources
	_entity_registry.bind_player(_player)

func after_each():
	_player.free()

func _make_item() -> Item:
	var item = load("res://scenes/item.tscn").instantiate()
	item.entity_registry = _entity_registry
	autofree(item)
	add_child(item)
	return item

func test_point_item_adds_score():
	_player_resources.max_point = 10000
	var item := _make_item()
	item.setup(Item.Type.POINT, Vector2(100, 100))
	item.collect()
	assert_eq(_player_resources.current_score, 10000, "点道具 → 分数入账")
	assert_eq(_player_resources.max_point, 10010, "max_point +10")

func test_power_item():
	var item := _make_item()
	item.setup(Item.Type.POWER, Vector2(100, 100))
	item.collect()
	assert_eq(_player_resources.power_raw, 1, "P 点 → power +1")

func test_life_fragment_item():
	var item := _make_item()
	item.setup(Item.Type.LIFE_FRAGMENT, Vector2(100, 100))
	item.collect()
	assert_eq(_player_resources.life_fragments, 1, "命碎片 +1")

func test_bomb_fragment_item():
	var item := _make_item()
	item.setup(Item.Type.BOMB_FRAGMENT, Vector2(100, 100))
	item.collect()
	assert_eq(_player_resources.bomb_fragments, 1, "Bomb 碎片 +1")

func test_life_full_item():
	var item := _make_item()
	item.setup(Item.Type.LIFE_FULL, Vector2(100, 100))
	_player_resources.lives = 1
	item.collect()
	assert_eq(_player_resources.lives, 2, "整命 → +1 命")

func test_bomb_full_item():
	var item := _make_item()
	item.setup(Item.Type.BOMB_FULL, Vector2(100, 100))
	_player_resources.bomb_count = 1
	item.collect()
	assert_eq(_player_resources.bomb_count, 2, "整 B → +1 Bomb")

## 拿到**完整残机**要单独给一声 `get_player`（里程碑反馈）：碎片第 5 片 / 整命道具 → 播
func test_extend_sfx_on_life_fragment_completion():
	_player_resources.life_fragments = 4
	_clear_sfx_pool()
	var item := _make_item()
	item.setup(Item.Type.LIFE_FRAGMENT, Vector2(100, 100))
	item.collect()
	assert_true(_pool_has(AssetRegistry.sounds[Item.EXTEND_SFX]),
			"第 5 片合成完整残机 → 播 %s" % Item.EXTEND_SFX)


## 碎片没集满只是 +1 片 → 不播整命回报音（否则每片都响一声，反馈就贬值了）
func test_no_extend_sfx_before_completion():
	_clear_sfx_pool()
	var item := _make_item()
	item.setup(Item.Type.LIFE_FRAGMENT, Vector2(100, 100))
	item.collect()
	assert_false(_pool_has(AssetRegistry.sounds[Item.EXTEND_SFX]), "碎片没集满 → 不播整命回报音")


func test_life_full_item_plays_extend_sfx():
	_clear_sfx_pool()
	var item := _make_item()
	item.setup(Item.Type.LIFE_FULL, Vector2(100, 100))
	item.collect()
	assert_true(_pool_has(AssetRegistry.sounds[Item.EXTEND_SFX]),
			"整命道具 → 播 %s" % Item.EXTEND_SFX)


## 8 命上限：道具照旧被吃掉，但**没有真的多命** → 不播（回报音不许撒谎）
func test_life_full_item_at_cap_plays_no_extend_sfx():
	_player_resources.lives = 8
	_clear_sfx_pool()
	var item := _make_item()
	item.setup(Item.Type.LIFE_FULL, Vector2(100, 100))
	item.collect()
	assert_false(_pool_has(AssetRegistry.sounds[Item.EXTEND_SFX]), "已满命 → 不播整命回报音")


## 清空 SFX 池与同帧去重表（照 test_boss_ui 的做法），避免上一条用例的残留影响
func _clear_sfx_pool() -> void:
	for player in AudioManager._sfx_players:
		player.stop()
		player.stream = null
	AudioManager._played_this_frame.clear()


func _pool_has(stream: AudioStream) -> bool:
	for player in AudioManager._sfx_players:
		if player.stream == stream:
			return true
	return false


func test_collect_once_only():
	var item := _make_item()
	item.setup(Item.Type.POWER, Vector2(100, 100))
	item.collect()
	item.collect()  # 第二次无效（_is_dead 保护）
	assert_eq(_player_resources.power_raw, 1, "重复收集不叠加")

func test_item_pool_reuse():
	var pool: Node = load("res://scripts/item/item_pool.gd").new()
	pool.entity_registry = _entity_registry
	autofree(pool)
	add_child(pool)
	var it: Item = pool.spawn(Vector2(200, 200), Item.Type.POINT)
	assert_not_null(it, "池应能生成道具")
	assert_eq(it.item_type, Item.Type.POINT, "类型正确")
	assert_eq(it.global_position, Vector2(200, 200), "位置正确")


func _make_pool() -> ItemPool:
	var pool: ItemPool = load("res://scripts/item/item_pool.gd").new()
	pool.entity_registry = _entity_registry
	autofree(pool)
	add_child(pool)
	return pool


## 爆发宽限：在自机处撒出的道具**先飞出去**，宽限内不被吸附 —— 否则 miss 的 P 点扇形当帧就没了
func test_burst_grace_delays_auto_collect():
	_player.global_position = Vector2(200, 400)
	var item := _make_item()
	item.setup(Item.Type.POWER, Vector2(200, 400))
	item.burst(Vector2.UP, 300.0, 0.2)

	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(_player_resources.power_raw, 0, "宽限内不该被吸附收走")
	assert_lt(item.global_position.y, 400.0, "burst 沿给定方向飞出（向上 → y 减小）")

	for i in 40:
		await get_tree().physics_frame
	assert_eq(_player_resources.power_raw, 1, "宽限过后应被吸附收走（P 点 +1 火力）")


## miss 的 P 点扇形：一次撒出 10 个、全部沿各自弧向飞出（弧向由 fan_targets 保证）
func test_spawn_fan_in_pool_bursts_all_outward():
	_player.global_position = Vector2(448, 400)
	var origin := Vector2(448, 400)
	var pool := _make_pool()
	var targets := ItemService.fan_targets(10, origin, Vector2.UP, 180.0, 240.0, 80.0, 816.0)
	var spawned := ItemService.spawn_fan_in_pool(pool, Item.Type.POWER, origin, targets, 0.3)
	assert_eq(spawned, 10, "应撒出 10 个 P 点")

	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame  # 池生成的道具，物理从下一帧起生效
	var alive := 0
	var going_up := 0
	var radii: Array[float] = []
	for child in pool.get_children():
		if child is Item and child.visible:
			alive += 1
			var offset: Vector2 = child.global_position - origin
			radii.append(offset.length())
			assert_gt(offset.length(), 0.5, "宽限内应沿各自弧向飞离自机")
			if absf(offset.y) > 0.5:
				going_up += 1
				assert_lt(offset.y, 0.0, "中段方向一律向上")
	assert_eq(alive, 10, "池里应有 10 个可见 P 点")
	assert_eq(going_up, 8, "含两端点 → 8 个明确向上、2 个水平（正左 / 正右）")
	# 「绕自机为弧」= 同一时刻 10 个点**等半径**（都离自机同样远）→ 落在以自机为心的圆弧上
	for radius in radii:
		assert_almost_eq(radius, radii[0], 0.5, "10 个点应等半径（同一条圆弧）")


## 两段式：① 沿弧向飞 → ② 径向初速归零 → **竖直下落**（横向冻住，不再向外飘）
func test_burst_drops_straight_down_after_grace():
	_player.global_position = Vector2(2000, 2000)  # 自机放远，避免吸附干扰观察
	var item := _make_item()
	item.setup(Item.Type.POWER, Vector2(400, 200))
	item.burst(Vector2(1, -1).normalized(), 300.0, 0.15)  # 斜向右上飞 → 第一段 x 会变

	for i in 12:
		await get_tree().physics_frame
	var x_after_arc: float = item.global_position.x
	var y_after_arc: float = item.global_position.y
	assert_gt(x_after_arc, 400.0, "第一段应沿给定方向飞（斜向右上 → x 增大）")
	assert_lt(y_after_arc, 200.0, "第一段应向上飞（y 减小）")

	for i in 30:
		await get_tree().physics_frame
	assert_almost_eq(item.global_position.x, x_after_arc, 0.001, "第二段横向冻住 = 竖直下落")
	assert_gt(item.global_position.y, y_after_arc, "第二段应向下落")


## 左右不出框：目标点横坐标一律夹在 [x_min, x_max]；贴墙时**靠墙一侧压扁、纵向半径不变**
func test_fan_targets_stay_inside_x_bounds():
	var radius := 240.0
	var x_min := 80.0
	var x_max := 816.0

	# ① 场地中央：不触发夹取 → 仍是完整均匀半圆（等半径、两端点 = 正左 / 正右）
	var center := Vector2(448.0, 400.0)
	var centered := ItemService.fan_targets(10, center, Vector2.UP, 180.0, radius, x_min, x_max)
	assert_eq(centered.size(), 10, "10 个目标点")
	for target in centered:
		assert_almost_eq((target - center).length(), radius, 0.001, "中央时不夹取 → 等半径")
	assert_almost_eq(centered[0].x, center.x - radius, 0.001, "左端点 = 正左（完整半径）")
	assert_almost_eq(centered[9].x, center.x + radius, 0.001, "右端点 = 正右（完整半径）")

	# ② 贴左墙：左侧压到边界、右侧保持完整半径，纵向（弧高）不变
	var at_left := Vector2(x_min, 400.0)
	var left_targets := ItemService.fan_targets(10, at_left, Vector2.UP, 180.0, radius, x_min, x_max)
	for target in left_targets:
		assert_true(target.x >= x_min and target.x <= x_max,
				"目标点必须留在框内：x=%.1f" % target.x)
	assert_almost_eq(left_targets[0].x, x_min, 0.001, "最左那颗压到左边界（不再出框）")
	assert_almost_eq(left_targets[0].y, at_left.y, 0.001, "最左那颗纵向不动 → 停在自机同高的边界上")
	assert_almost_eq(left_targets[9].x, at_left.x + radius, 0.001, "右侧不受影响，仍是完整半径")
	assert_almost_eq(left_targets[4].y, at_left.y - radius * cos(deg_to_rad(10.0)), 0.001,
			"纵向半径不变（只压横向）")

	# ③ 贴右墙：镜像成立
	var at_right := Vector2(x_max, 400.0)
	var right_targets := ItemService.fan_targets(10, at_right, Vector2.UP, 180.0, radius, x_min, x_max)
	for target in right_targets:
		assert_true(target.x >= x_min and target.x <= x_max,
				"目标点必须留在框内：x=%.1f" % target.x)
	assert_almost_eq(right_targets[9].x, x_max, 0.001, "最右那颗压到右边界")
	assert_almost_eq(right_targets[0].x, at_right.x - radius, 0.001, "左侧不受影响")


## 弧向几何：以「正上」为中轴、张角 180° → 正左 → 正上 → 正右，含两端点、相邻 20°（180/9）
func test_fan_directions_uniform_upward_arc():
	var dirs := ItemService.fan_directions(10, Vector2.UP, 180.0)
	assert_eq(dirs.size(), 10, "10 个方向")
	for dir in dirs:
		assert_almost_eq(dir.length(), 1.0, 0.001, "应为单位向量")
	for i in range(1, 9):
		assert_lt(dirs[i].y, 0.0, "中段方向一律朝上")
	assert_almost_eq(dirs[0].x, -1.0, 0.001, "左端点 = 正左")
	assert_almost_eq(dirs[0].y, 0.0, 0.001, "左端点水平")
	assert_almost_eq(dirs[9].x, 1.0, 0.001, "右端点 = 正右")
	assert_almost_eq(dirs[9].y, 0.0, 0.001, "右端点水平")
	# 10 个点（偶数）含两端点 → 正中**没有**采样点，两侧各偏 10°；整体关于正上轴对称
	var side_y := -cos(deg_to_rad(10.0))
	assert_almost_eq(dirs[4].y, side_y, 0.001, "中轴左侧最近点偏 10°")
	assert_almost_eq(dirs[5].y, side_y, 0.001, "中轴右侧最近点偏 10°")
	for i in range(10):
		assert_almost_eq(dirs[i].x, -dirs[9 - i].x, 0.001, "关于正上轴对称（x）")
		assert_almost_eq(dirs[i].y, dirs[9 - i].y, 0.001, "关于正上轴对称（y）")
	for i in range(9):
		var step := absf(rad_to_deg(dirs[i].angle_to(dirs[i + 1])))
		assert_almost_eq(step, 20.0, 0.01, "相邻夹角应为 20°（均匀）")

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

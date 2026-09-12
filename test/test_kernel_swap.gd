extends GutTest
## 内核路由（W4a-2 起内核唯一后端）：内核池 + 渲染数据源 + 行为装配 + bomb 宿主节点。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const REIMU_DATA = preload("res://data/player_data/reimu_data.tres")


func before_each() -> void:
	# W4c：不再有 autoload，用例自建弹幕世界
	var bm := BulletManager.new()
	bm.name = "BulletManager"
	add_child_autofree(bm)


func after_each() -> void:
	BulletManager.current.clear_all()
	BulletManager.current.inject_world_refs(null)


func _enemy_data() -> BulletData:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return d


func test_spawn_writes_kernel_pool() -> void:
	assert_not_null(BulletManager.current.kernel_system(), "内核弹池应已装配")
	BulletManager.current.shoot_enemy_bullet(_enemy_data(), Vector2(100, 100), Vector2.RIGHT)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "应写进内核池")


func test_kernel_cull_rect_set_to_field() -> void:
	assert_eq(BulletManager.current.kernel_system().cull_rect, Rect2(
		GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP), "剔除范围应对齐东方框")
	assert_gt(BulletManager.current.kernel_system().cull_margin, 0.0, "应有剔除余量")


func test_kernel_priority_precedes_manager() -> void:
	assert_lt(BulletManager.current.kernel_system().process_physics_priority,
		BulletManager.current.process_physics_priority, "内核积分必须先于宿主碰撞（§16.3）")


func test_behavior_pipeline_wired() -> void:
	var b: BehaviorProcessor = BulletManager.current._kernel.behavior
	assert_not_null(b, "应装配 BehaviorProcessor")
	assert_gt(b.process_physics_priority, BulletManager.current.kernel_system().process_physics_priority,
		"行为必须在积分之后（-10 < -5）")
	assert_lt(b.process_physics_priority, BulletManager.current.process_physics_priority,
		"行为必须在宿主碰撞之前（-5 < 0）")


func test_bomb_continuously_clears_nearby_enemy_bullets() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.player_data = REIMU_DATA
	add_child_autofree(player)
	player.global_position = Vector2(448, 700)
	var refs := EntityRegistry.new()
	refs.bind_player(player)
	BulletManager.current.inject_world_refs(refs)
	var ed := BulletData.new().enemy().tex("小玉")
	ed.velocity = Vector2.UP * 10.0
	BulletManager.current.shoot_enemy_bullet(ed, Vector2(448, 700), Vector2.UP)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "先有 1 颗敌弹")
	var d := BulletData.new().tex("bomb01_white").bomb()
	var bomb = BulletManager.current.shoot_bomb_bullet(d, Vector2(448, 700), Vector2.RIGHT)
	bomb._physics_process(1.0 / 60.0)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 0, "bomb 周围敌弹应被持续清")


func test_bomb_spawns_host_node() -> void:
	var d := BulletData.new().tex("bomb01_white").bomb()
	d.params = {"spawn_delay": 0.1}
	var node = BulletManager.current.shoot_bomb_bullet(d, Vector2(448, 700), Vector2.RIGHT)
	assert_not_null(node, "内核 bomb 应返回宿主节点")
	assert_true(node is Node2D, "应是 Node2D")
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 0, "bomb 不应进内核池")
	assert_almost_eq(node.spawn_delay, 0.1, 0.001, "应读 params.spawn_delay")


func test_radial_accel_via_manager() -> void:
	var d := BulletData.new().enemy().blend(true).tex("棱弹")
	d.velocity = Vector2.UP * 300.0
	d.coroutine_script = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")
	BulletManager.current.shoot_enemy_bullet(d, Vector2(300, GameConfig.FIELD_TOP + 20.0), Vector2.UP)
	for i in 10:
		await get_tree().physics_frame
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(BulletManager.current.kernel_system().get_velocity(0).y, 0.0, "换成了向下弹")


func test_death_clear_sweeps_kernel_bullets() -> void:
	BulletManager.current.shoot_enemy_bullet(_enemy_data(), Vector2(200, 200), Vector2.RIGHT)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "先有 1 颗内核敌弹")
	BulletManager.current.start_death_clear(Vector2(200, 200), 100.0, 1.0, 30.0)
	BulletManager.current._death_clear.process(0.5)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 0, "展开清弹圈应清掉内核敌弹")

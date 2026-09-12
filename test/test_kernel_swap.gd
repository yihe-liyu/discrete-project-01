extends GutTest
## 内核路由（W4a-1 起 use_kernel 默认 true）：内核池 + 渲染数据源 + 行为装配 + F2 回滚旧池。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const REIMU_DATA = preload("res://data/player_data/reimu_data.tres")


func after_each() -> void:
	BulletManager.set_use_kernel(false)
	BulletManager.clear_all()


func _enemy_data() -> BulletData:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return d


func test_swap_routes_spawn_to_kernel() -> void:
	BulletManager.set_use_kernel(true)
	assert_not_null(BulletManager.kernel_system(), "切到内核应建出内核弹池")
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2(100, 100), Vector2.RIGHT)
	assert_eq(BulletManager.kernel_system().get_active_count(), 1, "应写进内核池")
	assert_eq(BulletManager.active_bullets.size(), 0, "不应再写旧池")


func test_kernel_cull_rect_set_to_field() -> void:
	BulletManager.set_use_kernel(true)
	assert_eq(BulletManager.kernel_system().cull_rect, Rect2(
		GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP), "剔除范围应对齐东方框")
	assert_gt(BulletManager.kernel_system().cull_margin, 0.0, "应有剔除余量")


func test_swap_back_clears_kernel_and_restores_legacy() -> void:
	BulletManager.set_use_kernel(true)
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	BulletManager.set_use_kernel(false)
	assert_eq(BulletManager.kernel_system().get_active_count(), 0, "切回旧路应清空内核池")
	var before: int = BulletManager.active_bullets.size()
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	assert_eq(BulletManager.active_bullets.size(), before + 1, "切回旧路应写旧池")


func test_kernel_priority_precedes_manager() -> void:
	BulletManager.set_use_kernel(true)
	assert_lt(BulletManager.kernel_system().process_physics_priority,
		BulletManager.process_physics_priority, "内核积分必须先于宿主碰撞（§16.3）")


## S4a：切内核应装配行为处理器，且帧序在积分之后、宿主碰撞之前。
func test_behavior_pipeline_wired() -> void:
	BulletManager.set_use_kernel(true)
	var b: BehaviorProcessor = BulletManager._kernel.behavior
	assert_not_null(b, "切内核应装配 BehaviorProcessor")
	assert_gt(b.process_physics_priority, BulletManager.kernel_system().process_physics_priority,
		"行为必须在积分之后（-10 < -5）")
	assert_lt(b.process_physics_priority, BulletManager.process_physics_priority,
		"行为必须在宿主碰撞之前（-5 < 0）")


## S4d：bomb 持续清弹——每颗 bomb 周围半径内的敌弹被清（不是以自机为中心）。
func test_bomb_continuously_clears_nearby_enemy_bullets() -> void:
	BulletManager.set_use_kernel(true)
	var player := PLAYER_SCENE.instantiate()
	player.player_data = REIMU_DATA
	add_child_autofree(player)
	player.global_position = Vector2(448, 700)
	var prev: Player = GameState.player
	GameState.player = player
	var ed := BulletData.new().enemy().tex("小玉")
	ed.velocity = Vector2.UP * 10.0
	BulletManager.shoot_enemy_bullet(ed, Vector2(448, 700), Vector2.UP)
	assert_eq(BulletManager.kernel_system().get_active_count(), 1, "先有 1 颗敌弹")
	var d := BulletData.new().tex("bomb01_white").bomb()
	d.coroutine_script = preload("res://scripts/bullet/bomb_behavior.gd")
	var bomb = BulletManager.shoot_bomb_bullet(d, Vector2(448, 700), Vector2.RIGHT)
	bomb._physics_process(1.0 / 60.0)
	assert_eq(BulletManager.kernel_system().get_active_count(), 0, "bomb 周围敌弹应被持续清")
	GameState.player = prev


## S4d：bomb 走宿主节点（不进内核池）——out_grace 缘由见 docs §21.17。
func test_bomb_spawns_host_node() -> void:
	BulletManager.set_use_kernel(true)
	var d := BulletData.new().tex("bomb01_white").bomb()
	d.coroutine_script = preload("res://scripts/bullet/bomb_behavior.gd")
	d.params = {"spawn_delay": 0.1}
	var node = BulletManager.shoot_bomb_bullet(d, Vector2(448, 700), Vector2.RIGHT)
	assert_not_null(node, "内核 bomb 应返回宿主节点")
	assert_true(node is Node2D, "应是 Node2D")
	assert_eq(BulletManager.kernel_system().get_active_count(), 0, "bomb 不应进内核池")
	assert_almost_eq(node.spawn_delay, 0.1, 0.001, "应读 params.spawn_delay")


## S4c-1：走真实 BulletManager 路径（_enable_kernel 装配）验证 radial_accel 顶边换弹。
func test_radial_accel_via_manager() -> void:
	BulletManager.set_use_kernel(true)
	var d := BulletData.new().enemy().blend(true).tex("棱弹")
	d.velocity = Vector2.UP * 300.0
	d.coroutine_script = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")
	BulletManager.shoot_enemy_bullet(d, Vector2(300, GameConfig.FIELD_TOP + 20.0), Vector2.UP)
	for i in 10:
		await get_tree().physics_frame
	assert_eq(BulletManager.kernel_system().get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(BulletManager.kernel_system().get_velocity(0).y, 0.0, "换成了向下弹")


## S3d：展开清弹圈（死亡清弹）应清掉内核敌弹。
func test_death_clear_sweeps_kernel_bullets() -> void:
	BulletManager.set_use_kernel(true)
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2(200, 200), Vector2.RIGHT)
	assert_eq(BulletManager.kernel_system().get_active_count(), 1, "先有 1 颗内核敌弹")
	BulletManager.start_death_clear(Vector2(200, 200), 100.0, 1.0, 30.0)
	BulletManager._death_clear.process(0.5)   # 半径 30→100 走到 65，覆盖 (200,200)
	assert_eq(BulletManager.kernel_system().get_active_count(), 0, "展开清弹圈应清掉内核敌弹")


## S3d：旧池路径的死亡清弹保持原样（注入扫掠在旧池下返回 false）。
func test_death_clear_legacy_path_unchanged() -> void:
	BulletManager.set_use_kernel(false)
	BulletManager.shoot_enemy_bullet(_enemy_data(), Vector2(200, 200), Vector2.RIGHT)
	assert_eq(BulletManager.active_bullets.size(), 1, "旧池先有 1 颗弹")
	BulletManager.start_death_clear(Vector2(200, 200), 100.0, 1.0, 30.0)
	BulletManager._death_clear.process(0.5)
	assert_eq(BulletManager.active_bullets.size(), 0, "旧池路径清弹应仍生效")

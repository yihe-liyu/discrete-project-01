extends GutTest
## KernelBulletPhysics —— 敌弹 ↔ 自机（命中 + 擦弹），规则与旧 BulletPhysics 1:1。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
## 夹具自建（机制测试不绑内容 —— 见 docs/TEST_INDEX.md「内容绑定契约」）
const FIXTURES = preload("res://test/fixtures/fixture_lib.gd")


## 轻量假敌人：只实现本层用到的字段/方法（免依赖完整 Enemy/Boss 场景）。
class FakeEnemy extends Node2D:
	var hitbox_radius: float = 20.0
	var damage_taken: float = 0.0

	func take_damage(d: float) -> void:
		damage_taken += d

var _kernel_bullet_host: KernelBulletHost
var _kernel_bullet_physics: KernelBulletPhysics
var _player: Player
var _entity_registry: EntityRegistry
var _prev_memory: float
var _prev_graze: int
var _prev_lives: int


func before_each() -> void:
	_kernel_bullet_host = KernelBulletHost.new()
	add_child_autofree(_kernel_bullet_host)
	_kernel_bullet_physics = KernelBulletPhysics.new()
	_kernel_bullet_physics.setup(_kernel_bullet_host)
	_player = PLAYER_SCENE.instantiate()
	_player.player_data = FIXTURES.player_data()
	add_child_autofree(_player)
	_player.global_position = Vector2(448, 640)
	_player.is_invincible = false
	_entity_registry = EntityRegistry.new()
	_entity_registry.bind_player(_player)
	_kernel_bullet_physics.entity_registry = _entity_registry
	_prev_memory = _player.resources.memory_value
	_prev_graze = _player.resources.graze_count
	_prev_lives = _player.resources.lives
	_player.resources.memory_value = 0.0    # 关闭擦弹随机清弹（>=50 才触发）
	_player.resources.graze_count = 0


func after_each() -> void:
	_player.resources.memory_value = _prev_memory
	_player.resources.graze_count = _prev_graze
	_player.resources.lives = _prev_lives


func _enemy_bullet_at(pos: Vector2) -> int:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return _kernel_bullet_host.shoot(d, pos, Vector2.RIGHT)


func test_bullet_on_player_is_hit() -> void:
	_enemy_bullet_at(_player.global_position)
	_kernel_bullet_physics.process()
	assert_eq(_kernel_bullet_host.system.get_active_count(), 0, "命中后该弹应被回收")
	assert_true(_player.is_invincible, "miss() 应进入无敌")


func test_bullet_within_graze_is_grazed() -> void:
	# 命中阈值 = 自机 5 + 弹 6 = 11；擦弹阈值 = 40 + 6 = 46 → 放在 30 处只擦不中
	var id := _enemy_bullet_at(_player.global_position + Vector2(30, 0))
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "应计 1 次擦弹")
	assert_eq(_kernel_bullet_host.system.get_active_count(), 1, "擦弹不回收该弹（随机清弹已关）")
	assert_true(_kernel_bullet_host.system.is_grazed(id), "应标记为已擦弹")


func test_graze_not_counted_twice() -> void:
	_enemy_bullet_at(_player.global_position + Vector2(30, 0))
	_kernel_bullet_physics.process()
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "同一弹不应重复计擦弹")


## 高速弹在两次采样之间穿过自机：帧末位置在判定圈外，扫掠判定必须命中。
func test_fast_bullet_is_swept_hit() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.DOWN * 12000.0
	_kernel_bullet_host.shoot(d, Vector2(448, 500), Vector2.DOWN)
	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_true(_player.is_invincible, "高速弹扫过自机应判定命中")
	assert_eq(_kernel_bullet_host.system.get_active_count(), 0, "命中后应回收该弹")


## 高速弹从擦弹环外穿过：扫掠应计擦弹（仍保持每弹一次）。
func test_fast_bullet_is_swept_graze() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.DOWN * 12000.0
	var id := _kernel_bullet_host.shoot(d, Vector2(478, 500), Vector2.DOWN)
	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "高速弹擦过应计 1 次擦弹")
	assert_true(_kernel_bullet_host.system.is_grazed(id), "扫掠擦弹也应标记已擦")


## 扫掠不应把远离的弹误判为命中/擦弹。
func test_fast_bullet_far_away_is_ignored() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.DOWN * 12000.0
	_kernel_bullet_host.shoot(d, Vector2(748, 500), Vector2.DOWN)
	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_false(_player.is_invincible, "远离的弹不应命中")
	assert_eq(_player.resources.graze_count, 0, "远离的弹不应擦弹")


func test_invincible_player_ignores_bullets() -> void:
	_player.is_invincible = true
	_enemy_bullet_at(_player.global_position)
	_kernel_bullet_physics.process()
	assert_eq(_kernel_bullet_host.system.get_active_count(), 1, "无敌时弹应穿过")


func test_player_bullet_damages_enemy_via_bullet_type() -> void:
	var fake := FakeEnemy.new()
	fake.global_position = Vector2(200, 200)
	add_child_autofree(fake)
	_entity_registry.register_enemy(fake)
	_player.resources.memory_value = 100.0   # 关掉记忆加成（<50 才生效）
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 100.0
	d.damage = 10.0
	_kernel_bullet_host.shoot(d, Vector2(200, 200), Vector2.UP)
	_kernel_bullet_physics.process()
	assert_almost_eq(fake.damage_taken, 10.0, 0.01, "伤害应来自 BulletType.damage（内核自带）")
	assert_eq(_kernel_bullet_host.system.get_active_count(), 0, "命中后应回收该弹")
	_entity_registry.unregister_enemy(fake)


## 活跃真弹数：排除出生雾 / 消弹留下的纯特效行（_type_index < 0）。
func _live_bullets() -> int:
	var sys := _kernel_bullet_host.system
	var types: PackedInt32Array = sys.get_type_indices()
	var live := 0
	for i in sys.get_active_count():
		if types[i] >= 0:
			live += 1
	return live


## 死亡清弹扫掠只清圆内敌弹（与旧 DeathClear 逐弹循环 1:1）。
func test_sweep_enemy_bullets_clears_only_in_radius() -> void:
	_enemy_bullet_at(Vector2(200, 200))
	_enemy_bullet_at(Vector2(900, 900))
	_kernel_bullet_physics.sweep_enemy_bullets(Vector2(200, 200), 100.0)
	assert_eq(_live_bullets(), 1, "死亡清弹应只清圆内的敌弹")
	assert_gt(_kernel_bullet_host.system.get_active_count(), _live_bullets(), "原地应留一条消散特效行")
	assert_eq(_kernel_bullet_host.system.get_position(0), Vector2(900, 900), "圆外弹应保留（swap-with-last 后落 0 槽）")


## 死亡清弹不应误伤自机弹。
func test_sweep_enemy_bullets_spares_player_bullets() -> void:
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 100.0
	_kernel_bullet_host.shoot(d, Vector2(200, 200), Vector2.UP)
	_enemy_bullet_at(Vector2(200, 200))
	_kernel_bullet_physics.sweep_enemy_bullets(Vector2(200, 200), 100.0)
	assert_eq(_live_bullets(), 1, "死亡清弹不应清自机弹")
	assert_eq(_kernel_bullet_host.system.get_type(0).faction, BulletType.Faction.PLAYER, "留下的应是自机弹")


## D2：擦弹应按 tick 重新可计；同一颗弹跨 tick 仍贴近时，下一 tick 应再次计数。
func test_graze_can_repeat_across_ticks() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.ZERO
	var pos: Vector2 = _player.global_position + Vector2(20, 0)
	var id := _kernel_bullet_host.shoot(d, pos, Vector2.ZERO)
	_kernel_bullet_host.system.set_graze_interval_ticks(1)

	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "第一 tick 应计一次擦弹")
	assert_true(_kernel_bullet_host.system.is_grazed(id), "当前 tick 应标记已擦")

	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 2, "跨 tick 仍贴近应再次计擦弹")
	assert_true(_kernel_bullet_host.system.is_grazed(id), "新 tick 应重新标记已擦")


## 擦弹间隔：默认 6 tick；同一颗弹在冷却内不应重复计数。
func test_graze_respects_interval() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.ZERO
	var pos: Vector2 = _player.global_position + Vector2(20, 0)
	_kernel_bullet_host.shoot(d, pos, Vector2.ZERO)
	_kernel_bullet_host.system.set_graze_interval_ticks(6)

	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "第一 tick 计一次")

	_kernel_bullet_host.system.step(1.0 / 60.0)
	_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 1, "间隔内不应重复计擦弹")

	for _i in 5:
		_kernel_bullet_host.system.step(1.0 / 60.0)
		_kernel_bullet_physics.process()
	assert_eq(_player.resources.graze_count, 2, "满 6 tick 后应再次计擦弹")


## NativeBehavior 最小 pack：linear 必须与普通直线弹逐帧位置一致。
func test_native_linear_behavior_matches_program() -> void:
	_kernel_bullet_host.setup_behaviors(null, Callable())
	var bid := _kernel_bullet_host.system.get_behavior_id("linear")
	assert_gt(bid, -1, "linear behavior 应已注册")
	var d := BulletData.new().enemy().tex("小玉")
	d.velocity = Vector2.DOWN * 120.0
	var plain := _kernel_bullet_host.shoot(d, Vector2(400, 300), Vector2.DOWN)
	var native := _kernel_bullet_host.shoot(d, Vector2(600, 300), Vector2.DOWN)
	assert_true(_kernel_bullet_host.system.set_behavior(native, bid), "应能绑定 linear")
	assert_eq(_kernel_bullet_host.system.get_behavior(native), bid, "行应记录 behavior id")
	for _i in 60:
		_kernel_bullet_host.system.step(1.0 / 60.0)
	var p0: Vector2 = _kernel_bullet_host.system.get_position(plain)
	var p1: Vector2 = _kernel_bullet_host.system.get_position(native)
	var delta: Vector2 = p1 - p0
	assert_almost_eq(delta, Vector2(200, 0), Vector2(0.01, 0.01), "linear 行为不应改变运动")


## 内核逐弹表现属性：颜色 / 渲染朝向 / 判定盒的 get-set 对齐。
func test_native_bullet_visual_attributes() -> void:
	var d := BulletData.new().enemy().tex("小玉")
	d.hitbox_radius = 7.0
	d.hitbox_offset = Vector2(2, 3)
	d.follow_dir = false
	var id := _kernel_bullet_host.shoot(d, Vector2(300, 300), Vector2.DOWN)

	_kernel_bullet_host.system.set_color(id, Color.RED)
	assert_eq(_kernel_bullet_host.system.get_color(id), Color.RED, "set_color 应写回")

	_kernel_bullet_host.system.set_render_rot(id, 1.25)
	assert_almost_eq(_kernel_bullet_host.system.get_render_rot(id), 1.25, 0.0001, "set_render_rot 应写回")

	var hb: Dictionary = _kernel_bullet_host.system.get_hitbox(id)
	assert_almost_eq(float(hb.get("radius", 0.0)), 7.0, 0.0001, "get_hitbox.radius")
	assert_eq(hb.get("offset"), Vector2(2, 3), "get_hitbox.offset")
	assert_eq(hb.get("follow_dir"), false, "get_hitbox.follow_dir")


## 其余逐弹属性：wrap / spin / elapsed / behavior state+params。
func test_native_bullet_remaining_attributes() -> void:
	_kernel_bullet_host.setup_behaviors(null, Callable())
	var d := BulletData.new().enemy().tex("小玉").no_spawn_fog()
	var id := _kernel_bullet_host.shoot(d, Vector2(300, 300), Vector2.DOWN)
	_kernel_bullet_host.system.set_wrap(id, 5)
	assert_eq(_kernel_bullet_host.system.get_wrap(id), 5, "wrap 应写回")
	_kernel_bullet_host.system.set_spin_rot(id, 0.75)
	assert_almost_eq(_kernel_bullet_host.system.get_spin_rot(id), 0.75, 0.0001, "spin_rot 应写回")

	var bid := _kernel_bullet_host.system.get_behavior_id("linear")
	assert_true(_kernel_bullet_host.system.set_behavior(id, bid), "应能绑定 linear")
	assert_eq(_kernel_bullet_host.system.get_behavior_state(id).size(), 8, "state 固定 8 槽")
	assert_eq(_kernel_bullet_host.system.get_behavior_params(id).size(), 8, "params 固定 8 槽")

	_kernel_bullet_host.system.step(1.0 / 60.0)
	assert_gt(_kernel_bullet_host.system.get_elapsed(id), 0.0, "behavior 也应累计 elapsed")


## 内容桥接 + homing pack：BulletData.behavior 应自动绑定并真正转向自机。
func test_native_homing_behavior_content_bridge() -> void:
	_kernel_bullet_host.setup_behaviors(_player, Callable())
	var spec := BehaviorSpec.new(&"homing", PackedFloat32Array([120.0, 600.0]))
	var d := BulletData.new().enemy().tex("小玉").no_spawn_fog().with_behavior(spec)
	d.velocity = Vector2.ZERO
	var id := _kernel_bullet_host.shoot(d, Vector2(448, 300), Vector2.RIGHT)
	assert_gt(id, -1, "应能发射")
	var bid := _kernel_bullet_host.system.get_behavior_id("homing")
	assert_eq(_kernel_bullet_host.system.get_behavior(id), bid, "BulletData.behavior 应自动绑定")

	for _i in 30:
		_kernel_bullet_host.system.step(1.0 / 60.0)
	assert_gt(_kernel_bullet_host.system.get_position(id).y, 300.0, "homing 应开始向自机（下方）移动")
	assert_gt(_kernel_bullet_host.system.get_velocity(id).length(), 0.0, "homing 应产生速度")


## 第一张内容迁移：enemy 的 accel_world 与 native accel 逐帧一致。
func test_native_accel_matches_lifecycle() -> void:
	_kernel_bullet_host.setup_behaviors(null, Callable())
	var lc_data := BulletData.new().enemy().tex("棱弹").no_spawn_fog()
	lc_data.lifecycle = BulletLifecycle.new().accel_world(Vector2(0, 200))
	lc_data.velocity = Vector2(0, 175)
	var bh_data := BulletData.new().enemy().tex("棱弹").no_spawn_fog()
	bh_data.with_behavior(BehaviorSpec.new(&"accel", PackedFloat32Array([0, 200])))
	bh_data.velocity = Vector2(0, 175)

	var lc_id := _kernel_bullet_host.shoot(lc_data, Vector2(400, 300), Vector2.DOWN)
	var bh_id := _kernel_bullet_host.shoot(bh_data, Vector2(600, 300), Vector2.DOWN)
	assert_eq(_kernel_bullet_host.system.get_behavior(bh_id), _kernel_bullet_host.system.get_behavior_id("accel"))

	for _i in 60:
		_kernel_bullet_host.system.step(1.0 / 60.0)

	var lc_delta: Vector2 = _kernel_bullet_host.system.get_position(lc_id) - Vector2(400, 300)
	var bh_delta: Vector2 = _kernel_bullet_host.system.get_position(bh_id) - Vector2(600, 300)
	assert_almost_eq(bh_delta, lc_delta, Vector2(0.01, 0.01), "accel pack 应与 lifecycle 轨迹一致")


## bounce_emit Outcome：撞墙请求 emit，host 按模板真正 spawn 子弹出，父弹回收。
func test_native_bounce_emit_spawns_template() -> void:
	_kernel_bullet_host.setup_behaviors(_player, Callable())
	var child_data := BulletData.new().enemy().tex("米弹").no_spawn_fog()
	child_data.velocity = Vector2(0, 120)
	var tpl := EmitTemplate.new(&"rebound_test", child_data)
	assert_true(_kernel_bullet_host.system.register_emit_template(tpl), "模板应注册")

	var parent_data := BulletData.new().enemy().tex("棱弹").no_spawn_fog()
	parent_data.velocity = Vector2.ZERO
	parent_data.with_behavior(BehaviorSpec.new(&"bounce_emit", PackedFloat32Array([tpl.numeric_id, 120.0])))
	var id := _kernel_bullet_host.shoot(parent_data, Vector2(GameConfig.FIELD_LEFT, 300), Vector2.ZERO)
	assert_eq(_kernel_bullet_host.system.get_behavior(id), _kernel_bullet_host.system.get_behavior_id("bounce_emit"))

	_kernel_bullet_host.system.step(1.0 / 60.0)
	assert_eq(_kernel_bullet_host.system.get_active_count(), 1, "父弹应回收，子弹出应存在")
	var child_type := _kernel_bullet_host.system.get_type_index(0)
	assert_not_null(_kernel_bullet_host.texture_for_index(child_type), "同帧增删后子弹出仍必须有纹理")


## 从场内自然飞到上墙：bounce_emit 必须自己触发，而不是测试直接放在墙边。
func test_native_bounce_emit_hits_wall_naturally() -> void:
	_kernel_bullet_host.setup_behaviors(_player, Callable())
	var child_data := BulletData.new().enemy().tex("米弹").no_spawn_fog()
	child_data.velocity = Vector2(0, 120)
	var tpl := EmitTemplate.new(&"rebound_natural", child_data)
	assert_true(_kernel_bullet_host.system.register_emit_template(tpl), "模板应注册")

	var parent_data := BulletData.new().enemy().tex("棱弹").no_spawn_fog()
	parent_data.velocity = Vector2(0, -300)
	parent_data.with_behavior(BehaviorSpec.new(&"bounce_emit", PackedFloat32Array([tpl.numeric_id, 0.0, 0.0, 0.0])))
	var _id := _kernel_bullet_host.shoot(parent_data, Vector2(448, 500), Vector2.UP)
	for _i in 120:
		_kernel_bullet_host.system.step(1.0 / 60.0)
	assert_eq(_kernel_bullet_host.system.get_active_count(), 1, "飞抵上墙后父弹应回收、子弹出应存在")

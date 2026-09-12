extends GutTest
## S4a：行为管道 + world_accel + 内容端口契约（见 docs/NEW_KERNEL_REFACTOR_PLAN.md §21）。

const GRAVITY_BULLET = preload("res://data/stages/stage01/bullet/gravity_bullet.gd")
const MOVE_HOMING = preload("res://scripts/coroutine/player/move_homing.gd")
const NO_PORT = preload("res://test/fixtures/no_port_behavior.gd")
const RADIAL_ACCEL = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")
const BOUNCE_BULLET = preload("res://data/stages/stage01/bullet/bounce_bullet.gd")
const NON_MID = preload("res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd")

var _backend: KernelBulletBackend
var _saved_enemies: Array = []
var _saved_difficulty: int = 1


func before_each() -> void:
	_saved_enemies = GameState.active_enemies.duplicate()
	GameState.active_enemies.clear()   # 保证「无 Boss」分支确定
	_saved_difficulty = GameState.selected_difficulty
	_backend = KernelBulletBackend.new()
	add_child_autofree(_backend)
	_backend.setup_behaviors(null, Callable())


func after_each() -> void:
	GameState.active_enemies.clear()
	GameState.active_enemies.append_array(_saved_enemies)
	GameState.selected_difficulty = _saved_difficulty


func _enemy(tex := "小玉") -> BulletData:
	var d := BulletData.new().enemy().tex(tex)
	d.spawn_fog = false
	return d


## 世界 accel：行为只改 velocity，位置由系统积分（别双倍）。
func test_world_accel_changes_velocity() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 1000.0
	d.accel = Vector2(0, 500.0)
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var before: Vector2 = _backend.system.get_velocity(0)
	_backend.system._physics_process(0.1)
	_backend.behavior.process()
	var after: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 50.0, 0.01, "世界 accel 应给速度 +a·dt")
	assert_almost_eq(after.x, before.x, 0.01, "x 分量不应变")


## 内容端口：gravity_bullet.kernel_port() → world_accel。
func test_gravity_port_maps_to_world_accel() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = GRAVITY_BULLET
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var slot: int = _backend.system.get_behavior_id(0)
	assert_eq(_backend.system.get_move_name(slot), &"world_accel", "gravity_bullet 端口应映射到 world_accel")
	var before: Vector2 = _backend.system.get_velocity(0)
	_backend.system._physics_process(0.5)
	_backend.behavior.process()
	var after: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 200.0 * 0.5, 0.01, "默认 gravity=200 → 向下加速")


## BulletData.accel（无 coroutine）直接映射 world_accel。
func test_accel_field_without_coroutine_maps() -> void:
	var d := _enemy()
	d.velocity = Vector2.RIGHT * 100.0
	d.accel = Vector2(0, 100.0)
	_backend.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"world_accel",
		"BulletData.accel 应映射到 world_accel")


## 无端口的行为：计数 + 直线（夹具，不依赖内容进度）。
func test_unmapped_behavior_counted_and_straight() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = NO_PORT
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_backend.unmapped_behavior_count, 1, "无端口的行为应计数")
	assert_eq(_backend.system.get_behavior_id(0), BulletSystem.BEHAVIOR_NONE, "未映射应无行为（直线）")


## S4b：move_homing 端口 → homing；有敌人时朝它偏转。
func test_homing_turns_toward_enemy() -> void:
	var fake := Node2D.new()
	fake.global_position = Vector2(500, 0)
	add_child_autofree(fake)
	_backend.setup_behaviors(null, func() -> Array: return [fake])
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 500.0
	d.coroutine_script = MOVE_HOMING
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"homing",
		"move_homing 端口应映射 homing")
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	var v: Vector2 = _backend.system.get_velocity(0)
	assert_gt(v.x, 0.0, "应朝右侧敌人偏转")
	assert_almost_eq(v.length(), 512.5, 1.0, "速度量级 ≈ lerp(min_speed, top_speed, dt/accel_time)")


## S4c-3：TRAVEL → 靠近自机 → FLEE（沿远离方向）。
func test_non_mid_flees_from_player() -> void:
	var player := Node2D.new()
	player.global_position = Vector2(100, 100)
	add_child_autofree(player)
	_backend.setup_behaviors(player, Callable())
	var d := _enemy()
	d.velocity = Vector2.RIGHT * 100.0
	d.coroutine_script = NON_MID
	_backend.shoot(d, Vector2(80, 100), Vector2.RIGHT)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"non_mid_flee",
		"non_mid01_bullet 端口应映射 non_mid_flee")
	for i in 3:
		_backend.system._physics_process(1.0 / 60.0)
		_backend.behavior.process()
	assert_eq(_backend.system.get_behavior_phase(0), 1, "应进入 FLEE")
	assert_lt(_backend.system.get_velocity(0).x, 0.0, "应朝远离自机（左）飞")


## S4c-3：内容回调——近 Boss 散圈（入队后 flush）。
func test_non_mid_burst_queues_ring() -> void:
	GameState.selected_difficulty = 1   # Normal
	var probe = NON_MID.new()
	autofree(probe)
	var port: Dictionary = probe.kernel_port()
	var cb: Callable = port["params"][&"on_flee_burst"]
	assert_true(cb.is_valid(), "端口应给散圈回调")
	var ok: bool = cb.call(Vector2(400, 250), Vector2(400, 200), true, _backend._behavior_host)
	assert_true(ok, "近 Boss 应散圈")
	_backend._physics_process(0.0)   # flush 入队的散圈
	assert_gt(_backend.system.get_active_count(), 0, "应生成散圈弹")


## S4c-2：bounce 端口映射 + 无 Boss 时碰左框 → 换成向下弹。
func test_bounce_refires_down_without_boss() -> void:
	var d := _enemy()
	d.velocity = Vector2.LEFT * 100.0
	d.coroutine_script = BOUNCE_BULLET
	d.params = {"bounce_angle": 0.0, "accel": 0.0}
	_backend.shoot(d, Vector2(GameConfig.FIELD_LEFT - 5.0, 400.0), Vector2.LEFT)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"bounce",
		"bounce_bullet 端口应映射 bounce")
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	_backend._physics_process(0.0)
	assert_eq(_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(_backend.system.get_velocity(0).y, 0.0, "无 Boss → 朝下")
	assert_almost_eq(_backend.system.get_position(0).x, GameConfig.FIELD_LEFT, 0.01, "落回左边界")
	var ti: int = _backend.system.get_type_indices()[0]
	assert_not_null(_backend.texture_for_index(ti), "替换弹必须有贴图")


## S4c-2：bounce 沿飞行方向加速（远离边框时不换弹）。
func test_bounce_accelerates_along_velocity() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = BOUNCE_BULLET
	d.params = {"bounce_angle": 0.0, "accel": 60.0}
	_backend.shoot(d, Vector2(400, 400), Vector2.UP)
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	assert_almost_eq(_backend.system.get_velocity(0).y, -101.0, 0.01, "沿飞行方向加速 60/60")
	assert_eq(_backend.system.get_active_count(), 1, "未碰框不应换弹")


## 替换弹工厂：每次新对象 + 贴图不丢（duplicate 会丢 texture，故不用）。
func test_radial_port_factory_makes_fresh_textured_bullet() -> void:
	var probe = RADIAL_ACCEL.new()
	autofree(probe)
	var port: Dictionary = probe.kernel_port()
	var f: Callable = port["params"][&"spawn_factory"]
	assert_true(f.is_valid(), "端口应给工厂 Callable")
	var a: BulletData = f.call()
	var b: BulletData = f.call()
	assert_not_null(a.texture, "工厂出的弹应有贴图")
	assert_not_null(b.texture, "工厂出的弹应有贴图")
	assert_not_same(a, b, "每次应是新对象")


## S4c-1：radial_accel 沿初方向加速。
func test_radial_accel_accelerates_along_initial_dir() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = RADIAL_ACCEL
	_backend.shoot(d, Vector2(300, 400), Vector2.UP)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"radial_accel",
		"radial_accel 端口应映射 radial_accel")
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	var v: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(v.y, -102.5, 0.01, "沿初方向（-y）加速 150/60")


## S4c-1：radial_accel 碰顶边 → 延后换成向下弹（旧弹回收、新弹 1 颗）。
func test_radial_accel_re_fires_down_at_top() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = RADIAL_ACCEL
	_backend.shoot(d, Vector2(300, GameConfig.FIELD_TOP - 5.0), Vector2.UP)
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	_backend._physics_process(0.0)   # flush 延后 spawn
	assert_eq(_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	var v: Vector2 = _backend.system.get_velocity(0)
	assert_gt(v.y, 0.0, "换成向下弹")
	assert_almost_eq(_backend.system.get_position(0).y, GameConfig.FIELD_TOP, 0.01, "落在顶边")
	var ti: int = _backend.system.get_type_indices()[0]
	assert_not_null(_backend.texture_for_index(ti), "替换弹必须有贴图（否则渲染桥会跳过）")
	assert_eq(_backend.texture_for_index(ti), AssetRegistry.get_bullet_tex("米弹"), "应是米弹贴图")


## S4c-1（真帧）：让引擎物理帧自己跑，验证 system(-10)/behavior(-5)/backend(-4) 链路真的 flush。
func test_radial_accel_re_fires_via_real_frames() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 300.0
	d.coroutine_script = RADIAL_ACCEL
	_backend.shoot(d, Vector2(300, GameConfig.FIELD_TOP + 20.0), Vector2.UP)
	for i in 10:
		await get_tree().physics_frame
	assert_eq(_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(_backend.system.get_velocity(0).y, 0.0, "换成了向下弹")


## S4b：无敌人时 homing 只按速度曲线推进，不转。
func test_homing_without_enemy_keeps_direction() -> void:
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 500.0
	d.coroutine_script = MOVE_HOMING
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	_backend.system._physics_process(1.0 / 60.0)
	_backend.behavior.process()
	var v: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(v.x, 0.0, 0.0001, "无敌人不应偏转")
	assert_gt(v.length(), 500.0, "速度应随 elapsed 向 top_speed 爬升")


## 端口缓存：同一内容签名只探测一次（不每发 instantiate 探测）。
func test_port_cached_by_signature() -> void:
	var d := _enemy()
	d.coroutine_script = GRAVITY_BULLET
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_backend._port_by_sig.size(), 1, "同 Script×params 应命中缓存")
	assert_eq(_backend.unmapped_behavior_count, 0, "已映射不应计数")

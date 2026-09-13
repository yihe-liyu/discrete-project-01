extends GutTest
## 行为管道 + world_accel + 内容端口契约（见 docs/NEW_KERNEL_REFACTOR_PLAN.md）。

const GRAVITY_BULLET = preload("res://data/stages/stage01/bullet/gravity_bullet.gd")
const MOVE_HOMING = preload("res://scripts/coroutine/player/move_homing.gd")
const NO_PORT = preload("res://test/fixtures/no_port_behavior.gd")
const RADIAL_ACCEL = preload("res://data/stages/stage01/bullet/radial_accel_bullet.gd")
const BOUNCE_BULLET = preload("res://data/stages/stage01/bullet/bounce_bullet.gd")
const NON_MID = preload("res://data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd")
const MARISA_LASER = preload("res://scripts/coroutine/player/marisa_laser_follow.gd")

var _kernel_bullet_backend: KernelBulletBackend
var _entity_registry: EntityRegistry
var _player: Player
var _saved_enemies: Array = []
var _saved_difficulty: int = 1
var _saved_memory: float = 50.0


func before_each() -> void:
	_kernel_bullet_backend = KernelBulletBackend.new()
	add_child_autofree(_kernel_bullet_backend)
	# 资源读取经 entity_registry.player.resources：绑一个带独立 PlayerResources 的自机桩
	_entity_registry = EntityRegistry.new()
	_saved_enemies = _entity_registry.enemies.duplicate()
	_entity_registry.enemies.clear()   # 保证「无 Boss」分支确定
	_saved_difficulty = SaveData.selected_difficulty
	_player = Player.new()
	_player.resources = PlayerResources.new()
	_saved_memory = _player.resources.memory_value
	_entity_registry.bind_player(_player)
	_kernel_bullet_backend.entity_registry = _entity_registry
	_kernel_bullet_backend.setup_behaviors(null, Callable())


func after_each() -> void:
	_entity_registry.enemies.clear()
	_entity_registry.enemies.append_array(_saved_enemies)
	SaveData.selected_difficulty = _saved_difficulty
	_player.free()


func _enemy(tex := "小玉") -> BulletData:
	var d := BulletData.new().enemy().tex(tex)
	d.spawn_fog = false
	return d


## 世界 accel：行为只改 velocity，位置由系统积分（别双倍）。
func test_world_accel_changes_velocity() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 1000.0
	d.accel = Vector2(0, 500.0)
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var before: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	_kernel_bullet_backend.system._physics_process(0.1)
	_kernel_bullet_backend.behavior.process()
	var after: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 50.0, 0.01, "世界 accel 应给速度 +a·dt")
	assert_almost_eq(after.x, before.x, 0.01, "x 分量不应变")


## 内容端口：gravity_bullet.kernel_port() → world_accel。
func test_gravity_port_maps_to_world_accel() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = GRAVITY_BULLET
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var slot: int = _kernel_bullet_backend.system.get_behavior_id(0)
	assert_eq(_kernel_bullet_backend.system.get_move_name(slot), &"world_accel", "gravity_bullet 端口应映射到 world_accel")
	var before: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	_kernel_bullet_backend.system._physics_process(0.5)
	_kernel_bullet_backend.behavior.process()
	var after: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 200.0 * 0.5, 0.01, "默认 gravity=200 → 向下加速")


## BulletData.accel（无 coroutine）直接映射 world_accel。
func test_accel_field_without_coroutine_maps() -> void:
	var d := _enemy()
	d.velocity = Vector2.RIGHT * 100.0
	d.accel = Vector2(0, 100.0)
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"world_accel",
		"BulletData.accel 应映射到 world_accel")


## 无端口的行为：计数 + 直线（夹具，不依赖内容进度）。
func test_unmapped_behavior_counted_and_straight() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = NO_PORT
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_kernel_bullet_backend.unmapped_behavior_count, 1, "无端口的行为应计数")
	assert_eq(_kernel_bullet_backend.system.get_behavior_id(0), BulletSystem.BEHAVIOR_NONE, "未映射应无行为（直线）")


## move_homing 端口 → homing；有敌人时朝它偏转。
func test_homing_turns_toward_enemy() -> void:
	var fake := Node2D.new()
	fake.global_position = Vector2(500, 0)
	add_child_autofree(fake)
	_kernel_bullet_backend.setup_behaviors(null, func() -> Array: return [fake])
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 500.0
	d.coroutine_script = MOVE_HOMING
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"homing",
		"move_homing 端口应映射 homing")
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	var v: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_gt(v.x, 0.0, "应朝右侧敌人偏转")
	assert_almost_eq(v.length(), 512.5, 1.0, "速度量级 ≈ lerp(min_speed, top_speed, dt/accel_time)")


## 低记忆自机弹偏红（旧 Bullet.bind 语义，spawn 时定一次）。
func test_player_bullet_reddens_at_low_memory() -> void:
	_player.resources.memory_value = 0.0
	var d := BulletData.new().player().tex("reimu_main")
	d.tint = Color.WHITE
	d.velocity = Vector2.UP * 100.0
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var c: Color = _kernel_bullet_backend.system.get_color(0)
	assert_almost_eq(c.g, 0.5, 0.01, "memory=0 → 往红 lerp 0.5")


## 记忆 50 以上原色不变。（旧语义）
func test_player_bullet_stays_white_at_max_memory() -> void:
	_player.resources.memory_value = 100.0
	var d := BulletData.new().player().tex("reimu_main")
	d.tint = Color.WHITE
	d.velocity = Vector2.UP * 100.0
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_almost_eq(_kernel_bullet_backend.system.get_color(0).g, 1.0, 0.001, "高记忆应保持原色")


## 正确锚点——子机是玩家兄弟节点，须用 global_position（旧池语义）。
func test_marisa_laser_anchors_to_global_position() -> void:
	var player := Node2D.new()
	player.global_position = Vector2(100, 500)
	add_child_autofree(player)
	_kernel_bullet_backend.setup_behaviors(player, Callable())
	var opt := Node2D.new()
	opt.global_position = Vector2(180, 420)
	add_child_autofree(opt)
	var d := BulletData.new().player()
	d.texture = AssetRegistry.get_bullet_tex("marisa_opt1")
	d.coroutine_script = MARISA_LASER
	d.params = {"port_anchor_id": opt.get_instance_id(), "port_anchor_offset": Vector2.ZERO, "port_drift_speed": 2000.0, "port_drift_angle": 0.0}
	_kernel_bullet_backend.shoot(d, opt.global_position, Vector2.UP)
	for i in 2:   # 第 1 帧年龄 0 不推进
		_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
		_kernel_bullet_backend.behavior.process()
	var pos: Vector2 = _kernel_bullet_backend.system.get_position(0)
	assert_almost_eq(pos.x, 180.0, 0.5, "x 应贴子机世界位（不是 玩家+子机 翻倍）")
	assert_lt(pos.y, 420.0, "应向上漂移（第 2 帧起）")
	# 回归：激光段必须带漂移速度——渲染桥按 velocity 算贴图朝向，零速度就不旋转
	assert_ne(_kernel_bullet_backend.system.get_velocity(0), Vector2.ZERO, "激光段应设 velocity（否则贴图不旋转）")
	assert_almost_eq(_kernel_bullet_backend.system.get_velocity(0).angle(), -PI / 2.0, 0.01, "angle=0 → 朝上（贴图竖直）")


## 魔理沙激光段——端口映射 + 标 LASER kind；松手整批渐隐并清掉。
func test_marisa_laser_fades_and_clears() -> void:
	var d := BulletData.new().player()
	d.texture = AssetRegistry.get_bullet_tex("marisa_opt1")
	d.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	d.hitbox_size = Vector2(64, 32)
	d.coroutine_script = MARISA_LASER
	var anchor := Node2D.new()
	anchor.global_position = Vector2(448, 600)
	add_child_autofree(anchor)
	d.params = {"port_anchor_id": anchor.get_instance_id(), "port_anchor_offset": Vector2.ZERO, "port_drift_speed": 2000.0, "port_drift_angle": 0.0}
	_kernel_bullet_backend.shoot(d, Vector2(448, 600), Vector2.UP)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"marisa_laser",
		"marisa 激光端口应映射 marisa_laser")
	assert_eq(_kernel_bullet_backend.system.get_type(0).kind, BulletType.Kind.LASER, "应标 LASER kind")
	# 测试环境 Input 未按射击 → 立即进入渐隐
	for i in 20:
		_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
		_kernel_bullet_backend.behavior.process()
		_kernel_bullet_backend._physics_process(1.0 / 60.0)
	assert_eq(_kernel_bullet_backend.system.get_render_fade(BulletType.Kind.LASER), 0.0, "松手应淡到 0")
	assert_eq(_kernel_bullet_backend.system.get_active_count(), 0, "淡完应清掉激光段")


## TRAVEL → 靠近自机 → FLEE（沿远离方向）。
func test_non_mid_flees_from_player() -> void:
	var player := Node2D.new()
	player.global_position = Vector2(100, 100)
	add_child_autofree(player)
	_kernel_bullet_backend.setup_behaviors(player, Callable())
	var d := _enemy()
	d.velocity = Vector2.RIGHT * 100.0
	d.coroutine_script = NON_MID
	_kernel_bullet_backend.shoot(d, Vector2(80, 100), Vector2.RIGHT)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"non_mid_flee",
		"non_mid01_bullet 端口应映射 non_mid_flee")
	for i in 3:
		_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
		_kernel_bullet_backend.behavior.process()
	assert_eq(_kernel_bullet_backend.system.get_behavior_phase(0), 1, "应进入 FLEE")
	assert_lt(_kernel_bullet_backend.system.get_velocity(0).x, 0.0, "应朝远离自机（左）飞")


## 内容回调——近 Boss 散圈（入队后 flush）。
func test_non_mid_burst_queues_ring() -> void:
	SaveData.selected_difficulty = 1   # Normal
	var probe = NON_MID.new()
	autofree(probe)
	var port: Dictionary = probe.kernel_port()
	var cb: Callable = port["params"][&"on_flee_burst"]
	assert_true(cb.is_valid(), "端口应给散圈回调")
	var ok: bool = cb.call(Vector2(400, 250), Vector2(400, 200), true, _kernel_bullet_backend._behavior_host)
	assert_true(ok, "近 Boss 应散圈")
	_kernel_bullet_backend._physics_process(0.0)   # flush 入队的散圈
	assert_gt(_kernel_bullet_backend.system.get_active_count(), 0, "应生成散圈弹")


## bounce 端口映射 + 无 Boss 时碰左框 → 换成向下弹。
func test_bounce_refires_down_without_boss() -> void:
	var d := _enemy()
	d.velocity = Vector2.LEFT * 100.0
	d.coroutine_script = BOUNCE_BULLET
	d.params = {"bounce_angle": 0.0, "accel": 0.0}
	_kernel_bullet_backend.shoot(d, Vector2(GameConfig.FIELD_LEFT - 5.0, 400.0), Vector2.LEFT)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"bounce",
		"bounce_bullet 端口应映射 bounce")
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	_kernel_bullet_backend._physics_process(0.0)
	assert_eq(_kernel_bullet_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(_kernel_bullet_backend.system.get_velocity(0).y, 0.0, "无 Boss → 朝下")
	assert_almost_eq(_kernel_bullet_backend.system.get_position(0).x, GameConfig.FIELD_LEFT, 0.01, "落回左边界")
	var ti: int = _kernel_bullet_backend.system.get_type_indices()[0]
	assert_not_null(_kernel_bullet_backend.texture_for_index(ti), "替换弹必须有贴图")


## bounce 沿飞行方向加速（远离边框时不换弹）。
func test_bounce_accelerates_along_velocity() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = BOUNCE_BULLET
	d.params = {"bounce_angle": 0.0, "accel": 60.0}
	_kernel_bullet_backend.shoot(d, Vector2(400, 400), Vector2.UP)
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	assert_almost_eq(_kernel_bullet_backend.system.get_velocity(0).y, -101.0, 0.01, "沿飞行方向加速 60/60")
	assert_eq(_kernel_bullet_backend.system.get_active_count(), 1, "未碰框不应换弹")


## 替换弹工厂：返回**同一缓存实例**（M2：弹型缓存在实例上）且贴图不丢（不用 duplicate，它丢 texture）。
func test_radial_port_factory_returns_cached_textured_bullet() -> void:
	var probe = RADIAL_ACCEL.new()
	autofree(probe)
	var port: Dictionary = probe.kernel_port()
	var f: Callable = port["params"][&"spawn_factory"]
	assert_true(f.is_valid(), "端口应给工厂 Callable")
	var a: BulletData = f.call()
	var b: BulletData = f.call()
	assert_not_null(a.texture, "工厂出的弹应有贴图")
	assert_same(a, b, "M2：工厂复用同一实例（内核弹型表不膨胀）")


## radial_accel 沿初方向加速。
func test_radial_accel_accelerates_along_initial_dir() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = RADIAL_ACCEL
	_kernel_bullet_backend.shoot(d, Vector2(300, 400), Vector2.UP)
	assert_eq(_kernel_bullet_backend.system.get_move_name(_kernel_bullet_backend.system.get_behavior_id(0)), &"radial_accel",
		"radial_accel 端口应映射 radial_accel")
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	var v: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_almost_eq(v.y, -102.5, 0.01, "沿初方向（-y）加速 150/60")


## radial_accel 碰顶边 → 延后换成向下弹（旧弹回收、新弹 1 颗）。
func test_radial_accel_re_fires_down_at_top() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = RADIAL_ACCEL
	_kernel_bullet_backend.shoot(d, Vector2(300, GameConfig.FIELD_TOP - 5.0), Vector2.UP)
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	_kernel_bullet_backend._physics_process(0.0)   # flush 延后 spawn
	assert_eq(_kernel_bullet_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	var v: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_gt(v.y, 0.0, "换成向下弹")
	assert_almost_eq(_kernel_bullet_backend.system.get_position(0).y, GameConfig.FIELD_TOP, 0.01, "落在顶边")
	var ti: int = _kernel_bullet_backend.system.get_type_indices()[0]
	assert_not_null(_kernel_bullet_backend.texture_for_index(ti), "替换弹必须有贴图（否则渲染桥会跳过）")
	assert_eq(_kernel_bullet_backend.texture_for_index(ti), AssetRegistry.get_bullet_tex("米弹"), "应是米弹贴图")


## （真帧）：让引擎物理帧自己跑，验证 system（10)/behavior（5)/backend（4) 链路真的 flush。
func test_radial_accel_re_fires_via_real_frames() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 300.0
	d.coroutine_script = RADIAL_ACCEL
	_kernel_bullet_backend.shoot(d, Vector2(300, GameConfig.FIELD_TOP + 20.0), Vector2.UP)
	for i in 10:
		await get_tree().physics_frame
	assert_eq(_kernel_bullet_backend.system.get_active_count(), 1, "旧弹回收 + 新弹生成")
	assert_gt(_kernel_bullet_backend.system.get_velocity(0).y, 0.0, "换成了向下弹")


## 无敌人时 homing 只按速度曲线推进，不转。
func test_homing_without_enemy_keeps_direction() -> void:
	var d := BulletData.new().player().tex("reimu_main")
	d.velocity = Vector2.UP * 500.0
	d.coroutine_script = MOVE_HOMING
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	_kernel_bullet_backend.system._physics_process(1.0 / 60.0)
	_kernel_bullet_backend.behavior.process()
	var v: Vector2 = _kernel_bullet_backend.system.get_velocity(0)
	assert_almost_eq(v.x, 0.0, 0.0001, "无敌人不应偏转")
	assert_gt(v.length(), 500.0, "速度应随 elapsed 向 top_speed 爬升")


## 端口缓存：同一内容签名只探测一次（不每发 instantiate 探测）。
func test_port_cached_by_signature() -> void:
	var d := _enemy()
	d.coroutine_script = GRAVITY_BULLET
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	_kernel_bullet_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_kernel_bullet_backend._port_by_sig.size(), 1, "同 Script×params 应命中缓存")
	assert_eq(_kernel_bullet_backend.unmapped_behavior_count, 0, "已映射不应计数")

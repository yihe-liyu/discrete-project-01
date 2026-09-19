extends GutTest
## 出生雾 / 消弹消散的统一特效模型（EffectType + 行 fx_type + 纯特效行）：
## 原生存储的相位冻结/寿命、KernelNativeSystem 的阵营默认 + 逐弹开关、
## 渲染桥的弹/特效分流、消弹把雾中弹切成消散特效。

const FOG: EffectType = preload("res://data/fx/enemy_spawn_fx.tres")
const CLEAR: EffectType = preload("res://data/fx/enemy_clear_fx.tres")


func _native() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _enemy_data() -> BulletData:
	return BulletData.new().enemy().tex("小玉")


func test_native_spawn_fx_is_frozen_and_expires() -> void:
	if not _native():
		pending("未构建原生扩展 → 跳过")
		return
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(64, Rect2(-1000, -1000, 2000, 2000))
	var id: int = store.spawn_fx(0, Vector2(10, 20), Color.WHITE, 0, 0.3)
	assert_eq(store.get_active_count(), 1, "应生成 1 条纯特效行")
	assert_eq(store.get_type(id), -1, "纯特效行不属于任何弹型")
	assert_almost_eq(store.get_fx_phase(id), 0.3, 0.0001, "相位 = 寿命")
	store.integrate(0.1)
	assert_eq(store.get_active_count(), 1, "0.1s 后仍存活")
	assert_eq(store.get_position(id), Vector2(10, 20), "相位中不动")
	store.integrate(0.3)
	assert_eq(store.get_active_count(), 0, "到期应由 integrate 回收")


func test_faction_default_and_per_type_switch() -> void:
	if not _native():
		pending("未构建原生扩展 → 跳过")
		return
	var sys: KernelNativeSystem = autofree(KernelNativeSystem.new())
	sys.set_spawn_fx(BulletType.Faction.ENEMY, FOG)
	var enemy := _enemy_data()
	var eid: int = sys.spawn(enemy.to_bullet_type(), Vector2.ZERO, Vector2.UP, Color.WHITE)
	assert_almost_eq(sys.get_fx_phase(eid), FOG.duration, 0.0001, "敌弹应取阵营默认出生雾")
	assert_true(sys.get_fx_type_indices()[eid] >= 0, "行应指向特效表")
	var player := BulletData.new().player().tex("小玉")
	var pid: int = sys.spawn(player.to_bullet_type(), Vector2.ZERO, Vector2.UP, Color.WHITE)
	assert_eq(sys.get_fx_phase(pid), 0.0, "自机弹无阵营默认 → 无雾")
	enemy.no_spawn_fog()
	enemy.invalidate_bullet_type()
	var oid: int = sys.spawn(enemy.to_bullet_type(), Vector2.ZERO, Vector2.UP, Color.WHITE)
	assert_eq(sys.get_fx_phase(oid), 0.0, "逐弹开关关掉后无雾")
	# 开关与 .enemy() 的调用顺序无关（历史 bug：.enemy() 覆写 no_spawn_fog）
	var reversed := BulletData.new().no_spawn_fog().enemy().tex("小玉")
	assert_false(reversed.is_spawn_fog, "先 no_spawn_fog 再 enemy 也应保持关闭")
	var rid: int = sys.spawn(reversed.to_bullet_type(), Vector2.ZERO, Vector2.UP, Color.WHITE)
	assert_eq(sys.get_fx_phase(rid), 0.0, "顺序反转后仍无雾")


func test_frozen_bullet_does_not_move() -> void:
	if not _native():
		pending("未构建原生扩展 → 跳过")
		return
	var sys: KernelNativeSystem = autofree(KernelNativeSystem.new())
	sys.set_spawn_fx(BulletType.Faction.ENEMY, FOG)
	var enemy := _enemy_data()
	var id: int = sys.spawn(enemy.to_bullet_type(), Vector2(100, 100), Vector2.RIGHT * 600.0, Color.WHITE)
	sys._physics_process(0.1)
	assert_eq(sys.get_position(id), Vector2(100, 100), "雾中不移动（预告冻结）")
	sys._physics_process(0.3)
	assert_true(sys.get_position(id).x > 100.0, "雾结束后开始移动")


func test_sweep_turns_fog_into_clear_effect() -> void:
	if not _native():
		pending("未构建原生扩展 → 跳过")
		return
	var backend: KernelBulletHost = add_child_autofree(KernelBulletHost.new())
	backend.system.set_spawn_fx(BulletType.Faction.ENEMY, FOG)
	backend.shoot(_enemy_data(), Vector2(100, 100), Vector2.RIGHT)
	assert_gt(backend.system.get_fx_phase(0), 0.0, "出生即处于雾相位")
	var physics := KernelBulletPhysics.new()
	physics.setup(backend)
	physics.sweep_enemy_bullets(Vector2(100, 100), 50.0)
	var sys: KernelNativeSystem = backend.system
	assert_eq(sys.get_active_count(), 1, "弹被消掉、原地留 1 条消散特效行")
	assert_eq(sys.get_type_indices()[0], -1, "留下的是纯特效行")
	assert_almost_eq(sys.get_fx_phase(0), CLEAR.duration, 0.0001, "消散特效相位 = 消弹 EffectType 时长")


func test_render_bridge_splits_bullets_and_fx() -> void:
	var bridge = ClassDB.instantiate("DanmakuRenderBridge")
	bridge.set_type_table(
		PackedInt64Array([12345]), PackedInt32Array([BulletType.TintMode.BLEND]),
		PackedInt32Array([BulletType.Kind.POINT]), PackedByteArray([0]), PackedFloat32Array([0.0]))
	bridge.set_fx_table(
		PackedInt64Array([98765]), PackedFloat32Array([FOG.duration]),
		PackedFloat32Array([FOG.scale_from]), PackedFloat32Array([FOG.scale_to]),
		PackedFloat32Array([FOG.alpha_from]), PackedFloat32Array([FOG.alpha_to]),
		PackedInt32Array([BulletType.TintMode.BLEND]))
	var groups: Dictionary = bridge.group(
		2,
		PackedVector2Array([Vector2(10, 10), Vector2(20, 20)]),
		PackedVector2Array([Vector2.ZERO, Vector2.ZERO]),
		PackedColorArray([Color.WHITE, Color.WHITE]),
		PackedInt32Array([0, -1]),                     # 行0 = 弹；行1 = 纯特效行
		PackedByteArray([0, 0]),
		PackedFloat32Array([1.0, 1.0]),
		PackedFloat32Array([NAN, NAN]),
		PackedFloat32Array([0.0, FOG.duration]),       # 出生相位
		PackedInt32Array([-1, 0]))                     # 特效型下标
	assert_eq(groups["keys"].size(), 1, "行0 应进弹批次")
	assert_eq(groups["starts"][1], 1, "弹批次只含 1 行")
	assert_eq(groups["fx_keys"].size(), 1, "行1 应进特效批次")
	assert_eq(groups["fx_starts"][1], 1, "特效批次只含 1 行")
	assert_almost_eq(groups["fx_scales"][0], FOG.scale_from, 0.0001, "相位起点用 scale_from")
	assert_almost_eq(groups["fx_alphas"][0], FOG.alpha_from, 0.0001, "相位起点用 alpha_from")

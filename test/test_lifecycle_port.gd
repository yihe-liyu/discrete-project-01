extends GutTest
## 预拼描述符入口（`{lifecycle}`）：内容自己拼 BulletLifecycle，不经过命名 move、不涨 build()。
## 见 docs/LIFECYCLE_MODEL.md §7「`*_bullet.gd` → builder sugar」。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


## 非 preset 的两段组合：rotate 到上限 → 沿方向加速 → despawn。
func _composed() -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.5)
	lc.until_turned()
	lc.then()
	lc.accel_heading(300.0)
	lc.until_elapsed(1.0)
	lc.despawn()
	return lc


## 端口层：内容 kernel_port() 返回 {lifecycle} → prepare_shot 认出并透传。
func test_port_accepts_prebuilt_lifecycle() -> void:
	var backend: KernelBulletBackend = autofree(KernelBulletBackend.new())
	var data := BulletData.new()
	data.coroutine_script = preload("res://test/fixtures/lifecycle_port_behavior.gd")
	data.params = {&"turn_limit": 0.5}
	var spec: Dictionary = backend.prepare_shot(data, Vector2(300.0, 400.0), Vector2.UP)
	assert_eq(spec.get("move"), LifecycleCatalog.MOVE_LIFECYCLE, "应走 lifecycle 入口，而不是命名 move")
	assert_true(spec.get("params", {}).get(&"lifecycle") is BulletLifecycle, "应带上预拼描述符")


## 执行层：非 preset 的两段组合被原生跑起来（不是直线）。
func test_prebuilt_lifecycle_runs_natively() -> void:
	if not _available():
		pending("未构建原生扩展")
		return
	var lc := _composed()
	var ns: KernelNativeSystem = autofree(KernelNativeSystem.new())
	ns.cull_rect = CULL
	ns.cull_margin = 0.0
	ns.default_lifetime = 100.0
	ns.native_behaviors = true
	var pid: int = ns._program_for(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	assert_true(pid >= 0, "预拼 lifecycle 应注册成 program（非 -1）")
	assert_eq(ns._program_data.size(), 1, "应注册恰好 1 个 program")
	ns.spawn(BulletType.new(), Vector2(300.0, 400.0), Vector2.UP * 180.0, Color.WHITE,
		LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	assert_eq(ns.get_active_count(), 1, "应发射 1 颗")
	for _f in 40:
		ns._physics_process(DT)
	assert_eq(ns.get_active_count(), 1, "40 帧后仍在场")
	assert_gt(ns.get_velocity(0).length(), 260.0, "相位2 accel 应已把速度拉高（预设外组合真的在跑）")
	for _f in 100:
		ns._physics_process(DT)
	assert_eq(ns.get_active_count(), 0, "until_elapsed 后应 despawn")

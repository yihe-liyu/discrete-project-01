extends GutTest
## b0：BulletLifecycle 结构签名 —— 相同结构共用一个原生 program（防 per-instance 爆炸）。


func test_identical_structure_shares_signature() -> void:
	var a := BulletLifecycle.world_accel(Vector2(0, 200))
	var b := BulletLifecycle.world_accel(Vector2(0, 200))
	assert_true(a != b, "应是两个不同实例")
	assert_eq(a.content_signature(), b.content_signature(), "相同结构应同签名（→ 共用 program）")


func test_different_params_differ() -> void:
	var a := BulletLifecycle.world_accel(Vector2(0, 200))
	var b := BulletLifecycle.world_accel(Vector2(0, 400))
	assert_ne(a.content_signature(), b.content_signature(), "不同参数应不同签名")


func test_factory_identity_differs() -> void:
	# 结构相同但工厂对象不同 → 必须不同 program（动作表按 program 存，串了会调错工厂）
	var o1 := Node.new()
	autofree(o1)
	var o2 := Node.new()
	autofree(o2)
	var a := BulletLifecycle.radial_accel(150.0, Callable(o1, "free"))
	var b := BulletLifecycle.radial_accel(150.0, Callable(o2, "free"))
	assert_ne(a.content_signature(), b.content_signature(), "不同工厂实例应不同签名")


func test_spawn_data_identity_in_signature() -> void:
	var d1 := BulletData.new().enemy()
	var d2 := BulletData.new().enemy()
	var a := BulletLifecycle.bounce(100.0, 0.0, 0.0, d1)
	var b := BulletLifecycle.bounce(100.0, 0.0, 0.0, d1)
	var c := BulletLifecycle.bounce(100.0, 0.0, 0.0, d2)
	assert_eq(a.content_signature(), b.content_signature(), "同一替换弹实例应同签名")
	assert_ne(a.content_signature(), c.content_signature(), "不同替换弹实例应异签名")


func test_signature_is_stable() -> void:
	var a := BulletLifecycle.world_accel(Vector2(0, 200))
	assert_eq(a.content_signature(), a.content_signature(), "同实例签名应稳定（缓存）")


## 端到端：两个结构相同的 lifecycle 只注册 1 个原生 program（堵住 per-instance 爆炸）
func test_identical_lifecycles_share_one_program() -> void:
	if not ClassDB.class_exists("DanmakuStore"):
		pending("未构建原生扩展")
		return
	var ns: KernelNativeSystem = autofree(KernelNativeSystem.new())
	var a := BulletLifecycle.world_accel(Vector2(0, 200))
	var b := BulletLifecycle.world_accel(Vector2(0, 200))
	var p1: int = ns._program_for(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": a})
	var p2: int = ns._program_for(LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": b})
	assert_eq(p1, p2, "结构相同的 lifecycle 应复用同一 program")
	assert_eq(ns._program_data.size(), 1, "应只注册 1 个 program")


## b0：BulletData.lifecycle 走 {lifecycle} 入口（优先于 coroutine_script）
func test_bullet_data_lifecycle_preferred() -> void:
	var backend: KernelBulletBackend = autofree(KernelBulletBackend.new())
	var data := BulletData.new()
	data.lifecycle = BulletLifecycle.world_accel(Vector2(0, 200))
	var spec: Dictionary = backend.prepare_shot(data, Vector2(300.0, 400.0), Vector2.UP)
	assert_eq(spec.get("move"), LifecycleCatalog.MOVE_LIFECYCLE, "应走 lifecycle 入口")
	assert_eq(spec.get("params", {}).get(&"lifecycle"), data.lifecycle, "应带上该描述符")

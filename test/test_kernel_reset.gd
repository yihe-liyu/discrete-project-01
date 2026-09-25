extends GutTest
## 内核注册表重置（工作台清场 / 重开演回收 program / 弹型 —— 原生 store 只增不减）。


func test_system_reset_registries_drops_programs_types_and_bullets() -> void:
	var sys := KernelNativeSystem.new()
	add_child_autofree(sys)
	if not sys.is_native_ready():
		pending("无原生扩展")
		return
	var lc := BulletLifecycle.new()
	lc.until_elapsed(1.0).despawn()
	var id: int = sys.spawn(BulletType.new(), Vector2.ZERO, Vector2.DOWN, Color.WHITE,
		LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	assert_gt(id, -1, "应生成一颗弹")
	assert_gt(sys._program_data.size(), 0, "应注册 program")
	assert_gt(sys.get_type_registry().size(), 0, "应注册弹型")
	assert_gt(sys.get_active_count(), 0, "应有活跃弹")

	sys.reset_registries()
	assert_eq(sys._program_data.size(), 0, "program 表清空")
	assert_eq(sys.get_type_registry().size(), 0, "弹型表清空")
	assert_eq(sys.get_active_count(), 0, "弹清空（原生 store 重建）")

	# 重置后仍能注册（新 store 与 GDScript 表从 0 对齐）
	var id2: int = sys.spawn(BulletType.new(), Vector2.ZERO, Vector2.DOWN, Color.WHITE,
		LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	assert_gt(id2, -1, "重置后应能再发弹")
	assert_gt(sys._program_data.size(), 0, "重置后应能再注册 program")


func test_bullet_manager_reset_world_drops_registries() -> void:
	var bm := BulletManager.new()
	add_child_autofree(bm)
	await get_tree().process_frame
	var sys := bm.kernel_system()
	assert_not_null(sys, "BulletManager 应装配内核后端")
	if sys == null or not sys.is_native_ready():
		pending("无原生扩展")
		return
	var lc := BulletLifecycle.new()
	lc.until_elapsed(1.0).despawn()
	var data := BulletData.new().tex("小玉").speed(100.0).enemy().trajectory(lc)
	bm.shoot_bullet(data, Vector2.ZERO, Vector2.DOWN)
	assert_gt(bm.active_count(), 0, "应有弹")
	assert_gt(sys._program_data.size(), 0, "发弹后应注册 program")

	bm.reset_world()
	assert_eq(bm.active_count(), 0, "reset_world 后弹清空")
	assert_eq(sys._program_data.size(), 0, "program 表清空")
	assert_eq(sys.get_type_registry().size(), 0, "弹型表清空")

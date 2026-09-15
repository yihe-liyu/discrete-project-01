extends GutTest
## DecorManager 回归测试：静态路径（SCISSOR 层）性能优化后行为不变
## 注意：headless（RendererDummy）下 MultiMesh 的 RS 命令是 no-op，get_instance_transform
## 永远返回 identity —— 因此这里全部用内部状态（entries/free_slots/scroll_offset）+
## 实例写入计数器断言，不读 transform 回读。
##
## 覆盖：节点整体平移 / 稳态零写入 / world↔local 换算 / 淘汰 / 槽位复用 / clear / 动态层兼容

var _bg: Node3D
var _background_plane: BackgroundPlane
var _decor_manager: DecorManager


func before_each() -> void:
	_bg = Node3D.new()
	_background_plane = BackgroundPlane.new()
	_background_plane.scroll_speed = Vector2(0, -2.0)  # 加速滚动（85.3 m/s）方便测淘汰
	_background_plane.plane_size = Vector2(256, 256)
	_background_plane.tiling = Vector2(6, 6)
	_bg.add_child(_background_plane)
	_decor_manager = DecorManager.new()
	_bg.add_child(_decor_manager)
	var layer := DecorLayer.new()
	layer.name = "test"
	layer.alpha_mode = DecorLayer.AlphaMode.SCISSOR
	layer.size_min = Vector2(4, 4)
	layer.size_max = Vector2(4, 4)
	layer.is_billboard = false
	_decor_manager.add_layer(layer)
	add_child_autofree(_bg)


func _group() -> Dictionary:
	return _decor_manager._groups


func _alive_count(g: Dictionary) -> int:
	var n := 0
	for e in g["test"].entries:
		if e.is_alive:
			n += 1
	return n


## ① 节点整体平移：mmi 跟随 scroll_offset 移动，实例位置静止不动
func test_node_translation_instead_of_per_instance():
	_decor_manager.batch_spawn("test", 10, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(2)
	var g: Dictionary = _group()
	var mm: MultiMesh = g["test"].multi_mesh
	assert_true(mm.instance_count >= 10, "初始至少 10 个实例槽（分块扩容可能略多）")

	await wait_physics_frames(30)  # 0.5s → offset.z ≈ 42.7
	var off: Vector3 = g["test"].scroll_offset
	assert_gt(off.z, 30.0, "节点应整体平移（旧版是逐实例位移）")
	assert_eq(g["test"].mmi.position, off, "mmi.position 应与 scroll_offset 同步")
	assert_eq(_alive_count(g), 10, "平移期间实例本身不应被移动/淘汰")


## ② 稳态零写入（优化核心不变量）：不生成/不淘汰时，每帧不应有任何实例 transform 写入
func test_static_path_steady_state_zero_writes():
	_decor_manager.batch_spawn("test", 10, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(2)
	_decor_manager.debug_take_writes()  # 清掉初始化计数
	await wait_physics_frames(3)
	assert_eq(_decor_manager.debug_take_writes(), 0,
		"静态路径稳态不应有实例写入（节点平移替代逐实例更新被回归则此断言失败）")


## ③ 中途补种：world 坐标 → local 换算正确（local = world - scroll_offset）
func test_spawn_world_to_local_conversion():
	_decor_manager.batch_spawn("test", 10, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(30)  # 先滚一段，offset 非零
	var g: Dictionary = _group()
	var off: Vector3 = g["test"].scroll_offset
	_decor_manager.spawn("test", Vector3(0, 4, -200), Vector2(4, 4), _background_plane)
	var found := false
	for e in g["test"].entries:
		if e.is_alive and absf((e.position.z + off.z) - (-200.0)) < 1.0:
			found = true
	assert_true(found, "补种的树应出现在 world z=-200 附近（local=world-offset 换算错误则失败）")


## ④ 淘汰 + 槽位复用：树滚到 world z>100 死亡，新 spawn 复用槽位，高水位不涨
func test_culling_and_slot_reuse():
	_decor_manager.batch_spawn("test", 50, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(2)
	var g: Dictionary = _group()
	var mm: MultiMesh = g["test"].multi_mesh
	await wait_physics_frames(280)  # ≈4.7s：最远 -220 的树也过 z=100（需 ~3.75s）
	assert_eq(_alive_count(g), 0, "所有树应被淘汰（world z>100）")
	assert_eq(g["test"].free_slots.size(), 50, "死亡槽应全部进入复用栈")

	var before: int = mm.instance_count
	_decor_manager.spawn("test", Vector3(0, 4, -190), Vector2(4, 4), _background_plane)
	_decor_manager.spawn("test", Vector3(10, 4, -190), Vector2(4, 4), _background_plane)
	assert_eq(mm.instance_count, before, "新 spawn 应复用死亡槽位（instance_count 不增长）")
	assert_eq(_alive_count(g), 2, "复用后应有 2 棵存活")
	assert_eq(g["test"].free_slots.size(), 48, "复用栈应减少 2")

	var off: Vector3 = g["test"].scroll_offset
	var ok_pos := false
	for e in g["test"].entries:
		if e.is_alive and absf((e.position.z + off.z) - (-190.0)) < 1.0:
			ok_pos = true
	assert_true(ok_pos, "复用槽位的新树应出现在 world z=-190 附近")


## ⑤ clear_layer：清空 + 复位后能继续使用
func test_clear_layer_resets_and_restarts():
	_decor_manager.batch_spawn("test", 10, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(10)
	_decor_manager.clear_layer("test")
	var g: Dictionary = _group()
	assert_eq(g["test"].multi_mesh.instance_count, 0, "clear 后实例数应为 0")
	assert_eq(g["test"].entries.size(), 0, "clear 后 entry 应为空")
	assert_eq(g["test"].free_slots.size(), 0, "clear 后复用栈应为空")
	assert_eq(g["test"].scroll_offset, Vector3.ZERO, "clear 应复位 scroll_offset")
	assert_eq(g["test"].mmi.position, Vector3.ZERO, "clear 应复位 mmi.position")

	_decor_manager.spawn("test", Vector3(0, 4, -190), Vector2(4, 4), _background_plane)
	await wait_physics_frames(1)
	assert_eq(_alive_count(g), 1, "clear 后重新 spawn 应正常工作")


## ⑥ 半透明层（BLEND）走兼容路径：逐实例位移，行为不回归
func test_dynamic_path_still_works():
	var layer := DecorLayer.new()
	layer.name = "blend"
	layer.alpha_mode = DecorLayer.AlphaMode.BLEND
	layer.size_min = Vector2(4, 4)
	layer.size_max = Vector2(4, 4)
	layer.is_billboard = true
	_decor_manager.add_layer(layer)
	_decor_manager.batch_spawn("blend", 20, Vector2(-90, 90), Vector2(-220, -180), _background_plane)
	await wait_physics_frames(30)
	var g: Dictionary = _group()
	assert_eq(g["blend"].entries.size(), 20, "动态层未淘汰前应保持 20 个 entry")
	assert_gt(g["blend"].multi_mesh.instance_count, 0, "动态层应有实例")
	var z0: float = g["blend"].entries[0].position.z
	await wait_physics_frames(2)
	var z1: float = g["blend"].entries[0].position.z
	assert_gt(z1, z0, "动态层应保持逐实例位移（与静态层不同）")

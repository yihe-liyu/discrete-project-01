extends GutTest
## BulletMultiMesh 的**内核快照**渲染路径（不再遍历 Bullet 节点；分组键与旧路径共用）。
## 注：headless（dummy 渲染器）下 MultiMesh 实例变换读回恒为 0，故断言落在 CPU 侧可读的
##     批次数 / visible_instance_count / z_index / 材质 / 网格尺寸；逐实例几何写入由内核快照路径保证。


func _setup() -> Array:
	var backend := KernelBulletBackend.new()
	add_child_autofree(backend)
	var renderer := BulletMultiMesh.new()
	add_child_autofree(renderer)
	renderer.set_backend(backend)
	return [backend, renderer]


func _enemy_data(blend: bool = true) -> BulletData:
	var d := BulletData.new().enemy().blend(blend).tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return d


func _player_data() -> BulletData:
	var d := BulletData.new().player().tex("小玉")
	d.velocity = Vector2.UP * 100.0
	return d


func test_kernel_snapshot_renders_one_batch() -> void:
	var s := _setup()
	var backend: KernelBulletBackend = s[0]
	var renderer: BulletMultiMesh = s[1]
	for i in 3:
		backend.shoot(_enemy_data(), Vector2(10 + i * 20, 50), Vector2.RIGHT)
	renderer._sync()
	assert_eq(renderer._groups.size(), 1, "同纹理/阵营/tint_mode 应合成 1 批")
	var g: Dictionary = renderer._groups.values()[0]
	assert_eq(g.mm.visible_instance_count, 3, "3 发应写 3 个实例")


func test_tint_mode_splits_batches() -> void:
	var s := _setup()
	var backend: KernelBulletBackend = s[0]
	var renderer: BulletMultiMesh = s[1]
	backend.shoot(_enemy_data(true), Vector2.ZERO, Vector2.RIGHT)
	backend.shoot(_enemy_data(false), Vector2.ZERO, Vector2.RIGHT)
	renderer._sync()
	assert_eq(renderer._groups.size(), 2, "tint_mode 不同应分两批")


func test_despawn_clears_instances() -> void:
	var s := _setup()
	var backend: KernelBulletBackend = s[0]
	var renderer: BulletMultiMesh = s[1]
	var id := backend.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	renderer._sync()
	backend.system.despawn(id)
	renderer._sync()
	var g: Dictionary = renderer._groups.values()[0]
	assert_eq(g.mm.visible_instance_count, 0, "清空后实例数应归零")


func test_faction_maps_to_z() -> void:
	# 内核阵营(ENEMY=0/PLAYER=1) → 宿主阵营(PLAYER=0/ENEMY=1) → z_index；两处枚举顺序不同，必须显式映射。
	var s := _setup()
	var backend: KernelBulletBackend = s[0]
	var renderer: BulletMultiMesh = s[1]
	backend.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	backend.shoot(_player_data(), Vector2.ZERO, Vector2.RIGHT)
	renderer._sync()
	var zs: Array = []
	for g in renderer._groups.values():
		zs.append(g.mmi.z_index)
	zs.sort()
	assert_eq(zs, [LayerConfig.PLAYER_BULLET, LayerConfig.ENEMY_BULLET], "敌弹/自机弹应各得正确 z")


func test_material_and_mesh_come_from_type() -> void:
	var s := _setup()
	var backend: KernelBulletBackend = s[0]
	var renderer: BulletMultiMesh = s[1]
	backend.shoot(_enemy_data(true), Vector2.ZERO, Vector2.RIGHT)   # blend(true) → BLEND
	renderer._sync()
	var g: Dictionary = renderer._groups.values()[0]
	assert_eq(g.mmi.material.get_shader_parameter("tint_mode"), BulletType.TintMode.BLEND,
		"材质 tint_mode 应来自内核弹型")
	assert_eq(g.mesh.size, AssetRegistry.get_bullet_tex("小玉").get_size(), "网格尺寸应匹配贴图")

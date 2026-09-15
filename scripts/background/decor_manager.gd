# DecorManager.gd — 分层装饰物管理器（自定义 MultiMesh）
class_name DecorManager
extends Node3D

# ═══ 内部 ═══

class DecorEntry:
	var position: Vector3
	var scale: Vector2
	var follow: BackgroundPlane
	var spawn_time: float
	var lifetime: float = -1.0
	var is_alive: bool = true


class _LayerGroup:
	var multi_mesh: MultiMesh
	var mmi: MultiMeshInstance3D
	var entries: Array[DecorEntry] = []   # 槽位数组（静态层）：索引稳定、死亡槽占位复用
	var free_slots: Array[int] = []       # 静态层：可复用槽位栈
	var layer: DecorLayer
	var follow: BackgroundPlane = null    # 静态层：本层统一跟随平面（节点整体平移依据）
	var scroll_offset: Vector3 = Vector3.ZERO  # 静态层：节点累计平移量（= mmi.position）


var _groups: Dictionary = {}
var _elapsed: float = 0.0

## 实例 transform 写入计数（调试/回归测试用）：
## 静态路径稳态（无生成/无死亡）必须为 0 —— 保证"节点平移代替逐实例更新"不被回归
var _instance_writes: int = 0


func debug_take_writes() -> int:
	var n := _instance_writes
	_instance_writes = 0
	return n


# ═══ API ═══

func add_layer(layer: DecorLayer) -> void:
	var key := layer.name if layer.name != "" else layer.texture.resource_path
	if _groups.has(key): return
	var g := _LayerGroup.new()
	g.layer = layer
	_build_mesh(g, layer)
	_groups[key] = g


func spawn(layer_name: String, pos: Vector3, tex_scale: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	var sz := tex_scale
	if sz == Vector2.ZERO:
		sz = Vector2(RNG.randf_range(g.layer.size_min.x, g.layer.size_max.x), RNG.randf_range(g.layer.size_min.y, g.layer.size_max.y))
	_alloc_slot(g, pos - g.scroll_offset, sz, follow, lifetime)


func batch_spawn(layer_name: String, count: int, x_range: Vector2, z_range: Vector2, follow: BackgroundPlane, lifetime: float = -1.0) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	var layer := g.layer
	var band := z_range if z_range != Vector2.ZERO else layer.spawn_band
	var y_var := layer.y_variance
	var s_min := layer.size_min
	var s_max := layer.size_max
	for _i in count:
		var tex_scale := Vector2(RNG.randf_range(s_min.x, s_max.x), RNG.randf_range(s_min.y, s_max.y))
		var pos := Vector3(RNG.randf_range(x_range.x, x_range.y), tex_scale.y / 2.0 + RNG.randf_range(-y_var, y_var), RNG.randf_range(band.x, band.y))
		_alloc_slot(g, pos - g.scroll_offset, tex_scale, follow, lifetime)

func clear_layer(layer_name: String) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g: return
	g.entries.clear()
	g.free_slots.clear()
	g.scroll_offset = Vector3.ZERO
	g.mmi.position = Vector3.ZERO
	if g.multi_mesh.instance_count > 0:
		g.multi_mesh.instance_count = 0

func fade_out_layer(layer_name: String, duration: float) -> void:
	var g: _LayerGroup = _groups.get(layer_name)
	if not g or not g.mmi: return
	var tw := create_tween()
	tw.tween_property(g.mmi, "transparency", 1.0, duration)
	tw.tween_callback(func():
		if g.mmi: g.mmi.transparency = 0.0
		clear_layer(layer_name)
	)


# ═══ 生命周期 ═══

func _process(delta: float) -> void:
	_elapsed += delta
	for key in _groups:
		var g: _LayerGroup = _groups[key]
		if g.layer.alpha_mode == DecorLayer.AlphaMode.BLEND:
			_process_dynamic(g, delta)  # 半透明层：逐实例位移 + 画家排序（透明需要）
		else:
			_process_static(g, delta)   # 不透明层：整层平移 O(1)，transform 只在生成/死亡时写


## 不透明层（SCISSOR）—— 性能路径：
## 实例 transform 完全静态（生成时写一次），整层跟随地面用"移动 mmi 节点"实现 O(1) 平移；
## 淘汰用槽位复用（死亡槽 0 缩放隐藏 + free_slots 复用），无数组重建、无排序。
func _process_static(g: _LayerGroup, delta: float) -> void:
	# ① 节点整体平移（等价于旧版逐实例位移的合力）
	if g.follow:
		var rx: float = g.follow.plane_size.x / maxf(g.follow.tiling.x, 1.0)
		var ry: float = g.follow.plane_size.y / maxf(g.follow.tiling.y, 1.0)
		var step := Vector3(g.follow.scroll_speed.x * rx, 0, -g.follow.scroll_speed.y * ry) * delta
		g.scroll_offset += step
		g.mmi.position = g.scroll_offset
	# ② 淘汰：生命周期 / 超视野（原位标记死亡 → 槽位复用，无数组重建）
	var entries := g.entries
	var offset_z := g.scroll_offset.z
	for i in entries.size():
		var e := entries[i]
		if not e.is_alive:
			continue
		if e.lifetime > 0 and (e.spawn_time > 0 and _elapsed - e.spawn_time >= e.lifetime):
			_kill(g, i)
		elif offset_z + e.position.z > 100.0 or offset_z + e.position.z < -400.0:
			_kill(g, i)


## 半透明层（BLEND）—— 兼容路径：保持旧行为（逐实例位移 + 画家排序 + 全量刷新）。
## MultiMesh 半透明无法按实例排序，这里手动按 z 排（相机固定时有效）。
func _process_dynamic(g: _LayerGroup, delta: float) -> void:
	var entries: Array[DecorEntry] = g.entries
	for e in entries:
		if e.follow:
			var rx: float = e.follow.plane_size.x / maxf(e.follow.tiling.x, 1.0)
			var ry: float = e.follow.plane_size.y / maxf(e.follow.tiling.y, 1.0)
			e.position += Vector3(e.follow.scroll_speed.x * rx, 0, -e.follow.scroll_speed.y * ry) * delta
		if e.lifetime > 0 and (e.spawn_time > 0 and _elapsed - e.spawn_time >= e.lifetime):
			e.is_alive = false
		if e.position.z > 100 or e.position.z < -400:
			e.is_alive = false
	var is_alive: Array[DecorEntry] = []
	for e in entries:
		if e.is_alive: is_alive.append(e)
	g.entries = is_alive
	g.entries.sort_custom(func(a, b): return a.position.z < b.position.z)
	_flush_all(g)


# ═══ 内部 ═══

## 分配槽位：优先复用死亡槽（O(1)），否则追加（O(1) 均摊）——实例 transform 只写这一个
func _alloc_slot(g: _LayerGroup, local_pos: Vector3, sz: Vector2, follow: BackgroundPlane, lifetime: float) -> void:
	var e := DecorEntry.new()
	e.position = local_pos
	e.scale = sz
	e.follow = follow
	e.spawn_time = _elapsed
	e.lifetime = lifetime
	e.is_alive = true
	# 组级跟随平面：取首个非 null；之后不一致只警告（实际各层都统一 follow 同一地面）
	if g.follow == null and follow != null:
		g.follow = follow
	elif g.follow != null and follow != null and follow != g.follow:
		push_warning("DecorManager: 层 '%s' 混用多个跟随平面——整层平移以首个为准" % g.layer.name)
	var idx: int = g.free_slots.pop_back() if not g.free_slots.is_empty() else -1
	if idx >= 0:
		g.entries[idx] = e
	else:
		idx = g.entries.size()
		g.entries.append(e)
		_ensure_capacity(g, g.entries.size())
	_write_instance(g, idx)


## 保证 MultiMesh 缓冲能容纳 needed 个实例。
## 分块扩容（×2+8）：避免每 append 一次就触发一次缓冲重分配；
## 重分配可能清零缓冲 → 扩完后全量重写（含 padding 槽 0 缩放，防止多余实例出现在原点）
func _ensure_capacity(g: _LayerGroup, needed: int) -> void:
	var mm := g.multi_mesh
	if needed <= mm.instance_count:
		return
	var new_size: int = maxi(needed, mm.instance_count * 2 + 8)
	mm.instance_count = new_size
	var n_entries := g.entries.size()
	for i in new_size:
		if i < n_entries:
			_write_instance(g, i)
		else:
			mm.set_instance_transform(i, _zero_transform())
			_instance_writes += 1


## 淘汰：占位保留槽位，0 缩放隐藏实例，索引进复用栈
func _kill(g: _LayerGroup, idx: int) -> void:
	g.entries[idx].is_alive = false
	g.free_slots.append(idx)
	_write_instance(g, idx)  # 0 缩放隐藏该实例


func _write_instance(g: _LayerGroup, idx: int) -> void:
	_instance_writes += 1
	var e := g.entries[idx]
	if e.is_alive:
		g.multi_mesh.set_instance_transform(idx, _scale_transform(e.scale, e.position))
	else:
		g.multi_mesh.set_instance_transform(idx, _zero_transform())


func _scale_transform(sz: Vector2, pos: Vector3) -> Transform3D:
	# 注意：Transform3D.scaled() 会连 origin 一起缩放（Godot 4.7）→ 必须只缩 basis，origin 直接赋值
	return Transform3D(Basis().scaled(Vector3(sz.x, sz.y, 1.0)), pos)


func _zero_transform() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO)


## 动态层全量刷新（旧行为）
func _flush_all(g: _LayerGroup) -> void:
	var entries := g.entries
	var n := entries.size()
	var mm := g.multi_mesh
	if mm.instance_count != n:
		mm.instance_count = n
	for i in n:
		var e := entries[i]
		mm.set_instance_transform(i, _scale_transform(e.scale, e.position))


func _build_mesh(g: _LayerGroup, layer: DecorLayer) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 0
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1, 1)
	mesh.orientation = QuadMesh.FACE_Z
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = layer.texture
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if layer.alpha_mode == DecorLayer.AlphaMode.BLEND:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = layer.alpha_threshold
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED if layer.is_billboard else BaseMaterial3D.BILLBOARD_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = mat
	mm.mesh = mesh
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	g.multi_mesh = mm
	g.mmi = mmi

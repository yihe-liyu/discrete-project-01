extends Node3D
## Stage04 谷底/山壁彩色石块散布：一个 MultiMesh，实例颜色区分。

@export var count: int = 150
@export var rng_seed: int = 404
@export var valley_half_width: float = 110.0
@export var z_near: float = 40.0
@export var z_far: float = 3200.0
## 与 InfiniteValley.forward_speed 对齐
@export var scroll_speed: float = 80.0
## 石头越过镜头多远后回收到远处
@export var recycle_z: float = 45.0
## 贴壁石头占比
@export var wall_ratio: float = 0.28
## 成簇散布：一部分石头围绕这些簇中心生成，避免完全均匀随机。
@export var cluster_count: int = 16
@export var cluster_spread: float = 120.0
## 贴壁石头往山体里嵌入的比例（相对石头半径）
@export var wall_embed_ratio: float = 0.32

const PALETTE := [
	Color(0.18, 0.34, 0.4),
	Color(0.34, 0.26, 0.38),
	Color(0.44, 0.36, 0.24),
	Color(0.24, 0.4, 0.36),
	Color(0.3, 0.34, 0.4),
	Color(0.46, 0.3, 0.26),
]


var _mm: MultiMesh
var _rng: RandomNumberGenerator
var _valley: Node
var _material: ShaderMaterial
var _kind: PackedByteArray
var _wall_side: PackedFloat32Array
var _wall_t: PackedFloat32Array
var _cluster_z: PackedFloat32Array
var _cluster_x: PackedFloat32Array
var _cluster_side: PackedFloat32Array
var _cluster_t: PackedFloat32Array


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed
	_valley = get_node_or_null(^"../Valley")

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _make_rock_mesh()
	mm.instance_count = count
	_mm = mm
	_kind.resize(count)
	_wall_side.resize(count)
	_wall_t.resize(count)
	_cluster_z.resize(cluster_count)
	_cluster_x.resize(cluster_count)
	_cluster_side.resize(cluster_count)
	_cluster_t.resize(cluster_count)
	for c in cluster_count:
		_cluster_z[c] = -_rng.randf_range(z_near, z_far)
		_cluster_x[c] = _rng.randf_range(0.34, 0.94)
		_cluster_side[c] = -1.0 if _rng.randf() < 0.5 else 1.0
		_cluster_t[c] = _rng.randf_range(0.04, 0.34)

	for i in count:
		_scatter(i, true)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/stage04_rock.gdshader")
	_material = mat
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = mat
	add_child(instance)


## 供 Stage04 亮度接口调整彩石材质。
func set_brightness(value: float) -> void:
	if _material:
		_material.set_shader_parameter("brightness", value)


## 低模岩块：从 SphereMesh 取三角面，全部拆成独立面并生成面法线，得到硬朗的岩石切面。
func _make_rock_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.45
	sphere.radial_segments = 6
	sphere.rings = 4
	var src := sphere.get_mesh_arrays()
	var src_v: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var src_i: PackedInt32Array = src[Mesh.ARRAY_INDEX]

	var out_v := PackedVector3Array()
	var out_n := PackedVector3Array()
	var out_i := PackedInt32Array()
	for t in range(0, src_i.size(), 3):
		var a := src_v[src_i[t]]
		var b := src_v[src_i[t + 1]]
		var c := src_v[src_i[t + 2]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot(a) < 0.0:
			n = -n
		var base := out_v.size()
		out_v.append_array([a, b, c])
		out_n.append_array([n, n, n])
		out_i.append_array([base, base + 1, base + 2])

	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = out_n
	arrays[Mesh.ARRAY_INDEX] = out_i
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	if _mm == null:
		return
	for i in _mm.instance_count:
		var xf := _mm.get_instance_transform(i)
		xf.origin.z += scroll_speed * delta
		if _kind[i] == 1 and _valley:
			var hit: Dictionary = _valley.sample_wall(xf.origin.z, _wall_side[i], _wall_t[i])
			var embed := xf.basis.get_scale().x * wall_embed_ratio
			xf.origin = hit["position"] - (hit["normal"] as Vector3) * embed
		if xf.origin.z > recycle_z:
			_scatter(i, false)
		else:
			_mm.set_instance_transform(i, xf)


## 生成一块石头；initial 为 true 时分布在整段谷道，false 时只落回远端。
func _scatter(i: int, initial: bool) -> void:
	# 只有初始分布和回收后的远端分布；回收时不能突然出现在镜头前。
	var z := -_rng.randf_range(z_near, z_far) if initial else -_rng.randf_range(z_far * 0.82, z_far)
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var xf: Transform3D
	var s: float

	# 75% 的石头围绕一个簇中心，剩下 25% 保持松散分布。
	var clustered := initial and _rng.randf() < 0.75
	var cluster := _rng.randi_range(0, cluster_count - 1) if clustered else -1
	if cluster >= 0:
		z = _cluster_z[cluster] + _rng.randf_range(-cluster_spread, cluster_spread)
		side = _cluster_side[cluster]

	if _valley and _rng.randf() < wall_ratio:
		# 贴壁：t 靠近 0 的低处，位置由山壁高度场精确给出，并往山体里嵌一点。
		var t := (_cluster_t[cluster] + _rng.randf_range(-0.04, 0.06)) if cluster >= 0 else _rng.randf_range(0.03, 0.36)
		t = clampf(t, 0.015, 0.42)
		var hit: Dictionary = _valley.sample_wall(z, side, t)
		s = _rng.randf_range(1.4, 4.6)
		var embed := s * wall_embed_ratio
		var rot := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		rot = rot.scaled(Vector3(s, s * _rng.randf_range(0.7, 1.1), s))
		xf = Transform3D(rot, hit["position"] - (hit["normal"] as Vector3) * embed)
		_kind[i] = 1
		_wall_side[i] = side
		_wall_t[i] = t
	else:
		var landmark := _rng.randf() < 0.08
		var large := landmark or _rng.randf() < 0.22
		var x_norm := (_cluster_x[cluster] + _rng.randf_range(-0.06, 0.06)) if cluster >= 0 else _rng.randf_range(0.34, 0.98)
		x_norm = clampf(x_norm, 0.3, 0.99)
		var x := side * valley_half_width * x_norm
		var y := 0.3 if large else 0.4
		s = _rng.randf_range(12.0, 22.0) if landmark else (_rng.randf_range(6.0, 13.0) if large else _rng.randf_range(2.0, 6.5))
		var rot := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
		rot = rot.scaled(Vector3(s, s * _rng.randf_range(0.6, 1.15), s))
		xf = Transform3D(rot, Vector3(x, y, z))
		_kind[i] = 0

	_mm.set_instance_transform(i, xf)
	_mm.set_instance_color(i, PALETTE[_rng.randi_range(0, PALETTE.size() - 1)])

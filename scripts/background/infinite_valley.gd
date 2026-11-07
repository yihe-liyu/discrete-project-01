## 无限山谷：沿 Z 方向循环回收的连续 Mesh 块。
## 关键约束：高度只由世界坐标 H(x, world_z) 决定；相邻块在边界采样同一行顶点，
## 因此不会因为“换了一块”出现高度缝。块的回收只影响性能，不负责补缝。
class_name InfiniteValley
extends Node3D

@export var chunk_length: float = 1200.0
@export var chunk_count: int = 4
@export var width: float = 1200.0
@export var valley_half_width: float = 120.0
@export var wall_height: float = 340.0
@export var z_segments: int = 96
@export var noise_seed: int = 41
@export var noise_frequency: float = 0.008
@export var forward_speed: float = 80.0
@export var camera_z: float = 30.0
@export var base_color: Color = Color(0.05, 0.1, 0.09)
@export var peak_color: Color = Color(0.28, 0.4, 0.38)

var _chunks: Array[MeshInstance3D] = []
var _noise: FastNoiseLite
var _material: ShaderMaterial
var _z_step: float


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 3
	_z_step = chunk_length / z_segments

	_material = ShaderMaterial.new()
	_material.shader = preload("res://gdshader/valley_mountain.gdshader")

	for i in chunk_count:
		var chunk := MeshInstance3D.new()
		chunk.material_override = _material
		chunk.position.z = -chunk_length * i
		add_child(chunk)
		_chunks.append(chunk)
		_rebuild_chunk(chunk)

	for chunk in _chunks:
		chunk.visible = chunk.position.z > -3600.0


func _process(delta: float) -> void:
	for chunk in _chunks:
		chunk.position.z += forward_speed * delta

	# 只有整块尾巴都越过镜头才回收；放到最远处，保持块与块首尾相接。
	var min_z := _chunks[0].position.z
	for chunk in _chunks:
		min_z = minf(min_z, chunk.position.z)
	for chunk in _chunks:
		if chunk.position.z - chunk_length > camera_z:
			chunk.position.z = min_z - chunk_length
			min_z = chunk.position.z
		chunk.visible = chunk.position.z > -camera_z - 3600.0


func _rebuild_chunk(chunk: MeshInstance3D) -> void:
	# 横截面：谷底 → 山肩 → 次峰 → 主峰；每侧 5 个采样点。
	const PROFILE_X := [-0.5, -0.38, -0.26, -0.14, -0.05, 0.0, 0.05, 0.14, 0.26, 0.38, 0.5]
	const PROFILE_H := [1.0, 0.92, 0.58, 0.24, 0.04, 0.0, 0.04, 0.24, 0.58, 0.92, 1.0]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var base_z := chunk.position.z
	var cols := PROFILE_X.size()

	for i in z_segments + 1:
		var local_z := -i * _z_step
		var z_world := base_z + local_z
		for p in cols:
			var x := width * float(PROFILE_X[p])
			var ridge := _terrain_height(x, z_world)
			var h := ridge * float(PROFILE_H[p]) * wall_height
			verts.append(Vector3(x, h, local_z))
			uvs.append(Vector2(clampf(h / wall_height, 0.0, 1.0), float(p) / float(cols - 1)))
			normals.append(_terrain_normal(x, z_world, float(PROFILE_H[p])))

	for i in z_segments:
		var a := i * cols
		var b := (i + 1) * cols
		for p in cols - 1:
			indices.append_array([a + p, b + p, a + p + 1, a + p + 1, b + p, b + p + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	chunk.mesh = mesh


func _terrain_height(x: float, z: float) -> float:
	var large := (_noise.get_noise_2d(x * 0.35, z) + 1.0) * 0.5
	var detail := (_noise.get_noise_2d(x * 1.7, z * 1.8) + 1.0) * 0.5
	return 0.48 + 0.38 * large + 0.24 * detail


func _terrain_normal(x: float, z: float, profile_h: float) -> Vector3:
	# 用剖面上的有限差分估法线；边界处仍由纯世界坐标高度决定。
	const D := 2.0
	var h_l := _terrain_height(x - D, z) * profile_h
	var h_r := _terrain_height(x + D, z) * profile_h
	var h_b := _terrain_height(x, z - D) * profile_h
	var h_f := _terrain_height(x, z + D) * profile_h
	return Vector3(h_l - h_r, 2.0 * D, h_b - h_f).normalized()

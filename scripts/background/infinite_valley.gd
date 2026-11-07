## 无限山谷：沿 Z 方向循环回收的连续 Mesh 块。
## 关键约束：高度只由世界坐标 H(x, world_z) 决定；相邻块在边界采样同一行顶点，
## 因此不会因为“换了一块”出现高度缝。块的回收只影响性能，不负责补缝。
class_name InfiniteValley
extends Node3D

@export var chunk_length: float = 1200.0
@export var chunk_count: int = 4
@export var width: float = 900.0
@export var valley_half_width: float = 100.0
@export var wall_height: float = 260.0
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
	_material.shader = preload("res://gdshader/background_vertex_color.gdshader")

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
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var base_z := chunk.position.z

	for i in z_segments + 1:
		var local_z := -i * _z_step
		var z_world := base_z + local_z
		var h_left := _wall_height(-width * 0.5, z_world)
		var h_right := _wall_height(width * 0.5, z_world)
		verts.append_array([
			Vector3(-width * 0.5, h_left, local_z),
			Vector3(-valley_half_width, 0, local_z),
			Vector3(valley_half_width, 0, local_z),
			Vector3(width * 0.5, h_right, local_z),
		])
		colors.append_array([peak_color, base_color, base_color, peak_color])

	for i in z_segments:
		var a := i * 4
		var b := (i + 1) * 4
		# 谷底
		indices.append_array([a + 1, b + 1, a + 2, a + 2, b + 1, b + 2])
		# 左 / 右山壁
		indices.append_array([a, b, a + 1, a + 1, b, b + 1])
		indices.append_array([a + 2, b + 2, a + 3, a + 3, b + 2, b + 3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	chunk.mesh = mesh


func _wall_height(x: float, z: float) -> float:
	var n := (_noise.get_noise_2d(x, z) + 1.0) * 0.5
	return wall_height * (0.45 + 0.55 * pow(clampf(n, 0.0, 1.0), 1.4))

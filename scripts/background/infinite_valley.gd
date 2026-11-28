## 无限山谷：左壁 / 右壁 / 谷底拆成三个独立 Mesh，沿 Z 循环回收。
## 高度只由世界坐标 H(x, world_z) 决定；相邻块边界共享同一世界坐标行，因此不会出现高度缝。
## 拆 Mesh 是为了让中心线弯曲 / 谷宽变化时，山壁与谷底不会互相自交。
class_name InfiniteValley
extends Node3D

@export var chunk_length: float = 1200.0
@export var chunk_count: int = 4
@export var width: float = 850.0
@export var valley_half_width: float = 65.0
@export var wall_height: float = 560.0
@export var z_segments: int = 96
@export var noise_seed: int = 41
@export var noise_frequency: float = 0.008
@export var forward_speed: float = 80.0
@export var camera_z: float = 30.0
## 中心线摆动；会自动夹在谷宽内，保证镜头始终在山谷里
@export var meander: float = 40.0
@export var width_variation: float = 0.28
## 近景树线高度（世界单位）
@export var tree_height: float = 90.0
## 是否生成谷底（Stage04 原型关闭：谷底网格太抽象）
@export var build_floor: bool = true
## 是否生成山脚森林剪影（Stage04 原型关闭：会形成黑色条纹）
@export var build_forest: bool = true

const SIDE_T := [0.0, 0.18, 0.38, 0.62, 0.82, 1.0]
const LEFT_H := [0.0, 0.14, 0.34, 0.6, 0.84, 1.0]
const RIGHT_H := [0.0, 0.1, 0.3, 0.55, 0.8, 1.0]

var _chunks: Array[Node3D] = []
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
		var chunk := Node3D.new()
		chunk.position.z = -chunk_length * i
		add_child(chunk)
		_chunks.append(chunk)
		_build_chunk(chunk)

	for chunk in _chunks:
		chunk.visible = chunk.position.z > -3600.0


func _process(delta: float) -> void:
	for chunk in _chunks:
		chunk.position.z += forward_speed * delta

	var min_z := _chunks[0].position.z
	for chunk in _chunks:
		min_z = minf(min_z, chunk.position.z)
	for chunk in _chunks:
		if chunk.position.z - chunk_length > camera_z:
			chunk.position.z = min_z - chunk_length
			min_z = chunk.position.z
			_build_chunk(chunk)
		chunk.visible = chunk.position.z > -camera_z - 3600.0


func _build_chunk(chunk: Node3D) -> void:
	for child in chunk.get_children():
		child.queue_free()
	_add_wall(chunk, -1.0, LEFT_H)
	_add_wall(chunk, 1.0, RIGHT_H)
	if build_floor:
		_add_floor(chunk)
	if build_forest:
		_add_forest_line(chunk, -1.0)
		_add_forest_line(chunk, 1.0)


func _add_wall(chunk: Node3D, side: float, profile: Array) -> void:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var base_z := chunk.position.z
	var cols := SIDE_T.size()

	for i in z_segments + 1:
		var local_z := -i * _z_step
		var z_world := base_z + local_z
		var center := _center_at(z_world)
		var half := _half_width_at(z_world)
		for p in cols:
			var t: float = SIDE_T[p]
			var x := center + side * lerpf(half, width * 0.5, t)
			var h := _terrain_height(x, z_world) * float(profile[p]) * wall_height
			verts.append(Vector3(x, h, local_z))
			uvs.append(Vector2(clampf(h / wall_height, 0.0, 1.0), t))
			# 山壁法线稳定朝谷内：不再按高度噪声单独算，避免长条三角面被光切成宽条纹。
			normals.append(Vector3(-side, 0.18, 0.0).normalized())

	for i in z_segments:
		var a := i * cols
		var b := (i + 1) * cols
		for p in cols - 1:
			if side < 0.0:
				indices.append_array([a + p, b + p, a + p + 1, a + p + 1, b + p, b + p + 1])
			else:
				indices.append_array([a + p, a + p + 1, b + p, a + p + 1, b + p + 1, b + p])

	var mesh := _make_mesh(verts, normals, uvs, indices)
	var instance := MeshInstance3D.new()
	instance.name = "LeftWall" if side < 0.0 else "RightWall"
	instance.mesh = mesh
	instance.material_override = _material
	chunk.add_child(instance)


func _add_forest_line(chunk: Node3D, side: float) -> void:
	# 山壁脚部的针叶林剪影：一条不透明、顶边锯齿状的绿色带。
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var base_z := chunk.position.z

	for i in z_segments + 1:
		var local_z := -i * _z_step
		var z_world := base_z + local_z
		var center := _center_at(z_world)
		var half := _half_width_at(z_world)
		var x := center + side * (half - 1.0)
		var n1 := (_noise.get_noise_2d(x * 2.2, z_world * 0.9) + 1.0) * 0.5
		var n2 := (_noise.get_noise_2d(x * 5.1, z_world * 2.1) + 1.0) * 0.5
		var h := tree_height * (0.35 + 0.45 * n1 + 0.2 * n2)
		verts.append(Vector3(x, 0.0, local_z))
		verts.append(Vector3(x, h, local_z))
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		uvs.append(Vector2(0.0, 0.0))
		uvs.append(Vector2(0.0, 1.0))

	for i in z_segments:
		var a := i * 2
		var b := (i + 1) * 2
		indices.append_array([a, b, a + 1, a + 1, b, b + 1])

	var instance := MeshInstance3D.new()
	instance.name = "ForestL" if side < 0.0 else "ForestR"
	instance.mesh = _make_mesh(verts, normals, uvs, indices)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/forest_line.gdshader")
	instance.material_override = mat
	chunk.add_child(instance)


func _add_floor(chunk: Node3D) -> void:
	# 谷底不是一块平面：横向 5 列 + 轻微起伏；边缘回到 0 与山壁接上。
	const COLS := 5
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var base_z := chunk.position.z

	for i in z_segments + 1:
		var local_z := -i * _z_step
		var z_world := base_z + local_z
		var center := _center_at(z_world)
		var half := _half_width_at(z_world)
		for p in COLS:
			var t := float(p) / float(COLS - 1)
			var x := center - half + 2.0 * half * t
			var edge := absf(t - 0.5) * 2.0
			var y := (1.0 - edge) * _floor_height(x, z_world)
			verts.append(Vector3(x, y, local_z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.0, 0.5))

	for i in z_segments:
		var a := i * COLS
		var b := (i + 1) * COLS
		for p in COLS - 1:
			indices.append_array([a + p, b + p, a + p + 1, a + p + 1, b + p, b + p + 1])

	var instance := MeshInstance3D.new()
	instance.name = "Floor"
	instance.mesh = _make_mesh(verts, normals, uvs, indices)
	instance.material_override = _material
	chunk.add_child(instance)


func _floor_height(x: float, z: float) -> float:
	var n := _noise.get_noise_2d(x * 0.7 + 13.0, z * 0.9)
	return 2.2 + 2.0 * n


func _make_mesh(verts: PackedVector3Array, normals: PackedVector3Array,
		uvs: PackedVector2Array, indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _center_at(z: float) -> float:
	var half := _half_width_at(z)
	var raw := meander * _noise.get_noise_2d(17.0, z * 0.65)
	# 镜头在 x=0；中心线必须给内侧至少留 40 距离，避免山壁穿过镜头。
	var limit := maxf(0.0, half - 40.0)
	return clampf(raw, -limit, limit)


func _half_width_at(z: float) -> float:
	var n := (_noise.get_noise_2d(-31.0, z * 0.45) + 1.0) * 0.5
	return valley_half_width * (1.0 + width_variation * (n - 0.5) * 2.0)


func _terrain_height(x: float, z: float) -> float:
	var large := (_noise.get_noise_2d(x * 0.35, z) + 1.0) * 0.5
	# 降低高频细节，避免山嘴变成一排尖锐三角
	var detail := (_noise.get_noise_2d(x * 1.4, z * 1.4) + 1.0) * 0.5
	return 0.52 + 0.34 * large + 0.1 * detail


func _normal_at(x: float, z: float, profile_h: float) -> Vector3:
	const D := 2.0
	var h_l := _terrain_height(x - D, z) * profile_h
	var h_r := _terrain_height(x + D, z) * profile_h
	var h_b := _terrain_height(x, z - D) * profile_h
	var h_f := _terrain_height(x, z + D) * profile_h
	return Vector3(h_l - h_r, 2.0 * D, h_b - h_f).normalized()

extends MeshInstance3D
## Stage04 谷口收束墙：复用山壁材质，在远端把左右山壁连起来，避免中间露出天空缺口。

@export var width: float = 2600.0
@export var height: float = 520.0
@export var z_center: float = -2600.0
@export var segments: int = 96
@export var noise_seed: int = 73
@export var noise_frequency: float = 0.004


func _ready() -> void:
	var valley := get_node_or_null(^"../Valley")
	if valley and valley.has_method("get_wall_material"):
		material_override = valley.get_wall_material()

	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 3

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var x := -width * 0.5 + width * float(i) / float(segments)
		var n := (noise.get_noise_2d(x, z_center) + 1.0) * 0.5
		var top := height * (0.62 + 0.38 * n)
		verts.append(Vector3(x, 0.0, z_center))
		verts.append(Vector3(x, top, z_center))
		normals.append(Vector3(0, 0, 1))
		normals.append(Vector3(0, 0, 1))
		uvs.append(Vector2(float(i) / float(segments), 0.0))
		uvs.append(Vector2(float(i) / float(segments), 1.0))
	for i in segments:
		var a := i * 2
		var b := a + 2
		indices.append_array([a, b, a + 1, a + 1, b, b + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var built_mesh := ArrayMesh.new()
	built_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = built_mesh

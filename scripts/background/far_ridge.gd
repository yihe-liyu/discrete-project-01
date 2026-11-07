## 远景山脊幕布：只提供天际线，不参与滚动 / 碰撞。
## 用 UV.y 做山脚→山顶的颜色渐变；放在无限山谷的远后方，给山谷一个“出口”。
class_name FarRidge
extends MeshInstance3D

@export var width: float = 6000.0
@export var height: float = 900.0
@export var z_center: float = -3000.0
@export var segments: int = 160
@export var noise_seed: int = 71
@export var noise_frequency: float = 0.0018
@export var bottom_color: Color = Color(0.42, 0.52, 0.62)
@export var top_color: Color = Color(0.72, 0.8, 0.86)

var _noise: FastNoiseLite


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.fractal_octaves = 3
	_build()


func _build() -> void:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var step := width / segments
	for i in segments + 1:
		var x := -width * 0.5 + i * step
		var n := (_noise.get_noise_2d(x, z_center) + 1.0) * 0.5
		var h := height * (0.35 + 0.65 * pow(clampf(n, 0.0, 1.0), 1.5))
		verts.append(Vector3(x, 0.0, z_center))
		verts.append(Vector3(x, h, z_center))
		uvs.append(Vector2(float(i) / segments, 0.0))
		uvs.append(Vector2(float(i) / segments, 1.0))
	for i in segments:
		var a := i * 2
		var b := a + 2
		indices.append_array([a, b, a + 1, a + 1, b, b + 1])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var ridge_mesh := ArrayMesh.new()
	ridge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = ridge_mesh

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/far_ridge.gdshader")
	mat.set_shader_parameter("bottom_color", bottom_color)
	mat.set_shader_parameter("top_color", top_color)
	material_override = mat

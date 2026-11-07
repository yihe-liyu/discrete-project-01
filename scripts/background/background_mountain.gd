## 程序化低多边形山体：背景层专用，不参与碰撞。
##
## 一次生成一个「山脊地块」：X 方向山脊、Z 方向纵深；顶点色从谷底到山顶渐变。
## 不依赖外部网格 / 贴图，方便先定构图，再替换成正式资产。
class_name BackgroundMountain
extends MeshInstance3D

## 山体宽度（X）
@export var width: float = 1400.0
## 纵深（Z）
@export var depth: float = 260.0
## X / Z 分段数（越大越细，推荐 X=48~96 / Z=8~16）
@export var segments_x: int = 64
@export var segments_z: int = 12
## 最高峰高度
@export var height: float = 120.0
## 噪声种子 / 频率；不同层用不同 seed 避免完全同形
@export var noise_seed: int = 1
@export var noise_frequency: float = 0.006
## 谷底 / 山顶颜色
@export var base_color: Color = Color(0.18, 0.24, 0.28)
@export var peak_color: Color = Color(0.55, 0.62, 0.7)
## 世界 Z 位置（越远越负）
@export var z_center: float = -350.0


func _ready() -> void:
	_build()


func _build() -> void:
	if segments_x < 2 or segments_z < 1:
		push_error("BackgroundMountain: segments_x 至少 2，segments_z 至少 1")
		return
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var x_step := width / segments_x
	var z_step := depth / segments_z
	for zi in segments_z + 1:
		for xi in segments_x + 1:
			var x := -width * 0.5 + xi * x_step
			var z := z_center - depth * 0.5 + zi * z_step
			var n := (noise.get_noise_2d(x, z) + 1.0) * 0.5
			# 平方一下让山脚更平、山峰更尖
			var t := pow(clampf(n, 0.0, 1.0), 1.7)
			var y := t * height
			verts.append(Vector3(x, y, z))
			colors.append(base_color.lerp(peak_color, t))

	for zi in segments_z:
		for xi in segments_x:
			var a := zi * (segments_x + 1) + xi
			var b := a + 1
			var c := a + (segments_x + 1)
			var d := c + 1
			# 两个三角形；统一绕序，配合 cull_disabled
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mountain_mesh := ArrayMesh.new()
	mountain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	self.mesh = mountain_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color.WHITE
	material_override = mat

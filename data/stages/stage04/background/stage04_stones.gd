extends Node3D
## Stage04 谷底/山壁彩色石块散布：一个 MultiMesh，实例颜色区分。

@export var count: int = 130
@export var rng_seed: int = 404
@export var valley_half_width: float = 110.0
@export var z_near: float = 40.0
@export var z_far: float = 3200.0
## 与 InfiniteValley.forward_speed 对齐
@export var scroll_speed: float = 80.0
## 石头越过镜头多远后回收到远处
@export var recycle_z: float = 45.0

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


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed

	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.55
	sphere.radial_segments = 7
	sphere.rings = 4

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = sphere
	mm.instance_count = count
	_mm = mm

	for i in count:
		_scatter(i, true)

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/stage04_rock.gdshader")
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = mat
	add_child(instance)


func _process(delta: float) -> void:
	if _mm == null:
		return
	for i in _mm.instance_count:
		var xf := _mm.get_instance_transform(i)
		xf.origin.z += scroll_speed * delta
		if xf.origin.z > recycle_z:
			_scatter(i, false)
		else:
			_mm.set_instance_transform(i, xf)


## 生成一块石头；initial 为 true 时分布在整段谷道，false 时只落回远端。
func _scatter(i: int, initial: bool) -> void:
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	var z := -_rng.randf_range(z_near, z_far) if initial else -_rng.randf_range(z_far * 0.82, z_far)
	var x: float
	var y: float
	var s: float
	# 暂时只放地面：山壁石块需要贴山壁高度场，先不凭空放。
	x = side * _rng.randf_range(valley_half_width * 0.38, valley_half_width * 0.94)
	y = 0.4
	s = _rng.randf_range(2.0, 9.0)
	var rot := Basis(Vector3.UP, _rng.randf_range(0.0, TAU))
	rot = rot.scaled(Vector3(s, s * _rng.randf_range(0.6, 1.15), s))
	_mm.set_instance_transform(i, Transform3D(rot, Vector3(x, y, z)))
	_mm.set_instance_color(i, PALETTE[_rng.randi_range(0, PALETTE.size() - 1)])

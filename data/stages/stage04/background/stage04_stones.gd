extends Node3D
## Stage04 谷底/山壁彩色石块散布：一个 MultiMesh，实例颜色区分。

@export var count: int = 130
@export var rng_seed: int = 404
@export var valley_half_width: float = 110.0
@export var z_near: float = 40.0
@export var z_far: float = 3200.0

const PALETTE := [
	Color(0.18, 0.34, 0.4),
	Color(0.34, 0.26, 0.38),
	Color(0.44, 0.36, 0.24),
	Color(0.24, 0.4, 0.36),
	Color(0.3, 0.34, 0.4),
	Color(0.46, 0.3, 0.26),
]


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

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

	for i in count:
		var on_wall := i % 3 == 0
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var z := -rng.randf_range(z_near, z_far)
		var x: float
		var y: float
		var s: float
		if on_wall:
			x = side * rng.randf_range(valley_half_width * 0.55, valley_half_width * 0.95)
			y = rng.randf_range(15.0, 260.0)
			s = rng.randf_range(2.0, 7.0)
		else:
			x = side * rng.randf_range(valley_half_width * 0.38, valley_half_width * 0.94)
			y = rng.randf_range(0.0, 2.0)
			s = rng.randf_range(2.0, 9.0)

		var rot := Basis(Vector3.UP, rng.randf_range(0.0, TAU))
		rot = rot.scaled(Vector3(s, s * rng.randf_range(0.6, 1.15), s))
		var xf := Transform3D(rot, Vector3(x, y, z))
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, PALETTE[rng.randi_range(0, PALETTE.size() - 1)])

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/stage04_rock.gdshader")
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = mm
	instance.material_override = mat
	add_child(instance)

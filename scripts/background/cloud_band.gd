## 远景云带：一块竖向 Quad + 程序噪声 alpha；只做背景，不投影/不碰撞。
class_name CloudBand
extends Node3D

@export var size: Vector2 = Vector2(4200.0, 1300.0)
@export var position_offset: Vector3 = Vector3(0, 420, -2600)
@export var cloud_color: Color = Color(0.82, 0.88, 0.92, 1.0)
@export_range(0.0, 1.0) var opacity: float = 0.55
@export var noise_scale: float = 1.6
@export var speed: float = 0.008


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.position = position_offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/cloud_band.gdshader")
	mat.set_shader_parameter("noise_tex", preload("res://assets/Textures/background/stage01/cloud_noise.tres"))
	mat.set_shader_parameter("cloud_color", cloud_color)
	mat.set_shader_parameter("opacity", opacity)
	mat.set_shader_parameter("scale", noise_scale)
	mat.set_shader_parameter("speed", speed)
	instance.material_override = mat
	add_child(instance)

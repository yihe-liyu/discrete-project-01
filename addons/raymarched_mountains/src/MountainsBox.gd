@tool
@icon("res://addons/raymarched_mountains/src/icons8-mountain-32.png")
extends MeshInstance3D

@export_category("Textures")
@export var Heightmap : Texture2D:
	set(value):
		Heightmap = value
		if material_override: material_override.set_shader_parameter("noise", value)
@export var FogGradient : Texture2D:
	set(value):
		FogGradient = value
		if material_override: material_override.set_shader_parameter("fogGradient", value)

@export_category("Terrain Params")
@export var UVScale : float = 0.04:
	set(value):
		UVScale = value
		if material_override: material_override.set_shader_parameter("uv_scale", value)
@export var TerrainScale : float = 100.0:
	set(value):
		TerrainScale = value
		if material_override: material_override.set_shader_parameter("terrain_scale", value)

@export_category("Fog Params")
@export var FogStart : float = 500.0:
	set(value):
		FogStart = value
		if material_override: material_override.set_shader_parameter("fogStart", value)
@export var FogEnd : float = 1000.0:
	set(value):
		FogEnd = value
		if material_override: material_override.set_shader_parameter("fogEnd", value)

@export_category("Colors")
@export var TerrainColor : Color = Color(0.733, 0.969, 0.361):
	set(value):
		TerrainColor = value
		if material_override: material_override.set_shader_parameter("terrain_color", value)
@export var ShadowColor : Color = Color(0.129, 0.078, 0.0):
	set(value):
		ShadowColor = value
		if material_override: material_override.set_shader_parameter("shadow_color", value)

@export_category("Mesh Settings")
@export var mesh_size : float = 2000.0:
	set(value):
		mesh_size = value
		if SHADER_MATERIAL: SHADER_MATERIAL.set_shader_parameter("MAX_DIST", value)
var box_mesh : BoxMesh

var SHADER_MATERIAL : ShaderMaterial

func _ready():
	SHADER_MATERIAL = preload(
		"res://addons/raymarched_mountains/src/shaders/Terrain.tres"
	).duplicate()
	set_material()
	update_mesh()

func set_material():
	self.material_override = SHADER_MATERIAL
	if Engine.is_editor_hint():
		if Heightmap == null: Heightmap = preload("res://addons/raymarched_mountains/src/Textures/Heightmap.tres").duplicate_deep()
		if FogGradient == null: FogGradient = preload("res://addons/raymarched_mountains/src/Textures/Gradient.tres").duplicate_deep()


	material_override.set_shader_parameter("noise", Heightmap)
	material_override.set_shader_parameter("fogGradient", FogGradient)
	material_override.set_shader_parameter("uv_scale", UVScale)
	material_override.set_shader_parameter("terrain_scale", TerrainScale)
	material_override.set_shader_parameter("fogStart", FogStart)
	material_override.set_shader_parameter("fogEnd", FogEnd)
	material_override.set_shader_parameter("terrain_color", TerrainColor)
	material_override.set_shader_parameter("shadow_color", ShadowColor)
	material_override.set_shader_parameter("MAX_DIST", mesh_size)

func update_mesh():
	box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(mesh_size,mesh_size,mesh_size)
	box_mesh.flip_faces = true
	mesh = box_mesh

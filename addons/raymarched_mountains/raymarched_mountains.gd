@tool
extends EditorPlugin


func _enter_tree():
	add_custom_type("RaymarchedMountains", "MeshInstance3D",
		preload("res://addons/raymarched_mountains/src/MountainsBox.gd"),
		preload("res://addons/raymarched_mountains/src/icons8-mountain-32.png"))


func _exit_tree():
	remove_custom_type("RaymarchedMountains")

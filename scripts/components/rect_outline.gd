## 自动把自身像素尺寸同步到 shader 的 rect_size 参数
extends ColorRect
class_name RectOutline

func _ready() -> void:
	resized.connect(_update_size)
	_update_size()

func _update_size() -> void:
	if material and material is ShaderMaterial:
		material.set_shader_parameter("rect_size", size)

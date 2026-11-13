## 内容侧 native behavior 描述：只保存名字 + 固定 float 参数，不承载逻辑。
## 真正的 tick 在 behaviors_core 的 C++ pack 里。
class_name NativeBehaviorSpec
extends RefCounted

var id: StringName
var params: PackedFloat32Array


func _init(p_id: StringName = &"", p_params: PackedFloat32Array = PackedFloat32Array()) -> void:
	id = p_id
	params = p_params

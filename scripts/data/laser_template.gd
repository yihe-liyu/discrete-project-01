## 激光生成模板：behavior 只引用 id；宿主按模板创建 LaserBeam。
class_name LaserTemplate
extends RefCounted

var id: StringName
var numeric_id: int = -1
var skeleton: LaserSkeleton
var color: Color = Color.WHITE
var opts: Dictionary = {}
var offset: Vector2 = Vector2.ZERO
var at_current: bool = true


func _init(p_id: StringName = &"", p_skeleton: LaserSkeleton = null,
		p_color: Color = Color.WHITE, p_opts: Dictionary = {},
		p_offset: Vector2 = Vector2.ZERO, p_at_current: bool = true) -> void:
	id = p_id
	skeleton = p_skeleton
	color = p_color
	opts = p_opts
	offset = p_offset
	at_current = p_at_current


func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("LaserTemplate.id 不能为空")
	if skeleton == null:
		errors.append("LaserTemplate.skeleton 不能为空")
	return errors

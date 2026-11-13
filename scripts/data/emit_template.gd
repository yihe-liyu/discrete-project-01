## 可复用的子弹出模板：外观 / 运动 / 颜色。
## 模板是内容层的共享描述，不进入 C++；C++ behavior 只引用稳定 id。
class_name EmitTemplate
extends RefCounted

## 稳定模板 id（由内容层命名；Registry 查重）。
var id: StringName
## 复用的子弹构造器；模板只读，不要在发射后改它。
var bullet: BulletData
## 子弹出运动；null = 默认直线。
var behavior: BehaviorSpec


func _init(p_id: StringName = &"", p_bullet: BulletData = null, p_behavior: BehaviorSpec = null) -> void:
	id = p_id
	bullet = p_bullet
	behavior = p_behavior


## 返回错误列表；空 = 可用。这里只做内容层能判断的校验。
func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("EmitTemplate.id 不能为空")
	if bullet == null:
		errors.append("EmitTemplate.bullet 不能为空")
	if bullet != null:
		if bullet.texture == null:
			errors.append("EmitTemplate.bullet.texture 不能为空")
		if bullet.hitbox_radius <= 0.0:
			errors.append("EmitTemplate.bullet.hitbox_radius 必须 > 0")
	if behavior != null:
		if behavior.id == &"":
			errors.append("EmitTemplate.behavior.id 不能为空")
		if behavior.params.size() > 8:
			errors.append("EmitTemplate.behavior.params 不能超过 8 个")
	return errors

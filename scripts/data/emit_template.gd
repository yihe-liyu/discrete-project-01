## 可复用的子弹出模板：外观 / 运动 / 颜色。
## 模板是内容层的共享描述，不进入 C++；C++ behavior 只引用稳定 id。
class_name EmitTemplate
extends RefCounted

## 稳定模板 id（由内容层命名；Registry 查重）。
var id: StringName
## Registry 分配的数字 id；C++ Outcome 只引用它。
var numeric_id: int = -1
## 子弹出描述；必填。
var spawn_spec: SpawnSpec
## 子弹出运动；null = 默认直线。
var behavior: BehaviorSpec


func _init(p_id: StringName = &"", p_spec: SpawnSpec = null, p_behavior: BehaviorSpec = null) -> void:
	id = p_id
	spawn_spec = p_spec
	behavior = p_behavior


## 返回错误列表；空 = 可用。这里只做内容层能判断的校验。
func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("EmitTemplate.id 不能为空")
	if spawn_spec == null:
		errors.append("EmitTemplate.spawn_spec 不能为空")
		return errors
	if spawn_spec.texture == null:
		errors.append("EmitTemplate 的贴图不能为空")
	var radius := spawn_spec.hitbox_radius
	if radius < 0.0 and spawn_spec.bullet_def != null:
		radius = spawn_spec.bullet_def.hitbox_radius
	if radius == 0.0:
		errors.append("EmitTemplate.hitbox_radius 不能为 0")
	if behavior != null:
		if behavior.id == &"":
			errors.append("EmitTemplate.behavior.id 不能为空")
		if behavior.params.size() > 8:
			errors.append("EmitTemplate.behavior.params 不能超过 8 个")
	return errors

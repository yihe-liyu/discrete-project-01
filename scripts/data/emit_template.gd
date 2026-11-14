## 可复用的子弹出模板：外观 / 运动 / 颜色。
## 模板是内容层的共享描述，不进入 C++；C++ behavior 只引用稳定 id。
class_name EmitTemplate
extends RefCounted

## 稳定模板 id（由内容层命名；Registry 查重）。
var id: StringName
## Registry 分配的数字 id；C++ Outcome 只引用它。
var numeric_id: int = -1
## 旧路径：BulletData 模板（兼容旧内容）。
var bullet: BulletData
## 新路径：SpawnSpec 模板；两者只有一个非空。
var spawn_spec: SpawnSpec
## 子弹出运动；null = 默认直线。
var behavior: BehaviorSpec


func _init(p_id: StringName = &"", p_bullet: Variant = null, p_behavior: BehaviorSpec = null) -> void:
	id = p_id
	if p_bullet is SpawnSpec:
		spawn_spec = p_bullet
	elif p_bullet is BulletData:
		bullet = p_bullet
	behavior = p_behavior


## 返回错误列表；空 = 可用。这里只做内容层能判断的校验。
func validate() -> Array[String]:
	var errors: Array[String] = []
	if id == &"":
		errors.append("EmitTemplate.id 不能为空")
	if bullet == null and spawn_spec == null:
		errors.append("EmitTemplate.bullet / spawn_spec 不能为空")
	var tex: Texture2D = spawn_spec.texture if spawn_spec != null else (bullet.texture if bullet != null else null)
	if tex == null:
		errors.append("EmitTemplate 的贴图不能为空")
	var radius: float = spawn_spec.hitbox_radius if spawn_spec != null else (bullet.hitbox_radius if bullet != null else -1.0)
	if radius == 0.0:
		errors.append("EmitTemplate.hitbox_radius 不能为 0")
	if behavior != null:
		if behavior.id == &"":
			errors.append("EmitTemplate.behavior.id 不能为空")
		if behavior.params.size() > 8:
			errors.append("EmitTemplate.behavior.params 不能超过 8 个")
	return errors

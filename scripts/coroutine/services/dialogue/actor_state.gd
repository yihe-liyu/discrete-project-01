class_name ActorState
extends RefCounted
## 舞台角色状态 —— 对话演出中单个角色的"真相"（位置/翻转/明暗/表情/在场）
## 由 StageState 统一管理；DSL 步骤只描述"变化"，不重复整行属性

var char_name: String = ""
var profile: CharacterProfile
var position: Vector2 = Vector2(50, 230)
var flip_h: bool = false
var light: float = 1.0      ## 明暗：1=正常，<1=暗（沉默在场者 0.35）
var visible: bool = false   ## 在场与否
var emotion: String = "通常"
var bubble_offset: Vector2 = Vector2(12, 0)  ## 气泡相对立绘右缘偏移（旧模型默认粘滞值）


func setup(p_profile: CharacterProfile) -> void:
	profile = p_profile
	char_name = p_profile.char_name
	# 默认值来自 profile（新增字段，向后兼容：旧 .tres 加载用 @export 默认）
	position = p_profile.default_pos
	flip_h = p_profile.default_flip
	bubble_offset = p_profile.default_bubble_offset

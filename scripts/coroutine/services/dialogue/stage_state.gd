class_name StageState
extends RefCounted
## 对话舞台状态 —— 所有在场角色的唯一真相（char_name → ActorState）
##
## 关键语义：
## - 状态"声明即改变，不声明不动"——DSL 步骤只改自己关心的字段
## - apply_line 是唯一自动推断点：说话者亮、沉默在场者暗
## - 不涉及任何 UI/渲染（z 排序、气泡创建归播放器）

var actors: Dictionary = {}  # char_name → ActorState


## 取角色状态（不存在则按 profile 创建并登场）
func ensure(profile: CharacterProfile) -> ActorState:
	var name_key: String = profile.char_name
	if not actors.has(name_key):
		var a := ActorState.new()
		a.setup(profile)
		actors[name_key] = a
	return actors[name_key]


func actor(char_name: String) -> ActorState:
	return actors.get(char_name, null)


func has(char_name: String) -> bool:
	return actors.has(char_name)


## 应用一屏对话（bubbles）的自动规则：说话者亮 + 在场；沉默在场者变暗；表情跟随气泡。
## 返回说话者列表（text 非空的气泡）。
func apply_line(line: DialogueLine) -> Array[String]:
	var speakers_list: Array[String] = []
	for bubble in line.bubbles:
		if bubble.speaker == null:
			continue
		var actor_state := ensure(bubble.speaker)
		actor_state.is_visible = true
		# 表情是内容属性：这句里该角色什么表情（含沉默者，与旧模型一致）
		if not bubble.emotion.is_empty():
			actor_state.emotion = bubble.emotion
		if not bubble.text.is_empty():
			actor_state.light = 1.0
			if not speakers_list.has(actor_state.char_name):
				speakers_list.append(actor_state.char_name)
	# 沉默在场者变暗
	for name_key in actors:
		if not speakers_list.has(name_key):
			actors[name_key].light = 0.35
	return speakers_list


## 所有在场角色（调试/测试用）
func present_actors() -> Array:
	var out: Array = []
	for name_key in actors:
		if actors[name_key].is_visible:
			out.append(actors[name_key])
	return out

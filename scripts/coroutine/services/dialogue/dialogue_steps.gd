class_name DialogueSteps
extends RefCounted
## 对话流程 DSL —— 构建步骤序列（Array[DialogueStep]）
##
## **推荐写法（句柄）**：`enter()` 返回 `ActorHandle`，"谁"是接收者而不是参数：
##   var d := DialogueSteps.new()
##   var reimu := d.enter(reimu_profile, Vector2(200, 200))
##   reimu.line("啊，什么线索都没有…")                 # 顺序说完可链式
##   var ka := d.enter(ka_profile, Vector2(1300, 230))  # 进场后自动成为延续者
##   ka.line("哦呀，弱小的人类怎么会在永夜出门？", {"emotion": "疑惑"})
##   ka.portrait("耍帅").move(Vector2(550, 230), 1.0)
##   d.event("bgm_switch")                              # 行间事件，时机精确
##   d.wait(0.5)
##   ka.exit()
##   ctx.play_dialogue_steps(d.steps)
##
## 低层写法（同样有效，句柄就是薄委托）：`d.say(p, …)` / `d.move(p, …)` —— 收 profile。
## **多角色同屏**用 `d.screen([...])`（句柄表达不了"一屏多泡"）。
##
## 原则：只描述"变化"；位置/flip/明暗/表情等在状态里"声明即改变，不声明不动"。
## `d.line()` 的说话者默认延续上一句（enter 也会更新延续者）；想在句柄上显式指定就用 `handle.line()`。

var steps: Array[DialogueStep] = []

var _character_profile: CharacterProfile  ## line() 默认说话者（延续机制）
## 已登场且未退场的 actor key（`enter` 重复登场 / `exit` 之后再登场 的判据）
var _on_stage: Dictionary = {}

## 所有"演出版"动词（exit/move/flip/dim/portrait/bubble）都收 **CharacterProfile**，
## 与 enter/say 一致 —— 步骤里落的是 actor key（`char_name`），但内容层不该知道这个 stringly key：
## 角色改名不会静默漏掉编排，写错也没法拼错字符串。
func _actor_key(profile: CharacterProfile) -> String:
	if profile == null:
		push_warning("DialogueSteps: profile 为 null（步骤会被跳过）")
		return ""
	return profile.char_name


## 该角色当前是否"在场上"（已 enter 且未 exit）—— 供内容自检 / 重复登场判据
func has_entered(profile: CharacterProfile) -> bool:
	if profile == null:
		return false
	return _on_stage.has(profile.char_name)


## 退场时清掉在场标记（允许"退场后再登场"，但连续两次 enter 会告警）
func _mark_exited(profile: CharacterProfile) -> void:
	if profile != null:
		_on_stage.erase(profile.char_name)


func _add(step: DialogueStep) -> DialogueSteps:
	steps.append(step)
	return self


## 显示一句台词（延续上一说话者；首句或换人用 say() 或 opts.speaker）
func line(text: String, opts: Dictionary = {}) -> DialogueSteps:
	var speaker: CharacterProfile = opts.get("speaker", _character_profile)
	assert(speaker != null, "DialogueSteps.line: 需要说话者——首句请用 say(profile, text) 或传 opts.speaker")
	var line_data := _build_line(speaker, text, opts)
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.LINE
	step.line_data = line_data
	_character_profile = speaker
	return _add(step)


## 指定说话者的台词（换人/首句用）
func say(profile: CharacterProfile, text: String, opts: Dictionary = {}) -> DialogueSteps:
	opts["speaker"] = profile
	return line(text, opts)


## 一屏台词（多人）—— 数组每项：谁 / 什么表情 / 说什么话。
## 每项可写为数组 [speaker, emotion, text]，或字典 {speaker, emotion, text}。
## text 为空 → 该角色在场但沉默（自动变暗）；多气泡 → 同屏多人（齐声/一起在场）。
## 显式要求：每屏至少一个真正开口的（text 非空）；纯沉默转场请用 wait()。
## 延续说话者 = 最后一个真正开口的（text 非空），方便后续用 line() 继续。
func screen(specs: Array, opts: Dictionary = {}) -> DialogueSteps:
	assert(not specs.is_empty(), "DialogueSteps.screen: specs 不能为空")
	var line_data := DialogueLine.new()
	line_data.can_skip = opts.get("skippable", true)
	line_data.auto_advance = opts.get("auto_advance", 0.0)
	var has_spoke := false
	for spec in specs:
		var bubble_data := DialogueBubble.new()
		if spec is Array:
			if spec.size() > 0: bubble_data.speaker = spec[0]
			if spec.size() > 1: bubble_data.emotion = spec[1]
			if spec.size() > 2: bubble_data.text = spec[2]
		else:
			bubble_data.speaker = spec.get("speaker")
			bubble_data.emotion = spec.get("emotion", "")   # 不声明 = 保持该角色当前表情
			bubble_data.text = spec.get("text", "")
		line_data.bubbles.append(bubble_data)
		if bubble_data.speaker and not bubble_data.text.is_empty():
			_character_profile = bubble_data.speaker
			has_spoke = true
	assert(has_spoke, "DialogueSteps.screen: 每屏至少需一个真正开口的角色（text 非空）；纯沉默转场请用 wait()")
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.LINE
	step.line_data = line_data
	return _add(step)


func _build_line(speaker: CharacterProfile, text: String, opts: Dictionary) -> DialogueLine:
	var line_data := DialogueLine.new()
	var bubble_data := DialogueBubble.new()  # 不叫 bubble：避免遮蔽 DSL 的 bubble() 方法
	bubble_data.speaker = speaker
	bubble_data.text = text
	# **情绪不声明就不动**（"声明即改变"）：空串 → `StageState.apply_line` 不会覆盖 actor 当前表情。
	# ⚠️ 曾默认 "通常"，于是 `reimu.portrait("笑").line("…")` 刚设的表情会被这句话**冲掉**
	#    （handle 写法暴露的老 bug）。要复位写 `{"emotion": "通常"}`。
	bubble_data.emotion = opts.get("emotion", "")
	line_data.bubbles = [bubble_data]
	line_data.can_skip = opts.get("skippable", true)
	line_data.auto_advance = opts.get("auto_advance", 0.0)
	return line_data


## 登场：profile 决定立绘/表情集；opts 可带 flip/dim/emotion。
## **返回 `ActorHandle`** —— 之后这个角色的演出/台词都挂它（"谁"是接收者，不会传错人）。
## 同一角色连续两次 enter（没先 exit）会告警：剧本多半漏了 exit。
func enter(profile: CharacterProfile, pos: Vector2, opts: Dictionary = {}) -> ActorHandle:
	if profile == null:
		push_warning("DialogueSteps.enter: profile 为 null（步骤被跳过）")
		return ActorHandle.new(self, null)
	if has_entered(profile):
		push_warning("DialogueSteps.enter: %s 已经在场上（忘了 exit()？）" % profile.char_name)
	_on_stage[profile.char_name] = true
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.ENTER
	step.profile = profile
	step.char_name = profile.char_name
	step.pos = pos
	step.is_flip = opts.get("flip", false)
	step.light = opts.get("dim", 1.0)
	step.emotion = opts.get("emotion", "通常")
	# 新角色进场后通常是他说下一句 → 更新延续者
	_character_profile = profile
	_add(step)
	return ActorHandle.new(self, profile)


## 退场（传角色）
func exit(profile: CharacterProfile) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.EXIT
	step.char_name = _actor_key(profile)
	_mark_exited(profile)
	return _add(step)


## 移动立绘（可选时长，秒）
func move(profile: CharacterProfile, pos: Vector2, duration: float = 0.0) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.MOVE
	step.char_name = _actor_key(profile)
	step.pos = pos
	step.duration = duration
	return _add(step)


## 水平翻转
func flip(profile: CharacterProfile, flipped: bool) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.FLIP
	step.char_name = _actor_key(profile)
	step.is_flip = flipped
	return _add(step)


## 手动明暗（0~1）
func dim(profile: CharacterProfile, value: float) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.DIM
	step.char_name = _actor_key(profile)
	step.light = value
	return _add(step)


## 换表情（立绘 key）
func portrait(profile: CharacterProfile, emotion_key: String) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.PORTRAIT
	step.char_name = _actor_key(profile)
	step.emotion = emotion_key
	return _add(step)


## 调气泡偏移
func bubble(profile: CharacterProfile, offset: Vector2) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.BUBBLE
	step.char_name = _actor_key(profile)
	step.bubble_offset = offset
	return _add(step)


## 行间事件（时机精确：出现在步骤序列的任意位置）
func event(event_key: String) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.EVENT
	step.event_key = event_key
	return _add(step)


## 停顿（秒）——行间等待演出
func wait(seconds: float) -> DialogueSteps:
	var step := DialogueStep.new()
	step.type = DialogueStep.Type.WAIT
	step.duration = seconds
	return _add(step)

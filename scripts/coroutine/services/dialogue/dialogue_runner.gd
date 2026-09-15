class_name DialogueRunner
extends RefCounted
## 对话步骤解释器 —— 纯逻辑，不进树，可测试
##
## 语义：
## - 舞台状态（StageState）是唯一真相；步骤只描述"变化"
## - 演出类步骤（enter/exit/move/flip/dim/portrait/bubble/event）立即执行并推进
## - LINE 步骤从台词库取行 → 应用自动明暗 → 停在等待（玩家 advance 或 auto_advance）
## - WAIT 步骤停在计时（tick 驱动）
## - EVENT 步骤即"行间事件"：出现在步骤序列任意位置，时机精确

signal line_shown(line: DialogueLine, speakers: Array, state: StageState)
signal state_changed(state: StageState, duration: float)
signal event_fired(event_key: String)
signal finished()

var state := StageState.new()

var _steps: Array[DialogueStep] = []
var _idx: int = -1
var _dialogue_line: DialogueLine = null
var _wait_left: float = 0.0
var _auto_left: float = 0.0

var is_waiting_line: bool = false  ## 停在某句，等 advance / auto_advance
var is_waiting_time: bool = false  ## 停在 WAIT 计时


func start(steps: Array[DialogueStep]) -> void:
	state = StageState.new()
	_steps = steps
	_idx = -1
	_dialogue_line = null
	is_waiting_line = false
	is_waiting_time = false
	_advance()


## 每帧推进（WAIT 计时 / LINE 的 auto_advance）
func tick(delta: float) -> void:
	if is_waiting_time:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_advance()
	elif is_waiting_line and _auto_left > 0.0:
		_auto_left -= delta
		if _auto_left <= 0.0:
			_advance()


## 玩家推进（Z 确认 / X 跳过本句）：仅在停在 LINE 时有效
func advance() -> void:
	if is_waiting_line:
		_advance()


func current_line() -> DialogueLine:
	return _dialogue_line


func is_finished() -> bool:
	return _idx >= _steps.size()


func _advance() -> void:
	is_waiting_line = false
	is_waiting_time = false
	_idx += 1
	if _idx >= _steps.size():
		_dialogue_line = null
		finished.emit()
		return
	_exec(_steps[_idx])


func _exec(step: DialogueStep) -> void:
	match step.type:
		DialogueStep.Type.LINE:
			var line: DialogueLine = step.line_data
			if line == null:
				push_warning("DialogueRunner: LINE 步骤缺少台词数据")
				_advance()
				return
			_dialogue_line = line
			var speakers: Array = state.apply_line(line)
			_auto_left = line.auto_advance
			state_changed.emit(state, 0.0)
			line_shown.emit(line, speakers, state)
			is_waiting_line = true

		DialogueStep.Type.ENTER:
			var a := state.ensure(step.profile)
			a.is_visible = true
			a.position = step.pos
			a.is_flip_h = step.is_flip
			a.light = step.light
			a.emotion = step.emotion
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.EXIT:
			var a := state.actor(step.char_name)
			if a: a.is_visible = false
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.MOVE:
			var a := state.actor(step.char_name)
			if a: a.position = step.pos
			state_changed.emit(state, step.duration)
			_advance()

		DialogueStep.Type.FLIP:
			var a := state.actor(step.char_name)
			if a: a.is_flip_h = step.is_flip
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.DIM:
			var a := state.actor(step.char_name)
			if a: a.light = step.light
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.PORTRAIT:
			var a := state.actor(step.char_name)
			if a: a.emotion = step.emotion
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.BUBBLE:
			var a := state.actor(step.char_name)
			if a: a.bubble_offset = step.bubble_offset
			state_changed.emit(state, 0.0)
			_advance()

		DialogueStep.Type.EVENT:
			event_fired.emit(step.event_key)
			_advance()

		DialogueStep.Type.WAIT:
			if step.duration <= 0.0:
				_advance()
				return
			_wait_left = step.duration
			is_waiting_time = true

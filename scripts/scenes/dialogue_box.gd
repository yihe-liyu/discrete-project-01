extends CanvasLayer
## 气泡对话系统（步骤驱动版）—— 立绘 + 飘浮气泡
##
## 由 DialogueRunner 驱动：本节点只做"渲染舞台状态 + 转发事件"，不维护行索引/粘滞。
## 舞台状态（StageState/ActorState）是唯一真相：位置/翻转/明暗/表情/在场全部由 DSL 步骤改变。
##
## 操作:
##   Z / Enter     → 下一句 / 结束对话
##   X (短按)      → 跳过本句（若 line.skippable）
##   X (长按 0.6s) → 关闭整个对话
##
## 文本标记:
##   [shake=N]  — 气泡抖动 N 秒 (默认 0.3s)
##   BBCode 颜色 — [color=red]文字[/color] 等（Label 原生支持）

signal finished()

## 长按取消键多久关闭对话
@export var cancel_hold_threshold: float = 0.6
## 新句出现后的输入冷却（防止误触跳过）
@export var input_cooldown: float = 0.2

const POS_TWEEN_DEFAULT := 0.35  ## 无 duration 时立绘位置渐变时长
const MOD_TWEEN_DEFAULT := 0.25  ## 明暗渐变时长

@onready var _root: Control = $Control

var _runner: DialogueRunner
var _portrait_map: Dictionary = {}  # char_name → {node, profile}
var _cancel_held: float = 0.0
var _input_ready: bool = false
var _is_closing: bool = false

# ═══ 生命周期 ═══

func _ready() -> void:
	visible = false
	_root.modulate.a = 0.0

## 播放一段对话（DialogueSteps 步骤序列，台词已内联）
func play_steps(steps: Array) -> void:
	process_mode = PROCESS_MODE_ALWAYS  # 暂停时也跑
	_is_closing = false
	visible = true
	_runner = DialogueRunner.new()
	_runner.line_shown.connect(_on_line_shown)
	_runner.state_changed.connect(_on_state_changed)
	_runner.event_fired.connect(_on_event_fired)
	_runner.finished.connect(_on_finished)
	# 淡入完成后启动步骤（演出立绘在淡入后才开始出现，与旧行为一致）
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.3)
	tw.tween_callback(func(): _runner.start(steps))

	if not GameManager.game_state_changed.is_connected(_on_game_state):
		GameManager.game_state_changed.connect(_on_game_state)

func _exit_tree() -> void:
	if GameManager.game_state_changed.is_connected(_on_game_state):
		GameManager.game_state_changed.disconnect(_on_game_state)


func _process(delta: float) -> void:
	if _is_closing or not _runner:
		return
	# 暂停（暂停菜单）时冻结对话计时，恢复后从暂停处继续；
	# 保留 PROCESS_MODE_ALWAYS 让淡出动画照常，仅停掉 _runner.tick
	if GameManager.current_state == GameManager.AppState.PAUSED:
		return
	# 步骤计时（WAIT / auto_advance）
	_runner.tick(delta)
	if not _input_ready:
		return
	# 长按取消 → 关闭对话
	if Input.is_action_pressed("ui_cancel"):
		_cancel_held += delta
		if _cancel_held >= cancel_hold_threshold:
			_close()
			return
	else:
		_cancel_held = 0.0

func _input(event: InputEvent) -> void:
	if _is_closing or not _input_ready or not _runner:
		return
	# 暂停时不处理输入
	if GameManager.current_state == GameManager.AppState.PAUSED:
		return

	if event.is_action_pressed("ui_cancel"):
		_cancel_held = 0.0

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

	elif event.is_action_released("ui_cancel"):
		# 短按取消 = 跳过本句
		var line := _runner.current_line()
		if _cancel_held < cancel_hold_threshold and line and line.skippable:
			get_viewport().set_input_as_handled()
			_advance()

# ═══ 推进 ═══

func _advance() -> void:
	if _runner:
		_runner.advance()

# ═══ Runner 回调 ═══

func _on_line_shown(line: DialogueLine, speakers: Array, state: StageState) -> void:
	_clear_bubbles()
	_cancel_held = 0.0
	_render_state(state, speakers)

	# 创建气泡（仅说话者）
	for b in line.bubbles:
		if b.text.is_empty():
			continue
		if not state.has(b.speaker.char_name):
			continue
		var info: Dictionary = _portrait_map[b.speaker.char_name]
		var actor: ActorState = state.actor(b.speaker.char_name)
		var panel := BubblePanel.create(b.text)
		info.node.add_child(panel)
		panel.position = Vector2(info.node.size.x, 0) + actor.bubble_offset
		if panel._shake_dur > 0.0:
			panel.shake(info.node)
		info.node.set_meta("_bubble_panel", panel)

	# 输入冷却
	if input_cooldown > 0.0:
		_input_ready = false
		await get_tree().create_timer(input_cooldown).timeout
		if not is_inside_tree() or _is_closing:
			return
	_input_ready = true


func _on_state_changed(state: StageState, duration: float) -> void:
	if _is_closing:
		return
	_render_state(state, [], duration)


func _on_event_fired(event_key: String) -> void:
	GameEvents.dialogue_event.emit(event_key)


func _on_finished() -> void:
	_close()


## 按舞台状态渲染所有角色（在场/位置/翻转/明暗/表情/排序）
func _render_state(state: StageState, speakers: Array, duration: float = 0.0) -> void:
	var pos_dur := duration if duration > 0.0 else POS_TWEEN_DEFAULT
	for name_key in state.actors:
		var actor: ActorState = state.actor(name_key)
		var info: Dictionary = _portrait_map.get(name_key, {})
		if info.is_empty():
			info = _add_portrait(actor)
			_portrait_map[name_key] = info
		_apply_actor(info, actor, speakers, pos_dur)


func _apply_actor(info: Dictionary, actor: ActorState, speakers: Array, pos_dur: float) -> void:
	var node: Control = info.node
	if actor.visible != info.get("last_visible", true):
		node.visible = actor.visible
		info["last_visible"] = actor.visible
	if not actor.visible:
		return
	info.profile = actor.profile

	# 位置渐变：仅在目标位置变化时重建（去无操作 Tween）
	if info.get("last_pos", node.position) != actor.position:
		var tw_pos := create_tween().set_parallel(true)
		tw_pos.tween_property(node, "position", actor.position, pos_dur)\
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
		info["last_pos"] = actor.position

	# 翻转（立绘贴图）
	var tex := node.get_child(0) as TextureRect
	if tex:
		tex.flip_h = actor.flip_h

	# 明暗：line 时刻按 speakers 判定；演出时刻按 actor.light（apply_line 已编码说话/沉默）
	var target_mod: Color
	if speakers.size() > 0:
		target_mod = Color.WHITE if speakers.has(actor.char_name) else Color(0.35, 0.35, 0.35)
	else:
		target_mod = Color(actor.light, actor.light, actor.light)
	if target_mod != info.get("last_mod", node.modulate):
		var tw_mod := create_tween()
		tw_mod.tween_property(node, "modulate", target_mod, MOD_TWEEN_DEFAULT)
		info["last_mod"] = target_mod

	# UI 内相对排序（讲话者立绘置顶）
	var is_speaker: bool = speakers.has(actor.char_name)
	node.z_index = 10 if is_speaker else 0

	# 表情
	_apply_emotion(info, actor.emotion)

# ═══ 表情切换 ═══

func _apply_emotion(info: Dictionary, emotion: String) -> void:
	if info.get("last_emotion", "通常") == emotion:
		return  # 表情未变，不重复设贴图
	var profile: CharacterProfile = info.get("profile")
	if not profile:
		return
	var ctrl: Control = info.node
	if ctrl.get_child_count() > 0 and ctrl.get_child(0) is TextureRect:
		var tex: TextureRect = ctrl.get_child(0)
		var key := emotion if not emotion.is_empty() else "通常"
		if profile.portraits.has(key):
			tex.texture = profile.portraits[key]
	info["last_emotion"] = emotion

# ═══ 立绘节点 ═══

func _add_portrait(actor: ActorState) -> Dictionary:
	var ctrl := Control.new()
	ctrl.position = actor.position

	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.flip_h = actor.flip_h
	ctrl.add_child(tex)

	var profile: CharacterProfile = actor.profile
	if profile and profile.portraits.has("通常"):
		tex.texture = profile.portraits["通常"]
		tex.custom_minimum_size = tex.texture.get_size()
		ctrl.custom_minimum_size = tex.texture.get_size()
		ctrl.size = tex.texture.get_size()

	# 新角色淡入
	ctrl.modulate.a = 0.0
	_root.add_child(ctrl)
	return {node = ctrl, profile = profile, last_pos = ctrl.position, last_mod = ctrl.modulate, last_visible = true, last_emotion = "通常"}


# ═══ 清理 ═══

func _clear_child_bubbles(parent: Control) -> void:
	if parent.has_meta("_bubble_panel"):
		var p: BubblePanel = parent.get_meta("_bubble_panel")
		if is_instance_valid(p):
			p.queue_free()
		parent.remove_meta("_bubble_panel")

func _clear_bubbles() -> void:
	for info in _portrait_map.values():
		_clear_child_bubbles(info.node)

func _close() -> void:
	_is_closing = true
	_input_ready = false
	_cancel_held = 0.0
	process_mode = PROCESS_MODE_INHERIT  # 恢复默认

	if GameManager.game_state_changed.is_connected(_on_game_state):
		GameManager.game_state_changed.disconnect(_on_game_state)

	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		finished.emit()
		queue_free()
	)

func _on_game_state(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, 0.15)
	elif new == GameManager.AppState.PLAYING:
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 1.0, 0.15)

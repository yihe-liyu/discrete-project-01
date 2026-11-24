# PauseMenu.gd — 暂停菜单覆盖层
@tool
extends NavPage

## true 表示 GameOver 模式（禁用「继续」）
var is_game_over_mode: bool = false
## 退场动画时长：动画播完前 tree 保持 paused，播完才真正 resume。
const EXIT_DURATION := 0.5
var _resuming: bool = false
var _exit_done: bool = false
## 危险操作的二级确认（结束 / 保存后结束 / 重开）。
const CONFIRM_TITLE := 0
const CONFIRM_SAVE := 1
const CONFIRM_RESTART := 2
var _confirm_root: Control
var _confirm_options: VBoxContainer
var _confirm_action: int = -1
var _confirm_index: int = 1
var _confirm_open: bool = false
var _confirm_tween: Tween


func on_enter() -> void:
	_confirm_root = get_node_or_null("ConfirmRoot")
	_confirm_options = get_node_or_null("ConfirmRoot/Options")
	if _confirm_root:
		_confirm_root.visible = false
	# 先落锁再让 NavPage 收集/播入场；入场后再 refresh_colors 会把淡入直接覆盖掉。
	_apply_locks()
	super.on_enter()  # NavPage 入场动画

	# 暗色遮罩淡入（Overlay 只占游戏框，右侧状态栏不被压暗）
	_fade_overlay_in(0.45)
	AudioManager.play_sfx(AssetRegistry.sounds["pause"])


func _apply_locks() -> void:
	var list: Node = _container
	if list == null:
		list = get_node_or_null(container_path)
	if list == null:
		return
	var resume := list.get_node_or_null("Resume")
	if resume and is_game_over_mode:
		resume.set_meta("is_locked", true)
	var save := list.get_node_or_null("SaveReplay")
	if save:
		save.set_meta("is_locked", Callable(self, "_is_save_locked"))


func _is_save_locked() -> bool:
	return not ReplaySession.is_recording()


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	if _exit_done:
		queue_free()
		return
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			if not is_game_over_mode:
				_begin_resume()
		1:
			_open_confirm(CONFIRM_TITLE)
		2:
			_open_confirm(CONFIRM_SAVE)
		3:
			var manual: BasePage = load("res://scenes/ui/pause_manual_menu.tscn").instantiate()
			# 说明页放到 GameUI(32) 下面：Front 灰框线自然盖在上面，不需要再画假边框。
			visible = false
			_is_nav_enabled = false
			manual.back.connect(_on_manual_closed, CONNECT_ONE_SHOT)
			GameManager.push_overlay_menu(manual, 30)
		4:
			_open_confirm(CONFIRM_RESTART)


## 恢复：先播完退场动画（tree 仍 paused），再让 GameManager 真正恢复。
func _begin_resume() -> void:
	if _resuming or is_game_over_mode:
		return
	_resuming = true
	_is_nav_enabled = false
	_stop_pulse()
	GameEvents.pause_exit_started.emit()
	var tw := create_tween().set_parallel(true)
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, EXIT_DURATION)
	if _container:
		tw.tween_property(_container, "scale", Vector2(0.96, 0.96), EXIT_DURATION)
	await tw.finished
	_exit_done = true
	GameManager.resume_game()


func _open_confirm(action: int) -> void:
	if _confirm_open or _confirm_root == null:
		return
	_confirm_action = action
	_confirm_open = true
	_confirm_index = 1
	_is_nav_enabled = false
	_stop_pulse()
	# 暂停菜单退到后面，确认面板浮在上面。
	for path in ["Panel", "Title", "Subtitle"]:
		var n := get_node_or_null(path)
		if n:
			n.modulate.a = 0.25
	_confirm_root.visible = true
	_confirm_root.modulate.a = 0.0
	_refresh_confirm()
	if _confirm_tween and _confirm_tween.is_valid():
		_confirm_tween.kill()
	_confirm_tween = create_tween()
	_confirm_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_confirm_tween.tween_property(_confirm_root, "modulate:a", 1.0, 0.2)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _close_confirm() -> void:
	if not _confirm_open:
		return
	_confirm_open = false
	_confirm_action = -1
	if _confirm_root:
		_confirm_root.visible = false
	for path in ["Panel", "Title", "Subtitle"]:
		var n := get_node_or_null(path)
		if n:
			n.modulate.a = 1.0
	_is_nav_enabled = true
	refresh_colors()
	if _nav_index >= 0 and _nav_index < _nav_items.size():
		_start_pulse(_nav_items[_nav_index])


func _refresh_confirm() -> void:
	if _confirm_options == null:
		return
	for i in _confirm_options.get_child_count():
		var item := _confirm_options.get_child(i) as Control
		item.modulate = Color.WHITE if i == _confirm_index else Color(0.5, 0.5, 0.5)


func _confirm_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		sfx_nav()
		_confirm_index = wrapi(_confirm_index - 1, 0, 2)
		_refresh_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		sfx_nav()
		_confirm_index = wrapi(_confirm_index + 1, 0, 2)
		_refresh_confirm()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _confirm_index == 0:
			sfx_confirm()
			_confirm_yes()
		else:
			sfx_back()
			_close_confirm()
	elif event.is_action_pressed("ui_cancel"):
		sfx_back()
		get_viewport().set_input_as_handled()
		_close_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if _confirm_open:
		_confirm_input(event)
		return
	super._unhandled_input(event)


func _confirm_yes() -> void:
	var action := _confirm_action
	_confirm_open = false
	if _confirm_root:
		_confirm_root.visible = false
	match action:
		CONFIRM_TITLE:
			GameManager.change_scene.call_deferred(
				"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		CONFIRM_SAVE:
			_save_replay_and_quit()
		CONFIRM_RESTART:
			# 重开是硬切：淡出会让旧曲继续响 0.6s，新场景再起同一首时听感就是"先放一会再重播"。
			AudioManager.stop_bgm(0.0)
			SaveData.is_restarting = true
			GameManager.reload_current_scene()


func _on_manual_closed() -> void:
	visible = true
	_is_nav_enabled = true
	refresh_colors()


func _save_replay_and_quit() -> void:
	if ReplaySession.is_recording():
		ReplaySession.finish_recording({"result": "quit"})
	GameManager.change_scene.call_deferred(
		"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	if not is_game_over_mode:
		_begin_resume()

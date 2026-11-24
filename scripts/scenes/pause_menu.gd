# PauseMenu.gd — 暂停菜单覆盖层
@tool
extends NavPage

## true 表示 GameOver 模式（禁用「继续」）
var is_game_over_mode: bool = false
## 退场动画时长：动画播完前 tree 保持 paused，播完才真正 resume。
const EXIT_DURATION := 0.5
var _resuming: bool = false
var _exit_done: bool = false


func on_enter() -> void:
	super.on_enter()  # NavPage 入场动画

	# 暗色遮罩淡入（Overlay 只占游戏框，右侧状态栏不被压暗）
	_fade_overlay_in(0.45)

	_apply_locks()
	refresh_colors()
	AudioManager.play_sfx(AssetRegistry.sounds["pause"])


func _apply_locks() -> void:
	var resume := _container.get_node_or_null("Resume") if _container else null
	if resume and is_game_over_mode:
		resume.set_meta("is_locked", true)
	var save := _container.get_node_or_null("SaveReplay") if _container else null
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
			GameManager.change_scene.call_deferred(
				"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			_save_replay_and_quit()
		3:
			var manual: BasePage = load("res://scenes/ui/pause_manual_menu.tscn").instantiate()
			# 说明页放到 GameUI(32) 下面：Front 灰框线自然盖在上面，不需要再画假边框。
			visible = false
			_is_nav_enabled = false
			manual.back.connect(_on_manual_closed, CONNECT_ONE_SHOT)
			GameManager.push_overlay_menu(manual, 30)
		4:
			# 重开是硬切：淡出会让旧曲继续响 0.6s，新场景再起同一首时听感就是"先放一会再重播"。
			AudioManager.stop_bgm(0.0)
			SaveData.is_restarting = true
			GameManager.reload_current_scene()


## 恢复：先播完退场动画（tree 仍 paused），再让 GameManager 真正恢复。
func _begin_resume() -> void:
	if _resuming or is_game_over_mode:
		return
	_resuming = true
	_is_nav_enabled = false
	_stop_pulse()
	GameEvents.pause_exit_started.emit()
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, EXIT_DURATION)
	if _container:
		tw.tween_property(_container, "scale", Vector2(0.96, 0.96), EXIT_DURATION)
	await tw.finished
	_exit_done = true
	GameManager.resume_game()


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

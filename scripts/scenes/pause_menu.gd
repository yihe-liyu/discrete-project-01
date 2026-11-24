# PauseMenu.gd — 暂停菜单覆盖层
@tool
extends NavPage

## true 表示 GameOver 模式（禁用「继续」）
var is_game_over_mode: bool = false


func on_enter() -> void:
	super.on_enter()  # NavPage 入场动画

	# 暗色遮罩淡入（Overlay 只占游戏框，右侧状态栏不被压暗）
	_fade_overlay_in(0.3)

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
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			if not is_game_over_mode:
				GameManager.resume_game()
		1:
			GameManager.change_scene.call_deferred(
				"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
		2:
			_save_replay_and_quit()
		3:
			var manual: BasePage = load("res://scenes/ui/pause_manual_menu.tscn").instantiate()
			GameManager.push_overlay_menu(manual)
		4:
			# 重开是硬切：淡出会让旧曲继续响 0.6s，新场景再起同一首时听感就是"先放一会再重播"。
			AudioManager.stop_bgm(0.0)
			SaveData.is_restarting = true
			GameManager.reload_current_scene()


func _save_replay_and_quit() -> void:
	if ReplaySession.is_recording():
		ReplaySession.finish_recording({"result": "quit"})
	GameManager.change_scene.call_deferred(
		"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	if not is_game_over_mode:
		GameManager.resume_game()

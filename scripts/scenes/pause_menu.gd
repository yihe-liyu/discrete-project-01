# PauseMenu.gd — 暂停菜单覆盖层
@tool
extends NavPage

## true 表示 GameOver 模式（禁用「继续」）
var is_game_over_mode: bool = false


func on_enter() -> void:
	super.on_enter()  # NavPage 入场动画

	# 暗色遮罩淡入
	_fade_overlay_in(0.3)

	if is_game_over_mode:
		var resume := _container.get_node_or_null("ResumeLabel")
		if resume:
			resume.set_meta("is_locked", true)
	# 没有进行中的录制（练习 / 已结算）时不允许“保存并结束”。
	var save := _container.get_node_or_null("SaveReplayLabel")
	if save and not ReplaySession.is_recording():
		save.set_meta("is_locked", true)
	refresh_colors()

	AudioManager.play_sfx(AssetRegistry.sounds["pause"])


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
			# 重开是硬切：淡出会让旧曲继续响 0.6s，新场景再起同一首时听感就是"先放一会再重播"。
			AudioManager.stop_bgm(0.0)
			SaveData.is_restarting = true
			GameManager.reload_current_scene()
		2:
			_save_replay_and_end()
		3:
			# 符卡练习里"返回"→ 回**符卡练习菜单**（并还原到离开时那一级），而不是主菜单根
			# （逐面练习 is_practice_mode 为 false，仍走主菜单 ✓）
			if PracticeSession.is_practice_mode:
				PracticeSession.restore_menu_on_enter = true
				GameManager.pending_page_path = "res://scenes/ui/spell_practice_menu.tscn"
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _save_replay_and_end() -> void:
	if not ReplaySession.is_recording():
		return
	var res: PlayerResources = GameManager.entity_registry.get_player_resources() \
		if GameManager.entity_registry != null else null
	var meta := {
		"result": "pause_save",
		"difficulty": SaveData.selected_difficulty,
		"character": SaveData.selected_character,
		"route_id": String(SaveData.current_route_id),
		"stage_id": SaveData.current_stage_id,
		"stage_no": SaveData.current_route_index + 1,
		"score": res.current_score if res != null else 0,
		"recorded_at": Time.get_datetime_string_from_system(),
	}
	var path := ReplaySession.finish_run(meta)
	if path == "":
		push_warning("PauseMenu: 保存 Replay 失败，结束取消")
		return
	SaveData.reset_session()
	AudioManager.stop_bgm(0.0)
	GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	if not is_game_over_mode:
		GameManager.resume_game()

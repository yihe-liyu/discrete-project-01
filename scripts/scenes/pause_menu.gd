# PauseMenu.gd — 暂停菜单覆盖层
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
			AudioManager.stop_bgm()
			SaveData.is_restarting = true
			GameManager.reload_current_scene()
		2:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	if not is_game_over_mode:
		GameManager.resume_game()

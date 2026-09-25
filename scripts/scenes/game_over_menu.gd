# GameOverMenu.gd — Game Over 覆盖层
@tool
extends NavPage

@export var title_label: Label
@export var title_text: String = "Game Over"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := super()
	if title_label == null:
		warnings.append("GameOverMenu：title_label 未设置（Game Over 标题不会更新）。")
	return warnings


func on_enter() -> void:
	super.on_enter()
	_fade_overlay_in(0.3)
	if title_label:
		title_label.text = title_text


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			AudioManager.stop_bgm()
			SaveData.is_restarting = true
			GameManager.reload_current_scene()
		1:
			# 符卡练习里 Game Over → 回**练习菜单**（并还原到第三级），而不是主菜单根
			if PracticeSession.is_practice_mode:
				PracticeSession.restore_menu_on_enter = true
				GameManager.pending_page_path = "res://scenes/ui/spell_practice_menu.tscn"
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	_on_item_selected(1)

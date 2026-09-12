# GameOverMenu.gd — Game Over 覆盖层
extends NavPage

@export var title_label: Label
@export var title_text: String = "Game Over"


func on_enter() -> void:
	super.on_enter()
	_fade_overlay_in(0.3)
	if title_label:
		title_label.text = title_text


func on_leave() -> void:
	_nav_enabled = false
	_stop_pulse()
	_overlay_leave(_container)


func _on_item_selected(index: int) -> void:
	match index:
		0:
			AudioManager.stop_bgm()
			SaveData.restarting = true
			GameManager.reload_current_scene()
		1:
			GameManager.change_scene.call_deferred("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_cancel() -> void:
	_on_item_selected(1)

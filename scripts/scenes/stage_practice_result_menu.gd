## 单关练习通关结束页：保存录像 / 再来一次 / 返回标题菜单。
@tool
class_name StagePracticeResultMenu
extends NavPage

var _can_save: bool = true


func configure(data: Dictionary) -> void:
	_can_save = bool(data.get("can_save", true))
	if not _can_save:
		var save := get_node_or_null("Options/Save")
		if save:
			save.set_meta("is_locked", true)


func on_enter() -> void:
	super.on_enter()
	_fade_overlay_in(0.3)


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	if _container == null:
		queue_free()
		return
	_overlay_leave(_container)


## X / Esc 等同“返回标题”，不能走默认 go_back 直接恢复游戏。
func _on_cancel() -> void:
	finished.emit({"action": "return"})


func _on_item_selected(index: int) -> void:
	match index:
		0:
			if _can_save:
				finished.emit({"action": "save"})
		1:
			finished.emit({"action": "retry"})
		2:
			finished.emit({"action": "return"})

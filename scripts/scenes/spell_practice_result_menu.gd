## 符卡练习完成后的结果页：保存录像 / 重试 / 返回练习菜单。
@tool
class_name SpellPracticeResultMenu
extends NavPage

var _can_save: bool = true


## 在 push 之前调用：填标题 / 卡名 / 统计；没有录像时锁定保存项。
func configure(data: Dictionary) -> void:
	_can_save = bool(data.get("can_save", true))
	var title := get_node_or_null("Title") as Label
	if title:
		title.text = "符卡练习完成"
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


func _on_item_selected(index: int) -> void:
	match index:
		0:
			if _can_save:
				finished.emit({"action": "save"})
		1:
			finished.emit({"action": "retry"})
		2:
			finished.emit({"action": "return"})

## 回放播放完毕页：返回标题菜单 / 再次播放录像。
@tool
class_name ReplayEndMenu
extends NavPage


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


## X / Esc 不是关闭 overlay，而是走“返回”选项，避免恢复游戏。
func _on_cancel() -> void:
	finished.emit({"action": "return"})


func _on_item_selected(index: int) -> void:
	match index:
		0:
			finished.emit({"action": "return"})
		1:
			finished.emit({"action": "again"})

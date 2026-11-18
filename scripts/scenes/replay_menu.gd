# ReplayMenu.gd — 回放列表 / 选择播放
extends BasePage

var _entries: Array[Dictionary] = []
var _rows: Array[Label] = []
var _selected: int = 0
var _delete_armed: bool = false
var _box: VBoxContainer
var _hint: Label


func on_enter() -> void:
	# 黑底渐显 + 标题渐显
	var ov: ColorRect = $"Overlay"
	ov.modulate.a = 0.0
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ov, "modulate:a", 1.0, 0.5)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	_show_replays()


## 列表：一条回放一行；空列表时给明确提示。
func _show_replays() -> void:
	_entries = ReplaySession.list_replays()
	_selected = 0
	_delete_armed = false
	_rows.clear()
	_clear_box()
	_clear_hint()
	var box := VBoxContainer.new()
	box.name = "ReplayBox"
	box.position = Vector2(240, 220)
	box.size = Vector2(800, 560)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	_box = box
	if _entries.is_empty():
		var empty := Label.new()
		empty.text = "暂无回放。\n完整打完一局（通关或 Game Over）后会自动生成。"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 20)
		box.add_child(empty)
		_add_hint()
		return
	for i in _entries.size():
		var e := _entries[i]
		var meta: Dictionary = e.get("metadata", {})
		var diff := int(meta.get("difficulty", 1))
		var diff_name := Difficulty.display_name(diff) if Difficulty.is_valid(diff) else "?"
		var char_name := "灵梦" if int(meta.get("character", 0)) == 0 else "魔理沙"
		var row := Label.new()
		row.text = "Stage %s · %s · %s · %d 分 · %d 帧" % [
			str(meta.get("stage_no", "?")), diff_name, char_name,
			int(meta.get("score", 0)), int(e.get("duration", 0)),
		]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 20)
		box.add_child(row)
		_rows.append(row)
	_refresh_selection()
	_add_hint()


func _clear_box() -> void:
	if is_instance_valid(_box):
		_box.get_parent().remove_child(_box)
		_box.free()
	_box = null


func _clear_hint() -> void:
	if is_instance_valid(_hint):
		_hint.get_parent().remove_child(_hint)
		_hint.free()
	_hint = null


func _add_hint() -> void:
	_clear_hint()
	var hint := Label.new()
	hint.name = "HintLabel"
	hint.position = Vector2(240, 800)
	hint.size = Vector2(800, 80)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	if _delete_armed:
		hint.text = "再按一次 Delete 确认删除"
		hint.modulate = Color(1, 0.4, 0.4)
	else:
		hint.text = "↑↓ 选择 · Z/Enter 播放 · Delete 删除 · Esc 返回"
	add_child(hint)
	_hint = hint


func _refresh_selection() -> void:
	for i in _rows.size():
		if i == _selected:
			_rows[i].modulate = Color(1, 0.4, 0.4) if _delete_armed else Color.WHITE
		else:
			_rows[i].modulate = Color(0.5, 0.5, 0.5)
	if _delete_armed and is_instance_valid(_hint):
		_hint.text = "再按一次 Delete 确认删除"
		_hint.modulate = Color(1, 0.4, 0.4)


func _delete_selected() -> void:
	if _selected < 0 or _selected >= _entries.size():
		return
	if not _delete_armed:
		_delete_armed = true
		_refresh_selection()
		return
	var path := str(_entries[_selected].get("path", ""))
	_delete_armed = false
	if not ReplaySession.delete_replay(path):
		push_warning("ReplayMenu: 删除回放失败 " + path)
		_refresh_selection()
		return
	var keep := _selected
	_show_replays()
	if not _entries.is_empty():
		_selected = mini(keep, _entries.size() - 1)
		_refresh_selection()


func _play_selected() -> void:
	if _selected < 0 or _selected >= _entries.size():
		return
	var path := str(_entries[_selected].get("path", ""))
	if path == "":
		return
	if not ReplaySession.start_playback(path):
		push_warning("ReplayMenu: 无法开始回放 " + path)
		return
	GameManager.change_scene("res://scenes/game_scene.tscn")


func on_leave() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($"Overlay", "modulate:a", 0.0, 0.5)
	tw.tween_property($"TitleTexture", "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()
		return
	if _entries.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE):
		get_viewport().set_input_as_handled()
		_delete_selected()
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_selected = wrapi(_selected - 1, 0, _rows.size())
		_refresh_selection()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_selected = wrapi(_selected + 1, 0, _rows.size())
		_refresh_selection()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_play_selected()

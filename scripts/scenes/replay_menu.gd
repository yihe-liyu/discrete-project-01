# ReplayMenu.gd — 回放列表 / 选择播放 / 单条改名（Replay）
extends BasePage

const PAGE_SIZE: int = 10
const TOTAL_SLOTS: int = 25
const FONT_SIZE: int = 19
const COL_NO := 115
const COL_NAME := 180
const COL_DATE := 340
const COL_CHAR := 150
const COL_DIFF := 160
const COL_STAGE := 160
const COL_RATE := 110

var _entries: Array[Dictionary] = []
## 当前页里“真实回放”的行；空槽位不进这里，避免被当作可播放项。
var _rows: Array[HBoxContainer] = []
var _grid_rows: Array[HBoxContainer] = []
var _selected_slot: int = 0
var _page_offset: int = 0
var _delete_armed: bool = false
var _box: VBoxContainer
var _hint: Label
var _page_hint: Label
var _rename_edit: LineEdit
var _rename_index: int = -1


func on_enter() -> void:
	var ov: ColorRect = $"Overlay"
	ov.modulate.a = 0.0
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ov, "modulate:a", 1.0, 0.5)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	_show_replays()


func _show_replays() -> void:
	_entries = ReplaySession.list_replays()
	_selected_slot = clampi(_selected_slot, 0, TOTAL_SLOTS - 1)
	_page_offset = clampi(_page_offset, 0, _last_page_offset())
	if not _slot_on_page(_selected_slot):
		_page_offset = floori(float(_selected_slot) / PAGE_SIZE) * PAGE_SIZE
	_delete_armed = false
	_rows.clear()
	_grid_rows.clear()
	_clear_box()
	_clear_hint()
	_cancel_rename()

	var box := VBoxContainer.new()
	box.name = "ReplayBox"
	box.position = Vector2(25, 210)
	box.size = Vector2(1230, 350)
	box.add_theme_constant_override("separation", 3)
	add_child(box)
	_box = box

	for i in PAGE_SIZE:
		var slot := _page_offset + i
		if slot >= TOTAL_SLOTS:
			break
		var row := _make_row()
		box.add_child(row)
		_grid_rows.append(row)
		row.set_meta("slot", slot)
		if slot < _entries.size():
			_fill_row(row, _entries[slot], slot)
			_rows.append(row)
		else:
			_fill_empty_row(row, slot)
	_add_hint()
	_refresh_selection()


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 30)
	for width in [COL_NO, COL_NAME, COL_DATE, COL_CHAR, COL_DIFF, COL_STAGE, COL_RATE]:
		var cell := Label.new()
		cell.custom_minimum_size = Vector2(width, 30)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_font_size_override("font_size", FONT_SIZE)
		cell.add_theme_color_override("font_outline_color", Color.BLACK)
		cell.add_theme_constant_override("outline_size", 4)
		cell.clip_text = true
		cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(cell)
	return row


func _fill_row(row: HBoxContainer, entry: Dictionary, slot: int) -> void:
	var meta: Dictionary = entry.get("metadata", {})
	var display_name := str(meta.get("name", "")).strip_edges()
	if display_name == "":
		display_name = "--------"
	var char_name := "Reimu" if int(meta.get("character", 0)) == 0 else "Marisa"
	var diff := int(meta.get("difficulty", 1))
	var diff_name := Difficulty.display_name(diff) if Difficulty.is_valid(diff) else "?"
	var stage := int(meta.get("stage_no", meta.get("start_stage_no", 1)))
	_set_row_text(row, [
		_fw("No. %02d" % (slot + 1)),
		_fw(display_name),
		_fw(_format_date(str(meta.get("recorded_at", "")))),
		_fw(char_name),
		_fw(diff_name),
		_fw("Stage %d" % stage),
		_fw(_format_rate(meta)),
	])


func _fill_empty_row(row: HBoxContainer, slot: int) -> void:
	_set_row_text(row, [
		_fw("No. %02d" % (slot + 1)),
		_fw("--------"),
		_fw("--/--/-- --:--"),
		_fw("------"),
		_fw("-----"),
		_fw("--"),
		_fw("--.-%"),
	])


func _set_row_text(row: HBoxContainer, values: Array) -> void:
	for i in mini(row.get_child_count(), values.size()):
		(row.get_child(i) as Label).text = str(values[i])


## ASCII → 全角；保留中文 / 假名 / 已有全角字符。
func _fw(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 32:
			out += "　"
		elif c >= 33 and c <= 126:
			out += String.chr(c + 0xFEE0)
		else:
			out += text[i]
	return out


func _slot_on_page(slot: int) -> bool:
	return slot >= _page_offset and slot < _page_offset + PAGE_SIZE


func _refresh_selection() -> void:
	for row in _grid_rows:
		var slot := int(row.get_meta("slot", -1))
		var filled := slot >= 0 and slot < _entries.size()
		var selected := filled and slot == _selected_slot
		var color := Color(1.0, 0.86, 0.35) if selected else (
			Color(0.78, 0.78, 0.78) if filled else Color(0.36, 0.36, 0.36))
		for child in row.get_children():
			(child as Label).add_theme_color_override("font_color", color)
	if is_instance_valid(_hint):
		_hint.text = "再按一次 Delete 确认删除" if _delete_armed \
			else "↑↓ 选择 · PageUp/PageDown 翻页 · Z/Enter 播放 · F2 改名 · Delete 删除 · Esc 返回"
		_hint.modulate = Color(1, 0.4, 0.4) if _delete_armed else Color.WHITE
	if is_instance_valid(_page_hint):
		_page_hint.text = _fw("▲ %d–%d / %d ▼" % [
			_page_offset + 1, mini(_page_offset + PAGE_SIZE, TOTAL_SLOTS), TOTAL_SLOTS])


func _format_date(iso: String) -> String:
	# 2026-11-23T18:45:21 -> 26/11/23 18:45
	if iso.length() >= 16 and iso[4] == "-" and iso[7] == "-":
		return "%s/%s/%s %s" % [iso.substr(2, 2), iso.substr(5, 2), iso.substr(8, 2), iso.substr(11, 5)]
	return "--/--/-- --:--"


## 处理落率；旧录像没有该字段时显示 0.0%，不猜完成度。
func _format_rate(meta: Dictionary) -> String:
	return "%.1f%%" % float(meta.get("drop_rate", 0.0))


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
	if is_instance_valid(_page_hint):
		_page_hint.get_parent().remove_child(_page_hint)
		_page_hint.free()
	_page_hint = null


func _add_hint() -> void:
	_clear_hint()
	_page_hint = Label.new()
	_page_hint.name = "PageHint"
	_page_hint.position = Vector2(25, 610)
	_page_hint.size = Vector2(1230, 34)
	_page_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_hint.add_theme_font_size_override("font_size", 20)
	_page_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_page_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_page_hint.add_theme_constant_override("outline_size", 3)
	add_child(_page_hint)

	_hint = Label.new()
	_hint.name = "HintLabel"
	_hint.position = Vector2(25, 900)
	_hint.size = Vector2(1230, 34)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 3)
	if _entries.is_empty():
		_hint.text = "暂无回放。完整打完一局（通关或 Game Over）后会自动生成。"
	else:
		_hint.text = "↑↓ 选择 · PageUp/PageDown 翻页 · Z/Enter 播放 · F2 改名 · Delete 删除 · Esc 返回"
	add_child(_hint)


func _play_selected() -> void:
	if _selected_slot < 0 or _selected_slot >= _entries.size():
		return
	var path := str(_entries[_selected_slot].get("path", ""))
	if path == "":
		return
	if not ReplaySession.start_playback(path):
		push_warning("ReplayMenu: 无法开始回放 " + path)
		return
	GameManager.change_scene("res://scenes/game_scene.tscn")


func _delete_selected() -> void:
	if _selected_slot < 0 or _selected_slot >= _entries.size():
		return
	if not _delete_armed:
		_delete_armed = true
		_refresh_selection()
		return
	var path := str(_entries[_selected_slot].get("path", ""))
	_delete_armed = false
	if not ReplaySession.delete_replay(path):
		push_warning("ReplayMenu: 删除回放失败 " + path)
		_refresh_selection()
		return
	var keep := _selected_slot
	_show_replays()
	_selected_slot = mini(keep, maxi(0, _entries.size() - 1))
	_show_replays()


func _begin_rename() -> void:
	if _selected_slot < 0 or _selected_slot >= _entries.size():
		return
	_cancel_rename()
	_rename_index = _selected_slot
	var meta: Dictionary = _entries[_selected_slot].get("metadata", {})
	_rename_edit = LineEdit.new()
	_rename_edit.name = "RenameEdit"
	_rename_edit.position = Vector2(390, 410)
	_rename_edit.size = Vector2(500, 44)
	_rename_edit.max_length = 12
	_rename_edit.placeholder_text = "输入回放名字"
	_rename_edit.text = str(meta.get("name", ""))
	_rename_edit.add_theme_font_size_override("font_size", 20)
	add_child(_rename_edit)
	_rename_edit.grab_focus()
	_rename_edit.select_all()
	_rename_edit.text_submitted.connect(_commit_rename)
	_rename_edit.gui_input.connect(_on_rename_gui)
	if is_instance_valid(_hint):
		_hint.text = "输入名字 · Enter 保存 · Esc 取消"


func _on_rename_gui(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel_rename()


func _commit_rename(text: String) -> void:
	if _rename_index < 0 or _rename_index >= _entries.size():
		_cancel_rename()
		return
	var path := str(_entries[_rename_index].get("path", ""))
	if not ReplaySession.rename_replay(path, text):
		push_warning("ReplayMenu: 回放改名失败 " + path)
	var keep := _rename_index
	_cancel_rename()
	_selected_slot = keep
	_show_replays()


func _cancel_rename() -> void:
	if is_instance_valid(_rename_edit):
		_rename_edit.queue_free()
	_rename_edit = null
	_rename_index = -1


func on_leave() -> void:
	_cancel_rename()
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($"Overlay", "modulate:a", 0.0, 0.5)
	tw.tween_property($"TitleTexture", "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _last_page_offset() -> int:
	return floori(float(TOTAL_SLOTS - 1) / PAGE_SIZE) * PAGE_SIZE


func _turn_page(dir: int) -> void:
	_page_offset = clampi(_page_offset + dir * PAGE_SIZE, 0, _last_page_offset())
	_selected_slot = _page_offset
	_show_replays()


func _move_slot(dir: int) -> void:
	if _entries.is_empty():
		return
	# 空槽位不可选：上下移动只在真实回放之间跳。
	var slot := _selected_slot
	for _i in TOTAL_SLOTS:
		slot = wrapi(slot + dir, 0, TOTAL_SLOTS)
		if slot < _entries.size():
			_selected_slot = slot
			break
	if not _slot_on_page(_selected_slot):
		_page_offset = floori(float(_selected_slot) / PAGE_SIZE) * PAGE_SIZE
	_show_replays()


func _input(event: InputEvent) -> void:
	if is_instance_valid(_rename_edit):
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_cancel_rename()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP:
			get_viewport().set_input_as_handled()
			_turn_page(-1)
			return
		if event.keycode == KEY_PAGEDOWN:
			get_viewport().set_input_as_handled()
			_turn_page(1)
			return
		if event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			_delete_selected()
			return
		if event.keycode == KEY_F2:
			get_viewport().set_input_as_handled()
			_begin_rename()
			return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_move_slot(-1)
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_move_slot(1)
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_delete_armed = false
		_play_selected()


func _row_text(index: int) -> String:
	if index < 0 or index >= _rows.size():
		return ""
	var parts: Array[String] = []
	for child in _rows[index].get_children():
		parts.append((child as Label).text)
	return " ".join(parts)

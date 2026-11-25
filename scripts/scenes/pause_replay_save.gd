# PauseReplaySave.gd — 暂停菜单里的保存录像页：固定 25 槽位 + 命名。
extends BasePage

signal saved(path: String)

const SLOT_COUNT := 25
const SLOT_LIST_PATH := "SlotList"
const NAME_MAX := 8
const COLS := [90, 180, 130, 95, 120, 120]

var _slots: Array[Dictionary] = []
var _rows: Array[HBoxContainer] = []
var _selected: int = 0
var _name_mode: bool = false
var _name_edit: LineEdit
var _hint: Label
var _title: Label


func _ready() -> void:
	super._ready()
	_name_edit = $"NameEdit"
	_hint = $"Hint"
	_title = $"Title"
	_name_edit.text_submitted.connect(_on_name_submitted)
	_name_edit.gui_input.connect(_on_name_gui)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.max_length = NAME_MAX
	_name_edit.editable = false


func on_enter() -> void:
	_slots = ReplaySession.slot_entries()
	_selected = 0
	_build_slots()
	_name_mode = false
	_name_edit.editable = false
	_name_edit.text = "新录像"
	_update_hint()
	_fade_overlay_in(0.2)


func on_leave() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_overlay):
		tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	tw.tween_property(_title, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _build_slots() -> void:
	var list := get_node_or_null(SLOT_LIST_PATH)
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	_rows.clear()
	for i in SLOT_COUNT:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 4)
		row.custom_minimum_size = Vector2(0, 23)
		for width in COLS:
			var cell := Label.new()
			cell.custom_minimum_size = Vector2(width, 23)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.clip_text = true
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			cell.add_theme_font_size_override("font_size", 15)
			cell.add_theme_color_override("font_outline_color", Color.BLACK)
			cell.add_theme_constant_override("outline_size", 3)
			row.add_child(cell)
		list.add_child(row)
		_rows.append(row)
	_refresh_slots()


## ASCII → 全角；中文 / 假名保持原样。
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


func _refresh_slots() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var filled := i < _slots.size() and not _slots[i].is_empty()
		var meta: Dictionary = _slots[i].get("metadata", {}) if filled else {}
		var display_name := str(meta.get("name", "")).strip_edges() if filled else ""
		if display_name == "":
			display_name = "（未命名）" if filled else "--------"
		var date := str(meta.get("recorded_at", "")) if filled else ""
		if date.length() >= 16:
			date = "%s/%s/%s" % [date.substr(2, 2), date.substr(5, 2), date.substr(8, 2)]
		else:
			date = "--/--/--"
		var char_name := "------"
		var diff_name := "-----"
		var stage_name := "St-"
		if filled:
			char_name = "Reimu" if int(meta.get("character", 0)) == 0 else "Marisa"
			var diff := int(meta.get("difficulty", 1))
			diff_name = Difficulty.display_name(diff) if Difficulty.is_valid(diff) else "?"
			var stage_id := int(meta.get("stage_id", 0))
			if stage_id > 0:
				stage_name = StageCatalog.display_name_of(stage_id)
			else:
				stage_name = "Stage %d" % int(meta.get("stage_no", meta.get("start_stage_no", 1)))
		var values := [
			"No. %02d" % (i + 1), display_name, date, char_name, diff_name, stage_name,
		]
		for c in mini(row.get_child_count(), values.size()):
			(row.get_child(c) as Label).text = _fw(str(values[c]))
		var color := Color(1, 1, 1) if i == _selected else (
			Color(0.72, 0.72, 0.72) if filled else Color(0.38, 0.38, 0.38))
		for child in row.get_children():
			(child as Label).add_theme_color_override("font_color", color)


func _begin_name() -> void:
	_name_mode = true
	_name_edit.editable = true
	_name_edit.visible = true
	var meta: Dictionary = _slots[_selected].get("metadata", {}) if _selected < _slots.size() and not _slots[_selected].is_empty() else {}
	var existing := str(meta.get("name", "")).strip_edges()
	_name_edit.text = existing if existing != "" else "新录像"
	_name_edit.grab_focus()
	_name_edit.select_all()
	_update_hint()


func _back_to_slots() -> void:
	sfx_back()
	_name_mode = false
	_name_edit.editable = false
	_name_edit.release_focus()
	_update_hint()


func _update_hint() -> void:
	if _name_mode:
		_hint.text = "已输入 %d 字（最多 %d 字）· Enter 保存 · Esc 返回选槽" % [
			_name_edit.text.length(), NAME_MAX]
	else:
		_hint.text = "↑↓ 选择槽位 · Z/Enter 命名（最多 %d 字）· Esc 返回" % NAME_MAX


func _on_name_changed(_text: String) -> void:
	if _name_mode:
		_update_hint()


func _on_name_gui(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_back_to_slots()


func _on_name_submitted(_text: String) -> void:
	_save_now()


func _save_now() -> void:
	var display_name := _name_edit.text.strip_edges()
	if display_name == "":
		_update_hint()
		return
	var path: String
	if _selected < _slots.size() and not _slots[_selected].is_empty():
		path = str(_slots[_selected].get("path", ""))
	else:
		path = "%s/slot_%02d.json" % [ReplaySession.DIR, _selected + 1]
	var saved_path := ReplaySession.finish_recording(
		{"result": "save", "slot": _selected + 1}, path, display_name)
	if saved_path == "":
		_hint.text = "保存失败"
		return
	sfx_confirm()
	saved.emit(saved_path)


func _unhandled_input(event: InputEvent) -> void:
	if _name_mode:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_back_to_slots()
		return
	if event.is_action_pressed("ui_up"):
		_selected = wrapi(_selected - 1, 0, SLOT_COUNT)
		sfx_nav()
		_refresh_slots()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_selected = wrapi(_selected + 1, 0, SLOT_COUNT)
		sfx_nav()
		_refresh_slots()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		sfx_confirm()
		_begin_name()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()

# PauseReplaySave.gd — 暂停菜单里的保存录像页：在游戏框内选 25 个槽位并命名。
extends BasePage

const SLOT_COUNT := 25
const SLOT_LIST_PATH := "SlotList"

var _entries: Array[Dictionary] = []
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
	_name_edit.editable = false


func on_enter() -> void:
	_entries = ReplaySession.list_replays()
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
		row.add_theme_constant_override("separation", 10)
		var no := Label.new()
		no.custom_minimum_size = Vector2(86, 0)
		no.add_theme_font_size_override("font_size", 17)
		no.add_theme_color_override("font_outline_color", Color.BLACK)
		no.add_theme_constant_override("outline_size", 3)
		no.text = "No. %02d" % (i + 1)
		row.add_child(no)
		var name_label := Label.new()
		name_label.custom_minimum_size = Vector2(360, 0)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 3)
		row.add_child(name_label)
		var date_label := Label.new()
		date_label.custom_minimum_size = Vector2(200, 0)
		date_label.add_theme_font_size_override("font_size", 15)
		date_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		row.add_child(date_label)
		list.add_child(row)
		_rows.append(row)
	_refresh_slots()


func _refresh_slots() -> void:
	for i in _rows.size():
		var row := _rows[i]
		var filled := i < _entries.size()
		var meta: Dictionary = _entries[i].get("metadata", {}) if filled else {}
		var display_name := str(meta.get("name", "")) if filled else ""
		var date := str(meta.get("recorded_at", "")) if filled else ""
		if display_name == "":
			display_name = "--------" if not filled else "（未命名）"
		if date.length() >= 16:
			date = "%s/%s/%s %s" % [date.substr(2, 2), date.substr(5, 2), date.substr(8, 2), date.substr(11, 5)]
		else:
			date = ""
		(row.get_child(1) as Label).text = display_name
		(row.get_child(2) as Label).text = date
		var color := Color(1, 1, 1) if i == _selected else (Color(0.72, 0.72, 0.72) if filled else Color(0.38, 0.38, 0.38))
		for child in row.get_children():
			(child as Label).add_theme_color_override("font_color", color)


func _begin_name() -> void:
	_name_mode = true
	_name_edit.editable = true
	_name_edit.visible = true
	var meta: Dictionary = _entries[_selected].get("metadata", {}) if _selected < _entries.size() else {}
	var existing := str(meta.get("name", "")).strip_edges()
	_name_edit.text = existing if existing != "" else "新录像"
	_name_edit.grab_focus()
	_name_edit.select_all()
	_update_hint()


func _back_to_slots() -> void:
	_name_mode = false
	_name_edit.editable = false
	_name_edit.release_focus()
	_update_hint()


func _update_hint() -> void:
	if _name_mode:
		_hint.text = "输入名字 · Enter 保存 · Esc 返回选槽"
	else:
		_hint.text = "↑↓ 选择槽位 · Z/Enter 命名 · Esc 返回"


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
	if _selected < _entries.size():
		path = str(_entries[_selected].get("path", ""))
	else:
		path = "%s/slot_%02d.json" % [ReplaySession.DIR, _selected + 1]
	var saved := ReplaySession.finish_recording(
		{"result": "save", "slot": _selected + 1}, path, display_name)
	if saved == "":
		_hint.text = "保存失败"
		return
	AudioManager.play_ui_sfx("confirm")
	GameManager.change_scene.call_deferred(
		"res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _unhandled_input(event: InputEvent) -> void:
	if _name_mode:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			_back_to_slots()
		return
	if event.is_action_pressed("ui_up"):
		_selected = wrapi(_selected - 1, 0, SLOT_COUNT)
		_refresh_slots()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_selected = wrapi(_selected + 1, 0, SLOT_COUNT)
		_refresh_slots()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_begin_name()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()

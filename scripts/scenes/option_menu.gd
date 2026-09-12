# OptionMenu.gd — 设置菜单
# ↑↓ 选择设置项（选中白+脉冲，未选中暗）；←→ 调节音量；Z 切换开关；X 返回（变更即存）
extends BasePage

const ITEMS: Array[Dictionary] = [
	{"key": "volume_bgm", "zh": "ＢＧＭ音量", "type": "range", "min": 0.0, "max": 1.0, "step": 0.1, "def": 1.0},
	{"key": "volume_sfx", "zh": "ＳＥ音量",  "type": "range", "min": 0.0, "max": 1.0, "step": 0.1, "def": 0.7},
	{"key": "fullscreen", "zh": "全屏",     "type": "toggle", "def": false},
	{"key": "max_fps", "zh": "渲染帧率", "type": "choice", "choices": [0, 60, 120, 144], "def": 0},
]

const HIGHLIGHT := Color.WHITE
const NORMAL := Color(0.4, 0.4, 0.4)
const VALUE_COLOR := Color(1.0, 0.9, 0.5)

var _items: Array[HBoxContainer] = []
var _values: Array[Label] = []
var _nav_index: int = 0
var _pulse: Tween


func _ready() -> void:
	_build_items()
	_apply_nav()


func _build_items() -> void:
	var box: VBoxContainer = $"LeftPanel/ListContainer"
	box.add_theme_constant_override("separation", 26)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in ITEMS.size():
		# 每项一行：标题（左）+ 数值（右，同字号右对齐）
		var item := HBoxContainer.new()
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_theme_constant_override("separation", 24)
		var zh := Label.new()
		zh.text = ITEMS[i]["zh"]
		zh.add_theme_font_size_override("font_size", 32)
		zh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := Label.new()
		value.add_theme_font_size_override("font_size", 32)
		value.add_theme_color_override("font_color", VALUE_COLOR)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		item.add_child(zh)
		item.add_child(value)
		box.add_child(item)
		_items.append(item)
		_values.append(value)
	_refresh_values()


# ═══ 显示 ═══

func _refresh_values() -> void:
	for i in ITEMS.size():
		var item := ITEMS[i]
		var v: Variant = SaveData.save_mgr.get_setting(item["key"], item["def"])
		if item["type"] == "range":
			_values[i].text = TextAlign.pad_cn(TextAlign.full(str(int(round(v * 100.0)))), 3) + "％"
		elif item["type"] == "choice":
			var txt: String = "自动" if int(v) == 0 else TextAlign.full(str(int(v)))
			_values[i].text = TextAlign.pad_cn(txt, 3)
		else:
			_values[i].text = TextAlign.pad_cn(("开" if v else "关"), 3)


func _apply_nav() -> void:
	for i in _items.size():
		_items[i].modulate = HIGHLIGHT if i == _nav_index else NORMAL
	_start_pulse()


func _start_pulse() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	var item: Control = _items[_nav_index]
	_pulse = create_tween().set_loops()
	_pulse.set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(item, "modulate", HIGHLIGHT, 0.3)
	_pulse.tween_property(item, "modulate", Color(0.6, 0.6, 0.65), 0.3)


# ═══ 交互 ═══

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()
		return
	if event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_nav_index = wrapi(_nav_index - 1, 0, ITEMS.size())
		_apply_nav()
		sfx_nav()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_nav_index = wrapi(_nav_index + 1, 0, ITEMS.size())
		_apply_nav()
		sfx_nav()
	elif event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_adjust(-1)
		sfx_nav()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_adjust(1)
		sfx_nav()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_toggle()


func _adjust(dir: int) -> void:
	var item := ITEMS[_nav_index]
	if item["type"] == "range":
		var cur: float = float(SaveData.save_mgr.get_setting(item["key"], item["def"]))
		var v := clampf(cur + dir * item["step"], item["min"], item["max"])
		SaveData.save_mgr.set_setting(item["key"], v)
		_apply_setting(item["key"], v)
	elif item["type"] == "choice":
		var choices: Array = item["choices"]
		var idx: int = choices.find(SaveData.save_mgr.get_setting(item["key"], item["def"]))
		if idx < 0:
			idx = 0
		var v2: int = choices[wrapi(idx + dir, 0, choices.size())]
		SaveData.save_mgr.set_setting(item["key"], v2)
		_apply_setting(item["key"], v2)
	else:
		return
	_refresh_values()


func _toggle() -> void:
	var item := ITEMS[_nav_index]
	if item["type"] != "toggle":
		return
	var cur: bool = bool(SaveData.save_mgr.get_setting(item["key"], item["def"]))
	var v: bool = not cur
	SaveData.save_mgr.set_setting(item["key"], v)
	_apply_setting(item["key"], v)
	_refresh_values()
	sfx_confirm()


## 应用设置到运行时
func _apply_setting(key: String, v: Variant) -> void:
	match key:
		"volume_bgm":
			AudioManager.bgm_volume = float(v)
		"volume_sfx":
			AudioManager.sfx_volume = float(v)
		"fullscreen":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(v) else DisplayServer.WINDOW_MODE_WINDOWED)
		"max_fps":
			Engine.max_fps = _auto_fps() if int(v) == 0 else int(v)


## 自动帧率：跟显示器刷新率（读系统配置）；读不到则无上限(0)
func _auto_fps() -> int:
	var rate := DisplayServer.screen_get_refresh_rate(0)
	return int(rate) if rate > 0.0 else 0


# ═══ 生命周期 ═══

func on_enter() -> void:
	_fade_overlay_in(0.5)
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)


func on_leave() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_overlay_out(0.5)
	tw.tween_property($"TitleTexture", "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

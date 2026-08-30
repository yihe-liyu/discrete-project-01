extends Control
## 右下角浮动状态条（三台统一）
## 测试/调用方可直接读 .label.text（与旧 _reload_status 兼容）

var label: Label

var _timer := 0.0
const DURATION := 2.6
const SHOW := 1.0  # 不透明持续时长（之后淡出）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -460.0
	offset_top = -34.0
	offset_right = -8.0
	offset_bottom = -6.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 200
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	add_child(label)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_msg(text: String, color: Color) -> void:
	label.text = text
	label.modulate = color
	visible = true
	modulate.a = 1.0
	_timer = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	_timer += delta
	if _timer > SHOW:
		modulate.a = maxf(1.0 - (_timer - SHOW) / (DURATION - SHOW), 0.0)
		if _timer >= DURATION:
			visible = false

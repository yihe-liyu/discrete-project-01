extends Control
## 画面框中央浮动状态条（三台统一）
## 测试/调用方可直接读 .label.text（与旧 _reload_status 兼容）

const RIG_COMMON = preload("res://scripts/workbench/bench_common.gd")  # 字号阶梯单一来源

var label: Label

var _timer := 0.0
const DURATION := 2.6
const SHOW := 1.0  # 不透明持续时长（之后淡出）


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 画面框中央浮层：居中 + 高图层（z=200）；反正有渐隐，短暂显示于内容中央
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -300.0
	offset_top = -22.0
	offset_right = 300.0
	offset_bottom = 22.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = LayerConfig.UI_TOAST

	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", RIG_COMMON.LABEL_SIZE)
	add_child(label)
	# 显式填满容器（set_anchors_and_offsets_preset 会正确设定锚点布局模式）
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

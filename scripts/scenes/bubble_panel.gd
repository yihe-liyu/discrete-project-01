# BubblePanel — 对话气泡面板 + 文字特效
##
## 独立于 DialogueBox，只管「气泡长什么样」和「文字怎么呈现」。
## 未来加逐字打印、尾巴三角形、BBCode 特效等，全放这里。

class_name BubblePanel
extends PanelContainer

# ═══ 布局常量 ═══

const PAD_H := 16.0
const PAD_V := 10.0
const MIN_W := 440.0

# ═══ 状态 ═══

var _label: Label
var _shake_dur: float = 0.0

## 如果加了逐字打印功能，这里就是「是否正在打字中」
var is_typing: bool = false


# ═══ 工厂方法 ═══

static func create(text: String) -> BubblePanel:
	var panel := BubblePanel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ── 白色圆角背景 ──
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(10)
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.5, 0.5, 0.55, 0.7)
	sb.content_margin_left   = int(PAD_H)
	sb.content_margin_right  = int(PAD_H)
	sb.content_margin_top    = int(PAD_V)
	sb.content_margin_bottom = int(PAD_V)
	panel.add_theme_stylebox_override("panel", sb)

	# ── 文字标签 ──
	panel._label = Label.new()
	panel._label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15))
	panel._label.add_theme_font_size_override("font_size", 40)
	panel._label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	panel._label.custom_minimum_size = Vector2(MIN_W, 0)
	panel.add_child(panel._label)
	panel.custom_minimum_size = Vector2(MIN_W, 0)

	# ── 解析 BBCode 标记 ──
	panel._parse_tags(text)

	return panel


# ═══ BBCode 标记解析 ═══
## 所有自定义标记集中在这里处理，方便扩展

func _parse_tags(text: String) -> void:
	var display_text := text

	# [shake=N] 抖动
	var re_shake := RegEx.new()
	re_shake.compile("\\[shake=?(\\d*\\.?\\d*)\\]")
	var m_shake := re_shake.search(display_text)
	if m_shake:
		_shake_dur = float(m_shake.get_string(1)) if m_shake.get_string(1) else 0.3
		display_text = re_shake.sub(display_text, "", true)

	# 未来扩展点：
	# [speed=N]   — 逐字打印速度
	# [pause=N]   — 打字暂停
	# [wave]      — 波浪抖动

	_label.text = display_text


# ═══ 抖动特效 ═══

## 在指定父节点上执行抖动
func shake(parent: Control) -> void:
	if _shake_dur <= 0.0:
		return

	var orig := position
	var tw := parent.create_tween()
	tw.set_loops()
	var shakes := ceili(_shake_dur / 0.05)
	for _i in shakes:
		var off := Vector2(RNG.randf_range(-4, 4), RNG.randf_range(-2, 2))
		tw.tween_property(self, "position", orig + off, 0.025)
		tw.tween_property(self, "position", orig, 0.025)

	await parent.get_tree().create_timer(_shake_dur).timeout
	if is_instance_valid(self):
		tw.kill()
		position = orig


# ═══ 未来扩展 ═══

## 逐字打印效果（留好口子，需要时实现）
## func typewriter(text: String, speed: float = 0.05) -> void:
##     is_typing = true
##     var displayed := ""
##     for ch in text:
##         displayed += ch
##         _label.text = displayed
##         await get_tree().create_timer(speed).timeout
##     is_typing = false

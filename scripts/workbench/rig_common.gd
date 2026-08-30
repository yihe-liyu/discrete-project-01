extends RefCounted
## 组合台共享 UI 基建：标签/面板样式/标题（三台统一样式单一来源）

static func label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 二级标题（魂/壳/参数/操作/开发…）：金色小字，统一层级
static func section_label(text: String) -> Label:
	var l := label(text, 12)
	l.modulate = Color(1.0, 0.83, 0.5, 0.92)
	return l


## 主操作按钮（发射/生成/开演）：金底，与其他按钮区分
static func accent_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.83, 0.68, 0.35)
	normal.set_corner_radius_all(4)
	normal.set_content_margin_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.76, 0.45)
	hover.set_corner_radius_all(4)
	hover.set_content_margin_all(6)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.72, 0.56, 0.26)
	pressed.set_corner_radius_all(4)
	pressed.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	return b


static func panel_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.085, 0.09, 0.115, 1.0)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(10)
	return st


static func make_panel() -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.offset_left = -440.0
	p.offset_top = 8.0
	p.offset_right = -8.0
	p.offset_bottom = 952.0
	p.add_theme_stylebox_override("panel", panel_style())
	return p
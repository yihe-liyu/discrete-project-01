extends RefCounted
## 组合台共享 UI 基建：标签/面板样式/标题（三台统一样式单一来源）

static func label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


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

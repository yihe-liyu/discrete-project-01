extends RefCounted
## 组合台共享 UI 基建：标签/面板样式/标题（三台统一样式单一来源）
## 视觉与游戏页面统一：半透明黑底 + 金边卡片（ui_theme 同款）

## 字号阶梯（全创作台唯一来源）：改字号只动这里 + workbench_theme.default_font_size
const SECTION_SIZE := 16  ## 金色节标题（行为/外形/参数/操作/开发…）+ 各台标题
const LABEL_SIZE := 16    ## 字段标签（贴图/染色/外观/HP/难度…）
const HINT_SIZE := 13     ## 提示行（左键=… · 鼠标=自机）

static func label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 二级标题（行为/外形/参数/操作/开发…）：金色小字，统一层级
static func section_label(text: String) -> Label:
	var l := label(text, SECTION_SIZE)
	l.modulate = Color(1.0, 0.83, 0.5, 0.92)
	return l


## 提示行（左键=… · 鼠标=自机 等弱化说明）
static func hint_label(text: String) -> Label:
	return label(text, HINT_SIZE)


## 主操作按钮（发射/生成/开演）：金底，与其他按钮区分
static func accent_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.83, 0.68, 0.35)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.9, 0.76, 0.45)
	hover.set_corner_radius_all(6)
	hover.set_content_margin_all(6)
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.72, 0.56, 0.26)
	pressed.set_corner_radius_all(6)
	pressed.set_content_margin_all(6)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	return b


static func panel_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	# 游戏菜单同款：半透明黑 + 金边（与 ui_theme StyleBoxPanel 完全一致）
	st.bg_color = Color(0, 0, 0, 0.32)
	st.set_border_width_all(1)
	st.border_color = Color(0.62, 0.52, 0.28, 0.55)
	st.set_corner_radius_all(6)
	st.set_content_margin_all(8)
	return st


## 暗色舞台底（与整关预览一致的深黑底；作为根控件的第一个子节点垫底）
## 备注：组合台页签在创建站页区下，背景原是引擎默认灰——与游戏页面格格不入
static func add_stage_bg(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)


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
class_name WorkbenchTheme
extends RefCounted
## 工作台主题 —— 与游戏页面视觉统一：半透明黑底金边卡片 + 思源宋体描边
##
## 设计（完全对齐 themes/ui_theme.tres 与菜单面板 StyleBox）：
##   · 面板：底 (0,0,0,0.32) + 1px 金边 (0.62,0.52,0.28,0.55) + 圆角 6（主菜单/音乐室/设置同款）
##   · 字体：source_han_serif_cn_medium.otf（项目全局字体）+ 黑描边/投影（ui_theme Label 同款）
##   · 工作台是密集工具：默认字号 14（游戏页面文字 22~36，走大字号覆盖）
##   · 强调一律金色（东方风），弱化文字用中性灰（不再蓝灰）
##
## 用法：workbench 根 Control.theme = WorkbenchTheme.build()

const PANEL_BG := Color(0, 0, 0, 0.32)
const PANEL_BORDER := Color(0.62, 0.52, 0.28, 0.55)
const PANEL_BORDER_HOVER := Color(0.92, 0.73, 0.32, 0.75)
const INPUT_BG := Color(0, 0, 0, 0.35)
const TEXT := Color(0.92, 0.92, 0.92, 1.0)
const TEXT_DIM := Color(0.68, 0.68, 0.68, 1.0)
const ACCENT := Color(0.92, 0.73, 0.32, 1.0)
const SELECT := Color(0.92, 0.73, 0.32, 0.28)


## 构建主题：**单例缓存**——创作台（站根一套 + 每页一套）若各自 build()，
## 会产生多个 FontFile 实例，同文本被绘制两次（双绘重影 bug）；
## 全站共享一个 Theme 实例即单一字体来源
static var _cached: Theme = null

static func build() -> Theme:
	if _cached != null:
		return _cached
	var t := Theme.new()
	# ── 字体：全局思源宋体（逐字复刻游戏页面观感）──
	# 【重要】不配 fallbacks！本引擎会把回退字体里"主字体也有的字形"再画一遍 →
	# 所有文字双绘重影（曾误认成乱码）。UI 符号一律用宋体自带字形
	# （▾▸ 用 ▼▶；emoji 用 ★◆×＊！⚠ 等代替，Scripts 内已统一）
	var font: FontFile = (load("res://assets/fonts/source_han_serif_cn_medium.otf") as FontFile).duplicate() as FontFile
	t.default_font = font
	t.default_font_size = 18  # 控件默认字号；标签阶梯见 rig_common（SECTION/LABEL/HINT_SIZE）
	# 顶部切换按钮用硬编码 16 保持紧凑（creation_station._slot_buttons）
	# Label：描边 1 + 关阴影——工作台字号 12-14，游戏主题的 2px 描边 + 偏移阴影
	# 在小字上会把字形糊成一团（屏幕上看起来像乱码）；大字号页面才用重描边
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 1))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))
	t.set_constant("outline_size", "Label", 1)
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 0)

	# ── 卡片（PanelContainer：区块/弹窗面板）──
	t.set_stylebox("panel", "PanelContainer", _panel())
	t.set_stylebox("panel", "PopupPanel", _panel())

	# ── Button ──
	_style_button(t, "Button")
	_style_button(t, "OptionButton")

	# ── 输入框（LineEdit / SpinBox 共享）──
	var input := StyleBoxFlat.new()
	input.bg_color = INPUT_BG
	input.set_border_width_all(1)
	input.border_color = Color(PANEL_BORDER, 0.5)
	input.set_corner_radius_all(4)
	input.set_content_margin_all(5)
	t.set_stylebox("normal", "LineEdit", input)
	var input_focus := input.duplicate() as StyleBoxFlat
	input_focus.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", input_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)

	# ── CheckButton / CheckBox ──
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", ACCENT)
	t.set_color("font_color", "CheckBox", TEXT)

	# ── Tree（内容目录树）：逐项套卡片族 + 宋体描边 ──
	var tree_font: Font = t.default_font
	t.set_font("font", "Tree", tree_font)
	t.set_stylebox("panel", "Tree", _panel())
	t.set_stylebox("button_pressed", "Tree", _panel())
	var tree_btn := StyleBoxFlat.new()
	tree_btn.bg_color = Color(0, 0, 0, 0.30)
	tree_btn.set_corner_radius_all(4)
	tree_btn.set_content_margin_all(2)
	t.set_stylebox("button_unpressed", "Tree", tree_btn)
	t.set_stylebox("button_hover", "Tree", tree_btn)
	t.set_stylebox("selected_focus", "Tree", StyleBoxFlat.new())
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("font_hover_color", "Tree", Color.WHITE)
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("font_outline_color", "Tree", Color(0, 0, 0, 1))
	t.set_constant("outline_size", "Tree", 1)
	t.set_color("selected", "Tree", SELECT)
	t.set_color("cursor", "Tree", ACCENT)
	t.set_color("lines", "Tree", Color(1, 1, 1, 0.06))
	t.set_color("title_button_color", "Tree", Color(1, 1, 1, 0.45))
	t.set_color("title_button_hover_color", "Tree", Color.WHITE)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.08))
	t.set_color("relationship_line_color", "Tree", Color(1, 1, 1, 0.10))
	t.set_color("drop_position_color", "Tree", ACCENT)

	# ── ItemList（目录树/列表）──
	var il := StyleBoxFlat.new()
	il.bg_color = PANEL_BG
	il.set_border_width_all(1)
	il.border_color = PANEL_BORDER
	il.set_corner_radius_all(6)
	il.set_content_margin_all(4)
	t.set_stylebox("panel", "ItemList", il)
	t.set_color("font_color", "ItemList", TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("selected", "ItemList", SELECT)
	t.set_color("cursor", "ItemList", ACCENT)

	# ── RichTextLabel（日志）──
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("scroll_color", "RichTextLabel", Color(1, 1, 1, 0.1))

	# ── Label：颜色不动（用默认白 + 上述描边，观感与全局一致）──

	# ── 滚动条（细窄半透明）──
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0, 0, 0, 0.25)
	t.set_stylebox("panel", "ScrollContainer", scroll_bg)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(1, 1, 1, 0.14)
	grabber.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber", "HScrollBar", grabber)
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(0.92, 0.73, 0.32, 0.35)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber_hover)
	t.set_stylebox("grabber_highlight", "HScrollBar", grabber_hover)
	t.set_stylebox("track", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("track", "HScrollBar", StyleBoxEmpty.new())
	t.set_constant("width", "VScrollBar", 6)
	t.set_constant("width", "HScrollBar", 6)

	# ── SpinBox 微调（组合 LineEdit + 箭头按钮）──
	t.set_constant("separation", "SpinBox", 0)
	_cached = t
	return t



## 面板卡片样式（游戏菜单同款：半透明黑 + 金边 + 圆角 6 + 内容距 8）
static func _panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.set_border_width_all(1)
	sb.border_color = PANEL_BORDER
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


## 按钮三态样式（黑底金边卡片族；游戏页面无按钮，此为自然延伸）
static func _style_button(t: Theme, type: String) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0.40)
	normal.set_border_width_all(1)
	normal.border_color = Color(PANEL_BORDER, 0.75)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(6)
	t.set_stylebox("normal", type, normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0, 0, 0, 0.55)
	hover.border_color = PANEL_BORDER_HOVER
	t.set_stylebox("hover", type, hover)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.35, 0.27, 0.12, 0.90)
	pressed.border_color = ACCENT
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, TEXT)
	t.set_color("font_hover_color", type, Color.WHITE)
	t.set_color("font_pressed_color", type, ACCENT)

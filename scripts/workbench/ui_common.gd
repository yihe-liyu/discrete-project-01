class_name WorkbenchUI
extends RefCounted
## 工作台 UI 公共工具：统一的小控件工厂（标签/标题/参数行）

const TEXT_DIM := Color(0.72, 0.72, 0.72)  # 中性灰（与游戏页面弱化文字一致，不再蓝灰）
const ACCENT := Color(0.92, 0.73, 0.32)
const RIG_COMMON = preload("res://scripts/workbench/rig_common.gd")  # 字号阶梯单一来源


## 区块标题（金色，与组合台 section_label 同级）：── 状态 ── / ── 书签 ── 等
static func section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", RIG_COMMON.SECTION_SIZE)
	l.add_theme_color_override("font_color", ACCENT)
	l.custom_minimum_size = Vector2(0, 20)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## 参数标签（右对齐统一宽度，参数行对齐）
static func param_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(52, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.add_theme_font_size_override("font_size", RIG_COMMON.LABEL_SIZE)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


## 弱化文字标签（普通说明）
static func label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", RIG_COMMON.LABEL_SIZE)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


## SpinBox 行：右对齐标签 + 固定宽度 spinbox，挂到 parent，返回 spin
## width：框宽（默认 120px；不撑满行，视觉整齐、面板拖宽也不变形）
static func spin_row(parent: Node, label_text: String, value: float, min_v: float, max_v: float, step: float, width: float = 120.0) -> SpinBox:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(param_label(label_text))
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(width, 0)
	h.add_child(spin)
	parent.add_child(h)
	return spin


## 参数行内的小 SpinBox（Vector2 用，不挂行）
static func mini_spin(value: float, min_v: float, max_v: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = 1.0
	spin.value = value
	spin.custom_minimum_size = Vector2(70, 0)
	return spin


## 参数值标签（键名，用于字典动态表单）
static func param_key_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(48, 0)
	l.add_theme_font_size_override("font_size", RIG_COMMON.LABEL_SIZE)
	l.add_theme_color_override("font_color", TEXT_DIM)
	return l


## Vector2 参数行：x [ ] y [ ]（带 x/y 小标签，仿 Inspector 坐标编辑器）
## 返回 [sx: SpinBox, sy: SpinBox] 供写回
static func vec2_row(parent: Node, key: String, value: Vector2) -> Array:
	return coord_row(parent, key, value.x, value.y, -10000, 10000, -10000, 10000)


## 坐标行：label x[ ] y[ ]（带轴标签；x/y 的 min/max 可分别设）
static func coord_row(parent: Node, label_text: String, x_val: float, y_val: float,
		x_min: float, x_max: float, y_min: float, y_max: float) -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.add_child(param_label(label_text))
	var sx := _axis_spin(x_val, "x")
	var sy := _axis_spin(y_val, "y")
	sx.spin.min_value = x_min
	sx.spin.max_value = x_max
	sy.spin.min_value = y_min
	sy.spin.max_value = y_max
	h.add_child(sx.row)
	h.add_child(sy.row)
	parent.add_child(h)
	return [sx.spin, sy.spin]


static func _axis_spin(v: float, axis: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var l := Label.new()
	l.text = axis
	l.custom_minimum_size = Vector2(12, 0)
	l.add_theme_color_override("font_color", Color(0.52, 0.52, 0.55))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var spin := SpinBox.new()
	spin.min_value = -10000
	spin.max_value = 10000
	spin.step = 1.0
	spin.value = v
	spin.custom_minimum_size = Vector2(72, 0)
	row.add_child(spin)
	return {"row": row, "spin": spin}

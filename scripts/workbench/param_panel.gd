extends VBoxContainer
## 参数面板共享组件 —— 脚本 var 枚举 → 可调控件行 → collect() 字典
## 与游戏注入同源：EnemyData.params / BulletData.params → 脚本同名 var 注入
## 零值 Vector2 染橙提醒；自带可折叠标题（行数多默认收起）

const _label_hint_color := Color(1, 1, 0.7, 0.8)
const RIG_COMMON = preload("res://scripts/workbench/rig_common.gd")  # 字号阶梯单一来源

var _rows: Array = []  # [{name, kind, ctrl}]
var body: VBoxContainer   # 参数行容器（测试/外部读取 children 用）
var _header: Button


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_header = Button.new()
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.add_theme_font_size_override("font_size", RIG_COMMON.SECTION_SIZE)
	_header.pressed.connect(_toggle)
	add_child(_header)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	add_child(body)


## 重建参数行（脚本为 null = 清空）
func rebuild(script: Script) -> void:
	for c in body.get_children():
		c.queue_free()
	_rows.clear()
	if script == null:
		_header.text = "参数（选择脚本后显示）"
		body.visible = true
		return
	var inst = script.new()
	var prop_list: Array = script.get_script_property_list()
	var skipped := 0
	for p in prop_list:
		var nm: String = p.get("name", "")
		if nm == "" or nm.begins_with("_"):
			continue
		if not (int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var pt: int = p.get("type", TYPE_NIL)
		match pt:
			TYPE_FLOAT, TYPE_INT:
				var sp := _new_spin(0.5, -100000.0, 100000.0, inst.get(nm))
				_add_row(nm, "num", sp)
			TYPE_BOOL:
				var chk := CheckBox.new()
				chk.button_pressed = bool(inst.get(nm))
				_add_row(nm, "bool", chk)
			TYPE_STRING:
				var le := LineEdit.new()
				le.text = str(inst.get(nm))
				le.custom_minimum_size = Vector2(120, 0)
				_add_row(nm, "str", le)
			TYPE_VECTOR2:
				var vec_row := HBoxContainer.new()
				vec_row.add_theme_constant_override("separation", 4)
				var vx := _new_spin(10.0, -100000.0, 100000.0, (inst.get(nm) as Vector2).x)
				vx.custom_minimum_size = Vector2(70, 0)
				var vy := _new_spin(10.0, -100000.0, 100000.0, (inst.get(nm) as Vector2).y)
				vy.custom_minimum_size = Vector2(70, 0)
				vec_row.add_child(vx)
				vec_row.add_child(vy)
				var lbt := _add_row(nm, "vec2", vec_row)
				if (inst.get(nm) as Vector2).length() < 0.01:
					lbt.modulate = Color(1, 0.65, 0.2)  # (0,0) 陷阱提醒
			TYPE_COLOR:
				var cp := ColorPickerButton.new()
				cp.color = inst.get(nm)
				cp.custom_minimum_size = Vector2(120, 0)
				_add_row(nm, "color", cp)
			_:
				skipped += 1
	if skipped > 0:
		_add_note("（%d 个复杂类型参数走代码）" % skipped, _label_hint_color)
	if _rows.is_empty():
		_add_note("（该脚本无可调 var；默认值即脚本内声明）", Color(1, 1, 1, 0.5))
	_header.text = "参数 ▼（%d 个）" % _rows.size() if _rows.size() > 0 else "参数（无可调 var）"
	# 行数多默认收起；Toggle 文本同步
	body.visible = _rows.size() <= 6
	_header.text = ("参数 ▼（%d 个，点击折叠）" % _rows.size()) if body.visible \
		else ("参数 ▶（%d 个，点击展开）" % _rows.size())
	inst.free()


func _toggle() -> void:
	body.visible = not body.visible
	if _rows.size() > 0:
		_header.text = ("参数 ▼（%d 个，点击折叠）" % _rows.size()) if body.visible \
			else ("参数 ▶（%d 个，点击展开）" % _rows.size())


## 收集面板值 → 参数字典（与游戏 params 同构）
func collect() -> Dictionary:
	var out := {}
	for row in _rows:
		match row.kind:
			"num":
				out[row.name] = row.ctrl.value
			"bool":
				out[row.name] = row.ctrl.button_pressed
			"str":
				out[row.name] = row.ctrl.text
			"vec2":
				var vec_row: HBoxContainer = row.ctrl
				out[row.name] = Vector2(vec_row.get_child(0).value, vec_row.get_child(1).value)
			"color":
				out[row.name] = row.ctrl.color
	return out


func get_rows() -> Array:
	return _rows


# ── 内部 ──

func _new_spin(step: float, mn: float, mx: float, value: Variant) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.step = step
	sp.value = value
	sp.custom_minimum_size = Vector2(120, 0)
	return sp


func _add_row(nm: String, kind: String, ctrl: Control) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lb := _mk_label(nm, RIG_COMMON.HINT_SIZE)
	lb.custom_minimum_size = Vector2(90, 0)
	row.add_child(lb)
	row.add_child(ctrl)
	body.add_child(row)
	_rows.append({"name": nm, "kind": kind, "ctrl": ctrl})
	return lb


func _add_note(text: String, color: Color) -> void:
	var l := _mk_label(text, RIG_COMMON.HINT_SIZE)
	l.modulate = color
	body.add_child(l)


func _mk_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

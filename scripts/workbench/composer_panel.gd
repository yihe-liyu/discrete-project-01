extends VBoxContainer
## F10b 拼装面板 —— 描述符词汇 → 相位列表 → 参数表单 → 预览 → 可复制代码。
##
## 边界：只拼 `BulletLifecycle`（trajectory），不拼 `_tick` / 波次调度。
## 难度：4 个 BulletComposer 各存一档（Easy/Normal/Hard/Lunatic），切难度不丢。
## 代码里的 `_spawn` 是占位：作者替换成自己的 BulletData。

signal preview_requested(lifecycle: BulletLifecycle)
signal difficulty_changed(index: int)
signal status(text: String, color: Color)

const COMPOSER := preload("res://scripts/workbench/bullet_composer.gd")
const CATALOG := preload("res://scripts/workbench/descriptor_catalog.gd")
const RIG_COMMON := preload("res://scripts/workbench/bench_common.gd")

const KINDS := [&"move", &"until", &"action"]
const KIND_LABELS := {&"move": "Move", &"until": "Until", &"action": "Action"}
const TARGETS := [BulletLifecycle.T_PLAYER, BulletLifecycle.T_NEAREST_ENEMY, BulletLifecycle.T_BOSS]
const TARGET_LABELS := ["自机", "最近敌机", "Boss"]

var _composers: Array = []
var _difficulty: int = 0
var _phase_index: int = 0
var _selected: Dictionary = {}
var _spawn_provider: Callable
var _building: bool = false

var _difficulty_sel: OptionButton
var _kind_sel: OptionButton
var _op_sel: OptionButton
var _tree: Tree
var _param_box: VBoxContainer
var _param_title: Label
var _code_edit: TextEdit
var _copy_btn: Button
var _preview_btn: Button
var _add_btn: Button


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 4)
	_difficulty = clampi(SaveData.selected_difficulty, 0, 3)
	for i in 4:
		_composers.append(COMPOSER.new())
	_build_ui()
	_rebuild_all()


## 由弹幕台注入：返回当前“子弹外形”BulletData（emit/spawn 的预览载体）。
func setup(spawn_provider: Callable) -> void:
	_spawn_provider = spawn_provider


func _build_ui() -> void:
	add_child(RIG_COMMON.section_label("描述符拼装"))

	var diff_row := HBoxContainer.new()
	diff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_theme_constant_override("separation", 6)
	var diff_lb := RIG_COMMON.label("难度", RIG_COMMON.HINT_SIZE)
	diff_lb.custom_minimum_size = Vector2(40, 0)
	diff_row.add_child(diff_lb)
	_difficulty_sel = OptionButton.new()
	for d in ["Easy", "Normal", "Hard", "Lunatic"]:
		_difficulty_sel.add_item(d)
	_difficulty_sel.selected = _difficulty
	_difficulty_sel.item_selected.connect(_on_difficulty_changed)
	diff_row.add_child(_difficulty_sel)
	add_child(diff_row)

	var add_row := HBoxContainer.new()
	add_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_theme_constant_override("separation", 4)
	_kind_sel = OptionButton.new()
	for k in KINDS:
		_kind_sel.add_item(KIND_LABELS[k])
	_kind_sel.custom_minimum_size = Vector2(72, 0)
	_kind_sel.item_selected.connect(func(_i): _refresh_op_list())
	add_row.add_child(_kind_sel)
	_op_sel = OptionButton.new()
	_op_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_op_sel.fit_to_longest_item = false
	_op_sel.custom_minimum_size = Vector2(150, 0)
	add_row.add_child(_op_sel)
	_add_btn = RIG_COMMON.accent_button("加入")
	_add_btn.pressed.connect(_add_selected_op)
	add_row.add_child(_add_btn)
	add_child(add_row)

	var phase_row := HBoxContainer.new()
	phase_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_row.add_theme_constant_override("separation", 4)
	for spec in [["+ 相位", _add_phase], ["删除", _remove_selected], ["上移", _move_up], ["下移", _move_down]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		phase_row.add_child(b)
	add_child(phase_row)

	_tree = Tree.new()
	_tree.columns = 1
	_tree.hide_root = true
	_tree.custom_minimum_size = Vector2(0, 160)
	_tree.add_theme_font_size_override("font_size", RIG_COMMON.HINT_SIZE)
	_tree.item_selected.connect(_on_tree_selected)
	add_child(_tree)

	_param_title = RIG_COMMON.label("参数（选一个 Move/Until/Action）", RIG_COMMON.HINT_SIZE)
	_param_title.modulate = Color(1.0, 0.83, 0.5, 0.92)
	add_child(_param_title)
	_param_box = VBoxContainer.new()
	_param_box.add_theme_constant_override("separation", 2)
	add_child(_param_box)

	var code_head := HBoxContainer.new()
	code_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_head.add_theme_constant_override("separation", 4)
	var code_label := RIG_COMMON.label("代码", RIG_COMMON.HINT_SIZE)
	code_label.custom_minimum_size = Vector2(40, 0)
	code_head.add_child(code_label)
	_copy_btn = Button.new()
	_copy_btn.text = "复制"
	_copy_btn.pressed.connect(_copy_code)
	code_head.add_child(_copy_btn)
	_preview_btn = RIG_COMMON.accent_button("预览发射")
	_preview_btn.pressed.connect(_preview)
	code_head.add_child(_preview_btn)
	add_child(code_head)
	add_child(RIG_COMMON.hint_label("_spawn 是占位；替换成你的 BulletData"))

	_code_edit = TextEdit.new()
	_code_edit.editable = false
	_code_edit.custom_minimum_size = Vector2(0, 150)
	_code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(_code_edit)

	_refresh_op_list()


func _refresh_op_list() -> void:
	if _op_sel == null:
		return
	_op_sel.clear()
	var kind: StringName = KINDS[_kind_sel.selected]
	var defs: Array = CATALOG.move_defs() if kind == &"move" else (CATALOG.until_defs() if kind == &"until" else CATALOG.action_defs())
	for d in defs:
		_op_sel.add_item(str(d["id"]))
		_op_sel.set_item_metadata(_op_sel.item_count - 1, d["id"])
		_op_sel.set_item_tooltip(_op_sel.item_count - 1, str(d["label"]))


# ═══ 公开接缝（测试/创作台）═══

func composer():
	return _composers[_difficulty]


func difficulty() -> int:
	return _difficulty


func set_difficulty(index: int) -> void:
	_difficulty = clampi(index, 0, 3)
	if _difficulty_sel != null:
		_difficulty_sel.selected = _difficulty
	_selected.clear()
	_phase_index = 0
	_rebuild_all()


func phase_count() -> int:
	return composer().phases.size()


func current_phase() -> int:
	return _phase_index


func code() -> String:
	return composer().to_code()


func tree() -> Tree:
	return _tree


func code_edit() -> TextEdit:
	return _code_edit


## 从目录直达：加一个描述符到当前相位（Dir 只提示，不落相位）。
func add_op(kind: StringName, op_id: StringName) -> void:
	if kind == &"dir":
		status.emit("方向表达式在 set_heading / emit / on_end_heading 的参数里选", Color(1, 0.8, 0.4))
		return
	var def := _def_of(kind, op_id)
	if def.is_empty():
		return
	var args := _default_args(def)
	var c = composer()
	match kind:
		&"move":
			c.add_move(_phase_index, op_id, args)
			_selected = {"phase": _phase_index, "section": "moves", "index": c.phases[_phase_index]["moves"].size() - 1}
		&"until":
			c.set_until(_phase_index, op_id, args)
			_selected = {"phase": _phase_index, "section": "until", "index": 0}
		&"action":
			c.add_action(_phase_index, op_id, args)
			_selected = {"phase": _phase_index, "section": "on_end", "index": c.phases[_phase_index]["on_end"].size() - 1}
	_rebuild_all()
	status.emit("已加入 %s" % op_id, Color(0.5, 0.95, 0.6))


func preview_lifecycle() -> BulletLifecycle:
	var spawn = _current_spawn()
	for p in composer().phases:
		for a in p["on_end"]:
			var op := StringName(a.get("op", &""))
			if op == &"emit":
				a["spawn"] = spawn
			elif op == &"emit_variant":
				a["spawns"] = [spawn, spawn] if spawn != null else []
	return composer().to_lifecycle()


func dump() -> Dictionary:
	var variants: Array = []
	for c in _composers:
		variants.append(_serializable_spec(c))
	return {"difficulty": _difficulty, "variants": variants}


## ConfigFile 不能存 BulletData 实例：spawn/spawns 存占位，载入后再用当前子弹补。
func _serializable_spec(c) -> Dictionary:
	var spec: Dictionary = c.to_spec()
	for p in spec.get("phases", []):
		for a in p.get("on_end", []):
			var op := StringName(a.get("op", &""))
			if op == &"emit":
				a["spawn"] = null
			elif op == &"emit_variant":
				a["spawns"] = []
	return spec


func load_from(data: Dictionary) -> void:
	if data.is_empty():
		return
	var variants: Array = data.get("variants", [])
	for i in mini(4, variants.size()):
		_composers[i].from_spec(variants[i])
	_difficulty = clampi(int(data.get("difficulty", SaveData.selected_difficulty)), 0, 3)
	if _difficulty_sel != null:
		_difficulty_sel.selected = _difficulty
	_selected.clear()
	_phase_index = 0
	_rebuild_all()


# ═══ 树 / 选择 ═══

func _rebuild_all() -> void:
	_rebuild_tree()
	_rebuild_param_form()
	_refresh_code()


func _rebuild_tree() -> void:
	_building = true
	_tree.clear()
	var root := _tree.get_root()
	if root == null:
		root = _tree.create_item()
	var current: TreeItem = null
	for i in composer().phases.size():
		var p: Dictionary = composer().phases[i]
		var head := _tree.create_item(root)
		head.set_text(0, "相位 %d%s" % [i + 1, "  ← 当前" if i == _phase_index else ""])
		head.set_custom_color(0, Color(1.0, 0.83, 0.5, 0.9))
		head.set_metadata(0, {"phase": i})
		for j in p["moves"].size():
			var it := _tree.create_item(head)
			it.set_text(0, _item_text("Move", p["moves"][j]))
			it.set_metadata(0, {"phase": i, "section": "moves", "index": j})
			if _is_selected(i, "moves", j):
				current = it
		var u: Dictionary = p["until"]
		var uit := _tree.create_item(head)
		uit.set_text(0, _item_text("Until", u))
		uit.set_metadata(0, {"phase": i, "section": "until", "index": 0})
		if _is_selected(i, "until", 0):
			current = uit
		for j in p["on_end"].size():
			var ait := _tree.create_item(head)
			ait.set_text(0, _item_text("OnEnd", p["on_end"][j]))
			ait.set_metadata(0, {"phase": i, "section": "on_end", "index": j})
			if _is_selected(i, "on_end", j):
				current = ait
	if current != null:
		current.select(0)
	_building = false


func _is_selected(phase: int, section: String, index: int) -> bool:
	return int(_selected.get("phase", -1)) == phase \
		and str(_selected.get("section", "")) == section \
		and int(_selected.get("index", -1)) == index


func _on_tree_selected() -> void:
	if _building:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	var md: Dictionary = item.get_metadata(0)
	if md.is_empty():
		return
	_phase_index = int(md.get("phase", 0))
	if md.has("section"):
		_selected = md
	else:
		_selected = {}
	_rebuild_param_form()
	_refresh_code()


func _item_text(prefix: String, op_call: Dictionary) -> String:
	var op := str(op_call.get("op", "?"))
	var parts: Array[String] = []
	for key in op_call:
		if str(key) == "op":
			continue
		var value = op_call[key]
		if value is BulletData or value is Array:
			continue
		if value is Dictionary:
			parts.append("%s=%s" % [key, str(value.get("kind", "dir"))])
		elif parts.size() < 3:
			parts.append("%s=%s" % [key, str(value)])
	return "%s · %s%s" % [prefix, op, (" (" + ", ".join(parts) + ")") if parts.size() > 0 else ""]


# ═══ 参数表单 ═══

func _rebuild_param_form() -> void:
	if _param_box == null:
		return
	for child in _param_box.get_children():
		child.queue_free()
	var op_call := _selected_call()
	if op_call.is_empty():
		_param_title.text = "参数（选一个 Move/Until/Action）"
		return
	var kind := StringName(_selected.get("section", ""))
	var kind_id := &"move" if kind == "moves" else (&"until" if kind == "until" else &"action")
	var def := _def_of(kind_id, StringName(op_call.get("op", &"")))
	_param_title.text = "参数 · %s" % str(op_call.get("op", ""))
	for param in def.get("params", []):
		_add_param_row(param, op_call)


func _add_param_row(param: Dictionary, op_call: Dictionary) -> void:
	var key := str(param.get("key", ""))
	var ptype := str(param.get("type", "float"))
	# dir 编辑器自带 5 个控件，独占整行；塞进 key(92)+控制 的 HBox 会撑爆 432。
	if ptype == "dir":
		var dir_wrap := VBoxContainer.new()
		dir_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dir_wrap.add_child(RIG_COMMON.label(key, RIG_COMMON.HINT_SIZE))
		dir_wrap.add_child(_make_dir_editor(op_call))
		_param_box.add_child(dir_wrap)
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 6)
	var lb := RIG_COMMON.label(key, RIG_COMMON.HINT_SIZE)
	lb.custom_minimum_size = Vector2(92, 0)
	row.add_child(lb)

	match ptype:
		"float", "int":
			var sp := SpinBox.new()
			sp.min_value = -100000.0
			sp.max_value = 100000.0
			sp.step = 0.1 if ptype == "float" else 1.0
			var cur = op_call.get(key, param.get("default", 0.0))
			sp.value = float(cur) if cur != null else 0.0
			sp.value_changed.connect(func(v): _set_arg(key, v))
			row.add_child(sp)
		"bool":
			var chk := CheckBox.new()
			chk.button_pressed = bool(op_call.get(key, param.get("default", false)))
			chk.toggled.connect(func(v): _set_arg(key, v))
			row.add_child(chk)
		"Vector2":
			var v: Vector2 = op_call.get(key, param.get("default", Vector2.ZERO))
			var vx := SpinBox.new()
			vx.min_value = -100000.0
			vx.max_value = 100000.0
			vx.step = 1.0
			vx.value = v.x
			var vy := SpinBox.new()
			vy.min_value = -100000.0
			vy.max_value = 100000.0
			vy.step = 1.0
			vy.value = v.y
			var sync := func(_v): _set_arg(key, Vector2(vx.value, vy.value))
			vx.value_changed.connect(sync)
			vy.value_changed.connect(sync)
			row.add_child(vx)
			row.add_child(vy)
		"target":
			var opt := OptionButton.new()
			for i in TARGETS.size():
				opt.add_item(TARGET_LABELS[i])
				opt.set_item_metadata(i, TARGETS[i])
			opt.selected = maxi(0, TARGETS.find(op_call.get(key, BulletLifecycle.T_PLAYER)))
			opt.item_selected.connect(func(i): _set_arg(key, TARGETS[i]))
			row.add_child(opt)
		"at":
			var opt := OptionButton.new()
			opt.add_item("当前弹位置")
			opt.add_item("相位结束落点")
			opt.selected = 1 if int(op_call.get(key, BulletLifecycle.AT_CURRENT)) == BulletLifecycle.AT_PHASE_END else 0
			opt.item_selected.connect(func(i): _set_arg(key, BulletLifecycle.AT_PHASE_END if i == 1 else BulletLifecycle.AT_CURRENT))
			row.add_child(opt)
		"dir":
			row.add_child(_make_dir_editor(op_call))
		"spawn", "spawns":
			var note := RIG_COMMON.label("当前子弹（_spawn）", RIG_COMMON.HINT_SIZE)
			note.modulate = Color(1, 1, 1, 0.6)
			row.add_child(note)
			if ptype == "spawn":
				op_call[key] = _current_spawn()
			else:
				var s = _current_spawn()
				op_call[key] = [s, s] if s != null else []
		"hook", "sfx", "string":
			var le := LineEdit.new()
			le.text = str(op_call.get(key, param.get("default", "")))
			le.custom_minimum_size = Vector2(140, 0)
			le.text_changed.connect(func(t): _set_arg(key, StringName(t) if ptype != "string" else t))
			row.add_child(le)
		_:
			row.add_child(RIG_COMMON.label(str(op_call.get(key, "")), RIG_COMMON.HINT_SIZE))
	_param_box.add_child(row)


func _make_dir_editor(op_call: Dictionary) -> Control:
	var dir: Dictionary = op_call.get("dir", {})
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind_sel := OptionButton.new()
	kind_sel.custom_minimum_size = Vector2(88, 0)
	for d in CATALOG.dir_defs():
		kind_sel.add_item(d["label"])
		kind_sel.set_item_metadata(kind_sel.item_count - 1, d["id"])
	var cur_kind := StringName(dir.get(&"kind", BulletLifecycle.D_HEADING))
	var cur_idx := 0
	for i in kind_sel.item_count:
		if StringName(kind_sel.get_item_metadata(i)) == cur_kind:
			cur_idx = i
	kind_sel.selected = cur_idx
	box.add_child(kind_sel)

	var target_sel := OptionButton.new()
	target_sel.custom_minimum_size = Vector2(78, 0)
	for i in TARGETS.size():
		target_sel.add_item(TARGET_LABELS[i])
		target_sel.set_item_metadata(i, TARGETS[i])
	target_sel.selected = maxi(0, TARGETS.find(dir.get(&"target", BulletLifecycle.T_PLAYER)))
	box.add_child(target_sel)

	var angle := SpinBox.new()
	angle.min_value = -TAU * 4.0
	angle.max_value = TAU * 4.0
	angle.step = 0.05
	angle.value = float(dir.get(&"angle", 0.0))
	angle.custom_minimum_size = Vector2(64, 0)
	box.add_child(angle)

	var p := SpinBox.new()
	p.min_value = 0.0
	p.max_value = 1.0
	p.step = 0.05
	p.value = float(dir.get(&"p", 1.0))
	p.custom_minimum_size = Vector2(58, 0)
	box.add_child(p)

	var spread := SpinBox.new()
	spread.min_value = -TAU * 4.0
	spread.max_value = TAU * 4.0
	spread.step = 0.05
	spread.value = float(dir.get(&"spread", 0.0))
	spread.custom_minimum_size = Vector2(64, 0)
	box.add_child(spread)

	var apply := func(_v = null):
		var k := StringName(kind_sel.get_item_metadata(kind_sel.selected))
		op_call["dir"] = CATALOG.make_dir(k, {
			"target": target_sel.get_item_metadata(target_sel.selected),
			"angle": angle.value, "p": p.value, "spread": spread.value,
		})
		_refresh_code()
		_refresh_selected_label()
	kind_sel.item_selected.connect(func(_i): apply.call())
	target_sel.item_selected.connect(func(_i): apply.call())
	angle.value_changed.connect(func(_v): apply.call())
	p.value_changed.connect(func(_v): apply.call())
	spread.value_changed.connect(func(_v): apply.call())
	return box


func _selected_call() -> Dictionary:
	if _selected.is_empty():
		return {}
	var c = composer()
	var pi := int(_selected.get("phase", -1))
	if pi < 0 or pi >= c.phases.size():
		return {}
	var p: Dictionary = c.phases[pi]
	var section := str(_selected.get("section", ""))
	var idx := int(_selected.get("index", -1))
	match section:
		"until":
			return p["until"]
		"moves":
			var arr: Array = p["moves"]
			return arr[idx] if idx >= 0 and idx < arr.size() else {}
		"on_end":
			var arr2: Array = p["on_end"]
			return arr2[idx] if idx >= 0 and idx < arr2.size() else {}
	return {}


func _set_arg(key: String, value: Variant) -> void:
	var op_call := _selected_call()
	if op_call.is_empty():
		return
	op_call[key] = value
	_refresh_selected_label()
	_refresh_code()


func _refresh_selected_label() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var md: Dictionary = item.get_metadata(0)
	if md.is_empty() or not md.has("section"):
		return
	var op_call := _selected_call()
	if op_call.is_empty():
		return
	var prefix := "Move" if str(md["section"]) == "moves" else ("Until" if str(md["section"]) == "until" else "OnEnd")
	item.set_text(0, _item_text(prefix, op_call))


func _refresh_code() -> void:
	if _code_edit != null:
		_code_edit.text = composer().to_code()


func _current_spawn() -> Variant:
	if _spawn_provider.is_valid():
		return _spawn_provider.call()
	return null


# ═══ 操作 ═══

func _def_of(kind: StringName, op_id: StringName) -> Dictionary:
	var defs: Array = CATALOG.move_defs() if kind == &"move" else (CATALOG.until_defs() if kind == &"until" else CATALOG.action_defs())
	for d in defs:
		if StringName(d["id"]) == op_id:
			return d
	return {}


func _default_args(def: Dictionary) -> Dictionary:
	var args := {}
	for param in def.get("params", []):
		var key := str(param.get("key", ""))
		var ptype := str(param.get("type", "float"))
		var default = param.get("default")
		match ptype:
			"float": args[key] = float(default) if default != null else 0.0
			"int": args[key] = int(default) if default != null else 0
			"bool": args[key] = bool(default) if default != null else false
			"Vector2": args[key] = default if default is Vector2 else Vector2.ZERO
			"target": args[key] = default if default != null else BulletLifecycle.T_PLAYER
			"at": args[key] = default if default != null else BulletLifecycle.AT_CURRENT
			"dir": args[key] = BulletLifecycle.heading(0.0)
			"spawn": args[key] = _current_spawn()
			"spawns":
				var s = _current_spawn()
				args[key] = [s, s] if s != null else []
			"hook", "sfx": args[key] = StringName(default) if default != null else &""
			_: args[key] = default
	return args


func _add_selected_op() -> void:
	var kind: StringName = KINDS[_kind_sel.selected]
	if _op_sel.selected < 0:
		return
	var op_id = _op_sel.get_item_metadata(_op_sel.selected)
	add_op(kind, StringName(op_id))


func _add_phase() -> void:
	composer().add_phase()
	_phase_index = composer().phases.size() - 1
	_selected.clear()
	_rebuild_all()


func _remove_selected() -> void:
	if _selected.is_empty():
		# 删当前相位（至少留一个）
		if composer().phases.size() <= 1:
			return
		composer().phases.remove_at(_phase_index)
		_phase_index = clampi(_phase_index, 0, composer().phases.size() - 1)
		_rebuild_all()
		return
	var section := str(_selected.get("section", ""))
	var idx := int(_selected.get("index", -1))
	var c = composer()
	var p: Dictionary = c.phases[_phase_index]
	match section:
		"moves":
			if idx >= 0 and idx < (p["moves"] as Array).size():
				(p["moves"] as Array).remove_at(idx)
		"on_end":
			if idx >= 0 and idx < (p["on_end"] as Array).size():
				(p["on_end"] as Array).remove_at(idx)
		"until":
			c.set_until(_phase_index, &"never", {})
	_selected.clear()
	_rebuild_all()


func _move_up() -> void:
	_reorder(-1)


func _move_down() -> void:
	_reorder(1)


func _reorder(delta: int) -> void:
	if _selected.is_empty():
		return
	var section := str(_selected.get("section", ""))
	if section != "moves" and section != "on_end":
		return
	var idx := int(_selected.get("index", -1))
	var target := idx + delta
	var arr: Array = composer().phases[_phase_index][section]
	if idx < 0 or target < 0 or target >= arr.size():
		return
	var tmp = arr[idx]
	arr[idx] = arr[target]
	arr[target] = tmp
	_selected["index"] = target
	_rebuild_all()


func _on_difficulty_changed(index: int) -> void:
	_difficulty = clampi(index, 0, 3)
	_selected.clear()
	_phase_index = 0
	difficulty_changed.emit(_difficulty)
	_rebuild_all()


func _copy_code() -> void:
	DisplayServer.clipboard_set(composer().to_code())
	status.emit("代码已复制", Color(0.5, 0.95, 0.6))


func _preview() -> void:
	preview_requested.emit(preview_lifecycle())

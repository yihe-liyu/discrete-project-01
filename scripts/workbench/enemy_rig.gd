extends Control
## 敌人组合台（M3a）—— 选魂（行为脚本）× 换壳（外观/HP/判定/掉落）× 出生点 × 幽灵玩家（鼠标跟随）
## 跑真实 StageManager.spawn_enemy_data：敌人移动/发弹/行为脚本全部真实。

const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CATALOG := preload("res://scripts/data/content_catalog.gd")
const SHELL := preload("res://scripts/workbench/enemy_shell.gd")
const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")

const FIXED_SEED := 20260801
const HOT_POLL_INTERVAL := 0.5
const HOT_DEBOUNCE := 0.8
const VERSION_TAG := "v0.3-vec"

var _shell: Variant
var _catalog: Variant
var _ghost: Player
var _spawn_pos := Vector2(GameConfig.FIELD_CENTER_X, 260.0)
var _seed: int = FIXED_SEED

# ── UI ──
var _script_sel: OptionButton
var _visual_sel: OptionButton
var _hp_spin: SpinBox
var _hbox_spin: SpinBox
var _power_spin: SpinBox
var _point_spin: SpinBox
var _life_spin: SpinBox
var _bomb_spin: SpinBox
var _spawn_btn: Button
var _clear_btn: Button
var _seed_btn: Button
var _stats_label: Label
var _field: Control
var _reload_status: Label
var _diff_sel: OptionButton
var _params_container: VBoxContainer
var _param_rows: Array = []  # [{name, kind, ctrl}]（脚本 var 枚举结果）
var _hot_chk: CheckBox

# ── 热更新状态 ──
var _cur_script: Script = null
var _cur_script_path: String = ""
var _watch_paths: Array[String] = []
var _watch_mtimes: Dictionary = {}
var _hot_enabled := true
var _hot_poll := 0.0
var _hot_dirty_since := -1.0


func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	_shell = SHELL.new()
	_catalog = CATALOG.new().scan()
	theme = WORKBENCH_THEME.build()
	_build_world()
	_build_ui()
	_set_seed(FIXED_SEED)
	_set_current_script()
	_rebuild_params()
	_reload_status.text = "热更新：开 · 等待修改…"
	_reload_status.modulate = Color(0.5, 0.95, 0.6)


# ═══ 世界 ═══

func _build_world() -> void:
	_field = Control.new()
	_field.position = Vector2.ZERO
	_field.size = Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_BOTTOM)
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.gui_input.connect(_on_field_input)
	_field.draw.connect(_on_field_draw)
	add_child(_field)
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST)
	_ghost.name = "GhostPlayer"
	_ghost.set("mode", 1)
	_ghost.player_data = preload("res://data/player_data/reimu_data.tres")
	_ghost.position = Vector2(GameConfig.FIELD_CENTER_X, 620.0)
	_ghost.z_index = 30
	_field.add_child(_ghost)


# ═══ UI ═══

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -440.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.offset_bottom = 952.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.085, 0.09, 0.115, 1.0)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	panel_scroll.add_child(box)

	box.add_child(_label("敌人组合台 %s" % VERSION_TAG, 16))

	box.add_child(_label("魂：行为脚本", 12))
	_script_sel = OptionButton.new()
	_script_sel.add_item("（无）移动")
	var idx := 0
	for e in _catalog.by_role("enemy"):
		_script_sel.add_item(e.name if e.name != "" else e.path.get_file())
		_script_sel.set_item_tooltip(idx + 1, e.path)
		idx += 1
	_script_sel.item_selected.connect(_on_script_changed)
	box.add_child(_script_sel)

	box.add_child(_label("难度（即时生效）", 12))
	_diff_sel = OptionButton.new()
	for d in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(d)
	_diff_sel.selected = GameState.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	box.add_child(_diff_sel)

	box.add_child(_label("壳：外形/属性", 12))
	box.add_child(_label("外观", 12))
	_visual_sel = OptionButton.new()
	for k in SHELL.visual_keys():
		_visual_sel.add_item(k)
	box.add_child(_visual_sel)
	box.add_child(_label("HP · 判定半径", 12))
	var hrow := HBoxContainer.new()
	_hp_spin = SpinBox.new()
	_hp_spin.min_value = 1.0
	_hp_spin.max_value = 9999.0
	_hp_spin.value = 100.0
	_hp_spin.custom_minimum_size = Vector2(120, 0)
	hrow.add_child(_hp_spin)
	_hbox_spin = SpinBox.new()
	_hbox_spin.min_value = 1.0
	_hbox_spin.max_value = 200.0
	_hbox_spin.value = 25.0
	_hbox_spin.custom_minimum_size = Vector2(120, 0)
	hrow.add_child(_hbox_spin)
	box.add_child(hrow)
	box.add_child(_label("掉落  P/点/残/雷", 12))
	var drops := GridContainer.new()
	drops.columns = 2
	drops.add_theme_constant_override("h_separation", 8)
	for sp in [_power_spin, _point_spin, _life_spin, _bomb_spin]:
		pass
	_power_spin = _drop_spin(2.0)
	_point_spin = _drop_spin(0.0)
	_life_spin = _drop_spin(0.0)
	_bomb_spin = _drop_spin(0.0)
	for sp in [_power_spin, _point_spin, _life_spin, _bomb_spin]:
		drops.add_child(sp)
	box.add_child(drops)

	box.add_child(_label("参数（脚本 var 注入，可调）", 12))
	_params_container = VBoxContainer.new()
	_params_container.add_theme_constant_override("separation", 2)
	box.add_child(_params_container)

	box.add_child(_label("操作", 12))
	var ops := GridContainer.new()
	ops.columns = 2
	ops.add_theme_constant_override("h_separation", 8)
	ops.add_theme_constant_override("v_separation", 4)
	_spawn_btn = Button.new()
	_spawn_btn.text = "生成"
	_spawn_btn.pressed.connect(_spawn)
	_clear_btn = Button.new()
	_clear_btn.text = "清场"
	_clear_btn.pressed.connect(_clear_all)
	_seed_btn = Button.new()
	_seed_btn.text = "换种子"
	_seed_btn.pressed.connect(_next_seed)
	for c in [_spawn_btn, _clear_btn, _seed_btn]:
		ops.add_child(c)
	box.add_child(ops)

	_stats_label = _label("", 12)
	box.add_child(_stats_label)
	box.add_child(_label("开发", 12))
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	box.add_child(_hot_chk)
	_reload_status = _label("", 11)
	box.add_child(_reload_status)
	box.add_child(_label("左键=出生点 · 鼠标=自机", 11))


func _drop_spin(v: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 0.0
	sp.max_value = 99.0
	sp.value = v
	sp.custom_minimum_size = Vector2(70, 0)
	return sp


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


# ═══ 生成 ═══

func _spawn() -> void:
	_shell.visual_key = _visual_sel.get_item_text(_visual_sel.selected)
	_shell.max_hp = int(_hp_spin.value)
	_shell.hitbox_radius = _hbox_spin.value
	_shell.item_power = int(_power_spin.value)
	_shell.item_point = int(_point_spin.value)
	_shell.item_life = int(_life_spin.value)
	_shell.item_bomb = int(_bomb_spin.value)
	var data: EnemyData = _shell.build(_cur_script)
	# 参数注入（与游戏 params 同路径：ParamValidator.apply 同名 var 注入）
	# 注意：for-in 字典迭代的是键（GDScript 语义）
	var params := _collect_params()
	for k in params:
		data.param(k, params[k])
	data.pos(_spawn_pos)
	RNG.set_seed(_seed)
	data.spawn(BulletManager.get_bullet_ctx())
	_update_stats()


## 从参数面板收集 {参数名: 值}（与游戏 params 字典同构；可单测）
func _collect_params() -> Dictionary:
	var out := {}
	for row in _param_rows:
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


func _clear_all() -> void:
	for e in GameState.get_active_enemies():
		if is_instance_valid(e):
			e.queue_free()
	BulletManager.clear_all()
	_update_stats()


func _set_seed(s: int) -> void:
	_seed = s
	RNG.set_seed(s)


func _next_seed() -> void:
	_set_seed(randi())
	_update_stats()


func _update_stats() -> void:
	if _stats_label:
		_stats_label.text = "敌人：%d · 弹数：%d · 种子：%d" % [
			GameState.get_active_enemies().size(), BulletManager.active_bullets.size(), _seed]


func _process(delta: float) -> void:
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新（同 M2 管线）═══

func _on_script_changed(_idx: int) -> void:
	_set_current_script()
	_rebuild_params()
	if _reload_status:
		_reload_status.text = "魂：%s" % (_cur_script_path.get_file() if _cur_script_path != "" else "（无移动）")
		_reload_status.modulate = Color(1, 1, 1, 0.8)


func _set_current_script() -> void:
	var idx := _script_sel.selected
	if idx <= 0:
		_cur_script = null
		_cur_script_path = ""
	else:
		var entry = _catalog.by_role("enemy")[idx - 1]
		_cur_script_path = entry.path
		_cur_script = load(_cur_script_path)
	_rebuild_watch()


## 从脚本枚举 var（get_script_property_list）→ 生成可调参数行；参数与游戏 params 注入同源
func _rebuild_params() -> void:
	for c in _params_container.get_children():
		c.queue_free()
	_param_rows.clear()
	if _cur_script == null:
		return
	var inst = _cur_script.new()
	var prop_list: Array = _cur_script.get_script_property_list()
	var skipped := 0
	for p in prop_list:
		var nm: String = p.get("name", "")
		if nm == "" or nm.begins_with("_"):
			continue
		if not (int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var prop_type: int = p.get("type", TYPE_NIL)
		match prop_type:
			TYPE_FLOAT, TYPE_INT:
				var sp := SpinBox.new()
				sp.min_value = -100000.0
				sp.max_value = 100000.0
				sp.step = 0.5
				sp.value = inst.get(nm)
				sp.custom_minimum_size = Vector2(120, 0)
				_add_param_row(nm, "num", sp)
			TYPE_BOOL:
				var chk := CheckBox.new()
				chk.button_pressed = bool(inst.get(nm))
				_add_param_row(nm, "bool", chk)
			TYPE_STRING:
				var le := LineEdit.new()
				le.text = str(inst.get(nm))
				_add_param_row(nm, "str", le)
			TYPE_VECTOR2:
				var vec_row := HBoxContainer.new()
				vec_row.add_theme_constant_override("separation", 4)
				var vx := SpinBox.new()
				vx.min_value = -100000.0
				vx.max_value = 100000.0
				vx.step = 10.0
				vx.value = (inst.get(nm) as Vector2).x
				vx.custom_minimum_size = Vector2(70, 0)
				var vy := SpinBox.new()
				vy.min_value = -100000.0
				vy.max_value = 100000.0
				vy.step = 10.0
				vy.value = (inst.get(nm) as Vector2).y
				vy.custom_minimum_size = Vector2(70, 0)
				vec_row.add_child(vx)
				vec_row.add_child(vy)
				_add_param_row(nm, "vec2", vec_row)
			TYPE_COLOR:
				var cp := ColorPickerButton.new()
				cp.color = inst.get(nm)
				cp.custom_minimum_size = Vector2(120, 0)
				_add_param_row(nm, "color", cp)
			_:
				skipped += 1
	if skipped > 0:
		var hint := _label("（%d 个复杂类型参数走代码）" % skipped, 10)
		hint.modulate = Color(1, 1, 0.7, 0.8)
		_params_container.add_child(hint)
	if _param_rows.is_empty():
		var none := _label("（该脚本无可调 var；默认值即脚本内声明）", 10)
		none.modulate = Color(1, 1, 1, 0.5)
		_params_container.add_child(none)
	inst.free()


func _add_param_row(nm: String, kind: String, ctrl: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lb := _label(nm, 11)
	lb.custom_minimum_size = Vector2(90, 0)
	row.add_child(lb)
	row.add_child(ctrl)
	_params_container.add_child(row)
	_param_rows.append({"name": nm, "kind": kind, "ctrl": ctrl})


## 难度切换：diff_pick 运行时实时读取 → 立即生效
func _on_diff_changed(idx: int) -> void:
	GameState.selected_difficulty = idx
	_update_stats()


func _rebuild_watch() -> void:
	_watch_paths.clear()
	_watch_mtimes.clear()
	if _cur_script_path == "":
		return
	_watch_paths.append(_cur_script_path)
	var da := DirAccess.open(_cur_script_path.get_base_dir())
	if da:
		for f in da.get_files():
			if f.ends_with(".gd"):
				var p := _cur_script_path.get_base_dir().path_join(f)
				if not _watch_paths.has(p):
					_watch_paths.append(p)
	for p in _watch_paths:
		_watch_mtimes[p] = FileAccess.get_modified_time(p)


func _on_hot_toggled(on: bool) -> void:
	_hot_enabled = on
	if _reload_status:
		_reload_status.text = "热更新：开" if on else "热更新：关"
		_reload_status.modulate = Color(0.5, 0.95, 0.6) if on else Color(1, 1, 1, 0.6)


func _process_hot_reload(delta: float) -> void:
	if not _hot_enabled or _cur_script_path == "":
		return
	_hot_poll += delta
	if _hot_poll < HOT_POLL_INTERVAL:
		return
	_hot_poll = 0.0
	var changed := false
	for p in _watch_paths:
		var mt := int(FileAccess.get_modified_time(p))
		if mt != int(_watch_mtimes.get(p, 0)):
			changed = true
	if changed:
		if _hot_dirty_since < 0.0:
			_hot_dirty_since = 0.0
			_reload_status.text = "↻ 检测到修改…"
			_reload_status.modulate = Color(1, 1, 0.6)
		_hot_dirty_since += HOT_POLL_INTERVAL
		if _hot_dirty_since >= HOT_DEBOUNCE:
			_hot_dirty_since = -1.0
			_do_hot_reload()
	else:
		_hot_dirty_since = -1.0


func _refresh_watch_mtimes() -> void:
	for p in _watch_paths:
		_watch_mtimes[p] = int(FileAccess.get_modified_time(p))


func _do_hot_reload() -> void:
	var main_new: Script = null
	var failed := ""
	for p in _watch_paths:
		if p == _cur_script_path:
			continue
		if not FileAccess.file_exists(p):
			failed = p
			break
		var s: Script = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if s == null:
			failed = p
			break
	if failed == "" and FileAccess.file_exists(_cur_script_path):
		main_new = ResourceLoader.load(_cur_script_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if main_new == null:
			failed = _cur_script_path
	elif failed == "":
		failed = _cur_script_path
	if failed != "":
		_reload_status.text = "⚠ 重载失败：%s（旧版继续）" % failed.get_file()
		_reload_status.modulate = Color(1, 0.4, 0.4)
		_refresh_watch_mtimes()
		_hot_dirty_since = -1.0
		return
	_cur_script = main_new
	_refresh_watch_mtimes()
	_hot_dirty_since = -1.0
	_rebuild_params()  # 新脚本可能新增/改名参数 → 面板同步
	_clear_all()
	RNG.set_seed(_seed)
	_spawn()
	_reload_status.text = "↻ 已重载：%s" % _cur_script_path.get_file()
	_reload_status.modulate = Color(0.5, 0.95, 0.6)


# ═══ 场地交互 ═══

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_spawn_pos = (event as InputEventMouseButton).position
		_field.queue_redraw()


func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.35, 0.45, 0.7, 0.5), false, 2.0)
	var p := _spawn_pos
	_field.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color(1, 0.6, 0.2), 2.0)
	_field.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), Color(1, 0.6, 0.2), 2.0)

extends Control
## 阶段组合台（M4）—— 目录选阶段 × 双槽（move/shoot）× 壳字段（HP/时限）× Boss 视觉
## 运行基于 start_spell_card（符卡练习同款单阶段运行器：自建时钟+ctx+Boss 直进阶段）

const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const CATALOG := preload("res://scripts/data/content_catalog.gd")
const PHASE_SHELL := preload("res://scripts/workbench/phase_shell.gd")
const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const RIG_COMMON := preload("res://scripts/workbench/rig_common.gd")
const STATUS_TOAST := preload("res://scripts/workbench/status_toast.gd")
const PARAM_PANEL := preload("res://scripts/workbench/param_panel.gd")

const FIXED_SEED := 20260801
const HOT_POLL_INTERVAL := 0.5
const HOT_DEBOUNCE := 0.8
const VERSION_TAG := "v0.6-param"

var _shell: Variant
var _catalog: Variant
var _ghost: Player
var _boss_pos := Vector2(GameConfig.FIELD_CENTER_X, 250.0)
var _seed: int = FIXED_SEED
var _boss: Node = null          # 当前 Boss（开演/清场管理）

# ── UI ──
var _phase_sel: OptionButton
var _move_sel: OptionButton
var _shoot_sel: OptionButton
var _move_params: VBoxContainer
var _shoot_params: VBoxContainer
var _hp_spin: SpinBox
var _time_spin: SpinBox
var _diff_sel: OptionButton
var _play_btn: Button
var _clear_btn: Button
var _seed_btn: Button
var _stats_label: Label
var _name_label: Label
var _field: Control
var _reload_status: Label
var _toast: Control
var _hot_chk: CheckBox

# ── 热更新 ──
var _move_path: String = ""
var _shoot_path: String = ""
var _watch_paths: Array[String] = []
var _watch_mtimes: Dictionary = {}
var _hot_enabled := true
var _hot_poll := 0.0
var _hot_dirty_since := -1.0


func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	_shell = PHASE_SHELL.new()
	_catalog = CATALOG.new().scan()
	theme = WORKBENCH_THEME.build()
	_build_world()
	_build_ui()
	_toast = STATUS_TOAST.new()
	add_child(_toast)
	_reload_status = _toast.label
	_set_seed(FIXED_SEED)
	_select_phase(0)
	_toast.show_msg("热更新：开", Color(0.5, 0.95, 0.6))


# ═══ 世界 ═══

func _build_world() -> void:
	RIG_COMMON.add_stage_bg(self)
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
	var panel: PanelContainer = RIG_COMMON.make_panel()
	add_child(panel)
	var panel_scroll := ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(box)

	box.add_child(RIG_COMMON.section_label("阶段组合台 %s" % VERSION_TAG))

	box.add_child(RIG_COMMON.section_label("阶段（目录）"))
	_phase_sel = OptionButton.new()
	var phase_idx := 0
	for e in _catalog.by_role("phase"):
		var uid: int = e.extra.get("uid", 0)
		var display: String = e.name if e.name != "" else e.path.get_file()
		if uid > 0:
			display += " · uid" + str(uid)
		_phase_sel.add_item(display)
		_phase_sel.set_item_tooltip(phase_idx, e.path)
		phase_idx += 1
	_phase_sel.item_selected.connect(_select_phase)
	box.add_child(_phase_sel)
	_name_label = _label("", 13)
	box.add_child(_name_label)

	box.add_child(RIG_COMMON.section_label("魂：双槽（阶段内 move×shoot）"))
	box.add_child(_label("移动脚本", 13))
	_move_sel = OptionButton.new()
	_move_sel.add_item("（空）— Boss 原地")
	_fill_script_options(_move_sel, "boss_move")
	box.add_child(_move_sel)
	_move_params = PARAM_PANEL.new()
	box.add_child(_move_params)
	_move_sel.item_selected.connect(_on_slots_changed)
	box.add_child(_label("弹幕脚本", 13))
	_shoot_sel = OptionButton.new()
	_shoot_sel.add_item("（空）— 不发弹")
	_fill_script_options(_shoot_sel, "boss_shoot")
	box.add_child(_shoot_sel)
	_shoot_params = PARAM_PANEL.new()
	box.add_child(_shoot_params)
	_shoot_sel.item_selected.connect(_on_slots_changed)

	box.add_child(RIG_COMMON.section_label("壳：阶段数值"))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	var hp_lb := _label("血量", 13)
	hp_lb.custom_minimum_size = Vector2(34, 0)
	hp_row.add_child(hp_lb)
	_hp_spin = _num_spin(100.0, 100000.0, 4000.0)
	_hp_spin.custom_minimum_size = Vector2(110, 0)
	hp_row.add_child(_hp_spin)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	var time_lb := _label("时限(s)", 13)
	time_lb.custom_minimum_size = Vector2(46, 0)
	time_row.add_child(time_lb)
	_time_spin = _num_spin(5.0, 300.0, 30.0)
	_time_spin.custom_minimum_size = Vector2(110, 0)
	time_row.add_child(_time_spin)
	hr.add_child(hp_row)
	hr.add_child(time_row)
	box.add_child(hr)

	box.add_child(RIG_COMMON.section_label("难度（即时生效）"))
	_diff_sel = OptionButton.new()
	for d in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(d)
	_diff_sel.selected = GameState.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	box.add_child(_diff_sel)

	box.add_child(RIG_COMMON.section_label("操作"))
	var ops := GridContainer.new()
	ops.columns = 2
	ops.add_theme_constant_override("h_separation", 8)
	ops.add_theme_constant_override("v_separation", 4)
	_play_btn = RIG_COMMON.accent_button("开演")
	_play_btn.pressed.connect(_play)
	_clear_btn = Button.new()
	_clear_btn.text = "清场"
	_clear_btn.pressed.connect(_clear_all)
	_seed_btn = Button.new()
	_seed_btn.text = "换种子"
	_seed_btn.pressed.connect(_next_seed)
	for c in [_play_btn, _clear_btn, _seed_btn]:
		ops.add_child(c)
	box.add_child(ops)

	_stats_label = _label("", 16)
	box.add_child(_stats_label)
	box.add_child(RIG_COMMON.section_label("开发"))
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	box.add_child(_hot_chk)
	box.add_child(_label("左键=Boss落点 · 鼠标=自机", 13))


func _num_spin(mn: float, mx: float, val: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.value = val
	return sp


func _fill_script_options(sel: OptionButton, role: String) -> void:
	var idx := 1
	for e in _catalog.by_role(role):
		sel.add_item(e.name if e.name != "" else e.path.get_file())
		sel.set_item_tooltip(idx, e.path)
		idx += 1


func _label(text: String, font_size: int) -> Label:
	return RIG_COMMON.label(text, font_size)


## 阶段选择：默认槽位/数值取该 .tres 现值
func _select_phase(idx: int) -> void:
	var phases = _catalog.by_role("phase")
	if phases.is_empty() or idx < 0 or idx >= phases.size():
		return
	var e = phases[idx]
	var p: PhaseData = load(e.path)
	if p == null:
		return
	_hp_spin.value = float(p.hp)
	_time_spin.value = p.time_limit
	_name_label.text = "%s · uid=%d · %s" % [p.name if p.name != "" else e.path.get_file(), p.uid,
		"符卡" if p.uid != 0 else "非符"]
	# 双槽默认 = 阶段现值；在目录脚本列表中定位
	_move_sel.selected = _script_index("boss_move", p.move_script)
	_shoot_sel.selected = _script_index("boss_shoot", p.shoot_script)
	_move_path = p.move_script.resource_path if p.move_script else ""
	_shoot_path = p.shoot_script.resource_path if p.shoot_script else ""
	_rebuild_watch()
	_rebuild_param_panels()


func _script_index(role: String, script: Script) -> int:
	if script == null:
		return 0
	var list = _catalog.by_role(role)
	for i in list.size():
		if list[i].path == script.resource_path:
			return i + 1
	return 0


## 槽位手动变更：刷新监听 + 参数面板
func _on_slots_changed(_i: int) -> void:
	var mv: Script = _resolve_slot(_move_sel, "boss_move")
	var sh: Script = _resolve_slot(_shoot_sel, "boss_shoot")
	_move_path = mv.resource_path if mv else ""
	_shoot_path = sh.resource_path if sh else ""
	_rebuild_watch()
	_rebuild_param_panels()


## 按当前槽位重建两个参数面板
func _rebuild_param_panels() -> void:
	_move_params.rebuild(_resolve_slot(_move_sel, "boss_move"))
	_shoot_params.rebuild(_resolve_slot(_shoot_sel, "boss_shoot"))


## 双槽 → 当前脚本路径（空=null）
func _resolve_slot(sel: OptionButton, role: String) -> Script:
	var i := sel.selected
	if i <= 0:
		return null
	var list = _catalog.by_role(role)
	if i - 1 >= list.size():
		return null
	return load(list[i - 1].path)


# ═══ 目录直达 / 工作区恢复 ═══

func _preset_from_entry(entry) -> void:
	var phases = _catalog.by_role("phase")
	for i in phases.size():
		if phases[i].path == entry.path:
			_phase_sel.selected = i
			_select_phase(i)
			_play()
			return


func _snapshot() -> Dictionary:
	var phases = _catalog.by_role("phase")
	var path := ""
	if _phase_sel.selected >= 0 and _phase_sel.selected < phases.size():
		path = phases[_phase_sel.selected].path
	return {
		"phase": path, "seed": _seed, "diff": GameState.selected_difficulty,
		"hp": _hp_spin.value, "time": _time_spin.value,
		"pos_x": _boss_pos.x, "pos_y": _boss_pos.y,
	}


func _restore(d: Dictionary) -> void:
	if d.has("seed"):
		_seed = d.seed
	if d.has("diff"):
		GameState.selected_difficulty = d.diff
		_diff_sel.selected = int(d.diff)
	if d.has("hp"):
		_hp_spin.value = d.hp
	if d.has("time"):
		_time_spin.value = d.time
	if d.has("pos_x"):
		_boss_pos = Vector2(d.pos_x, d.pos_y)
		_field.queue_redraw()
	if d.has("phase") and str(d.phase) != "":
		var phases = _catalog.by_role("phase")
		for i in phases.size():
			if phases[i].path == str(d.phase):
				_phase_sel.selected = i
				_select_phase(i)
				break


# ═══ 开演 ═══

func _play() -> void:
	var phases = _catalog.by_role("phase")
	if phases.is_empty():
		return
	var idx: int = _phase_sel.selected
	var e = phases[idx]
	var base: PhaseData = load(e.path)
	if base == null:
		return
	_clear_all()  # 防叠
	var phase: PhaseData = _shell.build_copy(base, _resolve_slot(_move_sel, "boss_move"),
		_resolve_slot(_shoot_sel, "boss_shoot"), _hp_spin.value, _time_spin.value)
	# 参数合并：基础 + 槽位面板（同键 shoot 覆盖；Boss 把同一字典灌给双脚本）
	var merged := phase.params
	merged.merge(_move_params.collect())
	merged.merge(_shoot_params.collect())
	phase.params = merged
	_move_path = phase.move_script.resource_path if phase.move_script else ""
	_shoot_path = phase.shoot_script.resource_path if phase.shoot_script else ""
	_rebuild_watch()
	RNG.set_seed(_seed)
	var boss := StageManager.start_spell_card(phase, _shell.boss_scene(), _name_label.text, _boss_pos)
	_boss = boss
	_update_stats()


func _clear_all() -> void:
	if _boss and is_instance_valid(_boss):
		_boss.queue_free()
		_boss = null
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
		var boss_hp := -1
		if _boss and is_instance_valid(_boss):
			boss_hp = _boss.get("hp") if _boss.get("hp") != null else -1
		_stats_label.text = "Boss状态：%s · 弹数 %d · 种子 %d" % [
			("运行中 hp=%s" % str(boss_hp)) if boss_hp >= 0 else "无",
			BulletManager.active_bullets.size(), _seed]


func _process(delta: float) -> void:
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新（同管线；双脚本监听）═══

## 难度切换：diff_pick 运行时实时读取 → 立即生效
func _on_diff_changed(idx: int) -> void:
	GameState.selected_difficulty = idx


func _on_hot_toggled(on: bool) -> void:
	_hot_enabled = on
	_toast.show_msg("热更新：开" if on else "热更新：关", Color(0.5, 0.95, 0.6) if on else Color(1, 1, 1, 0.6))


func _rebuild_watch() -> void:
	_watch_paths.clear()
	_watch_mtimes.clear()
	var dirs := {}
	for p in [_move_path, _shoot_path]:
		if p == "":
			continue
		_watch_paths.append(p)
		dirs[p.get_base_dir()] = true
	for d in dirs:
		var da := DirAccess.open(d)
		if da:
			for f in da.get_files():
				if f.ends_with(".gd"):
					var full: String = d.path_join(f)
					if not _watch_paths.has(full):
						_watch_paths.append(full)
	for p in _watch_paths:
		_watch_mtimes[p] = FileAccess.get_modified_time(p)


func _refresh_watch_mtimes() -> void:
	for p in _watch_paths:
		_watch_mtimes[p] = int(FileAccess.get_modified_time(p))


func _process_hot_reload(delta: float) -> void:
	if not _hot_enabled or _watch_paths.is_empty():
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
			_toast.show_msg("＊ 检测到修改…", Color(1, 1, 0.6))
		_hot_dirty_since += HOT_POLL_INTERVAL
		if _hot_dirty_since >= HOT_DEBOUNCE:
			_hot_dirty_since = -1.0
			_do_hot_reload()
	else:
		_hot_dirty_since = -1.0


func _do_hot_reload() -> void:
	var failed := ""
	for p in _watch_paths:
		if not FileAccess.file_exists(p):
			failed = p
			break
		var s: Script = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if s == null:
			failed = p
			break
	if failed != "":
		_toast.show_msg("⚠ 重载失败：%s（旧版继续）" % failed.get_file(), Color(1, 0.4, 0.4))
		_refresh_watch_mtimes()
		_hot_dirty_since = -1.0
		return
	_refresh_watch_mtimes()
	_hot_dirty_since = -1.0
	_rebuild_param_panels()
	_play()  # 重建演出
	_toast.show_msg("＊ 已重载并重开演", Color(0.5, 0.95, 0.6))


# ═══ 场地交互 ═══

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_boss_pos = (event as InputEventMouseButton).position
		_field.queue_redraw()


func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	var p := _boss_pos
	_field.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color(0.7, 0.5, 0.95), 2.0)
	_field.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), Color(0.7, 0.5, 0.95), 2.0)
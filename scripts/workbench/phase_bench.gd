extends "res://scripts/workbench/bench_base.gd"
## 阶段组合台—— 目录选阶段 × 双槽（move/shoot）× 阶段字段（HP/时限）× Boss 视觉
## 运行基于 start_spell_card（符卡练习同款单阶段运行器：自建时钟+ctx+Boss 直进阶段）

const PHASE_SHELL := preload("res://scripts/workbench/phase_shell.gd")
const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const STATUS_TOAST := preload("res://scripts/workbench/status_toast.gd")

const VERSION_TAG := "v1.5"

var _shell: Variant
var _boss_pos := Vector2(GameConfig.FIELD_CENTER_X, 250.0)
var _seed: int = RIG_COMMON.FIXED_SEED
var _boss: Node = null          # 当前 Boss（开演/清场管理）

# ── UI ──
var _phase_sel: OptionButton
var _move_sel: OptionButton
var _shoot_sel: OptionButton
var _hp_spin: SpinBox
var _time_spin: SpinBox
var _diff_sel: OptionButton
var _play_btn: Button
var _clear_btn: Button
var _seed_btn: Button
var _stats_label: Label
var _name_label: Label
var _move_desc: Label
var _shoot_desc: Label
var _hot_chk: CheckBox

var _move_path: String = ""
var _shoot_path: String = ""


func _ready() -> void:
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	get_window().size = Vector2i(1280, 960)
	_shell = PHASE_SHELL.new()
	_catalog = CATALOG.new().scan()
	theme = WORKBENCH_THEME.build()
	build_world()  # 场地+幽灵（rig_base）
	ensure_stage_runtime()  # 自备关卡运行时（开演用）
	_build_ui()
	_toast = STATUS_TOAST.new()
	add_child(_toast)
	_reload_status = _toast.label
	_set_seed(RIG_COMMON.FIXED_SEED)
	_select_phase(0)
	_toast.show_msg("热更新：开", Color(0.5, 0.95, 0.6))


# ═══ 世界 ═══



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
	for entry in _catalog.by_role("phase"):
		var uid: int = entry.extra.get("uid", 0)
		var display: String = entry.name if entry.name != "" else entry.path.get_file()
		if uid > 0:
			display += " · uid" + str(uid)
		_phase_sel.add_item(display)
		_phase_sel.set_item_tooltip(phase_idx, entry.path)
		phase_idx += 1
	_phase_sel.item_selected.connect(_select_phase)
	box.add_child(_phase_sel)
	_name_label = _hint("")
	box.add_child(_name_label)

	box.add_child(RIG_COMMON.section_label("双槽（阶段内 move×shoot）"))
	box.add_child(_hint("移动脚本"))
	_move_sel = OptionButton.new()
	_move_sel.add_item("（空）— Boss 原地")
	_fill_script_options(_move_sel, "boss_move")
	box.add_child(_move_sel)
	_move_desc = _desc_label()
	box.add_child(_move_desc)
	_move_sel.item_selected.connect(_on_slots_changed)
	box.add_child(_hint("弹幕脚本"))
	_shoot_sel = OptionButton.new()
	_shoot_sel.add_item("（空）— 不发弹")
	_fill_script_options(_shoot_sel, "boss_shoot")
	box.add_child(_shoot_sel)
	_shoot_desc = _desc_label()
	box.add_child(_shoot_desc)
	_shoot_sel.item_selected.connect(_on_slots_changed)

	box.add_child(RIG_COMMON.section_label("阶段数值"))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	var hp_lb := _hint("血量")
	hp_lb.custom_minimum_size = Vector2(34, 0)
	hp_row.add_child(hp_lb)
	_hp_spin = _num_spin(100.0, 100000.0, 4000.0)
	_hp_spin.custom_minimum_size = Vector2(110, 0)
	hp_row.add_child(_hp_spin)
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 4)
	var time_lb := _hint("时限(s)")
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
	for difficulty in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(difficulty)
	_diff_sel.selected = SaveData.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	box.add_child(_diff_sel)

	box.add_child(RIG_COMMON.section_label("开发"))
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	box.add_child(_hot_chk)
	box.add_child(_hint("左键=Boss落点 · 鼠标=自机"))

	box.add_child(RIG_COMMON.section_label("操作"))
	var ops := GridContainer.new()
	ops.columns = 3
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
	for button in [_play_btn, _clear_btn, _seed_btn]:
		ops.add_child(button)
	box.add_child(ops)

	_stats_label = _label("")
	box.add_child(_stats_label)


func _num_spin(mn: float, mx: float, val: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = mn
	sp.max_value = mx
	sp.value = val
	return sp


func _fill_script_options(sel: OptionButton, role: String) -> void:
	var idx := 1
	for entry in _catalog.by_role(role):
		sel.add_item(entry.name if entry.name != "" else entry.path.get_file())
		sel.set_item_tooltip(idx, entry.path)
		idx += 1


## 阶段选择：默认槽位/数值取该 .tres 现值
func _select_phase(idx: int) -> void:
	var phases = _catalog.by_role("phase")
	if phases.is_empty() or idx < 0 or idx >= phases.size():
		return
	var entry = phases[idx]
	var phase: PhaseData = load(entry.path)
	if phase == null:
		return
	_hp_spin.value = float(phase.hp)
	_time_spin.value = phase.time_limit
	_name_label.text = "%s · uid=%d · %s" % [phase.name if phase.name != "" else entry.path.get_file(), phase.uid,
		"符卡" if phase.uid != 0 else "非符"]
	# 双槽默认 = 阶段现值；在目录脚本列表中定位
	_move_sel.selected = _script_index("boss_move", phase.move_script)
	_shoot_sel.selected = _script_index("boss_shoot", phase.shoot_script)
	_move_path = phase.move_script.resource_path if phase.move_script else ""
	_shoot_path = phase.shoot_script.resource_path if phase.shoot_script else ""
	_rebuild_watch()
	_update_slot_desc()


func _script_index(role: String, script: Script) -> int:
	if script == null:
		return 0
	var list = _catalog.by_role(role)
	for i in list.size():
		if list[i].path == script.resource_path:
			return i + 1
	return 0


## 槽位手动变更：刷新监听 + 刷新描述
func _on_slots_changed(_index: int) -> void:
	var mv: Script = _resolve_slot(_move_sel, "boss_move")
	var sh: Script = _resolve_slot(_shoot_sel, "boss_shoot")
	_move_path = mv.resource_path if mv else ""
	_shoot_path = sh.resource_path if sh else ""
	_rebuild_watch()
	_update_slot_desc()


## 描述 Label：16 号（同字段标签）+ 弱化金色，与可交互项区分
func _desc_label() -> Label:
	var label := _label("")
	label.modulate = Color(0.82, 0.78, 0.7, 1.0)
	return label


## 刷新两个脚本槽位的描述（来自目录 entry.description = @desc / const META）
func _update_slot_desc() -> void:
	_move_desc.text = "▶ 描述：" + _slot_desc(_move_sel, "boss_move")
	_shoot_desc.text = "▶ 描述：" + _slot_desc(_shoot_sel, "boss_shoot")


## 取某槽位当前选项的描述；无选项/无描述给占位
func _slot_desc(sel: OptionButton, role: String) -> String:
	var index := sel.selected
	if index <= 0:
		return "（无脚本）"
	var list = _catalog.by_role(role)
	if index - 1 >= list.size():
		return ""
	var entry = list[index - 1]
	if entry.description == "":
		return "（无描述）"
	return entry.description


## 双槽 → 当前脚本路径（空=null）
func _resolve_slot(sel: OptionButton, role: String) -> Script:
	var index := sel.selected
	if index <= 0:
		return null
	var list = _catalog.by_role(role)
	if index - 1 >= list.size():
		return null
	return load(list[index - 1].path)


# ═══ 目录直达 / 工作区恢复 ═══

func preset_from_entry(entry) -> void:
	var phases = _catalog.by_role("phase")
	for i in phases.size():
		if phases[i].path == entry.path:
			_phase_sel.selected = i
			_select_phase(i)
			_play()
			return


func snapshot() -> Dictionary:
	var phases = _catalog.by_role("phase")
	var path := ""
	if _phase_sel.selected >= 0 and _phase_sel.selected < phases.size():
		path = phases[_phase_sel.selected].path
	return {
		"phase": path, "seed": _seed, "diff": SaveData.selected_difficulty,
		"hp": _hp_spin.value, "time": _time_spin.value,
		"pos_x": _boss_pos.x, "pos_y": _boss_pos.y,
	}


func restore(data: Dictionary) -> void:
	if data.has("seed"):
		_seed = data.seed
	if data.has("diff"):
		SaveData.selected_difficulty = data.diff
		_diff_sel.selected = int(data.diff)
	if data.has("hp"):
		_hp_spin.value = data.hp
	if data.has("time"):
		_time_spin.value = data.time
	if data.has("pos_x"):
		_boss_pos = Vector2(data.pos_x, data.pos_y)
		_field.queue_redraw()
	if data.has("phase") and str(data.phase) != "":
		var phases = _catalog.by_role("phase")
		for i in phases.size():
			if phases[i].path == str(data.phase):
				_phase_sel.selected = i
				_select_phase(i)
				break


# ═══ 开演 ═══

func _play() -> void:
	var phases = _catalog.by_role("phase")
	if phases.is_empty():
		return
	var idx: int = _phase_sel.selected
	var entry = phases[idx]
	var base: PhaseData = load(entry.path)
	if base == null:
		return
	_clear_all()  # 防叠
	var phase: PhaseData = _shell.build_copy(base, _resolve_slot(_move_sel, "boss_move"),
		_resolve_slot(_shoot_sel, "boss_shoot"), _hp_spin.value, _time_spin.value)
	# 参数：直接用阶段 .tres 自带 params（Boss 把同一字典灌给 move/shoot 两个脚本）
	_move_path = phase.move_script.resource_path if phase.move_script else ""
	_shoot_path = phase.shoot_script.resource_path if phase.shoot_script else ""
	_rebuild_watch()
	RNG.set_seed(_seed)
	var boss := _stage_runtime.start_spell_card(phase, _shell.boss_scene(), _name_label.text, _boss_pos)
	_boss = boss
	_update_stats()


# ═══ 公开接缝（创作台 / 测试；用户操作走的是同一条实现）═══

func _primary_selector() -> OptionButton: return _phase_sel


## 选一张阶段（同步下拉；= 用户在阶段下拉里选）
func select_phase(idx: int) -> void:
	_phase_sel.selected = idx
	_select_phase(idx)


## 开演一次（= 用户按"开演"）
func play() -> void:
	_play()


## 清场（= 用户按"清场"）
func clear_all() -> void:
	_clear_all()


## HP / 时限输入框当前值（开演用的就是它们）
func hp_value() -> float:
	return _hp_spin.value


func time_value() -> float:
	return _time_spin.value


## 双槽当前选中下标（0 = 空槽）
func move_slot_index() -> int:
	return _move_sel.selected


## 设 move/shoot 槽的下标（0 = 空槽；测试与创作台恢复工作区用）
func set_move_slot_index(index: int) -> void:
	_move_sel.selected = index


func set_shoot_slot_index(index: int) -> void:
	_shoot_sel.selected = index


func shoot_slot_index() -> int:
	return _shoot_sel.selected


## 双槽当前解析出的脚本（空槽 → null；开演时用的就是这两个）
func selected_move_script() -> Script:
	return _resolve_slot(_move_sel, "boss_move")


func selected_shoot_script() -> Script:
	return _resolve_slot(_shoot_sel, "boss_shoot")


## 当前阶段的 move 脚本路径（槽里为空 → 空串）
func move_script_path() -> String:
	return _move_path


## Boss 出生点（用户点场地设的那个）
func boss_spawn_pos() -> Vector2:
	return _boss_pos


func set_boss_spawn_pos(pos: Vector2) -> void:
	_boss_pos = pos
	_field.queue_redraw()


## 当前选择对应的 Boss 外观场景（开演时用的就是它）
func boss_scene() -> PackedScene:
	return _shell.boss_scene()


func _clear_all() -> void:
	if _boss and is_instance_valid(_boss):
		_boss.queue_free()
		_boss = null
	_bullet_manager.reset_world()  # 清场 + 回收内核 program/弹型（反复开演会积累）
	_update_stats()


func _set_seed(seed_value: int) -> void:
	_seed = seed_value
	RNG.set_seed(seed_value)


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
			_bullet_manager.active_count(), _seed]


func _process(delta: float) -> void:
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新（同管线；双脚本监听）═══

## 难度切换：diff_pick 运行时实时读取 → 立即生效
func _on_diff_changed(idx: int) -> void:
	SaveData.selected_difficulty = idx
# ═══ 场地交互 ═══

## 左键(游戏坐标) → Boss 落点（rig_base 基类处理坐标换算）
func _on_click(game_pos: Vector2) -> void:
	_boss_pos = game_pos


## Boss 落点标记（紫十字；rig_base 已画金框）
func _draw_marker() -> void:
	var pos := _boss_pos
	_field.draw_line(pos + Vector2(-12, 0), pos + Vector2(12, 0), Color(0.7, 0.5, 0.95), 2.0)
	_field.draw_line(pos + Vector2(0, -12), pos + Vector2(0, 12), Color(0.7, 0.5, 0.95), 2.0)


# ═══ 热更新钩子（管线在 BenchBase）═══

func _collect_watch_paths() -> Array[String]:
	return _with_dir_scripts([_move_path, _shoot_path])


func _on_hot_reloaded(_main_new: Script) -> void:
	_play()  # 重建演出
	_toast.show_msg("＊ 已重载并重开演", Color(0.5, 0.95, 0.6))

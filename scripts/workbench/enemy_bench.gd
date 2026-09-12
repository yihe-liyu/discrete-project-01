extends "res://scripts/workbench/bench_base.gd"
## 敌人组合台（M3a）—— 选行为（脚本）× 设外形（外观/HP/判定/掉落）× 出生点 × 幽灵玩家（鼠标跟随）
## 跑真实 StageRuntime.spawn_enemy_data：敌人移动/发弹/行为脚本全部真实。

const CATALOG := preload("res://scripts/data/content_catalog.gd")
const SHELL := preload("res://scripts/workbench/enemy_shell.gd")
const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const PARAM_PANEL := preload("res://scripts/workbench/param_panel.gd")
const STATUS_TOAST := preload("res://scripts/workbench/status_toast.gd")

const FIXED_SEED := 20260801
const HOT_POLL_INTERVAL := 0.5
const HOT_DEBOUNCE := 0.8
const VERSION_TAG := "v1.7-ui"

var _shell: Variant
var _catalog: Variant
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
var _life_full_spin: SpinBox
var _bomb_full_spin: SpinBox
var _spawn_btn: Button
var _clear_btn: Button
var _seed_btn: Button
var _stats_label: Label
var _reload_status: Label
var _toast: Control
var _diff_sel: OptionButton
var _param_panel: VBoxContainer  # 共享参数面板（param_panel.gd）
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
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	get_window().size = Vector2i(1280, 960)
	sync_world_offset()  # 见 rig_base：页面偏移记入（游戏坐标换算用）
	_shell = SHELL.new()
	_catalog = CATALOG.new().scan()
	theme = WORKBENCH_THEME.build()
	build_world()  # 场地+幽灵（rig_base）
	ensure_stage_runtime()  # W3b-2：自备关卡运行时（生成敌人用）
	_build_ui()
	_toast = STATUS_TOAST.new()
	add_child(_toast)
	_reload_status = _toast.label
	_set_seed(FIXED_SEED)
	_set_current_script()
	_param_panel.rebuild(_cur_script)
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

	box.add_child(RIG_COMMON.section_label("敌人组合台 %s" % VERSION_TAG))

	box.add_child(RIG_COMMON.section_label("行为脚本"))
	_script_sel = OptionButton.new()
	_script_sel.add_item("（无）移动")
	var idx := 0
	for e in _catalog.by_role("enemy"):
		_script_sel.add_item(e.name if e.name != "" else e.path.get_file())
		_script_sel.set_item_tooltip(idx + 1, e.path)
		idx += 1
	_script_sel.item_selected.connect(_on_script_changed)
	box.add_child(_script_sel)

	box.add_child(RIG_COMMON.section_label("难度（即时生效）"))
	_diff_sel = OptionButton.new()
	for d in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(d)
	_diff_sel.selected = SaveData.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	box.add_child(_diff_sel)

	box.add_child(RIG_COMMON.section_label("外形/属性"))
	box.add_child(_label("外观"))
	_visual_sel = OptionButton.new()
	for k in SHELL.visual_keys():
		_visual_sel.add_item(k)
	box.add_child(_visual_sel)
	box.add_child(_label("HP · 判定半径"))
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
	box.add_child(_label("掉落（P/点/残/雷/整残/整B）"))
	var drops := GridContainer.new()
	drops.columns = 2
	drops.add_theme_constant_override("h_separation", 8)
	drops.add_theme_constant_override("v_separation", 2)
	_power_spin = _drop_spin(2.0)
	_point_spin = _drop_spin(0.0)
	_life_spin = _drop_spin(0.0)
	_bomb_spin = _drop_spin(0.0)
	_life_full_spin = _drop_spin(0.0)
	_bomb_full_spin = _drop_spin(0.0)
	for pair in [["P", _power_spin], ["点", _point_spin], ["残", _life_spin], ["雷", _bomb_spin], ["整残", _life_full_spin], ["整B", _bomb_full_spin]]:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 6)
		var lb := _hint(pair[0])
		lb.custom_minimum_size = Vector2(34, 0)
		cell.add_child(lb)
		cell.add_child(pair[1])
		drops.add_child(cell)
	box.add_child(drops)

	_param_panel = PARAM_PANEL.new()
	box.add_child(_param_panel)

	box.add_child(RIG_COMMON.section_label("开发"))
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	box.add_child(_hot_chk)
	box.add_child(_hint("左键=出生点 · 鼠标=自机"))

	box.add_child(RIG_COMMON.section_label("操作"))
	var ops := GridContainer.new()
	ops.columns = 3
	ops.add_theme_constant_override("h_separation", 8)
	ops.add_theme_constant_override("v_separation", 4)
	_spawn_btn = RIG_COMMON.accent_button("生成")
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

	_stats_label = _label("")
	box.add_child(_stats_label)


func _drop_spin(v: float) -> SpinBox:
	var sp := SpinBox.new()
	sp.min_value = 0.0
	sp.max_value = 99.0
	sp.value = v
	sp.custom_minimum_size = Vector2(70, 0)
	return sp


# ═══ 目录直达 / 工作区恢复 ═══

func _preset_from_entry(entry) -> void:
	var list = _catalog.by_role("enemy")
	for i in list.size():
		if list[i].path == entry.path:
			_script_sel.selected = i + 1
			_on_script_changed(i + 1)
			_spawn()
			return


func _snapshot() -> Dictionary:
	return {
		"script": _cur_script_path, "seed": _seed, "diff": SaveData.selected_difficulty,
		"visual": _shell.visual_key, "hp": _shell.max_hp, "pos_x": _spawn_pos.x, "pos_y": _spawn_pos.y,
	}


func _restore(d: Dictionary) -> void:
	if d.has("seed"):
		_seed = d.seed
	if d.has("diff"):
		SaveData.selected_difficulty = d.diff
		_diff_sel.selected = int(d.diff)
	if d.has("visual"):
		_shell.visual_key = d.visual
		for i in _visual_sel.item_count:
			if _visual_sel.get_item_text(i) == d.visual:
				_visual_sel.selected = i
				break
	if d.has("hp"):
		_shell.max_hp = int(d.hp)
		_hp_spin.value = d.hp
	if d.has("pos_x"):
		_spawn_pos = Vector2(d.pos_x, d.pos_y)
		_field.queue_redraw()
	if d.has("script") and str(d.script) != "":
		var list = _catalog.by_role("enemy")
		for i in list.size():
			if list[i].path == str(d.script):
				_script_sel.selected = i + 1
				_on_script_changed(i + 1)
				break


# ═══ 生成 ═══

func _spawn() -> void:
	_shell.visual_key = _visual_sel.get_item_text(_visual_sel.selected)
	_shell.max_hp = int(_hp_spin.value)
	_shell.hitbox_radius = _hbox_spin.value
	_shell.item_power = int(_power_spin.value)
	_shell.item_point = int(_point_spin.value)
	_shell.item_life = int(_life_spin.value)
	_shell.item_bomb = int(_bomb_spin.value)
	_shell.item_life_full = int(_life_full_spin.value)
	_shell.item_bomb_full = int(_bomb_full_spin.value)
	var data: EnemyData = _shell.build(_cur_script)
	# 参数注入（与游戏 params 同路径：ParamValidator.apply 同名 var 注入）
	# 注意：for-in 字典迭代的是键（GDScript 语义）
	var params = _param_panel.collect()
	for k in params:
		data.param(k, params[k])
	data.pos(_spawn_pos)
	RNG.set_seed(_seed)
	_stage_runtime.spawn_enemy_data(data, BulletManager.current.get_bullet_ctx())
	_update_stats()

func _clear_all() -> void:
	for e in _stage_runtime.refs.get_active_enemies():
		if is_instance_valid(e):
			e.queue_free()
	BulletManager.current.clear_all()
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
			_stage_runtime.refs.get_active_enemies().size(), BulletManager.current.active_count(), _seed]


func _process(delta: float) -> void:
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新（同 M2 管线）═══

func _on_script_changed(_idx: int) -> void:
	_set_current_script()
	_param_panel.rebuild(_cur_script)
	_toast.show_msg("行为：%s" % (_cur_script_path.get_file() if _cur_script_path != "" else "（无移动）"), Color(1, 1, 1, 0.85))


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

func _on_diff_changed(idx: int) -> void:
	SaveData.selected_difficulty = idx
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
	_toast.show_msg("热更新：开" if on else "热更新：关", Color(0.5, 0.95, 0.6) if on else Color(1, 1, 1, 0.6))


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
			_toast.show_msg("＊ 检测到修改…", Color(1, 1, 0.6))
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
		_toast.show_msg("⚠ 重载失败：%s（旧版继续）" % failed.get_file(), Color(1, 0.4, 0.4))
		_refresh_watch_mtimes()
		_hot_dirty_since = -1.0
		return
	_cur_script = main_new
	_refresh_watch_mtimes()
	_hot_dirty_since = -1.0
	_param_panel.rebuild(_cur_script)  # 新脚本可能新增/改名参数 → 面板同步
	_clear_all()
	RNG.set_seed(_seed)
	_spawn()
	_toast.show_msg("＊ 已重载：%s" % _cur_script_path.get_file(), Color(0.5, 0.95, 0.6))


# ═══ 场地交互 ═══

## 左键(游戏坐标) → 出生点（rig_base 基类处理坐标换算）
func _on_click(game_pos: Vector2) -> void:
	_spawn_pos = game_pos


## 出生点标记（橙十字；rig_base 已画金框）
func _draw_marker() -> void:
	var p := from_game(_spawn_pos)
	_field.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color(1, 0.6, 0.2), 2.0)
	_field.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), Color(1, 0.6, 0.2), 2.0)

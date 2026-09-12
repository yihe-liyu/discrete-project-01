extends "res://scripts/workbench/bench_base.gd"
## 弹幕试验台（M2a）—— 选行为（脚本）× 换外形（贴图/染色/初速/方向）× 发射点 × 幽灵玩家（鼠标跟随）
## 跑真实 BulletManager：子弹飞行/碰撞/擦弹/自定义行为 全部真实；所见即最终效果。
## 快捷键：F=发射 · C=清场 · 点击场地=设发射点

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const PARAM_PANEL := preload("res://scripts/workbench/param_panel.gd")
const STATUS_TOAST := preload("res://scripts/workbench/status_toast.gd")  # WorkbenchTheme 构建器
const CATALOG := preload("res://scripts/data/content_catalog.gd")
const SHELL := preload("res://scripts/workbench/bullet_shell.gd")

const FIXED_SEED := 20260801
## 标题版本号：每次改版递增；截图对照可立刻确认运行的是不是最新脚本
const VERSION_TAG := "v3.4-ui"

## 热更新：mtime 轮询间隔 + 修改稳定防抖（保存后不再变化才算完成）
const HOT_POLL_INTERVAL := 0.5
const HOT_DEBOUNCE := 0.8

var _shell: Variant      # BulletShell（preload 构造，规避新 class 全局缓存）
var _catalog: Variant    # ContentCatalog
var _emitter_pos := Vector2(GameConfig.FIELD_CENTER_X, 300.0)
var _seed: int = FIXED_SEED
var _burst_left := 0.0

# ── UI ──
var _script_sel: OptionButton
var _tex_sel: OptionButton
var _color_btn: ColorPickerButton
var _blend_chk: CheckBox
var _speed_spin: SpinBox
var _dir_sel: OptionButton
var _fire_btn: Button
var _burst_chk: CheckBox
var _interval_spin: SpinBox
var _clear_btn: Button
var _seed_btn: Button
var _stats_label: Label
var _dir_angle_label: Label
var _param_panel: VBoxContainer

var _reload_status: Label
var _toast: Control

var _hot_chk: CheckBox
var _diff_sel: OptionButton

# ── 热更新状态 ──
var _cur_script: Script = null          # 当前行为脚本（发射用它；热重载后替换）
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
	# 关键：用工作台同款主题——项目全局 ui_theme 字体大，面板会被内容撑爆（513>432）
	theme = WORKBENCH_THEME.build()
	build_world()  # 场地+幽灵（rig_base）
	_build_ui()
	_toast = STATUS_TOAST.new()
	add_child(_toast)
	_reload_status = _toast.label   # 统一右下角浮动状态条（原面板状态行）
	_set_seed(FIXED_SEED)
	_refresh_dir_label()
	_set_current_script()
	_param_panel.rebuild(_cur_script)
	_toast.show_msg("热更新：开", Color(0.5, 0.95, 0.6))


# ═══ 世界 ═══

# ═══ UI ═══

func _build_ui() -> void:
	# 面板：与工作台 RightPanel 同款——【显式】右锚(1,0)+负偏移(-440..-8, 8..952)
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -440.0
	panel.offset_top = 8.0
	panel.offset_right = -8.0
	panel.offset_bottom = -8.0
	# 与游戏页面统一：半透明黑底 + 金边卡片（rig_common 单一来源）
	panel.add_theme_stylebox_override("panel", RIG_COMMON.panel_style())
	add_child(panel)
	# 内部滚动：未来加字段也不会裁内容
	var panel_scroll := ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	panel_scroll.add_child(box)

	box.add_child(RIG_COMMON.section_label("弹幕组合台 %s" % VERSION_TAG))
	box.add_child(RIG_COMMON.section_label("行为脚本"))

	_script_sel = OptionButton.new()
	_script_sel.add_item("（无）直线弹")
	# 注意：选项只放短名（OptionButton 最小宽=最长选项宽；文件名后缀曾把面板顶到 469）
	var script_idx := 0
	for e in _catalog.by_role("bullet"):
		var item_text: String = e.name if e.name != "" else e.path.get_file()
		_script_sel.add_item(item_text)
		_script_sel.set_item_tooltip(script_idx + 1, e.path)
		script_idx += 1
	_script_sel.selected = 0
	_script_sel.item_selected.connect(_on_script_changed)
	box.add_child(_script_sel)

	box.add_child(RIG_COMMON.section_label("难度（即时生效）"))
	_diff_sel = OptionButton.new()
	for d in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(d)
	_diff_sel.selected = SaveData.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	box.add_child(_diff_sel)

	box.add_child(RIG_COMMON.section_label("外形"))

	box.add_child(_label("贴图（含判定）"))
	_tex_sel = OptionButton.new()
	var tex_idx := 0
	for key in AssetRegistry.bullet_configs:
		_tex_sel.add_item(key)
		var hb: Dictionary = AssetRegistry.bullet_configs[key].get("hitbox", {})
		if hb.has("circle"):
			_tex_sel.set_item_tooltip(tex_idx, "判定：圆 %s px" % str(hb["circle"]))
		elif hb.has("rect"):
			var rr: Dictionary = hb["rect"]
			_tex_sel.set_item_tooltip(tex_idx, "判定：矩形 %s×%s" % [str(rr.get("w", 0)), str(rr.get("h", 0))])
		tex_idx += 1
	box.add_child(_tex_sel)

	box.add_child(_label("染色"))
	_color_btn = ColorPickerButton.new()
	_color_btn.color = Color.WHITE
	_color_btn.text = "染色"
	box.add_child(_color_btn)

	_blend_chk = CheckBox.new()
	_blend_chk.text = "加色混合"
	box.add_child(_blend_chk)

	box.add_child(_label("初速（px/s）"))
	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 10.0
	_speed_spin.max_value = 4000.0
	_speed_spin.step = 5.0
	_speed_spin.value = 300.0
	_speed_spin.custom_minimum_size = Vector2(160, 0)
	_speed_spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(_speed_spin)

	box.add_child(_label("方向（右键=指向）"))
	_dir_sel = OptionButton.new()
	_dir_sel.add_item("自选（右键场地）")
	for d in SHELL.DIR_NAMES:
		_dir_sel.add_item(d)
	_dir_sel.item_selected.connect(_on_dir_preset)
	box.add_child(_dir_sel)
	_dir_angle_label = _hint("")
	box.add_child(_dir_angle_label)

	_param_panel = PARAM_PANEL.new()
	box.add_child(_param_panel)

	box.add_child(RIG_COMMON.section_label("开发"))
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	box.add_child(_hot_chk)
	box.add_child(_hint("左键=发射点 · 右键=指向 · 鼠标=自机"))

	box.add_child(RIG_COMMON.section_label("操作"))

	# 操作按钮 2×2 网格：横排 4 个会把面板最小宽顶爆（489>432）
	var ops := GridContainer.new()
	ops.columns = 2
	ops.add_theme_constant_override("h_separation", 8)
	ops.add_theme_constant_override("v_separation", 4)
	_fire_btn = RIG_COMMON.accent_button("发射")
	_fire_btn.pressed.connect(_fire)
	_burst_chk = CheckBox.new()
	_burst_chk.text = "连发"
	_clear_btn = Button.new()
	_clear_btn.text = "清场"
	_clear_btn.pressed.connect(_clear_all)
	_seed_btn = Button.new()
	_seed_btn.text = "换种子"
	_seed_btn.pressed.connect(_next_seed)
	for c in [_fire_btn, _burst_chk, _clear_btn, _seed_btn]:
		ops.add_child(c)
	box.add_child(ops)

	var itv := HBoxContainer.new()
	itv.add_theme_constant_override("separation", 8)
	itv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var itv_label := _label("间隔")
	itv_label.custom_minimum_size = Vector2(36, 0)
	itv.add_child(itv_label)
	_interval_spin = SpinBox.new()
	_interval_spin.min_value = 0.05
	_interval_spin.max_value = 2.0
	_interval_spin.step = 0.05
	_interval_spin.value = 0.5
	_interval_spin.custom_minimum_size = Vector2(140, 0)
	itv.add_child(_interval_spin)
	box.add_child(itv)

	_stats_label = _label("")
	box.add_child(_stats_label)


# ═══ 目录直达 / 工作区恢复 ═══

## 目录双击直达：自动选脚本 + 重建参数 + 立即发射
func preset_from_entry(entry) -> void:
	var list = _catalog.by_role("bullet")
	for i in list.size():
		if list[i].path == entry.path:
			_script_sel.selected = i + 1
			_on_script_changed(i + 1)
			_fire()
			return


func snapshot() -> Dictionary:
	return {
		"script": _cur_script_path, "seed": _seed,
		"diff": SaveData.selected_difficulty,
		"tex": _shell.tex_key, "tint": _shell.tint, "speed": _shell.speed,
	}


func restore(d: Dictionary) -> void:
	if d.has("seed"):
		_seed = d.seed
	if d.has("diff"):
		SaveData.selected_difficulty = d.diff
		_diff_sel.selected = int(d.diff)
	if d.has("tex"):
		_shell.tex_key = d.tex
		for i in _tex_sel.item_count:
			if _tex_sel.get_item_text(i) == d.tex:
				_tex_sel.selected = i
				break
	if d.has("tint"):
		_shell.tint = d.tint
		_color_btn.color = d.tint
	if d.has("speed"):
		_shell.speed = d.speed
		_speed_spin.value = d.speed
	if d.has("script") and str(d.script) != "":
		var list = _catalog.by_role("bullet")
		for i in list.size():
			if list[i].path == str(d.script):
				_script_sel.selected = i + 1
				_on_script_changed(i + 1)
				break
	_refresh_dir_label()


# ═══ 发射 ═══

func _fire() -> void:
	_shell.tex_key = _tex_sel.get_item_text(_tex_sel.selected)
	_shell.tint = _color_btn.color
	_shell.blend = _blend_chk.button_pressed
	_shell.speed = _speed_spin.value
	var data: BulletData = _shell.build(_cur_script)
	data.params = _param_panel.collect()
	BulletManager.current.shoot_enemy_bullet(data, _emitter_pos, _shell.get_dir())
	_update_stats()


func _clear_all() -> void:
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
		_stats_label.text = "场上弹数：%d · 种子：%d" % [BulletManager.current.active_count(), _seed]


func _process(delta: float) -> void:
	if _burst_chk and _burst_chk.button_pressed:
		_burst_left -= delta
		if _burst_left <= 0.0:
			_burst_left = _interval_spin.value
			_fire()
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新（M2b）：保存脚本 → 自动重载重演 ═══

func _on_script_changed(_idx: int) -> void:
	_set_current_script()
	_param_panel.rebuild(_cur_script)
	_toast.show_msg("行为：%s" % (_cur_script_path.get_file() if _cur_script_path != "" else "（直线弹）"), Color(1, 1, 1, 0.85))


func _set_current_script() -> void:
	var idx := _script_sel.selected
	if idx <= 0:
		_cur_script = null
		_cur_script_path = ""
	else:
		var entry = _catalog.by_role("bullet")[idx - 1]
		_cur_script_path = entry.path
		_cur_script = load(_cur_script_path)
	_rebuild_watch()


## 监听集：主脚本 + 同目录全部 .gd（A preload B 时，只重载 B 无效 → 连坐）
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


## 重载完成后刷新监听基线（避免同一改动反复触发）
func _refresh_watch_mtimes() -> void:
	for p in _watch_paths:
		_watch_mtimes[p] = int(FileAccess.get_modified_time(p))


## 难度切换：diff_pick 运行时实时读取 → 立即生效
func _on_diff_changed(idx: int) -> void:
	SaveData.selected_difficulty = idx


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
			# 注意：检测期间【不】更新基线！更新会把防抖清零导致永不重载；重载完成后统一刷新
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


## 连坐重载 + 重建演出；解析失败 → 旧版继续 + 红条
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
	_param_panel.rebuild(_cur_script)  # 脚本参数变更同步
	BulletManager.current.clear_all()
	RNG.set_seed(_seed)
	_fire()
	_toast.show_msg("＊ 已重载：%s" % _cur_script_path.get_file(), Color(0.5, 0.95, 0.6))


# ═══ 场地交互 ═══

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos := (event as InputEventMouseButton).position + _world_offset  # 场地局部 → 游戏坐标
		if event.button_index == MOUSE_BUTTON_LEFT:
			_emitter_pos = pos
			_field.queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# 右键：从发射点指向点击处（任意角度）
			var delta := pos - _emitter_pos
			if delta.length() > 10.0:
				_shell.dir = delta.normalized()
				_dir_sel.selected = 0  # 跳到"自选"
				_refresh_dir_label()
				_field.queue_redraw()


## 8 方位预设选择（index>=1 = 预设；item 0 = 自选，仅在右键时显示）
func _on_dir_preset(idx: int) -> void:
	if idx > 0:
		_shell.dir = SHELL.preset(idx - 1)
		_refresh_dir_label()
		_field.queue_redraw()


func _refresh_dir_label() -> void:
	if _dir_angle_label:
		_dir_angle_label.text = "%s · %s" % [SHELL.dir_name(_shell.dir), SHELL.angle_text(_shell.dir)]


func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP - _world_offset.y,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	var p := _emitter_pos - _world_offset
	_field.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color(1, 0.85, 0.3), 2.0)
	_field.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), Color(1, 0.85, 0.3), 2.0)
	# 发射方向箭头（绿色，从发射点指向）
	if _shell and _shell.dir.length() > 0.001:
		var d: Vector2 = _shell.dir
		var tip := p + d * 56.0
		_field.draw_line(p, tip, Color(0.35, 0.95, 0.45), 2.0)
		var side := d.rotated(2.6) * 10.0
		_field.draw_line(tip, tip + side, Color(0.35, 0.95, 0.45), 2.0)
		_field.draw_line(tip, tip + _shell.dir.rotated(-2.6) * 10.0, Color(0.35, 0.95, 0.45), 2.0)

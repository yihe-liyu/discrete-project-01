extends "res://scripts/workbench/bench_base.gd"
## 弹幕试验台—— 选行为（脚本）× 换外形（贴图/染色/初速/方向）× 发射点 × 幽灵玩家（鼠标跟随）
## 跑真实 BulletManager：子弹飞行/碰撞/擦弹/自定义行为 全部真实；所见即最终效果。
## 快捷键：F=发射 · C=清场 · 点击场地=设发射点

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const PARAM_PANEL := preload("res://scripts/workbench/param_panel.gd")
const STATUS_TOAST := preload("res://scripts/workbench/status_toast.gd")  # WorkbenchTheme 构建器
const SHELL := preload("res://scripts/workbench/bullet_shell.gd")
const COMPOSER_PANEL := preload("res://scripts/workbench/composer_panel.gd")

## 标题版本号：每次改版递增；截图对照可立刻确认运行的是不是最新脚本
const VERSION_TAG := "v3.5-ui"


var _shell: Variant      # BulletShell（preload 构造，规避新 class 全局缓存）
var _emitter_pos := Vector2(GameConfig.FIELD_CENTER_X, 300.0)
var _seed: int = RIG_COMMON.FIXED_SEED
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
var _mode_sel: OptionButton
var _direct_box: VBoxContainer
var _composer_panel
var _has_legacy_scripts: bool = false
var _behavior_label: Label
var _dev_label: Label
var _dev_hint: Label


var _hot_chk: CheckBox
var _diff_sel: OptionButton



func _ready() -> void:
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	if not _embedded:
		get_window().size = Vector2i(1280, 960)
	_shell = SHELL.new()
	_catalog = CATALOG.new().scan()
	# 关键：用工作台同款主题——项目全局 ui_theme 字体大，面板会被内容撑爆（513>432）
	theme = WORKBENCH_THEME.build()
	build_world()  # 场地+幽灵（rig_base）
	_build_ui()
	_toast = STATUS_TOAST.new()
	add_child(_toast)
	_reload_status = _toast.label   # 统一右下角浮动状态条（原面板状态行）
	_set_seed(RIG_COMMON.FIXED_SEED)
	_refresh_dir_label()
	_set_current_script()
	_param_panel.rebuild(_cur_script)
	if _has_legacy_scripts:
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
	var mode_row := HBoxContainer.new()
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.add_theme_constant_override("separation", 6)
	var mode_lb := RIG_COMMON.label("模式", RIG_COMMON.HINT_SIZE)
	mode_lb.custom_minimum_size = Vector2(40, 0)
	mode_row.add_child(mode_lb)
	_mode_sel = OptionButton.new()
	_mode_sel.add_item("直射")
	_mode_sel.add_item("拼装")
	_mode_sel.selected = 0
	_mode_sel.item_selected.connect(_on_mode_changed)
	mode_row.add_child(_mode_sel)
	box.add_child(mode_row)
	_direct_box = VBoxContainer.new()
	_direct_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_direct_box.add_theme_constant_override("separation", 6)
	box.add_child(_direct_box)
	var direct := _direct_box
	_has_legacy_scripts = _catalog.by_role("bullet").size() > 0
	direct.add_child(RIG_COMMON.hint_label("弹道形状在「拼装」页编辑；这里只调发射的这颗"))
	_behavior_label = RIG_COMMON.section_label("旧行为脚本（兼容）")
	direct.add_child(_behavior_label)

	_script_sel = OptionButton.new()
	_script_sel.add_item("（无）直线弹")
	# 注意：选项只放短名（OptionButton 最小宽=最长选项宽；文件名后缀曾把面板顶到 469）
	var script_idx := 0
	for entry in _catalog.by_role("bullet"):
		var item_text: String = entry.name if entry.name != "" else entry.path.get_file()
		_script_sel.add_item(item_text)
		_script_sel.set_item_tooltip(script_idx + 1, entry.path)
		script_idx += 1
	_script_sel.selected = 0
	_script_sel.item_selected.connect(_on_script_changed)
	direct.add_child(_script_sel)

	# 难度：一行，和初始弹的紧凑行同风格
	var diff_row := HBoxContainer.new()
	diff_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_theme_constant_override("separation", 6)
	var diff_lb := _label("难度", RIG_COMMON.HINT_SIZE)
	diff_lb.custom_minimum_size = Vector2(40, 0)
	diff_row.add_child(diff_lb)
	_diff_sel = OptionButton.new()
	_diff_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for difficulty in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(difficulty)
	_diff_sel.selected = SaveData.selected_difficulty
	_diff_sel.item_selected.connect(_on_diff_changed)
	diff_row.add_child(_diff_sel)
	direct.add_child(diff_row)

	direct.add_child(RIG_COMMON.section_label("初始弹（发射的这颗）"))

	# 外观：贴图 / 染色 / 加色 / 速度 一行（同拼装页的初始弹）
	var app_row := HBoxContainer.new()
	app_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app_row.add_theme_constant_override("separation", 4)
	var app_lb := _label("外观", RIG_COMMON.HINT_SIZE)
	app_lb.custom_minimum_size = Vector2(40, 0)
	app_row.add_child(app_lb)

	_tex_sel = OptionButton.new()
	_tex_sel.fit_to_longest_item = false
	_tex_sel.custom_minimum_size = Vector2(100, 0)
	var tex_idx := 0
	for key in BulletCatalog.keys():
		_tex_sel.add_item(key)
		var bt: BulletDef = BulletCatalog.find(key)
		if bt.hitbox_size == Vector2.ZERO:
			_tex_sel.set_item_tooltip(tex_idx, "判定：圆 %s px" % str(bt.hitbox_radius))
		else:
			_tex_sel.set_item_tooltip(tex_idx, "判定：矩形 %s×%s" % [str(bt.hitbox_size.x), str(bt.hitbox_size.y)])
		tex_idx += 1
	app_row.add_child(_tex_sel)

	_color_btn = ColorPickerButton.new()
	_color_btn.color = Color.WHITE
	_color_btn.text = "色"
	_color_btn.custom_minimum_size = Vector2(36, 0)
	app_row.add_child(_color_btn)

	_blend_chk = CheckBox.new()
	_blend_chk.text = "加色"
	app_row.add_child(_blend_chk)

	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 10.0
	_speed_spin.max_value = 4000.0
	_speed_spin.step = 5.0
	_speed_spin.value = 300.0
	_speed_spin.custom_minimum_size = Vector2(64, 0)
	_speed_spin.tooltip_text = "初速 px/s"
	app_row.add_child(_speed_spin)
	direct.add_child(app_row)

	# 方向：一行，自选/8 方位；场地右键仍可指向
	var dir_row := HBoxContainer.new()
	dir_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dir_row.add_theme_constant_override("separation", 6)
	var dir_lb := _label("方向", RIG_COMMON.HINT_SIZE)
	dir_lb.custom_minimum_size = Vector2(40, 0)
	dir_row.add_child(dir_lb)
	_dir_sel = OptionButton.new()
	_dir_sel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dir_sel.add_item("自选（右键场地）")
	for dir_name in SHELL.DIR_NAMES:
		_dir_sel.add_item(dir_name)
	_dir_sel.item_selected.connect(_on_dir_preset)
	dir_row.add_child(_dir_sel)
	direct.add_child(dir_row)
	_dir_angle_label = _hint("")
	direct.add_child(_dir_angle_label)

	_param_panel = PARAM_PANEL.new()
	direct.add_child(_param_panel)

	_dev_label = RIG_COMMON.section_label("旧行为脚本 / 热更新")
	direct.add_child(_dev_label)
	_hot_chk = CheckBox.new()
	_hot_chk.text = "热更新"
	_hot_chk.button_pressed = true
	_hot_chk.toggled.connect(_on_hot_toggled)
	direct.add_child(_hot_chk)
	_dev_hint = _hint("左键=发射点 · 右键=指向 · 鼠标=自机")
	direct.add_child(_dev_hint)



	if not _has_legacy_scripts:
		_behavior_label.visible = false
		_script_sel.visible = false
		_param_panel.visible = false
		_dev_label.visible = false
		_hot_chk.visible = false


	_composer_panel = COMPOSER_PANEL.new()
	_composer_panel.setup(_composer_spawn, _composer_base_spec, _apply_composer_base)
	_composer_panel.preview_requested.connect(_on_composer_preview)
	_composer_panel.difficulty_changed.connect(_on_composer_difficulty)
	_composer_panel.status.connect(_on_composer_status)
	_composer_panel.visible = false
	box.add_child(_composer_panel)

	# 操作底栏：直射/拼装共用（连发/清场/种子状态一致）
	var ops_parent := VBoxContainer.new()
	ops_parent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ops_parent.add_theme_constant_override("separation", 6)
	box.add_child(ops_parent)

	ops_parent.add_child(RIG_COMMON.section_label("操作"))

	# 操作按钮一行：紧凑化后 4 个按钮总宽已能放进 432；每键均分剩余宽。
	var ops := HBoxContainer.new()
	ops.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ops.add_theme_constant_override("separation", 6)
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
	for button in [_fire_btn, _burst_chk, _clear_btn, _seed_btn]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ops.add_child(button)
	ops_parent.add_child(ops)

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
	ops_parent.add_child(itv)

	_stats_label = _label("")
	ops_parent.add_child(_stats_label)
	# 操作栏常驻在模式行下方：拼装页也能直接发射/连发/清场/换种子，不必滚到代码框下面。
	box.move_child(ops_parent, 2)


# ═══ 拼装页接线 ═══

func _on_mode_changed(index: int) -> void:
	var composing := index == 1
	if _direct_box != null:
		_direct_box.visible = not composing
	if _composer_panel != null:
		_composer_panel.visible = composing
		if composing:
			_sync_shell_from_direct()
			_composer_panel.refresh_base_ui()


func _composer_spawn() -> Variant:
	return _shell.build(null)


## 拼装页“初始弹”外观 → 当前 shell；同时同步直射控件，避免切回直射时被旧值覆盖。
func _composer_base_spec() -> Dictionary:
	var dir_index := -1
	for i in SHELL.DIR_NAMES.size():
		if SHELL.dir_dot(_shell.dir, SHELL.preset(i)) > 0.999:
			dir_index = i
			break
	return {
		"tex": _shell.tex_key, "tint": _shell.tint, "blend": _shell.is_blend,
		"speed": _shell.speed, "dir_index": dir_index,
	}


func _apply_composer_base(spec: Dictionary) -> void:
	_shell.tex_key = str(spec.get("tex", _shell.tex_key))
	_shell.tint = spec.get("tint", _shell.tint)
	_shell.is_blend = bool(spec.get("blend", _shell.is_blend))
	_shell.speed = float(spec.get("speed", _shell.speed))
	var dir_index := int(spec.get("dir_index", -1))
	if dir_index >= 0:
		_shell.dir = SHELL.preset(dir_index)
		if _dir_sel != null:
			_dir_sel.selected = dir_index + 1
		_refresh_dir_label()
	# 直射页的控件也同步：否则切回直射发射会拿旧 tex/color/speed 覆盖。
	if _tex_sel != null:
		for i in _tex_sel.item_count:
			if _tex_sel.get_item_text(i) == _shell.tex_key:
				_tex_sel.selected = i
				break
	if _color_btn != null:
		_color_btn.color = _shell.tint
	if _blend_chk != null:
		_blend_chk.button_pressed = _shell.is_blend
	if _speed_spin != null:
		_speed_spin.value = _shell.speed


func _on_composer_preview(lifecycle: BulletLifecycle) -> void:
	_launch_lifecycle(lifecycle)


func _on_composer_difficulty(index: int) -> void:
	_diff_sel.selected = index
	SaveData.selected_difficulty = index


func _on_composer_status(text: String, color: Color) -> void:
	if _toast != null:
		_toast.show_msg(text, color)

# ═══ 目录直达 / 工作区恢复 ═══

## 目录双击直达：自动选脚本 + 重建参数 + 立即发射
func preset_from_entry(entry) -> void:
	# 描述符目录组：切拼装页，把该 Move/Until/Action 加到当前相位。
	if entry.role == "descriptor" or entry.extra.has("descriptor_kind"):
		set_composer_mode(true)
		_composer_panel.add_op(
			StringName(entry.extra.get("descriptor_kind", &"")),
			StringName(entry.extra.get("descriptor_id", &"")))
		return
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
		"dir": _shell.dir,
		"mode": _mode_sel.selected, "composer": _composer_panel.dump(),
	}


func restore(data: Dictionary) -> void:
	if data.has("seed"):
		_seed = data.seed
	if data.has("diff"):
		SaveData.selected_difficulty = data.diff
		_diff_sel.selected = int(data.diff)
	if data.has("tex"):
		_shell.tex_key = data.tex
		for i in _tex_sel.item_count:
			if _tex_sel.get_item_text(i) == data.tex:
				_tex_sel.selected = i
				break
	if data.has("tint"):
		_shell.tint = data.tint
		_color_btn.color = data.tint
	if data.has("speed"):
		_shell.speed = data.speed
		_speed_spin.value = data.speed
	if data.has("script") and str(data.script) != "":
		var list = _catalog.by_role("bullet")
		for i in list.size():
			if list[i].path == str(data.script):
				_script_sel.selected = i + 1
				_on_script_changed(i + 1)
				break
	if data.has("dir"):
		_shell.dir = data.dir
		_refresh_dir_label()
	if data.has("composer"):
		_composer_panel.load_from(data.composer)
	if data.has("mode"):
		set_composer_mode(int(data.mode) == 1)
	_refresh_dir_label()


# ═══ 发射 ═══

func _fire() -> void:
	if _mode_sel != null and _mode_sel.selected == 1:
		_launch_lifecycle(_composer_panel.preview_lifecycle())
		return
	_sync_shell_from_direct()
	var data: BulletData = _shell.build(_cur_script)
	# 直射模式若没有脚本，必须清掉拼装页可能留在同一个缓存实例上的 lifecycle
	if _cur_script == null:
		data.lifecycle = null
	data.params = _param_panel.collect()
	_bullet_manager.shoot_bullet(data, _emitter_pos, _shell.get_dir())
	_update_stats()


## 拼装页发射：外形取当前 shell，弹道用 composer 生成的 lifecycle。
func _sync_shell_from_direct() -> void:
	if _tex_sel == null:
		return
	_shell.tex_key = _tex_sel.get_item_text(_tex_sel.selected)
	_shell.tint = _color_btn.color
	_shell.is_blend = _blend_chk.button_pressed
	_shell.speed = _speed_spin.value


func _launch_lifecycle(lifecycle: BulletLifecycle) -> void:
	_sync_shell_from_direct()
	var data: BulletData = _shell.build(null)
	data.params = {}
	data.trajectory(lifecycle)
	_bullet_manager.shoot_bullet(data, _emitter_pos, _shell.get_dir())
	_update_stats()


func _clear_all() -> void:
	_bullet_manager.reset_world()  # 清场 + 回收内核 program/弹型（反复发射/改配置会积累）
	_update_stats()


func _set_seed(seed_value: int) -> void:
	_seed = seed_value
	RNG.set_seed(seed_value)


func _next_seed() -> void:
	_set_seed(randi())
	_update_stats()


func _update_stats() -> void:
	if _stats_label:
		_stats_label.text = "场上弹数：%d · 种子：%d" % [_bullet_manager.active_count(), _seed]


func _process(delta: float) -> void:
	if _burst_chk and _burst_chk.button_pressed:
		_burst_left -= delta
		if _burst_left <= 0.0:
			_burst_left = _interval_spin.value
			_fire()
	_process_hot_reload(delta)
	_update_stats()


# ═══ 热更新：保存脚本 → 自动重载重演 ═══

func _on_script_changed(_idx: int) -> void:
	_set_current_script()
	_param_panel.rebuild(_cur_script)
	_toast.show_msg("行为：%s" % (_cur_script_path.get_file() if _cur_script_path != "" else "（直线弹）"), Color(1, 1, 1, 0.85))


func _on_diff_changed(idx: int) -> void:
	SaveData.selected_difficulty = idx
	if _composer_panel != null and _composer_panel.difficulty() != idx:
		_composer_panel.set_difficulty(idx)


# ═══ 公开接缝（创作台 / 测试；用户操作走的是同一条实现）═══

func _catalog_role() -> String: return "bullet"
func _script_selector() -> OptionButton: return _script_sel
func _primary_selector() -> OptionButton: return _script_sel


## 打一次（= 用户按 F / 点"发射"）
func fire_once() -> void:
	_fire()


## 切直射/拼装（用户点模式下拉走同一条）
func set_composer_mode(on: bool) -> void:
	_mode_sel.selected = 1 if on else 0
	_on_mode_changed(_mode_sel.selected)


func composer_mode() -> bool:
	return _mode_sel.selected == 1


func composer_panel():
	return _composer_panel


## 连发开关（同步勾选框，UI 与内部状态不会各说各话）
func set_burst(on: bool) -> void:
	_burst_chk.button_pressed = on


## 连发剩余秒数（0 = 不在连发）
func burst_remaining() -> float:
	return _burst_left
# ═══ 场地交互 ═══

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var pos := (event as InputEventMouseButton).position  # 场地局部即游戏坐标
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
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	var emitter_pos := _emitter_pos
	_field.draw_line(emitter_pos + Vector2(-12, 0), emitter_pos + Vector2(12, 0), Color(1, 0.85, 0.3), 2.0)
	_field.draw_line(emitter_pos + Vector2(0, -12), emitter_pos + Vector2(0, 12), Color(1, 0.85, 0.3), 2.0)
	# 发射方向箭头（绿色，从发射点指向）
	if _shell and _shell.dir.length() > 0.001:
		var direction: Vector2 = _shell.dir
		var tip := emitter_pos + direction * 56.0
		_field.draw_line(emitter_pos, tip, Color(0.35, 0.95, 0.45), 2.0)
		var side := direction.rotated(2.6) * 10.0
		_field.draw_line(tip, tip + side, Color(0.35, 0.95, 0.45), 2.0)
		_field.draw_line(tip, tip + _shell.dir.rotated(-2.6) * 10.0, Color(0.35, 0.95, 0.45), 2.0)


# ═══ 热更新钩子（管线在 BenchBase）═══

func _collect_watch_paths() -> Array[String]:
	return _with_dir_scripts([_cur_script_path])


func _main_watch_path() -> String:
	return _cur_script_path


func _on_hot_reloaded(main_new: Script) -> void:
	_cur_script = main_new
	_param_panel.rebuild(_cur_script)  # 脚本参数变更同步
	_bullet_manager.reset_world()
	RNG.set_seed(_seed)
	_fire()
	_toast.show_msg("＊ 已重载：%s" % _cur_script_path.get_file(), Color(0.5, 0.95, 0.6))

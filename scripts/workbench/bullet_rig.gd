extends Control
## 弹幕试验台（M2a）—— 选魂（行为脚本）× 换壳（外形面板）× 发射点 × 幽灵玩家（鼠标跟随）
## 跑真实 BulletManager：子弹飞行/碰撞/擦弹/自定义行为 全部真实；所见即最终效果。
## 快捷键：F=发射 · C=清场 · 点击场地=设发射点

const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
const CATALOG := preload("res://scripts/data/content_catalog.gd")
const SHELL := preload("res://scripts/workbench/bullet_shell.gd")

const FIXED_SEED := 20260801

var _shell: Variant      # BulletShell（preload 构造，规避新 class 全局缓存）
var _catalog: Variant    # ContentCatalog
var _ghost: Player
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
var _field: Control


func _ready() -> void:
	get_window().size = Vector2i(1600, 960)  # 与工作台一致：横向给右侧面板腾位置
	_shell = SHELL.new()
	_catalog = CATALOG.new().scan()
	_build_world()
	_build_ui()
	_set_seed(FIXED_SEED)


# ═══ 世界 ═══

func _build_world() -> void:
	# 场地（画框 + 发射点十字；点击设发射点）
	_field = Control.new()
	_field.set_anchors_preset(Control.PRESET_FULL_RECT)
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.gui_input.connect(_on_field_input)
	_field.draw.connect(_on_field_draw)
	add_child(_field)
	# 幽灵玩家：鼠标跟随（自机狙目标）
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST)
	_ghost.name = "GhostPlayer"
	_ghost.set("mode", 1)  # GhostPlayer.Mode.MOUSE（AUTO=0/MOUSE=1/STATIC=2；静态类型 Player 无 mode，用 set 动态写）
	_ghost.player_data = REIMU_DATA  # 必须：Player._ready 会应用角色数据（工作台同款）
	_ghost.position = Vector2(GameConfig.FIELD_CENTER_X, 620.0)
	_ghost.z_index = 30
	add_child(_ghost)


# ═══ UI ═══

func _build_ui() -> void:
	# 面板停靠场地右侧（不遮挡演出），同工作台右侧面板规格：432 宽 × 712 高
	var panel := PanelContainer.new()
	panel.offset_left = 856.0
	panel.offset_top = 8.0
	panel.offset_right = 1288.0
	panel.offset_bottom = 720.0
	add_child(panel)
	# 内部滚动：未来加字段也不会裁内容
	var panel_scroll := ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	panel_scroll.add_child(box)

	box.add_child(_label("弹幕试验台 v0（M2a）", 16))
	box.add_child(_label("魂：行为脚本", 12))

	_script_sel = OptionButton.new()
	_script_sel.add_item("（无）直线弹")
	for e in _catalog.by_role("bullet"):
		var item_text: String = (e.name if e.name != "" else e.path.get_file()) + "（" + e.path.get_file() + "）"
		_script_sel.add_item(item_text)
	_script_sel.selected = 0
	box.add_child(_script_sel)

	box.add_child(_label("壳：外形", 12))

	_tex_sel = OptionButton.new()
	for key in AssetRegistry.bullet_configs:
		_tex_sel.add_item(key)
	box.add_child(_tex_sel)

	_color_btn = ColorPickerButton.new()
	_color_btn.color = Color.WHITE
	box.add_child(_color_btn)

	_blend_chk = CheckBox.new()
	_blend_chk.text = "加色混合"
	box.add_child(_blend_chk)

	_speed_spin = SpinBox.new()
	_speed_spin.min_value = 10.0
	_speed_spin.max_value = 4000.0
	_speed_spin.step = 5.0
	_speed_spin.value = 300.0
	box.add_child(_speed_spin)

	_dir_sel = OptionButton.new()
	for d in SHELL.DIR_LABELS:
		_dir_sel.add_item(d)
	box.add_child(_dir_sel)

	box.add_child(_label("操作", 12))

	var ops := HBoxContainer.new()
	_fire_btn = Button.new()
	_fire_btn.text = "发射"
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
	itv.add_child(_label("间隔", 12))
	_interval_spin = SpinBox.new()
	_interval_spin.min_value = 0.05
	_interval_spin.max_value = 2.0
	_interval_spin.step = 0.05
	_interval_spin.value = 0.5
	_interval_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	itv.add_child(_interval_spin)
	box.add_child(itv)

	_stats_label = _label("", 12)
	box.add_child(_stats_label)
	box.add_child(_label("点击场地 = 发射点；幽灵玩家 = 鼠标", 11))


func _label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l


# ═══ 发射 ═══

func _fire() -> void:
	_shell.tex_key = _tex_sel.get_item_text(_tex_sel.selected)
	_shell.tint = _color_btn.color
	_shell.blend = _blend_chk.button_pressed
	_shell.speed = _speed_spin.value
	_shell.dir_index = _dir_sel.selected
	var script: Script = null
	var idx := _script_sel.selected
	if idx > 0:
		var entry = _catalog.by_role("bullet")[idx - 1]
		script = load(entry.path)
	var data: BulletData = _shell.build(script)
	BulletManager.shoot_enemy_bullet(data, _emitter_pos, _shell.get_dir())
	_update_stats()


func _clear_all() -> void:
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
		_stats_label.text = "场上弹数：%d · 种子：%d" % [BulletManager.active_bullets.size(), _seed]


func _process(delta: float) -> void:
	if _burst_chk and _burst_chk.button_pressed:
		_burst_left -= delta
		if _burst_left <= 0.0:
			_burst_left = _interval_spin.value
			_fire()
	_update_stats()


# ═══ 场地交互 ═══

func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_emitter_pos = (event as InputEventMouseButton).position
		_field.queue_redraw()


func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.35, 0.45, 0.7, 0.5), false, 2.0)
	var p := _emitter_pos
	_field.draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), Color(1, 0.85, 0.3), 2.0)
	_field.draw_line(p + Vector2(0, -12), p + Vector2(0, 12), Color(1, 0.85, 0.3), 2.0)
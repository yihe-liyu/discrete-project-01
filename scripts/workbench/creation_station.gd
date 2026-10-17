extends Control
## 创作台（四页签）—— 单窗口统一入口：整关预览 | 弹幕台 | 敌人台 | 阶段台
## 试验台实例常驻（切换保留选择状态）；切走时清运行时残留（弹/敌人/Boss）
## 目录是**全局抽屉**：四个页签下都能打开，双击直达对应台（不再只活在整关预览里）。

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const WORKBENCH := preload("res://scenes/workbench.tscn")
const CATALOG_PANEL := preload("res://scripts/workbench/catalog_panel.gd")
const RIG_COMMON := preload("res://scripts/workbench/bench_common.gd")
const BENCHS := [
	preload("res://scenes/workbench/bullet_bench.tscn"),
	preload("res://scenes/workbench/enemy_bench.tscn"),
	preload("res://scenes/workbench/phase_bench.tscn"),
]
const SLOTS := ["整关预览", "弹幕台", "敌人台", "阶段台"]

var _slot_buttons: Array[Button] = []
var _view: Control = null
var _current_slot: int = -1
var _bench_instances: Array[BenchBase] = [null, null, null]
var _workspace_restores: Array = [{}, {}, {}]

# ── 全局目录抽屉（CanvasLayer(3)：高于顶栏(2)与各页自带 UI(1)）──
var _catalog_btn: Button
var _catalog_layer: CanvasLayer
var _catalog_drawer: PanelContainer
var _catalog_panel               # CatalogPanel（preload 构造，避免 class_name 缓存）
var _catalog_open: bool = false

const CFG_PATH := "user://creation_station.cfg"


func _ready() -> void:
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	get_window().size = Vector2i(1280, 960)
	theme = WORKBENCH_THEME.build()
	_build_ui()
	_load_workspace()
	_on_slot(_load_slot_override())


func _build_ui() -> void:
	# 布局用场景里挂好的节点（作者在编辑器建的）——填充式。
	# ⚠️ 横栏挂在 **CanvasLayer(layer=2)** 里，不是内容区里：
	# 被托管的视图会**压住横栏吃掉点击**（组合台的场地是 `top_level` 的 832x928 Control +
	# MOUSE_FILTER_STOP；整关预览的 BgContainer 被嵌页归一时移到 y≈1、宽 762）→
	# 整关预览/弹幕台/敌人台（x<832~963 一带）点不动。GUI 拾取按**画布层从高到低** →
	# 横栏必须在更高的层上，且**必须显式挂主题**（CanvasLayer 会断 Control 主题链）。
	# 顶栏底板：原来按钮之间的空隙直接透出场地，场地的金色左边框会像一根“悬空竖线”。
	# 加一条 36px 的深色 header + 底部金线，给页签/内容一个明确的接缝。
	var bar_layer: CanvasLayer = $BarLayer
	var header_bg := ColorRect.new()
	header_bg.color = Color(0.035, 0.035, 0.05, 0.98)
	header_bg.anchor_right = 1.0
	header_bg.offset_bottom = 36.0
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_layer.add_child(header_bg)
	bar_layer.move_child(header_bg, 0)
	var header_line := ColorRect.new()
	header_line.color = Color(0.62, 0.52, 0.28, 0.55)
	header_line.anchor_right = 1.0
	header_line.offset_top = 35.0
	header_line.offset_bottom = 36.0
	header_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_layer.add_child(header_line)
	bar_layer.move_child(header_line, 1)

	var bar: HBoxContainer = $BarLayer/Bar
	bar.theme = theme
	for i in SLOTS.size():
		var button := Button.new()
		button.text = SLOTS[i]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_slot.bind(i))
		bar.add_child(button)
		_slot_buttons.append(button)

	# 全局目录开关：固定在顶栏右侧；抽屉挂在 layer=3，不挤占 1280 的场地+右面板。
	_catalog_btn = Button.new()
	_catalog_btn.text = "目录 ▾"
	_catalog_btn.tooltip_text = "打开全局目录"
	_catalog_btn.toggle_mode = true
	_catalog_btn.custom_minimum_size = Vector2(88, 0)
	_catalog_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_catalog_btn.add_theme_font_size_override("font_size", 16)
	_catalog_btn.toggled.connect(set_catalog_open)
	bar.add_child(_catalog_btn)
	_build_catalog_drawer()


## 全局目录抽屉：左覆盖层（不缩场地），四个页签共用。
## 位置避开顶栏（y=44 起）；打开时只挡左侧 432px，右侧场地仍可点。
func _build_catalog_drawer() -> void:
	_catalog_layer = CanvasLayer.new()
	_catalog_layer.name = "CatalogLayer"
	_catalog_layer.layer = 3
	add_child(_catalog_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catalog_layer.add_child(root)

	_catalog_drawer = PanelContainer.new()
	_catalog_drawer.name = "CatalogDrawer"
	_catalog_drawer.anchor_left = 0.0
	_catalog_drawer.anchor_right = 0.0
	_catalog_drawer.anchor_top = 0.0
	_catalog_drawer.anchor_bottom = 1.0
	_catalog_drawer.offset_left = 8.0
	_catalog_drawer.offset_top = 44.0
	_catalog_drawer.offset_right = 440.0
	_catalog_drawer.offset_bottom = -8.0
	_catalog_drawer.mouse_filter = Control.MOUSE_FILTER_STOP
	_catalog_drawer.custom_minimum_size = Vector2(432, 0)
	_catalog_drawer.add_theme_stylebox_override("panel", RIG_COMMON.panel_style())
	_catalog_drawer.theme = theme
	root.add_child(_catalog_drawer)

	_catalog_panel = CATALOG_PANEL.new()
	_catalog_panel.show_descriptors = true
	_catalog_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_panel.preset_requested.connect(_on_catalog_preset)
	_catalog_drawer.add_child(_catalog_panel)
	# CatalogPanel._ready() 会把 custom_minimum_size 重置成 (0,420) → 必须在入树后再压宽度
	_catalog_panel.custom_minimum_size = Vector2(408, 420)
	_catalog_drawer.visible = false


# ═══ 公开接缝（测试/外部驱动；用户点页签走的是同一条实现）═══

## 页签名（顺序 = 槽位下标：0 = 整关预览，1..3 = 三台）
func slot_names() -> Array[String]:
	return SLOTS.duplicate()


func slot_count() -> int:
	return SLOTS.size()


## 第 i 个页签按钮（用户点的就是这个；测试也走它，不去摸节点路径）
func slot_button(slot_index: int) -> Button:
	if slot_index < 0 or slot_index >= _slot_buttons.size():
		return null
	return _slot_buttons[slot_index]


## 当前槽位下标（-1 = 还没打开过）
func current_slot() -> int:
	return _current_slot


## 当前显示的子视图（整关预览 = workbench；其余 = 对应试验台）
func current_view() -> Control:
	return _view


## 常驻试验台实例（0=弹幕台 / 1=敌人台 / 2=阶段台；没建过 → null）
func bench_instance(slot_index: int) -> BenchBase:
	if slot_index < 0 or slot_index >= _bench_instances.size():
		return null
	return _bench_instances[slot_index]


## 全局目录抽屉是否打开
func catalog_open() -> bool:
	return _catalog_open


## 全局目录面板（CatalogPanel；测试/外部驱动用）
func catalog_panel():
	return _catalog_panel


## 顶栏「目录」按钮（测试点它 = 用户点它）
func catalog_button() -> Button:
	return _catalog_btn


## 开/关全局目录（不递归触发按钮 toggled）
func set_catalog_open(open: bool) -> void:
	_catalog_open = open
	if _catalog_btn != null:
		_catalog_btn.set_pressed_no_signal(open)
		_catalog_btn.text = "目录 ▴" if open else "目录 ▾"
		_catalog_btn.tooltip_text = "关闭全局目录（Esc）" if open else "打开全局目录"
	if _catalog_drawer != null:
		_catalog_drawer.visible = open


func _on_catalog_preset(entry) -> void:
	route_preset(entry)
	set_catalog_open(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if _catalog_open and event.is_action_pressed("ui_cancel"):
		set_catalog_open(false)
		get_viewport().set_input_as_handled()


## 打开某个槽位（同步页签高亮 + 切换视图）
func open_slot(slot_index: int) -> void:
	_on_slot(slot_index)


## 页签切换
func _on_slot(slot_index: int) -> void:
	if _current_slot == slot_index and _view != null:
		return
	_clear_view()
	_current_slot = slot_index
	if slot_index == 0:
		_view = WORKBENCH.instantiate()
	else:
		var bench_i: int = slot_index - 1
		if _bench_instances[bench_i] == null:
			_bench_instances[bench_i] = BENCHS[bench_i].instantiate() as BenchBase
		_view = _bench_instances[bench_i]
	_view.visible = true
	_view.process_mode = Node.PROCESS_MODE_INHERIT  # 恢复运转（连发状态保留，只是不再后台跑）
	if _view.get_parent():
		_view.get_parent().remove_child(_view)  # 常驻实例：切换前先脱离旧父
	var content: Control = $Root/Content
	content.add_child(_view)
	# 目录双击 → 组合台直达（整关页内目录）
	if slot_index == 0:
		# 嵌入模式：隐藏整关预览自带的“目录”页签，统一走全局抽屉，避免截图里双目录。
		if _view.has_method("set_embedded"):
			_view.call("set_embedded", true)
		var catalog = _view.call("catalog_panel")
		if catalog and not catalog.preset_requested.is_connected(route_preset):
			catalog.preset_requested.connect(route_preset)
	# 工作区恢复
	if slot_index > 0:
		var ri := slot_index - 1
		var bench := _view as BenchBase
		var saved: Dictionary = _workspace_restores[ri]
		if not saved.is_empty():
			bench.restore(saved)
	_save_workspace()
	for button_index in _slot_buttons.size():
		_slot_buttons[button_index].button_pressed = button_index == slot_index


## 目录双击条目 → 切对应台并装配
## 把目录条目路由到对应试验台并装配（目录双击走这条；测试/外部也可直接调）
func route_preset(entry) -> void:
	var slot := 1
	match entry.role:
		"bullet", "descriptor":
			slot = 1
		"enemy":
			slot = 2
		"phase", "boss_move", "boss_shoot":
			slot = 3
		_:
			return
	_on_slot(slot)
	var bench := _view as BenchBase
	if bench:
		bench.preset_from_entry(entry)
	set_catalog_open(false)


# ═══ 工作区自动恢复（user:// 配置）═══

func _load_slot_override() -> int:
	var config_file := ConfigFile.new()
	if config_file.load(CFG_PATH) != OK:
		return 1  # 默认弹幕台
	return int(config_file.get_value("ws", "slot", 1))


func _load_workspace() -> void:
	var config_file := ConfigFile.new()
	if config_file.load(CFG_PATH) != OK:
		return
	for i in 3:
		_workspace_restores[i] = config_file.get_value("bench%d" % i, "data", {})


func _save_workspace() -> void:
	if _current_slot < 0:
		return
	var config_file := ConfigFile.new()
	config_file.set_value("ws", "slot", _current_slot)
	for i in 3:
		var bench: BenchBase = _bench_instances[i]
		if bench:
			config_file.set_value("bench%d" % i, "data", bench.snapshot())
	config_file.save(CFG_PATH)


func _exit_tree() -> void:
	_save_workspace()


## 切走：整关 = 停关卡+清弹+停BGM 后释放；试验台 = 清运行时残留（UI 状态保留）
func _clear_view() -> void:
	if _view == null:
		return
	var bullet_manager: BulletManager = null
	if _view.has_method("bullet_manager"):
		bullet_manager = _view.call("bullet_manager")
	if _current_slot == 0:
		_view.call("stop_stage")
		if bullet_manager: bullet_manager.reset_world()
		AudioManager.stop_bgm()
		_view.queue_free()
	else:
		if bullet_manager: bullet_manager.reset_world()
		var rt: StageRuntime = _view.call("stage_runtime") if _view.has_method("stage_runtime") else null
		var entity_registry: EntityRegistry = rt.entity_registry if rt else null
		for enemy in (entity_registry.get_active_enemies() if entity_registry else []):
			if is_instance_valid(enemy):
				enemy.queue_free()
		_view.visible = false
		_view.process_mode = Node.PROCESS_MODE_DISABLED  # 冻结：连发/热更新/幽灵不后台跑
	_view = null

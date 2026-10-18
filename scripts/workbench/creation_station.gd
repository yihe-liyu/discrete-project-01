extends Control
## 创作台（四页签）—— 单窗口统一入口：整关预览 | 弹幕台 | 敌人台 | 阶段台
## 试验台实例常驻（切换保留选择状态）；切走时清运行时残留（弹/敌人/Boss）
## 目录是**全局抽屉**：四个页签下都能打开，双击直达对应台（不再只活在整关预览里）。

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const WORKBENCH := preload("res://scenes/workbench.tscn")
const RIG_COMMON := preload("res://scripts/workbench/bench_common.gd")
const WORKSPACE_STORE := preload("res://scripts/workbench/workspace_store.gd")
const BENCHS := [
	preload("res://scenes/workbench/bullet_bench.tscn"),
	preload("res://scenes/workbench/enemy_bench.tscn"),
	preload("res://scenes/workbench/phase_bench.tscn"),
]
const SLOTS := ["整关预览", "弹幕台", "敌人台", "阶段台"]

var _slot_buttons: Array[Button] = []
var _view: Control = null
var _current_slot: int = -1
var _workbench_view = null
var _bench_instances: Array[BenchBase] = [null, null, null]
## 工作区配置/迁移（无树服务，D3）
var _workspace_store
## 上次看到的物理窗口宽度（size_changed 在 viewport stretch 下可能不触发，用 _process 兜底）
var _last_window_w: int = 0
## 三台是否已经从配置恢复过（之后保留常驻实例的当前状态，不再用旧快照覆盖）
var _bench_restored: Array[bool] = [false, false, false]

# ── 全局目录抽屉（CanvasLayer(3)：高于顶栏(2)与各页自带 UI(1)）──
var _catalog_btn: Button
var _catalog_layer: CanvasLayer
var _catalog_drawer: PanelContainer
var _catalog_panel               # CatalogPanel（preload 构造，避免 class_name 缓存）
var _catalog_open: bool = false

func _ready() -> void:
	# Phase 3A：1600x960 = 左栏 320 + 内容 1280（场地 832 + 右面板 440 + 间距）。
	# 1280 时自动收起左栏，改为覆盖抽屉，避免把场地/右面板挤坏。
	get_window().size = Vector2i(1600, 960)
	get_window().content_scale_size = Vector2i(1600, 960)
	get_window().min_size = Vector2i(1280, 960)
	get_window().size_changed.connect(_on_window_size_changed)
	_last_window_w = get_window().size.x
	theme = WORKBENCH_THEME.build()
	_build_ui()
	_catalog_open = get_window().size.x >= 1600
	set_catalog_open(_catalog_open)
	_workspace_store = WORKSPACE_STORE.new()
	_workspace_store.load(SLOTS.size())
	_on_slot(_workspace_store.slot())


func _process(_delta: float) -> void:
	var w := get_window().size.x
	if w != _last_window_w:
		_last_window_w = w
		_on_window_size_changed()


func _build_ui() -> void:
	# 静态 chrome（顶栏/页签/目录抽屉）在 creation_station.tscn 里声明；
	# 这里只接信号、套主题、压 CatalogPanel 的最小宽度。
	var bar: HBoxContainer = $BarLayer/Bar
	bar.theme = theme
	_slot_buttons.clear()
	for i in SLOTS.size():
		var button := bar.get_node("Tab%d" % i) as Button
		button.pressed.connect(_on_slot.bind(i))
		_slot_buttons.append(button)
	_catalog_btn = bar.get_node("CatalogButton") as Button
	_catalog_btn.toggled.connect(set_catalog_open)
	_configure_catalog_drawer()


## 目录抽屉在场景里声明（CanvasLayer(3)）；这里只套主题/样式、接信号、修正 CatalogPanel 宽度。
func _configure_catalog_drawer() -> void:
	_catalog_layer = $CatalogLayer as CanvasLayer
	_catalog_drawer = $CatalogLayer/Root/CatalogDrawer as PanelContainer
	_catalog_panel = $CatalogLayer/Root/CatalogDrawer/CatalogPanel
	_catalog_drawer.add_theme_stylebox_override("panel", RIG_COMMON.panel_style())
	_catalog_drawer.theme = theme
	_catalog_panel.set_show_descriptors(true)
	_catalog_panel.preset_requested.connect(_on_catalog_preset)
	# CatalogPanel._ready() 会把 custom_minimum_size 重置成 (0,420) → 必须在入树后压宽度
	_catalog_panel.custom_minimum_size = Vector2(360, 420)
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


## 常驻整关预览（未建过 → null；切页保活，不再 queue_free）
func workbench_instance():
	return _workbench_view


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


## 开/关全局目录（不递归触发按钮 toggled）。
## 1600 下目录是常驻左栏，关闭无意义且会留空白 ⇒ 强制保持打开、隐藏按钮；
## 1280 下才是可开合的覆盖抽屉。
func set_catalog_open(open: bool) -> void:
	var wide := get_window().content_scale_size.x >= 1600
	_catalog_open = true if wide else open
	if _catalog_btn != null:
		_catalog_btn.visible = not wide
		_catalog_btn.set_pressed_no_signal(_catalog_open)
		_catalog_btn.text = "目录 ▴" if _catalog_open else "目录 ▾"
		_catalog_btn.tooltip_text = "关闭全局目录（Esc）" if _catalog_open else "打开全局目录"
	if _catalog_drawer != null:
		_catalog_drawer.visible = _catalog_open
	_apply_layout()


func _on_window_size_changed() -> void:
	var w := get_window().size.x
	var logical_w := clampi(w, 1280, 1600)
	if get_window().content_scale_size.x != logical_w:
		get_window().content_scale_size = Vector2i(logical_w, 960)
	if logical_w < 1600 and _catalog_open:
		set_catalog_open(false)
		return
	_apply_layout()


## 1600：左栏常驻、内容 1280；1280：左栏覆盖、内容占满。内容始终 1280 宽，避免改三台场景。
func _apply_layout() -> void:
	var win_w := get_window().content_scale_size.x
	var wide := win_w >= 1600
	var x := 0
	if wide:
		_catalog_open = true
		x = 320
	else:
		x = 0
	if _catalog_btn != null:
		_catalog_btn.visible = not wide
	if _catalog_drawer != null:
		_catalog_drawer.visible = _catalog_open
	# 游戏画布整体平移（top_level 场地/BulletManager 也会跟着走）；
	# UI 在 CanvasLayer 上，不受 canvas_transform 影响。
	# 页签横栏保持全宽：否则 GUT 输出面板会截走右侧页签点击。
	var content: Control = $Root/ContentHost/Content
	content.offset_left = 0
	content.offset_right = 0
	content.offset_top = 0
	content.offset_bottom = 0
	get_viewport().canvas_transform.origin.x = float(x)
	if _workbench_view != null:
		_workbench_view.set_view_offset_x(float(x))


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


## 页面协议（Phase 2）：
##   整关预览：set_embedded / catalog_panel / suspend_preview / resume_preview /
##             preview_suspended / current_time / bullet_manager / stage_runtime
##   试验台：BenchBase.pause_view / resume_view / clear_runtime / snapshot / restore /
##           preset_from_entry / catalog / stage_runtime / bullet_manager
## 不再用 has_method/call 猜（动态 call 已从本文件删除）。
##
## 页签切换
func _on_slot(slot_index: int) -> void:
	if _current_slot == slot_index and _view != null:
		return
	_clear_view()
	_current_slot = slot_index
	if slot_index == 0:
		if _workbench_view == null:
			_workbench_view = WORKBENCH.instantiate()
			_workbench_view.set_embedded(true)  # 先标记，避免 Workbench._ready 把窗口改回 1280
		_view = _workbench_view
	else:
		var bench_i: int = slot_index - 1
		if _bench_instances[bench_i] == null:
			_bench_instances[bench_i] = BENCHS[bench_i].instantiate() as BenchBase
			_bench_instances[bench_i].set_embedded(true)  # 先标记，避免 bench._ready 把窗口改回 1280
			_bench_restored[bench_i] = false
		_view = _bench_instances[bench_i]
	var content: Control = $Root/ContentHost/Content
	# 常驻视图不要每次 remove_child + add_child：会触发整棵子树的 _exit_tree/_enter_tree，
	# CoroutineRunner._exit_tree() 会 stop() 背景/敌人/关卡协程，回来只 _enter_tree 不会重启。
	# 已挂在 Content 下就只切 visible/process；只有首次/异常父节点才重新挂。
	if _view.get_parent() != content:
		if _view.get_parent():
			_view.get_parent().remove_child(_view)
		content.add_child(_view)
	_view.visible = true

	if slot_index == 0:
		# 嵌入模式：隐藏整关预览自带的“目录”页签，统一走全局抽屉，避免截图里双目录。
		_workbench_view.set_embedded(true)
		_workbench_view.set_view_offset_x(get_viewport().canvas_transform.origin.x)
		_workbench_view.resume_preview()
		var catalog = _workbench_view.catalog_panel()
		if catalog and not catalog.preset_requested.is_connected(route_preset):
			catalog.preset_requested.connect(route_preset)
	else:
		var bench := _view as BenchBase
		bench.resume_view()
		var ri := slot_index - 1
		if not _bench_restored[ri]:
			var saved: Dictionary = _workspace_store.restore(ri)
			if not saved.is_empty():
				bench.restore(saved)
			_bench_restored[ri] = true

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


# ═══ 工作区（实现见 WorkspaceStore）═══

func workspace_version() -> int:
	return _workspace_store.version()


func workspace_loaded_from_version() -> int:
	return _workspace_store.loaded_version()


func workspace_slot() -> int:
	return _workspace_store.slot()


func workspace_restore(slot_index: int) -> Dictionary:
	return _workspace_store.restore(slot_index)


## 公开保存（测试/外部；用户切页/退出走同一条实现）
func save_workspace() -> void:
	_save_workspace()


func _save_workspace() -> void:
	if _current_slot < 0:
		return
	_workspace_store.save(_current_slot, _bench_instances)

func _exit_tree() -> void:
	_save_workspace()
	get_window().content_scale_size = Vector2i(1280, 960)
	get_window().size = Vector2i(1280, 960)
	get_window().min_size = Vector2i.ZERO
	get_viewport().canvas_transform.origin.x = 0.0


## 切走：整关预览冻结保活（时间/关卡/书签保留）；试验台清运行时残留后冻结。
func _clear_view() -> void:
	if _view == null:
		return
	if _current_slot == 0:
		_workbench_view.suspend_preview()
	else:
		var bench := _view as BenchBase
		if bench != null:
			# 切走前写回最新状态；切回时（常驻实例）不再被配置里的旧快照覆盖。
			_workspace_store.put_restore(_current_slot - 1, bench.snapshot())
			bench.clear_runtime()
			bench.pause_view()  # 冻结：连发/热更新/幽灵不后台跑
	_view = null

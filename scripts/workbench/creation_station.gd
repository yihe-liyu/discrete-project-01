extends Control
## 创作台（三合一）—— 单窗口统一入口：整关预览 | 弹幕台 | 敌人台 | 阶段台
## 试验台实例常驻（切换保留选择状态）；切走时清运行时残留（弹/敌人/Boss）

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const WORKBENCH := preload("res://scenes/workbench.tscn")
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
		var wb = _view
		var catalog = wb.get("_catalog")
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
		"bullet":
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
	var bullet_manager: BulletManager = _view.get("_bullet_manager")   # 整关/试验台都有 _bullet_manager（不读 .current）
	if _current_slot == 0:
		_view.stop_stage()
		if bullet_manager: bullet_manager.reset_world()
		AudioManager.stop_bgm()
		_view.queue_free()
	else:
		if bullet_manager: bullet_manager.reset_world()
		var rt: StageRuntime = _view.get("_stage_runtime")
		var entity_registry: EntityRegistry = rt.entity_registry if rt else null
		for enemy in (entity_registry.get_active_enemies() if entity_registry else []):
			if is_instance_valid(enemy):
				enemy.queue_free()
		_view.visible = false
		_view.process_mode = Node.PROCESS_MODE_DISABLED  # 冻结：连发/热更新/幽灵不后台跑
	_view = null

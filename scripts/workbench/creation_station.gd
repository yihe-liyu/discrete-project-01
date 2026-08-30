extends Control
## 创作台（三合一）—— 单窗口统一入口：整关预览 | 弹幕台 | 敌人台 | 阶段台
## 试验台实例常驻（切换保留选择状态）；切走时清运行时残留（弹/敌人/Boss）

const WORKBENCH_THEME := preload("res://scripts/workbench/workbench_theme.gd")
const WORKBENCH := preload("res://scenes/workbench.tscn")
const RIGS := [
	preload("res://scenes/workbench/bullet_rig.tscn"),
	preload("res://scenes/workbench/enemy_rig.tscn"),
	preload("res://scenes/workbench/phase_rig.tscn"),
]
const TABS := ["整关预览", "弹幕台", "敌人台", "阶段台"]

var _tab_btns: Array[Button] = []
var _content: Control
var _page: Control = null
var _current := -1
var _rig_instances: Array = [null, null, null]
var _workspace_restores: Array = [{}, {}, {}]

const CFG_PATH := "user://creation_station.cfg"


func _ready() -> void:
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	get_window().size = Vector2i(1280, 960)
	theme = WORKBENCH_THEME.build()
	_build_ui()
	_load_workspace()
	_on_tab(_load_tab_override())


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.custom_minimum_size = Vector2(0, 34)
	root.add_child(bar)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab.bind(i))
		bar.add_child(b)
		_tab_btns.append(b)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_content)


## 页签切换
func _on_tab(i: int) -> void:
	if _current == i and _page != null:
		return
	_clear_page()
	_current = i
	if i == 0:
		_page = WORKBENCH.instantiate()
	else:
		var ri := i - 1
		if _rig_instances[ri] == null:
			_rig_instances[ri] = RIGS[ri].instantiate()
		_page = _rig_instances[ri]
	_page.visible = true
	_page.process_mode = Node.PROCESS_MODE_INHERIT  # 恢复运转（连发状态保留，只是不再后台跑）
	if _page.get_parent():
		_page.get_parent().remove_child(_page)  # 常驻实例：切换前先脱离旧父
	_content.add_child(_page)
	# 目录双击 → 组合台直达（整关页内目录）
	if i == 0:
		var wb = _page
		var catalog = wb.get("_catalog")
		if catalog and not catalog.preset_requested.is_connected(_route_preset):
			catalog.preset_requested.connect(_route_preset)
	# 工作区恢复
	if i > 0:
		var ri := i - 1
		var rig = _page
		var saved: Dictionary = _workspace_restores[ri]
		if not saved.is_empty() and rig.has_method("_restore"):
			rig._restore(saved)
	_save_workspace()
	for t in _tab_btns.size():
		_tab_btns[t].button_pressed = t == i


## 目录双击条目 → 切对应台并装配
func _route_preset(entry) -> void:
	var tab := 1
	match entry.role:
		"bullet":
			tab = 1
		"enemy":
			tab = 2
		"phase", "boss_move", "boss_shoot":
			tab = 3
		_:
			return
	_on_tab(tab)
	var rig = _page
	if rig and rig.has_method("_preset_from_entry"):
		rig._preset_from_entry(entry)


# ═══ 工作区自动恢复（user:// 配置）═══

func _load_tab_override() -> int:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return 1  # 默认弹幕台
	return int(cf.get_value("ws", "tab", 1))


func _load_workspace() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG_PATH) != OK:
		return
	for i in 3:
		_workspace_restores[i] = cf.get_value("rig%d" % i, "data", {})


func _save_workspace() -> void:
	if _current < 0:
		return
	var cf := ConfigFile.new()
	cf.set_value("ws", "tab", _current)
	for i in 3:
		var rig = _rig_instances[i]
		if rig and rig.has_method("_snapshot"):
			cf.set_value("rig%d" % i, "data", rig._snapshot())
	cf.save(CFG_PATH)


func _exit_tree() -> void:
	_save_workspace()


## 切走：整关 = 停关卡+清弹+停BGM 后释放；试验台 = 清运行时残留（UI 状态保留）
func _clear_page() -> void:
	if _page == null:
		return
	if _current == 0:
		StageManager.stop_stage()
		BulletManager.clear_all()
		AudioManager.stop_bgm()
		_page.queue_free()
	else:
		BulletManager.clear_all()
		for e in GameState.get_active_enemies():
			if is_instance_valid(e):
				e.queue_free()
		_page.visible = false
		_page.process_mode = Node.PROCESS_MODE_DISABLED  # 冻结：连发/热更新/幽灵不后台跑
	_page = null

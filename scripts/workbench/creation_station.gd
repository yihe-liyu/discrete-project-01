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


func _ready() -> void:
	get_window().size = Vector2i(1600, 960)
	theme = WORKBENCH_THEME.build()
	_build_ui()
	_on_tab(1)  # 默认弹幕台（创作主战场）


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
	if _page.get_parent():
		_page.get_parent().remove_child(_page)  # 常驻实例：切换前先脱离旧父
	_content.add_child(_page)
	for t in _tab_btns.size():
		_tab_btns[t].button_pressed = t == i


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
	_page = null

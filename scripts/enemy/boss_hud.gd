## BossHud —— Boss 的**显示状态**（名字文字 + 名字显隐 + 阶段进度点显隐）。
## 从 Boss 抽出来：Boss 只管战斗，显示层自己攒状态、发信号，BossUI 订阅。
class_name BossHud
extends RefCounted

signal display_name_changed(display_name: String)
signal name_visibility_changed(is_shown: bool)
signal phase_dots_visibility_changed(is_shown: bool)

var _boss_data: BossData
var _display_name: String = ""         ## 运行时显示名覆盖（空 = 用 _boss_data.boss_name）
var _is_name_shown: bool = false       ## 名字节点是否可见（默认隐藏，手动 show）
var _is_phase_dots_shown: bool = false ## 阶段进度点是否可见（默认隐藏，手动 show）


func _init(p_data: BossData = null) -> void:
	_boss_data = p_data


## 显示名：运行时覆盖优先，否则用 data.boss_name（UI/外部只读这个）
func get_name() -> String:
	return _display_name if _display_name != "" else (_boss_data.boss_name if _boss_data else "")


## 运行时改显示名（发 display_name_changed）
func set_name(n: String) -> void:
	if _display_name == n:
		return
	_display_name = n
	display_name_changed.emit(get_name())   # 用有效名：清空覆盖时回退 data.boss_name


## 名字节点是否可见——默认 false：只在关底 reveal（或手动 show_name）时出现。
func is_name_shown() -> bool:
	return _is_name_shown


## 手动开关名字节点（默认隐藏；只切可见性，不改名）。
func set_name_shown(v: bool) -> void:
	if _is_name_shown == v:
		return
	_is_name_shown = v
	name_visibility_changed.emit(v)


## 阶段进度点（BossUI 的 History 行）是否可见 —— 默认 false，手动控制。
func is_phase_dots_shown() -> bool:
	return _is_phase_dots_shown


## 手动开关阶段进度点（默认隐藏）。
func set_phase_dots_shown(v: bool) -> void:
	if _is_phase_dots_shown == v:
		return
	_is_phase_dots_shown = v
	phase_dots_visibility_changed.emit(v)

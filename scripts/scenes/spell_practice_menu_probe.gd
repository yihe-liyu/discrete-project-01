## 符卡练习菜单的测试/调试探针：把内部状态收口到一处，测试不再散落 [code]menu._xxx[/code]。
## 生产代码不调用；菜单内部重构时只需同步这里。
##
## 用法：[code]var p = menu.probe()[/code]，然后 p.set_phases(...) / p.build_diff_list() / p.diff_index() ...
class_name SpellPracticeMenuProbe
extends RefCounted

var _menu

func _init(menu) -> void:
	_menu = menu

## 替换测试用的阶段列表（写 data.phases）。
func set_phases(phases: Array[Dictionary]) -> void:
	_menu._spell_practice_data.phases = phases

## 当前阶段数（菜单 _phases）。
func phases_count() -> int:
	return _menu._phases.size()

## 清空阶段列表（写 data.phases）。
func clear_phases() -> void:
	_menu._spell_practice_data.phases.clear()

## 阶段列表容器。
func phase_box() -> VBoxContainer:
	return _menu._phase_box

## 设当前阶段索引。
func set_phase_index(index: int) -> void:
	_menu._phase_index = index

## 当前阶段索引。
func phase_index() -> int:
	return _menu._phase_index

## 设当前难度索引。
func set_diff_index(index: int) -> void:
	_menu._diff_index = index

## 当前难度索引。
func diff_index() -> int:
	return _menu._diff_index

## 设当前层级（Section）。
func set_section(value: int) -> void:
	_menu._section = value

## 当前层级。
func section() -> int:
	return _menu._section

## 替换测试用的关卡列表。
func set_stages(stages: Array[int]) -> void:
	_menu._spell_practice_data.stages = stages

## 当前关卡数。
func stages_count() -> int:
	return _menu._stages.size()

## 清空关卡列表。
func clear_stages() -> void:
	_menu._spell_practice_data.stages.clear()

## 设当前角色索引。
func set_char_index(index: int) -> void:
	_menu._char_index = index

## 当前角色索引。
func char_index() -> int:
	return _menu._char_index

## 当前关卡索引。
func stage_index() -> int:
	return _menu._stage_index

## 列表视图当前阶段滚动偏移。
func phase_offset() -> int:
	return _menu._spell_practice_list_view.phase_offset_value()

## 人物名标签文本。
func char_name_text() -> String:
	return _menu._char_name.text

## 当前难度条目（深拷贝）。
func diff_entries() -> Array:
	return _menu._diff_entries.duplicate(true)

## 重建菜单数据 + 阶段列表。
func build_data() -> void:
	_menu._build_data()

## 重建阶段 / 难度列表。
func build_lists() -> void:
	_menu._build_lists()

## 重建难度列表并选中首个解锁项。
func build_diff_list() -> void:
	_menu._build_diff_list()

## 只重建阶段列表。
func build_phase_list() -> void:
	_menu._build_phase_list()

## 按当前层级刷新高亮；PHASE 层会先重建难度列表。
func highlight() -> void:
	_menu._highlight()

## 在难度间移动，跳过锁定项。
func move_diff(direction: int) -> void:
	_menu._move_diff(direction)

## 按当前层级设置索引（STAGE 会切面并重建）。
func set_idx(index: int) -> void:
	_menu._set_idx(index)

## 启动当前选中练习；空选 / 锁定会警告并返回。
func start_practice() -> void:
	_menu._start_practice()

## 从练习返回时还原层级 / 选中项（并消费状态）。
func restore_return_state() -> void:
	_menu._restore_return_state()

## 某阶段全难度收取状态（测试用）。
func phase_capture_all(stage: int, boss: int, phase: int, boss_override: BossData = null) -> int:
	return _menu._phase_capture_all(stage, boss, phase, boss_override)

## 当前阶段在列表中的局部序号。
func phase_local_index() -> int:
	return _menu._phase_local_index()

## VBox 当前可见行数。
func rows_visible(box: VBoxContainer) -> int:
	return _menu._rows_visible(box)

## 阶段列表子项数。
func phase_box_count() -> int:
	return _menu._phase_box.get_child_count()

## 阶段列表文本快照。
func phase_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._phase_box.get_children():
		out.append((child as Label).text)
	return out

## 难度列表文本快照。
func diff_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._diff_box.get_children():
		var box := child as VBoxContainer
		out.append((box.get_child(0) as Label).text if box.get_child_count() > 0 else "")
	return out

## 难度列表高度快照。
func diff_heights() -> Array[int]:
	var out: Array[int] = []
	for child in _menu._diff_box.get_children():
		out.append(int((child as Control).size.y))
	return out

## 关卡列表子项数。
func stage_box_count() -> int:
	return _menu._stage_box.get_child_count()

## 关卡列表文本快照。
func stage_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._stage_box.get_children():
		out.append((child as Label).text)
	return out

## 阶段滚动提示文本。
func phase_scroll_hint_text() -> String:
	return _menu._phase_scroll_hint.text

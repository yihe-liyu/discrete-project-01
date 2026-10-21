## 符卡练习菜单的测试/调试探针：把内部状态收口到一处，测试不再散落 `menu._xxx`。
## 生产代码不调用；菜单内部重构时只需同步这里。
##
## 用法：`var p = menu.probe()`，然后 p.set_phases(...) / p.build_diff_list() / p.diff_index() ...
class_name SpellPracticeMenuProbe
extends RefCounted

var _menu

func _init(menu) -> void:
	_menu = menu

func set_phases(phases: Array[Dictionary]) -> void:
	_menu._spell_practice_data.phases = phases

func phases_count() -> int:
	return _menu._phases.size()

func clear_phases() -> void:
	_menu._spell_practice_data.phases.clear()

func phase_box() -> VBoxContainer:
	return _menu._phase_box

func set_phase_index(index: int) -> void:
	_menu._phase_index = index

func phase_index() -> int:
	return _menu._phase_index

func set_diff_index(index: int) -> void:
	_menu._diff_index = index

func diff_index() -> int:
	return _menu._diff_index

func set_section(value: int) -> void:
	_menu._section = value

func section() -> int:
	return _menu._section

func set_stages(stages: Array[int]) -> void:
	_menu._spell_practice_data.stages = stages

func stages_count() -> int:
	return _menu._stages.size()

func clear_stages() -> void:
	_menu._spell_practice_data.stages.clear()

func set_char_index(index: int) -> void:
	_menu._char_index = index

func char_index() -> int:
	return _menu._char_index

func stage_index() -> int:
	return _menu._stage_index

func phase_offset() -> int:
	return _menu._spell_practice_list_view.phase_offset_value()

func char_name_text() -> String:
	return _menu._char_name.text

func diff_entries() -> Array:
	return _menu._diff_entries.duplicate(true)

func build_data() -> void:
	_menu._build_data()

func build_lists() -> void:
	_menu._build_lists()

func build_diff_list() -> void:
	_menu._build_diff_list()

func build_phase_list() -> void:
	_menu._build_phase_list()

func highlight() -> void:
	_menu._highlight()

func move_diff(direction: int) -> void:
	_menu._move_diff(direction)

func set_idx(index: int) -> void:
	_menu._set_idx(index)

func start_practice() -> void:
	_menu._start_practice()

func restore_return_state() -> void:
	_menu._restore_return_state()

func phase_capture_all(stage: int, boss: int, phase: int, boss_override: BossData = null) -> int:
	return _menu._phase_capture_all(stage, boss, phase, boss_override)

func phase_local_index() -> int:
	return _menu._phase_local_index()

func rows_visible(box: VBoxContainer) -> int:
	return _menu._rows_visible(box)

func phase_box_count() -> int:
	return _menu._phase_box.get_child_count()

func phase_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._phase_box.get_children():
		out.append((child as Label).text)
	return out

func diff_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._diff_box.get_children():
		var box := child as VBoxContainer
		out.append((box.get_child(0) as Label).text if box.get_child_count() > 0 else "")
	return out

func diff_heights() -> Array[int]:
	var out: Array[int] = []
	for child in _menu._diff_box.get_children():
		out.append(int((child as Control).size.y))
	return out

func stage_box_count() -> int:
	return _menu._stage_box.get_child_count()

func stage_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _menu._stage_box.get_children():
		out.append((child as Label).text)
	return out

func phase_scroll_hint_text() -> String:
	return _menu._phase_scroll_hint.text

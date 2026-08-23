extends GutTest
## 符卡练习菜单：难度槽（锁定的 "?" 显示问号、不可选，导航跳过锁定）

const MENU_SCENE = preload("res://scenes/ui/spell_practice_menu.tscn")

func _mk_menu() -> Node:
	var menu := MENU_SCENE.instantiate()
	add_child_autofree(menu)
	return menu


func _mk_phase_info(diffs: Dictionary) -> Dictionary:
	var rec := SpellRecord.new()
	rec.stage = 1
	rec.boss_index = 0
	rec.phase_index = 0
	rec.difficulty = 1
	rec.uid = 0
	return {rec = rec, boss_index = 0, phase_index = 0, diffs = diffs, label = "非符1"}


func _mk_phases(diffs: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_mk_phase_info(diffs))
	return out


## 只有 Normal 解锁 → 4 个难度槽都出现，但只有 Normal 可选
func test_build_diff_list_shows_all_slots_but_locks_unseen():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()})
	menu._phase_index = 0
	menu._build_diff_list()

	assert_eq(menu._diff_entries.size(), 4, "卡摩瑞应有 4 个难度槽（Easy~Lunatic）")
	assert_eq(menu._diff_entries[1].locked, false, "Normal(1) 已解锁")
	assert_eq(menu._diff_entries[0].locked, true, "Easy(0) 未解锁 → 锁定")
	assert_eq(menu._diff_entries[2].locked, true, "Hard(2) 未解锁 → 锁定")
	assert_eq(menu._diff_entries[3].locked, true, "Lunatic(3) 未解锁 → 锁定")
	assert_eq(menu._diff_index, 1, "初始索引跳到第一个解锁难度(Normal)")


## 锁定槽的名子显示 "?"
func test_locked_slot_shows_question_mark():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()})
	menu._phase_index = 0
	menu._build_diff_list()

	var children: Array = menu._diff_box.get_children()
	assert_eq(children.size(), 4, "4 个难度槽")
	var locked_vbox: VBoxContainer = children[0]  # Easy(0) 锁定
	var first_label: Label = locked_vbox.get_child(0) as Label
	assert_eq(first_label.text, "?", "锁定难度名显示 ?")
	var unlocked_vbox: VBoxContainer = children[1]  # Normal(1) 解锁
	var unlocked_label: Label = unlocked_vbox.get_child(0) as Label
	assert_ne(unlocked_label.text, "?", "解锁难度名不显示 ?")


## 导航跳过锁定：向下从 Normal 到 Hard，再向下 wrap 回 Normal
func test_move_diff_skips_locked():
	var menu = _mk_menu()
	# Normal(1) 和 Hard(2) 解锁，Easy(0)/Lunatic(3) 锁定
	menu._phases = _mk_phases({1: SpellRecord.new(), 2: SpellRecord.new()})
	menu._phase_index = 0
	menu._build_diff_list()

	menu._diff_index = 1  # Normal
	menu._move_diff(1)    # 向下
	assert_eq(menu._diff_index, 2, "向下 Normal → Hard（跳过锁定项）")
	menu._move_diff(1)    # 再向下：Lunatic 锁定 → wrap 到 Normal
	assert_eq(menu._diff_index, 1, "再向下 wrap 回 Normal")

	menu._move_diff(-1)   # 从 Normal 向上：Easy 锁定 → wrap 到 Hard
	assert_eq(menu._diff_index, 2, "向上 wrap 到 Hard")


## phase 级变蓝：花名册里全部难度槽都收齐才算全收
func test_phase_capture_all_requires_all_difficulty_slots():
	var original_book: SpellRecordBook = GameState.spell_book
	var book := SpellRecordBook.new()
	GameState.spell_book = book
	var menu = _mk_menu()

	# 只有 Normal(1) 收 → 不算全收
	var r_n := SpellRecord.new()
	r_n.stage = 1; r_n.boss_index = 0; r_n.phase_index = 0; r_n.character = 0; r_n.difficulty = 1
	r_n.practice_captures = 1
	book.records = [r_n]
	assert_ne(menu._phase_capture_all(1, 0, 0), 2, "只有 Normal 收不算全收")

	# 4 个难度全收 → 蓝(2)
	var recs: Array[SpellRecord] = []
	for d in [0, 1, 2, 3]:
		var r := SpellRecord.new()
		r.stage = 1; r.boss_index = 0; r.phase_index = 0; r.character = 0; r.difficulty = d
		r.practice_captures = 1
		recs.append(r)
	book.records = recs
	assert_eq(menu._phase_capture_all(1, 0, 0), 2, "4 个难度都收齐 → 蓝")

	GameState.spell_book = original_book  # 还原


## 锁定难度不可开始练习
func test_start_practice_guard_locked():
	GameState.selected_difficulty = 1
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()})
	menu._phase_index = 0
	menu._build_diff_list()
	menu._diff_index = 0  # Easy 锁定
	# 直接调用应被守卫拦截（不改 selected_difficulty）
	menu._start_practice()
	assert_eq(GameState.selected_difficulty, 1, "锁定难度不改变选择")

extends GutTest
## 符卡练习菜单：难度槽（锁定的 "?" 显示问号、不可选，导航跳过锁定）。
## BossData 用**合成夹具**经 info["boss"] 注入，不绑真实内容 —— 加/改符卡不影响本测试。

const MENU_SCENE = preload("res://scenes/ui/spell_practice_menu.tscn")


func _mk_menu() -> Node:
	var menu := MENU_SCENE.instantiate()
	add_child_autofree(menu)
	return menu


## 合成 Boss：只填给定难度的 phases（其余空 → 该难度不出现在候选，不回退）。
func _mk_boss(diff_list: Array) -> BossData:
	var bd := BossData.new()
	for d in diff_list:
		var phase := PhaseData.new()
		phase.name = "P%d" % d
		phase.uid = 0
		match d:
			0: bd.phases_easy.append(phase)
			1: bd.phases_normal.append(phase)
			2: bd.phases_hard.append(phase)
			3: bd.phases_lunatic.append(phase)
			4: bd.phases_extra.append(phase)
	return bd


func _mk_phase_info(diffs: Dictionary, boss: BossData) -> Dictionary:
	var rec := SpellRecord.new()
	rec.stage = 1
	rec.boss_index = 0
	rec.phase_index = 0
	rec.difficulty = 1
	rec.uid = 0
	return {rec = rec, boss_index = 0, phase_index = 0, diffs = diffs, label = "非符1", boss = boss}


func _mk_phases(diffs: Dictionary, boss: BossData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append(_mk_phase_info(diffs, boss))
	return out


## 合成 N 个二级项（label = P0..Pn），用于超长列表的开窗测试
func _mk_many_phases(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var boss := _mk_boss([0, 1, 2, 3])
	for i in count:
		var rec := SpellRecord.new()
		rec.stage = 1
		rec.boss_index = 0
		rec.phase_index = i
		rec.difficulty = 1
		out.append({rec = rec, boss_index = 0, phase_index = i, diffs = {1: rec}, label = "P%d" % i, boss = boss})
	return out


## 二级列表当前渲染出来的行文字
func _phase_labels(menu: Node) -> Array:
	var out: Array = []
	for child in menu._phase_box.get_children():
		out.append((child as Label).text)
	return out


## Boss 定义 4 个难度，只有 Normal 有记录 → 4 槽都在，只有 Normal 可选
func test_build_diff_list_shows_configured_slots_locks_unseen():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	menu._build_diff_list()

	assert_eq(menu._diff_entries.size(), 4, "Boss 定义了 4 个难度 → 4 个槽")
	assert_eq(menu._diff_entries[1].is_locked, false, "Normal(1) 已解锁")
	assert_eq(menu._diff_entries[0].is_locked, true, "Easy(0) 未解锁 → 锁定")
	assert_eq(menu._diff_entries[2].is_locked, true, "Hard(2) 未解锁 → 锁定")
	assert_eq(menu._diff_entries[3].is_locked, true, "Lunatic(3) 未解锁 → 锁定")
	assert_eq(menu._diff_index, 1, "初始索引跳到第一个解锁难度(Normal)")


## 槽位是固定 MENU_DIFFS（4）；Boss 只定义 Normal → 其余因「无阶段」锁定（不回退）
func test_menu_slots_fixed_unconfigured_locked():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([1]))
	menu._phase_index = 0
	menu._build_diff_list()
	assert_eq(menu._diff_entries.size(), 4, "槽位是固定 MENU_DIFFS（4）")
	assert_eq(menu._diff_entries[1].is_locked, false, "Normal 有阶段且有记录 → 可选")
	assert_eq(menu._diff_entries[0].is_locked, true, "Easy 无阶段 → 锁定")
	assert_eq(menu._diff_entries[2].is_locked, true, "Hard 无阶段 → 锁定")
	assert_eq(menu._diff_entries[3].is_locked, true, "Lunatic 无阶段 → 锁定")


## 锁定槽的名字显示 "?"；解锁的非符名字行为空（见下面那条高度一致性用例）
func test_locked_slot_shows_question_mark():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	menu._build_diff_list()

	var children: Array = menu._diff_box.get_children()
	assert_eq(children.size(), 4, "4 个难度槽")
	var locked_vbox: VBoxContainer = children[0]  # Easy(0) 锁定
	assert_eq((locked_vbox.get_child(0) as Label).text, "?", "锁定难度名显示 ?")
	var unlocked_vbox: VBoxContainer = children[1]  # Normal(1) 解锁（非符）
	assert_eq((unlocked_vbox.get_child(0) as Label).text, "", "解锁的非符不显示名字")


## 回归（作者报）：非符 / 符卡两种状态下，三级选项**高度必须一致**。
## 非符靠**空名字行占位**（空 Label(font 30) 最小高仍是 44），而不是省掉那一行 ——
## 省了选项就从 81 掉到 33，切难度时三级会跳。
func test_diff_option_height_same_for_nonspell_and_spell():
	var menu = _mk_menu()
	# ① 非符
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	menu._build_diff_list()
	await get_tree().process_frame
	var nonspell_entry: VBoxContainer = menu._diff_box.get_child(1)   # Normal(1) 解锁
	var nonspell_name := (nonspell_entry.get_child(0) as Label).text
	var nonspell_h := int(nonspell_entry.size.y)

	# ② 符卡（卡名经注入的夹具名册取，不绑真实内容）
	var rec := SpellRecord.new()
	rec.stage = 1
	rec.phase_index = 0
	rec.uid = 7          # 非 0 = 符卡
	rec.difficulty = 1
	var info := {rec = rec, boss_index = 0, phase_index = 0, diffs = {1: rec}, label = "符卡1",
		boss = _mk_boss([0, 1, 2, 3])}
	var phases: Array[Dictionary] = [info]
	menu._phases = phases
	var named := PhaseData.new()
	named.name = "夹具「符卡」"
	named.hp = 1000
	named.time_limit = 30.0
	named.uid = 7
	BossCatalog.set_catalog_override({1: [BossData.new().normal_phase(named)]})
	menu._build_diff_list()
	BossCatalog.clear_catalog_override()
	await get_tree().process_frame
	var spell_entry: VBoxContainer = menu._diff_box.get_child(1)
	var spell_name := (spell_entry.get_child(0) as Label).text
	var spell_h := int(spell_entry.size.y)

	assert_eq(nonspell_name, "", "非符不显示名字")
	assert_eq(spell_name, "夹具「符卡」", "符卡显示卡名")
	assert_eq(nonspell_h, spell_h, "两种状态选项高度必须一致（非符靠空行占位）")


## EX 面（该面 Boss 只配 Extra 档）：三级难度槽 = **仅 Extra 一档**，且该记录可选。
## 回归（2026-09-26 作者报）：`MENU_DIFFS` 硬编码 [0,1,2,3] → EX 面 `configured` 恒为空 →
## 四个槽全锁 `?`、`_diff_index` 停在 -1 → 卡在菜单里"看得见也点不动"。
func test_extra_only_stage_lists_extra_slot():
	var menu = _mk_menu()
	var boss := _mk_boss([4])
	BossCatalog.set_catalog_override({9: [boss]})

	var rec := SpellRecord.new()
	rec.stage = 9
	rec.boss_index = 0
	rec.phase_index = 0
	rec.character = 0
	rec.difficulty = 4
	rec.uid = 161
	var info := {rec = rec, boss_index = 0, phase_index = 0, diffs = {4: rec}, label = "道中·符卡1", boss = boss}
	var phases: Array[Dictionary] = [info]
	menu._phases = phases
	menu._phase_index = 0
	menu._build_diff_list()
	BossCatalog.clear_catalog_override()

	assert_eq(menu._diff_entries.size(), 1, "EX 面只列 Extra 一槽（不是固定 4 槽）")
	assert_eq(menu._diff_entries[0].diff, SpellRecord.Difficulty.EXTRA, "该槽就是 Extra")
	assert_eq(menu._diff_entries[0].is_locked, false, "有记录 + 该难度有阶段 → 可选")
	assert_eq(menu._diff_index, 0, "初始索引跳到 Extra（可开始练习）")


## 回归（2026-09-26 作者报）：二级（阶段）列表超长会**膨胀出面板**。
## 现在按 PhaseBox 实测高度开窗：只渲染放得下的行数，选中项上下移动时窗口跟着滚。
func test_phase_list_window_follows_selection():
	var menu = _mk_menu()
	await get_tree().process_frame          # 让锚点布局生效 → PhaseBox 有实测高度
	var limit: int = menu._rows_visible(menu._phase_box)
	assert_gt(limit, 1, "PhaseBox 应能量出可视行数（实测 %d）" % limit)

	var total: int = limit + 3              # 故意超出容量
	menu._phases = _mk_many_phases(total)
	menu._section = menu.Section.PHASE
	menu._phase_index = 0
	menu._build_phase_list()
	assert_eq(menu._phase_box.get_child_count(), limit, "只渲染放得下的行数（不膨胀出面板）")
	assert_eq(_phase_labels(menu)[0], "P0", "初始窗口从第 1 项开始")

	menu._phase_index = limit               # 往下移动，越过窗口下沿
	menu._highlight()
	assert_eq(menu._phase_offset, 1, "越过下沿 → 窗口下滚一行")
	assert_eq(menu._phase_box.get_child_count(), limit, "任何位置上渲染行数都不超过容量")
	assert_true(_phase_labels(menu).has("P%d" % limit), "选中项必须出现在窗口里")
	assert_eq(menu._phase_local_index(), limit - 1, "选中项落在窗口末行")
	assert_eq(_phase_labels(menu)[0], "P1", "旧行出、新行入（1、2、3 → 2、3、4…）")

	menu._phase_index = total - 1           # 移到最后一项
	menu._highlight()
	assert_eq(menu._phase_offset, total - limit, "移到末项 → 窗口贴底")
	assert_true(_phase_labels(menu).has("P%d" % (total - 1)), "末项必须在窗口里")

	menu._phase_index = 0                   # 往回移动
	menu._highlight()
	assert_eq(menu._phase_offset, 0, "回到首项 → 窗口回顶")
	assert_eq(_phase_labels(menu)[0], "P0", "首项在窗口首行")
	assert_eq(menu._phase_local_index(), 0, "选中项回到窗口首行")


## 滚动提示：▲ = 上面还有、▼ = 下面还有，中间是可见区间/总数；全都看得见时为空串。
func test_phase_scroll_hint_shows_hidden_ends():
	var menu = _mk_menu()
	await get_tree().process_frame
	var limit: int = menu._rows_visible(menu._phase_box)
	assert_gt(limit, 1, "PhaseBox 应能量出可视行数（实测 %d）" % limit)
	var total: int = limit + 3
	menu._phases = _mk_many_phases(total)
	menu._section = menu.Section.PHASE
	menu._phase_index = 0
	menu._build_phase_list()

	# 窗口贴顶：只有下面还有
	var top_hint: String = menu._phase_scroll_hint.text
	assert_false(top_hint.contains("▲"), "贴顶时不应有「上面还有」：%s" % top_hint)
	assert_true(top_hint.contains("▼"), "贴顶时下面还有 → 应有 ▼：%s" % top_hint)
	assert_true(top_hint.contains("1–%d / %d" % [limit, total]), "应显示可见区间/总数：%s" % top_hint)

	# 中间：两头都有
	menu._phase_index = limit
	menu._highlight()
	var mid_hint: String = menu._phase_scroll_hint.text
	assert_true(mid_hint.contains("▲") and mid_hint.contains("▼"), "中间位置两头都还有：%s" % mid_hint)
	assert_true(mid_hint.contains("2–%d / %d" % [limit + 1, total]), "区间随窗口滚动：%s" % mid_hint)

	# 窗口贴底：只有上面还有
	menu._phase_index = total - 1
	menu._highlight()
	var bottom_hint: String = menu._phase_scroll_hint.text
	assert_true(bottom_hint.contains("▲"), "贴底时上面还有 → 应有 ▲：%s" % bottom_hint)
	assert_false(bottom_hint.contains("▼"), "贴底时不应有「下面还有」：%s" % bottom_hint)

	# 装得下 → 不显示（不制造噪音）
	menu._phases = _mk_many_phases(limit)
	menu._phase_index = 0
	menu._build_phase_list()
	assert_eq(menu._phase_scroll_hint.text, "", "全部看得见 → 提示为空")

	# 二级清空（无记录）→ 提示也清
	menu._phases.clear()
	menu._stages.clear()
	menu._build_lists()
	assert_eq(menu._phase_scroll_hint.text, "", "二级清空 → 提示为空")


## 量不到高度（未入树 / 尚未布局）→ `_rows_visible` 返回 -1，调用方退回「全渲染」，不藏内容
func test_rows_visible_is_unknown_without_layout():
	var menu = _mk_menu()
	var box := VBoxContainer.new()          # 未入树 → 无尺寸
	assert_eq(menu._rows_visible(box), -1, "量不到高度 → -1")
	box.free()


## 导航跳过锁定：向下从 Normal 到 Hard，再向下 wrap 回 Normal
func test_move_diff_skips_locked():
	var menu = _mk_menu()
	# 4 槽都在；Normal(1)/Hard(2) 解锁，Easy(0)/Lunatic(3) 锁定
	menu._phases = _mk_phases({1: SpellRecord.new(), 2: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	menu._build_diff_list()

	menu._diff_index = 1  # Normal
	menu._move_diff(1)    # 向下
	assert_eq(menu._diff_index, 2, "向下 Normal → Hard（跳过锁定项）")
	menu._move_diff(1)    # 再向下：Lunatic 锁定 → wrap 到 Normal
	assert_eq(menu._diff_index, 1, "再向下 wrap 回 Normal")

	menu._move_diff(-1)   # 从 Normal 向上：Easy 锁定 → wrap 到 Hard
	assert_eq(menu._diff_index, 2, "向上 wrap 到 Hard")


## phase 级变蓝：花名册里全部**已配置**难度槽都收齐才算全收
func test_phase_capture_all_requires_all_configured_slots():
	var original_book: SpellRecordBook = SaveData.spell_book
	var book := SpellRecordBook.new()
	SaveData.spell_book = book
	var menu = _mk_menu()
	var boss := _mk_boss([0, 1, 2, 3])

	# 只有 Normal(1) 收 → 不算全收（Easy/Hard/Lunatic 还空着）
	var r_n := SpellRecord.new()
	r_n.stage = 1; r_n.boss_index = 0; r_n.phase_index = 0; r_n.character = 0; r_n.difficulty = 1
	r_n.practice_captures = 1
	book.records = [r_n]
	assert_ne(menu._phase_capture_all(1, 0, 0, boss), 2, "只有 Normal 收不算全收")

	# 4 个难度全收 → 蓝(2)
	var recs: Array[SpellRecord] = []
	for d in [0, 1, 2, 3]:
		var rec := SpellRecord.new()
		rec.stage = 1; rec.boss_index = 0; rec.phase_index = 0; rec.character = 0; rec.difficulty = d
		rec.practice_captures = 1
		recs.append(rec)
	book.records = recs
	assert_eq(menu._phase_capture_all(1, 0, 0, boss), 2, "4 个难度都收齐 → 蓝")

	# Boss 只配置 Normal → 收 Normal 即全收
	book.records = [r_n]
	assert_eq(menu._phase_capture_all(1, 0, 0, _mk_boss([1])), 2, "只配置 Normal 时收 Normal 即全收")

	SaveData.spell_book = original_book  # 还原


## 四个槽全锁（无记录 或 无阶段）→ 无可选难度（_diff_index = -1），按 Z 不开始
func test_all_locked_has_no_selectable_diff():
	SaveData.selected_difficulty = 1
	var menu = _mk_menu()
	# 只有 Normal 有阶段，且没有任何记录 → 全锁
	menu._phases = _mk_phases({}, _mk_boss([1]))
	menu._phase_index = 0
	menu._build_diff_list()
	assert_eq(menu._diff_entries.size(), 4, "固定 4 槽")
	assert_eq(menu._diff_index, -1, "全锁 → 无可选难度")
	menu._start_practice()
	assert_eq(SaveData.selected_difficulty, 1, "全锁时按 Z 不应开始/改选择")


## 锁定难度不可开始练习
func test_start_practice_guard_locked():
	SaveData.selected_difficulty = 1
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	menu._build_diff_list()
	menu._diff_index = 0  # Easy 锁定
	# 直接调用应被守卫拦截（不改 selected_difficulty）
	menu._start_practice()
	assert_eq(SaveData.selected_difficulty, 1, "锁定难度不改变选择")


## 第一级舞台名走 `StageCatalog`（内容侧 `display_name`），**不自己拼 "Stage %d"** ——
## 否则「3 面 B 线」（id 4）这类 id 与名字对不上的舞台就没法显示。
func test_stage_label_uses_catalog_name():
	var menu = _mk_menu()
	var stages: Array[int] = [1]
	menu._stages = stages
	menu._build_lists()
	assert_eq(menu._stage_box.get_child_count(), 1, "应建 1 行舞台名")
	assert_eq((menu._stage_box.get_child(0) as Label).text, StageCatalog.display_name_of(1),
		"舞台名应来自 StageCatalog（与 id 解耦）")
	# 对齐方式不锁：那是纯视觉偏好（居中/左对齐都试过），锁了只会在调整时白红


# ═══════════ 第一级切换 stage → 第二级必须重建 ═══════════

func _mk_rec(stage: int, boss: int, phase: int) -> SpellRecord:
	var rec := SpellRecord.new()
	rec.stage = stage
	rec.boss_index = boss
	rec.phase_index = phase
	rec.character = 0
	rec.difficulty = 1
	rec.uid = 0
	rec.phase_number = phase + 1
	return rec


## 回归（2026-09-23）：在第一级按 ↓ 切 stage 时，第二级列表必须跟着重建。
## 曾经 `_change_stage()` 只换 `_phases` **数据**、不重建 `_phase_box` → 二级仍显示上一个 stage 的行，
## 而且与三级（按新 `_phases` 建）自相矛盾：二级写着「非符1/非符2/符卡1」、三级却是新 stage 的内容。
func test_stage_nav_rebuilds_phase_list():
	var saved_book: SpellRecordBook = SaveData.spell_book
	var book := SpellRecordBook.new()
	book.records.append(_mk_rec(1, 0, 0))   # stage1 两张
	book.records.append(_mk_rec(1, 0, 1))
	book.records.append(_mk_rec(2, 0, 0))   # stage2 一张
	SaveData.spell_book = book

	var menu = _mk_menu()
	menu._char_index = 0
	menu._build_data()
	menu._build_lists()
	assert_eq(menu._stages.size(), 2, "两个 stage")
	assert_eq(menu._phases.size(), 2, "stage1 有 2 张")
	assert_eq(menu._phase_box.get_child_count(), 2, "二级应显示 2 行")

	menu._set_idx(1)        # 模拟第一级按 ↓
	menu._highlight()
	assert_eq(menu._stage_index, 1, "已切到第二个 stage")
	assert_eq(menu._phases.size(), 1, "数据切到 stage2（1 张）")
	assert_eq(menu._phase_box.get_child_count(), 1, "**二级 UI 必须跟着重建**（回归点）")

	# 反方向：切回 stage1 也要能长回来（防止只清不建）
	menu._set_idx(0)
	menu._highlight()
	assert_eq(menu._phase_box.get_child_count(), 2, "切回 stage1 二级应恢复 2 行")

	SaveData.spell_book = saved_book


## 从练习返回：还原到**第三级**（DIFF）与选中项，并消费掉状态
func test_restore_return_state_goes_to_third_level():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	menu._phase_index = 0
	PracticeSession.restore_menu_on_enter = true
	PracticeSession.return_menu_state = {"section": 2, "stage": 0, "phase": 0, "diff": 1, "char": 0}
	menu._restore_return_state()
	assert_eq(menu._section, 2, "应回到第三级（DIFF = 2）")
	assert_eq(PracticeSession.return_menu_state, {}, "状态应被消费（否则下次正常进入也会跳级）")


## 没有待还原状态时，什么都不动（正常进入不受影响）
func test_restore_return_state_is_noop_without_state():
	var menu = _mk_menu()
	PracticeSession.return_menu_state = {}
	menu._section = 0
	menu._restore_return_state()
	assert_eq(menu._section, 0, "无状态时不改动层级")


## 回归（作者报）：**残留状态但没有"本次是返回"的授权** → 不许跳级
## （从主菜单正常进入符卡练习时，上一局的状态还在，曾被误消费而直接进第三级）
func test_stale_state_without_authorization_is_ignored():
	var menu = _mk_menu()
	menu._phases = _mk_phases({1: SpellRecord.new()}, _mk_boss([0, 1, 2, 3]))
	PracticeSession.return_menu_state = {"section": 2, "stage": 0, "phase": 0, "diff": 1, "char": 0}
	PracticeSession.restore_menu_on_enter = false      # ← 不是"返回"，只是正常进入
	menu._section = 0
	menu._restore_return_state()
	assert_eq(menu._section, 0, "未授权 → 不跳级（正常进入仍是第一级）")
	assert_eq(PracticeSession.return_menu_state, {}, "残留状态也应被清掉，避免下次再犯")


# ═══════════ 人物选择：进菜单 / 从练习返回都要"同一个人" ═══════════

## 夹具记录（指定人物）
func _mk_rec_char(stage: int, boss: int, phase: int, char_idx: int) -> SpellRecord:
	var rec := _mk_rec(stage, boss, phase)
	rec.character = char_idx
	return rec


## 回归（作者报）：**从练习返回后，人物选择必须回到同一个人**。
## 病根：`on_enter()` 在建列表**之前**就把 `_char_name` 写成了那一刻的 `_char_index`
## （新实例 = 0），而 `_char_index` 是 `_restore_return_state()` 之后才被还原的
## —— 标签因此停在 0 号人物，和已经按 1 号人物重建的记录列表自相矛盾。
func test_return_from_practice_restores_same_character():
	var saved_book: SpellRecordBook = SaveData.spell_book
	var saved_char: int = SaveData.selected_character
	var book := SpellRecordBook.new()
	book.records.append(_mk_rec_char(1, 0, 0, 0))
	book.records.append(_mk_rec_char(1, 0, 0, 1))
	SaveData.spell_book = book
	SaveData.selected_character = 0

	var menu = _mk_menu()
	PracticeSession.restore_menu_on_enter = true
	PracticeSession.return_menu_state = {"section": 2, "stage": 0, "phase": 0, "diff": 0, "char": 1}
	menu.on_enter()

	assert_eq(menu._char_index, 1, "还原后内部人物 = 1（这条本来就对）")
	assert_eq(menu._char_name.text, "← %s →" % SpellRecord.CHAR_NAMES[1],
		"**人物标签也要回到 1 号**（实得：%s）" % menu._char_name.text)

	SaveData.spell_book = saved_book
	SaveData.selected_character = saved_char


## 进菜单的**起点** = 上次选的那个人物（与 `player_data_menu` 同口径）——
## 否则"退出再进来"永远回到 0 号人物。
func test_enter_starts_from_last_selected_character():
	var saved_book: SpellRecordBook = SaveData.spell_book
	var saved_char: int = SaveData.selected_character
	SaveData.spell_book = SpellRecordBook.new()
	SaveData.selected_character = 1

	var menu = _mk_menu()
	PracticeSession.return_menu_state = {}
	PracticeSession.restore_menu_on_enter = false
	menu.on_enter()

	assert_eq(menu._char_index, 1, "起点跟着 SaveData.selected_character")
	assert_eq(menu._char_name.text, "← %s →" % SpellRecord.CHAR_NAMES[1], "标签与内部一致")

	SaveData.spell_book = saved_book
	SaveData.selected_character = saved_char

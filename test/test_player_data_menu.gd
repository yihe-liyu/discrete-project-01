extends GutTest
## 玩家数据菜单 · 符卡记录页：**列出该难度下的全部符卡**（不看记录），三档显示：
##   ① 未遇见 → uid +「？？？」    ② 遇见过（有记录）→ 真名    ③ 至少收取过一次 → 真名**蓝色**
##
## 回归：`_collect_cards()` 曾读 `record.name`（`SpellRecord` 没这个字段）→ 打开菜单即崩，
## 名字要**现从花名册取**；列表也曾只列"有记录的卡" → 没遇见的整张看不见。

const MENU := preload("res://scenes/ui/player_data_menu.tscn")
const MENU_SCRIPT := preload("res://scripts/scenes/player_data_menu.gd")


func _open_menu() -> Control:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame     # _ready() 里就会 `_collect_cards()`
	return menu


## 合成"卡片字典"（列表的输入形态；stage 90 = 纯夹具，不绑真实内容）
func _mk_cards(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in count:
		out.append({
			"stage": 90, "phase_index": i, "boss_index": 0,
			"uid": 900 + i, "name": "夹具符卡%d" % i,
		})
	return out


## 按卡片字典造一条记录（key = stage/phase_index/char/diff，另校验 uid）
func _mk_record(card: Dictionary, captures: int, attempts: int) -> SpellRecord:
	var rec := SpellRecord.new()
	rec.uid = int(card["uid"])
	rec.phase_type = SpellRecord.PhaseType.SPELL
	rec.stage = int(card["stage"])
	rec.phase_index = int(card["phase_index"])
	rec.boss_index = int(card["boss_index"])
	rec.character = 0
	rec.difficulty = 1
	rec.captures = captures
	rec.attempts = attempts
	return rec


# ═══════════ 列表来源：花名册（全部符卡） ═══════════

## 一条记录都没有，也要列出该难度的全部符卡 —— 没遇见的显示 uid + ？？？
func test_collect_cards_lists_whole_roster_without_records() -> void:
	var backup: Array = SaveData.spell_book.records.duplicate()
	var saved_diff: int = SaveData.selected_difficulty
	SaveData.spell_book.records = []
	SaveData.selected_difficulty = 1                  # 1 面 Normal 有真实符卡

	var menu: Control = await _open_menu()

	assert_gt(menu._cards.size(), 0, "没记录也该列出花名册里的符卡")
	for card in menu._cards:
		assert_gt(int(card["uid"]), 0, "只列符卡（非符没有 uid）")
		assert_ne(String(card["name"]), "", "名字现从花名册取（记录里没有 name）")

	SaveData.spell_book.records = backup
	SaveData.selected_difficulty = saved_diff


# ═══════════ 三档显示 ═══════════

func test_row_shows_three_tiers() -> void:
	var backup: Array = SaveData.spell_book.records.duplicate()
	var saved_diff: int = SaveData.selected_difficulty
	var saved_char: int = SaveData.selected_character
	SaveData.selected_difficulty = 1
	SaveData.selected_character = 0
	SaveData.spell_book.records = []

	var menu: Control = await _open_menu()
	assert_gt(menu._cards.size(), 2, "夹具前提：该难度至少 3 张卡")
	var encountered: Dictionary = menu._cards[0]
	var captured: Dictionary = menu._cards[1]
	SaveData.spell_book.records = [
		_mk_record(encountered, 0, 3),   # 遇见过、没收取
		_mk_record(captured, 2, 5),      # 收取过
	]

	# ① 未遇见：名字位只有问号（uid 照常显示，便于按 uid 找卡）
	var unknown_row: HBoxContainer = menu._make_row(menu._cards[2])
	var unknown_name := unknown_row.get_child(1) as Label
	assert_eq(unknown_name.text, MENU_SCRIPT.UNKNOWN_NAME, "未遇见 → uid + 问号")
	assert_ne(unknown_name.get_theme_color("font_color"), MENU_SCRIPT.CAPTURED_NAME_COLOR,
		"未遇见不该是收取蓝")
	var uid_shown: String = (unknown_row.get_child(0) as Label).text
	var uid_cn: String = menu._to_full(str(menu._cards[2]["uid"]))   # uid 显示成全角数字
	assert_true(uid_shown.contains(uid_cn), "uid 仍要显示（全角数字 %s，实得 %s）" % [uid_cn, uid_shown])

	# ② 遇见过未收取：真名、非蓝
	var enc_name := (menu._make_row(encountered).get_child(1)) as Label
	assert_ne(enc_name.text, MENU_SCRIPT.UNKNOWN_NAME, "遇见过 → 显示真名")
	assert_ne(enc_name.get_theme_color("font_color"), MENU_SCRIPT.CAPTURED_NAME_COLOR,
		"没收取过 → 不是蓝色")

	# ③ 收取过：真名 + 蓝
	var cap_name := (menu._make_row(captured).get_child(1)) as Label
	assert_ne(cap_name.text, MENU_SCRIPT.UNKNOWN_NAME, "收取过 → 显示真名")
	assert_eq(cap_name.get_theme_color("font_color"), MENU_SCRIPT.CAPTURED_NAME_COLOR,
		"至少收取过一次 → 符卡名蓝色")

	SaveData.spell_book.records = backup
	SaveData.selected_difficulty = saved_diff
	SaveData.selected_character = saved_char


# ═══════════ 分页：每页行数按面板实测高度算 ═══════════

## 回归（2026-09-26 作者报）：符卡记录分页曾写死 `PER_PAGE = 6` → 面板下方还空一大半就翻页。
## 现在每页行数由面板实测高度决定：面板变高 → 行数跟着变多。
func test_rows_per_page_follows_panel_height() -> void:
	var menu: Control = await _open_menu()
	var panel: PanelContainer = menu.get_node("RecordView/RecordPanel")
	var before: int = menu._rows_per_page()
	assert_gt(before, 0, "应能按面板高度算出每页行数")

	panel.size.y += 200.0
	assert_gt(menu._rows_per_page(), before, "面板变高 → 每页行数变多")
	panel.size.y -= 400.0
	assert_lt(menu._rows_per_page(), before, "面板变矮 → 每页行数变少")


## 一页必须**填满**实测容量（而不是填到某个写死值），且翻页 / 页码越界都不出空白页。
## 用**注入的卡片**测分页（列表来源已改成花名册，分页逻辑与来源无关）。
func test_page_fills_measured_capacity() -> void:
	var menu: Control = await _open_menu()
	menu._cards = _mk_cards(30)
	menu._show_record_view()
	await get_tree().process_frame

	var box: VBoxContainer = menu.get_node("RecordView/RecordPanel/ListBox")
	assert_gt(menu._per_page, 6, "面板装得下的行数应多于写死的 6（回归点）")
	assert_eq(menu._per_page, menu._rows_per_page(), "每页行数应等于实测容量")
	assert_eq(box.get_child_count(), menu._per_page, "第一页应填满实测容量")
	assert_eq(menu._total_pages(), int(ceil(30.0 / menu._per_page)), "页数 = 卡数 / 每页行数")

	# 末页：只剩余数那么多行
	menu._page = menu._total_pages() - 1
	menu._render()
	await get_tree().process_frame
	var expected_last: int = 30 - menu._per_page * (menu._total_pages() - 1)
	assert_eq(box.get_child_count(), expected_last, "末页行数 = 剩余卡数")

	# 页码越界 → 收敛到末页（不显示空白页）
	menu._page = 99
	menu._render()
	await get_tree().process_frame
	assert_eq(menu._page, menu._total_pages() - 1, "页码越界应收敛")
	assert_eq(box.get_child_count(), expected_last, "收敛后仍是末页内容")

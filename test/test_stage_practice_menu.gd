extends GutTest
## 关卡练习菜单：一级列表来源（可玩清单）、进页会话标志、难度槽、选择写回。
##
## 与 `test_data_validity` 的分工：那边验**数据合法**（注册表只收可玩的），
## 这里验**菜单行为** —— 不数真实内容有几面、也不写死面名，加面 / 改名不该让它红。
##
## 回归：本页曾是**占位**（只设旗标 + 淡入标题，没有任何列表），
## 于是"关卡练习"在菜单里可点、进去却选不了任何关。

const MENU := preload("res://scenes/ui/stage_practice_menu.tscn")
const MENU_SCRIPT := preload("res://scripts/scenes/stage_practice_menu.gd")


func after_each() -> void:
	# 本页会改全局选择与会话标志（per-run static）——用完还原，别污染后续用例
	SaveData.reset_session()


func _open() -> Control:
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)     # 入树 → `_ready()` → `@onready` 就位
	menu.on_enter()
	return menu


## 菜单眼里的"可玩清单"（与实现同源：注册表里真有 create_script 的面）
func _playable_count() -> int:
	var count := 0
	for stage in StageCatalog.all():
		if stage != null and stage.create_script != null:
			count += 1
	return count


func _first_playable() -> StageData:
	for stage in StageCatalog.all():
		if stage != null and stage.create_script != null:
			return stage
	return null


# ═══════════ 一级列表 ═══════════

func test_lists_exactly_the_playable_stages():
	var expected := _playable_count()
	assert_gt(expected, 0, "至少应有一面可玩（否则本页没有意义）")

	var menu := _open()
	await wait_frames(1)

	var box: VBoxContainer = menu.get_node_or_null("StageBox")
	assert_not_null(box, "场景应有 StageBox（一级列表容器）")
	if box == null:
		return
	assert_eq(box.get_child_count(), expected,
		"一级列表应逐行对应「可玩清单」（= StageCatalog 里有 create_script 的面）")


func test_secondary_list_is_empty_until_entered():
	var menu := _open()
	await wait_frames(1)
	var box: VBoxContainer = menu.get_node_or_null("DiffBox")
	assert_not_null(box, "场景应有 DiffBox（二级列表容器）")
	if box == null:
		return
	assert_eq(box.get_child_count(), 0, "停在一级时二级不留行（否则看着像可以直接选难度）")


## 回归：**二级不显示** —— 停在一级时 `_highlight()` 会把 `_diff_box` 清空（免得"看着能选"），
## 而"确认进二级"那一步当时只改了 `_section`、**没重建列表** ⇒ 进二级是空的、选不了难度。
func test_confirm_enters_secondary_and_shows_difficulties():
	var menu := _open()
	await wait_frames(1)

	var stage_box: VBoxContainer = menu.get_node_or_null("StageBox")
	var diff_box: VBoxContainer = menu.get_node_or_null("DiffBox")
	assert_not_null(stage_box, "场景应有 StageBox")
	assert_not_null(diff_box, "场景应有 DiffBox")
	if stage_box == null or diff_box == null:
		return

	assert_gt(stage_box.get_child_count(), 0, "一级应先有行")
	assert_eq(diff_box.get_child_count(), 0, "进二级前二级应为空")

	await menu.confirm_current()    # 确认键：一级 →（闪一下）→ 二级

	assert_gt(diff_box.get_child_count(), 0,
		"进二级后**必须**有难度行（回归：二级不显示）")
	var stage := _first_playable()
	if stage != null:
		assert_eq(diff_box.get_child_count(), MENU_SCRIPT.menu_diffs_for(stage).size(),
			"二级行数应等于当前面的难度槽数")


## 确认**要先播反馈**再进下一级（与 `SpellPracticeMenu._flash_then` 同观感）。
## 判据用"时间窗"：确认后**一小段内**二级仍不该出现（在闪），过了反馈时长才出现。
## 这样一旦有人把闪烁删掉、改成立刻跳级，第一条断言就会红。
func test_confirm_plays_feedback_before_advancing():
	var menu := _open()
	await wait_frames(1)
	var diff_box: VBoxContainer = menu.get_node_or_null("DiffBox")
	assert_not_null(diff_box, "场景应有 DiffBox")
	if diff_box == null:
		return

	menu.confirm_current()          # 不 await：反馈期内
	await wait_seconds(0.1)         # 早于反馈时长（2×0.06s）
	assert_eq(diff_box.get_child_count(), 0,
		"确认后应先播闪烁反馈，二级不是立刻出现")

	await wait_seconds(0.4)         # 过了反馈时长
	assert_gt(diff_box.get_child_count(), 0, "反馈播完才进二级")


## 最高保真的一条：**按 Z 走真实 `_input`**（上面两条直接调 `confirm_current()`，绕过了按键接线）。
## 挡住"按键名写错 / 忘了接 `_input` / `_is_input_ready` 没放行"这一类"按了没反应"。
func test_accept_key_reaches_secondary():
	var menu := _open()
	await wait_seconds(0.5)          # 淡入 0.35s 之后 `_is_input_ready` 才放行
	var diff_box: VBoxContainer = menu.get_node_or_null("DiffBox")
	assert_not_null(diff_box, "场景应有 DiffBox")
	if diff_box == null:
		return
	assert_eq(diff_box.get_child_count(), 0, "进二级前二级应为空")

	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await wait_seconds(0.5)          # 等闪烁反馈播完（0.24s）

	assert_gt(diff_box.get_child_count(), 0, "按确认键（ui_accept）应进二级并建出难度列")


# ═══════════ 会话标志 ═══════════

func test_enter_sets_stage_practice_and_resets_session():
	SaveData.current_stage_id = 7          # 脏进度：进练习必须先被复位
	SaveData.is_stage_practice = false

	var _menu := _open()
	await wait_frames(1)

	assert_true(SaveData.is_stage_practice, "进关卡练习 = 置位（唯一复位点仍是 reset_session）")
	assert_eq(SaveData.current_stage_id, 1, "进练习先经过 reset_session()（唯一复位入口）")


# ═══════════ 难度槽（纯函数，喂夹具） ═══════════

func test_difficulty_slots_normal_face():
	var normal := StageData.new()
	normal.stage_id = 90
	normal.stage_no = 2
	var diffs: Array[int] = MENU_SCRIPT.menu_diffs_for(normal)
	assert_eq(diffs.size(), 4, "普通面 = 4 档（Easy~Lunatic，与 difficulty_screen 一致）")
	assert_true(diffs.has(SpellRecord.Difficulty.EASY), "普通面应含 Easy")
	assert_true(diffs.has(SpellRecord.Difficulty.LUNATIC), "普通面应含 Lunatic")


func test_difficulty_slots_extra_face():
	var extra := StageData.new()
	extra.stage_id = 91
	extra.stage_no = 7                     # 约定：EX 面 stage_no = 7（见 StageData.stage_no）
	var diffs: Array[int] = MENU_SCRIPT.menu_diffs_for(extra)
	assert_eq(diffs.size(), 1, "EX 面只有一档")
	assert_true(diffs.has(SpellRecord.Difficulty.EXTRA), "EX 面应是 Extra")


# ═══════════ 选择写回 ═══════════

func test_commit_selection_writes_global_choices():
	var expected := _first_playable()
	assert_not_null(expected, "至少应有一面可玩")
	if expected == null:
		return

	var menu := _open()
	await wait_frames(1)
	assert_true(menu.commit_selection(), "有可选面时应提交成功")
	assert_eq(SaveData.current_stage_id, expected.stage_id, "应写回选中的面")
	assert_true(SaveData.is_stage_practice, "提交后仍处练习模式（通关回标题靠它）")
	assert_true(SaveData.selected_difficulty >= 0, "应写回一个合法难度")


## 回归（2026-10-04 作者实测「关卡练习菜单的黑幕怎么没有了」）：
## `BasePage._create_overlay()` 会按名字**复用**场景里的 `Overlay` 并把它的 `modulate.a` 归 0
## ⇒ 淡入时**必须**把它拉回 1。只 tween `self.modulate` 的话有效 alpha = `0.55 × 0` = **黑幕看不见**。
func test_overlay_curtain_is_restored_after_enter():
	var menu: Control = MENU.instantiate()
	add_child_autofree(menu)
	await wait_frames(1)
	var ov := menu.get_node("Overlay") as ColorRect
	assert_not_null(ov, "场景里应有 Overlay（黑幕）")
	if ov == null:
		return
	assert_almost_eq(ov.modulate.a, 0.0, 0.01, "前提：BasePage 已把遮罩归 0（否则本用例没测到东西）")
	menu.on_enter()
	await wait_frames(40)          # 等淡入跑完（0.35s ≈ 21 帧）
	assert_almost_eq(ov.modulate.a, 1.0, 0.02, "遮罩自己的 modulate 必须淡到 1（不能一直停在 BasePage 归的 0）")
	assert_almost_eq(menu.modulate.a * ov.modulate.a * ov.color.a, 0.55, 0.02,
		"黑幕有效 alpha 应回到 0.55（= 0 就是作者看到的「黑幕没有了」）")

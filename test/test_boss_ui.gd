extends GutTest
## BossUI 场景声明式建树（R21）：倒计时 Label 与阶段点模板都在 .tscn 里，代码不再 .new()。

const BOSS_UI_SCENE := preload("res://scenes/ui/boss_ui.tscn")
const ANNOUNCE_SCENE := preload("res://scenes/ui/announce_label.tscn")
const BOSS_UI_SCRIPT := preload("res://scripts/scenes/boss_ui.gd")   # 取「失败」常量（该脚本没有 class_name）


## 回归（2026-09-26 作者报）：倒计时曾和符卡名**同高**（局部 y=16，而名字视觉带 14–56）→ 压着名字。
## 现在位置声明在场景里，且必须落在符卡名**视觉底之下**（锁关系，不锁具体像素）。
func test_timer_sits_below_spell_name() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var control := ui.get_node("Control") as Control
	var timer := ui.get_node("Control/TimerLabel") as Label
	assert_not_null(timer, "倒计时 Label 在场景里")

	# 符卡名（BOSS 大字报）右停位的**视觉底**：布局高 × (1+SHRINK)/2（缩放绕中心）
	var announce := ANNOUNCE_SCENE.instantiate() as AnnounceLabel
	control.add_child(announce)   # 随 ui 的 add_child_autofree 一起回收
	announce.add_theme_font_size_override("font_size", AnnounceLabel.DEFAULT_FONT_SIZE)
	announce.text = "阳符「宏辉抑世」"
	announce.size = announce.get_minimum_size()
	var name_bottom: float = announce.size.y * (1.0 + AnnounceLabel.SHRINK) / 2.0

	assert_gt(timer.offset_top, name_bottom,
		"倒计时必须在符卡名视觉底之下（倒计时顶=%.1f，名字底=%.1f）" % [timer.offset_top, name_bottom])
	assert_eq(timer.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "仍然水平居中")
	assert_false(timer.visible, "默认隐藏（等阶段开始才亮）")


func test_scene_declares_timer_and_dot_template() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	assert_not_null(ui.get_node_or_null("Control/TimerLabel"), "倒计时 Label 声明在场景里")
	assert_not_null(ui.get_node_or_null("Control/DotTemplate"), "阶段点模板声明在场景里")


func test_dot_template_hidden_and_sized() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var dot := ui.get_node_or_null("Control/DotTemplate") as ColorRect
	assert_not_null(dot, "模板在场景里")
	assert_false(dot.visible, "模板默认隐藏（不参与 HBox 布局）")
	assert_eq(dot.custom_minimum_size, Vector2(16.0, 16.0), "模板尺寸声明在场景里")


## 符卡宣言时放 `card` 音效（该资源曾在 AssetRegistry 注册却无人播放）
func test_spell_card_plays_card_sfx() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var card: AudioStream = AssetRegistry.sounds["card"]
	_clear_sfx_pool()
	ui._on_phase_start(_phase(5))
	# 断言池里被交进了 card 流（headless 下 playing 标志不可靠，故看 stream 身份）
	assert_true(_pool_has(card), "符卡宣言应播 card 音效")


## 非符不放宣言音
func test_nonspell_does_not_play_card_sfx() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var card: AudioStream = AssetRegistry.sounds["card"]
	_clear_sfx_pool()
	ui._on_phase_start(_phase(0))
	assert_false(_pool_has(card), "非符不该播 card 音效")


## 符卡结算横幅：`Boss` 发 `spell_result` → 场地正中偏上出现结算
func test_spell_result_shows_banner() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	assert_null(ui.get_node_or_null("Control/PhaseResultBanner"), "默认没有结算横幅")

	GameEvents.spell_result.emit(true, 12345, 12.34, false)

	var banner := ui.get_node_or_null("Control/PhaseResultBanner") as PhaseResultBanner
	assert_not_null(banner, "干净收取 → 应出现结算横幅")
	assert_eq((banner.get_node("Lines/Title") as Label).text, banner.captured_title, "标题 = 收取成功那条")
	assert_eq((banner.get_node("Lines/Bonus") as Label).text, banner.bonus_prefix + "12345",
			"分数行 = 前缀 + 实得奖励分")


## **横幅与阶段边界解耦**（作者要求：时长别和阶段间隔挂钩）：
## 下一张开卡不该掐掉还没淡完的横幅 —— 它只按自己的 @export 走完。
func test_next_phase_start_does_not_cut_banner() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	GameEvents.spell_result.emit(true, 12345, 1.0, false)
	var banner := ui.get_node_or_null("Control/PhaseResultBanner") as PhaseResultBanner

	ui._on_phase_start(_phase(5))        # 下一张符卡开打（报幕照常走）
	await get_tree().process_frame       # `clear()` 会 queue_free → 一帧后节点就无效了
	assert_true(is_instance_valid(banner), "横幅不该被阶段边界收掉（否则时长只能跟着阶段间隔走）")
	assert_eq(ui.get_node_or_null("Control/PhaseResultBanner"), banner, "还是同一张（没被换掉）")


## 唯一提前收掉横幅的是**又出了一张结算**：换新的，不叠两张
func test_second_spell_result_replaces_banner() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	GameEvents.spell_result.emit(true, 1, 1.0, false)
	var first := ui.get_node_or_null("Control/PhaseResultBanner") as PhaseResultBanner
	GameEvents.spell_result.emit(false, 0, 9.9, false)
	await get_tree().process_frame
	var banners: Array[Node] = []
	for child in ui.get_node("Control").get_children():
		if child is PhaseResultBanner:
			banners.append(child)
	assert_eq(banners.size(), 1, "同时只该有一张结算横幅")
	assert_ne(banners[0], first, "第二张结算应替换掉第一张")


## 收取失败（miss / bomb 作废）：横幅照出，但只亮「Bonus Failed」+ 击破时间
func test_spell_result_failed_hides_bonus_line() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	GameEvents.spell_result.emit(true, 12345, 5.0, true)
	var banner := ui.get_node_or_null("Control/PhaseResultBanner") as PhaseResultBanner
	assert_not_null(banner, "作废也要给结算横幅（只是不显示分数）")
	assert_eq((banner.get_node("Lines/Title") as Label).text, banner.failed_title, "标题 = 失败那条")
	assert_false((banner.get_node("Lines/Bonus") as Label).visible, "作废 → 不显示分数行")


func _phase(uid: int) -> PhaseData:
	var phase := PhaseData.new()
	phase.name = "夹具符卡"
	phase.uid = uid
	phase.hp = 1000
	phase.time_limit = 30.0
	return phase


## 清空 SFX 池与同帧去重表，避免上一条用例的残留影响
func _clear_sfx_pool() -> void:
	for player in AudioManager._sfx_players:
		player.stop()
		player.stream = null
	AudioManager._played_this_frame.clear()


func _pool_has(stream: AudioStream) -> bool:
	for player in AudioManager._sfx_players:
		if player.stream == stream:
			return true
	return false


## 奖励分作废（miss / bomb）→ **数字位换成「失败」两个字**，且之后不再被数字 tick 覆盖。
## 这是作者要的机制："击破前 miss 或用 bomb，这张符卡的奖励分数就无法获得，数字改为失败"。
func test_bonus_failed_shows_failed_text() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	ui._on_phase_start(_phase(5))
	var label: AnnounceLabel = ui._announce_label
	assert_not_null(label, "符卡阶段应有公告牌")

	GameEvents.phase_bonus_failed.emit()

	var bonus_label := label.get_node("BonusLabel") as Label
	assert_true(bonus_label.text.contains(BOSS_UI_SCRIPT.BONUS_FAILED_TEXT),
		"作废后数字位应显示「失败」（实得：%s）" % bonus_label.text)
	assert_true(bonus_label.text.begins_with(label.bonus_prefix),
		"前缀仍保留（奖励分数：失败）")


## 切「失败」之前，数字显示照常（作废只影响作废之后）
func test_bonus_failed_keeps_prefix_and_counting_still_works_before_it() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	ui._on_phase_start(_phase(5))
	var label: AnnounceLabel = ui._announce_label
	ui._on_tick(12345)
	assert_true((label.get_node("BonusLabel") as Label).text.contains("12345"), "作废前照常显示数字")

	GameEvents.phase_bonus_failed.emit()
	assert_true((label.get_node("BonusLabel") as Label).text.contains(BOSS_UI_SCRIPT.BONUS_FAILED_TEXT),
		"作废后切到「失败」")

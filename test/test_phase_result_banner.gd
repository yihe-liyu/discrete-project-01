extends GutTest
## 符卡结算横幅（`PhaseResultBanner`）：干净收取 / 失败（超时 / miss·bomb 作废）的文案与行显隐、
## 「渐显 → 停 → 渐隐」的顺序、以及落点（**倒计时之下、报幕大字之上**那条带子 —— 时长因此才自由）。

const BANNER_SCENE := preload("res://scenes/ui/phase_result_banner.tscn")
const BOSS_UI_SCENE := preload("res://scenes/ui/boss_ui.tscn")
const ANNOUNCE_SCENE := preload("res://scenes/ui/announce_label.tscn")


func _make_banner() -> PhaseResultBanner:
	var banner := BANNER_SCENE.instantiate() as PhaseResultBanner
	add_child_autofree(banner)
	return banner


func _title(banner: PhaseResultBanner) -> Label:
	return banner.get_node("Lines/Title") as Label


func _bonus(banner: PhaseResultBanner) -> Label:
	return banner.get_node("Lines/Bonus") as Label


func _time(banner: PhaseResultBanner) -> Label:
	return banner.get_node("Lines/Time") as Label


## 真值表：干净收取 = **击破了** 且 **奖励分没作废**（超时 / miss·bomb 都不算）
func test_is_clean_capture_truth_table() -> void:
	assert_true(PhaseResultBanner.is_clean_capture(true, false), "击破且没作废 = 干净收取")
	assert_false(PhaseResultBanner.is_clean_capture(true, true), "击破了但 miss / bomb 作废 → 不算干净收取")
	assert_false(PhaseResultBanner.is_clean_capture(false, false), "超时（没击破）→ 不算")
	assert_false(PhaseResultBanner.is_clean_capture(false, true), "超时 + 作废 → 不算")


## 默认隐藏（等 `show_result` 才亮）
func test_starts_hidden() -> void:
	assert_false(_make_banner().visible, "实例化后应隐藏")


## 干净收取：标题「Get Spell Card Bonus」+ 分数行 + 击破时间行
func test_clean_capture_shows_bonus_and_time() -> void:
	var banner := _make_banner()
	banner.show_result(true, 123456, 12.345, false)
	assert_true(banner.visible, "播放中应可见")
	assert_eq(_title(banner).text, banner.captured_title, "标题 = 收取成功那条")
	assert_true(_bonus(banner).visible, "干净收取要显示奖励分")
	assert_eq(_bonus(banner).text, banner.bonus_prefix + "123456", "分数 = 前缀 + 实得奖励分")
	assert_true(_time(banner).visible, "击破时间两种结果都要有")
	assert_eq(_time(banner).text, banner.time_prefix + "12.35", "用时两位小数（12.345 → 12.35）")


## 失败（击破了但 miss / bomb 作废）：只亮「Bonus Failed」+ 击破时间，**不显示分数**（那分没入账）
func test_failed_capture_hides_bonus_line() -> void:
	var banner := _make_banner()
	banner.show_result(true, 123456, 3.5, true)
	assert_eq(_title(banner).text, banner.failed_title, "作废 → 标题 = 失败那条")
	assert_false(_bonus(banner).visible, "作废 → 不显示分数行")
	assert_eq(_bonus(banner).text, "", "分数行文本也要清掉（不留上一张的残影）")
	assert_true(_time(banner).visible, "不管成败都要有击破时间")
	assert_eq(_time(banner).text, banner.time_prefix + "3.50", "用时照样两位小数")


## 超时（根本没击破）同样算收取失败
func test_timeout_shows_failed_title() -> void:
	var banner := _make_banner()
	banner.show_result(false, 0, 30.0, false)
	assert_eq(_title(banner).text, banner.failed_title, "超时 → 失败标题")
	assert_false(_bonus(banner).visible, "没击破 → 没有可展示的奖励分")
	assert_eq(_time(banner).text, banner.time_prefix + "30.00", "时间行照旧")


## 标题配色跟着结果走：干净收取金色 / 失败偏红（与阶段进度点的金 · 红同源）
func test_title_color_follows_outcome() -> void:
	var banner := _make_banner()
	banner.show_result(true, 1, 1.0, false)
	assert_eq(_title(banner).get_theme_color("font_color"), banner.captured_color, "干净收取 → 金色")
	banner.show_result(false, 0, 1.0, false)
	assert_eq(_title(banner).get_theme_color("font_color"), banner.failed_color, "失败 → 红")


## 落点：**水平居中于场地**（左右锚点/偏移对称）、**在场地垂直中线之上**（不去压自机）
func test_lines_centered_and_above_field_center() -> void:
	var lines := _make_banner().get_node("Lines") as Control
	assert_eq(lines.anchor_left, 0.5, "左锚点在中线")
	assert_eq(lines.anchor_right, 0.5, "右锚点在中线")
	assert_almost_eq(lines.offset_left, -lines.offset_right, 0.001, "左右偏移对称 → 水平居中")
	assert_lt(lines.anchor_top, 0.5, "在场地垂直中线**之上**")


## **时长自由的前提**：横幅块整体落在「倒计时之下、下一张报幕大字之上」那条带子里 ——
## 只有这样，横幅比阶段间隔长（作者把它调到 1.2s > 内容里的 1.0s）时才不会和报幕叠字。
## 锁**关系**不锁像素（与 `test_boss_ui.test_timer_sits_below_spell_name` 同法）：
## 以后改倒计时位置 / 报幕字号 / 行高 / 本场景落点，这条会替我们红一次。
func test_block_fits_between_countdown_and_spell_announce() -> void:
	var field_h: float = GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP

	# 横幅块的真实高度：三行最小高 + 行距（不写死 160）
	var lines := _make_banner().get_node("Lines") as VBoxContainer
	var block_h := 0.0
	for child in lines.get_children():
		block_h += (child as Control).get_combined_minimum_size().y
	block_h += lines.get_theme_constant("separation") * (lines.get_child_count() - 1)
	var top := lines.anchor_top * field_h
	var bottom := top + block_h

	# 上面那个邻居：BossUI 的倒计时（位置声明在 boss_ui.tscn，本局有效值 = offset_bottom）
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var timer_bottom: float = (ui.get_node("Control/TimerLabel") as Control).offset_bottom

	# 下面那个邻居：下一张符卡名大字**最大态**的视觉顶（缩放绕中心 pivot → 中心 − 布局高×3/2）
	var announce := ANNOUNCE_SCENE.instantiate() as AnnounceLabel
	add_child_autofree(announce)
	announce.add_theme_font_size_override("font_size", AnnounceLabel.DEFAULT_FONT_SIZE)
	announce.text = "阳符「宏辉抑世」"          # 8 字夹具（只影响宽度，不影响行高）
	announce.size = announce.get_minimum_size()
	var announce_top := field_h / 2.0 - announce.size.y * AnnounceLabel.INITIAL_SCALE / 2.0

	assert_gt(top, timer_bottom,
			"横幅块顶(%.1f) 要在倒计时底(%.1f) 之下 —— 否则贴上去了" % [top, timer_bottom])
	assert_lt(bottom, announce_top,
			"横幅块底(%.1f) 要在报幕大字视觉顶(%.1f) 之上 —— 否则长横幅和报幕叠字" % [bottom, announce_top])


## 行序：标题 → 分数 → 击破时间（自上而下）
func test_line_order_title_bonus_time() -> void:
	var banner := _make_banner()
	assert_lt(_title(banner).get_index(), _bonus(banner).get_index(), "分数在标题下面")
	assert_lt(_bonus(banner).get_index(), _time(banner).get_index(), "击破时间在分数下面")


## 动画顺序：渐显 → **停**（这一刻必须还是满亮）→ 渐隐。
## **手动步进时间轴**而不是 await 真实计时 —— GUT 起来后的第一个帧可能特别长（实测能把
## 0.05s 的 timer 一帧吞掉），拿真实时间采样会假红；`custom_step` 是确定性的。
func test_fade_in_hold_fade_out_sequence() -> void:
	var banner := _make_banner()
	banner.show_result(true, 999, 1.0, false)
	var title := _title(banner)
	var tween := banner._tween
	tween.pause()
	assert_almost_eq(title.modulate.a, 0.0, 0.001, "刚播时还没亮起来")

	tween.custom_step(banner.fade_in * 0.5)
	assert_almost_eq(title.modulate.a, 0.5, 0.02, "渐显走到一半")

	tween.custom_step(banner.fade_in * 0.5 + banner.hold * 0.6)
	assert_almost_eq(title.modulate.a, 1.0, 0.001, "停留期必须满亮（渐隐不能和它并行）")

	tween.custom_step(banner.hold * 0.4 + banner.fade_out * 0.5)
	assert_almost_eq(title.modulate.a, 0.5, 0.02, "停留走完才开始渐隐")


## 放完：自己隐藏 + 发 `finished`（BossUI 靠它回收节点）—— 同样手动步进，确定性且不占 1.2s
func test_finishes_hidden_and_emits_finished() -> void:
	var banner := _make_banner()
	watch_signals(banner)
	banner.show_result(true, 5, 1.0, false)
	banner._tween.pause()
	banner._tween.custom_step(banner.total_duration() + 0.05)
	assert_signal_emitted(banner, "finished", "淡完应发 finished")
	assert_false(banner.visible, "淡完后应隐藏（不留残影）")


## `clear()` 提前掐掉动画并释放（切阶段 / 退场时用）
func test_clear_frees_immediately() -> void:
	var root := Node.new()
	add_child_autofree(root)
	var banner := BANNER_SCENE.instantiate() as PhaseResultBanner
	root.add_child(banner)
	banner.show_result(true, 1, 1.0, false)
	banner.clear()
	await get_tree().process_frame
	assert_false(is_instance_valid(banner), "clear() 后应已释放（不留动画）")

extends GutTest
## 符卡奖励分规则（`SpellBonus`）：初始值 = (难度权重 + 面序号 − 1) × 50 万；非符 0；
## 非时符在**时限内均匀**衰减到初始值的 30%；时符不掉。
## 规则表只此一处，别在内容里手填（作者 2026-09-26 实测 + 二次核对 + 定调）。


## 初始值查表：**难度权重 × 面序号 × 50 万**；权重 E/N/H/L = 1/2/3/4、EX = 2；面序号 1..6 / EX 面 = 7
func test_initial_is_weight_times_stage_no():
	assert_eq(SpellBonus.initial(1, SpellRecord.Difficulty.EASY), 500000, "1 面 Easy = 1×1×50万")
	assert_eq(SpellBonus.initial(1, SpellRecord.Difficulty.NORMAL), 1000000, "1 面 Normal = 2×1×50万")
	assert_eq(SpellBonus.initial(1, SpellRecord.Difficulty.LUNATIC), 2000000, "1 面 Lunatic = 4×1×50万")
	assert_eq(SpellBonus.initial(1, SpellRecord.Difficulty.EXTRA), 1000000, "1 面 Extra = 2×1×50万")
	assert_eq(SpellBonus.initial(3, SpellRecord.Difficulty.LUNATIC), 6000000, "3 面 Lunatic = 4×3×50万")
	assert_eq(SpellBonus.initial(6, SpellRecord.Difficulty.HARD), 9000000, "6 面 Hard = 3×6×50万")
	assert_eq(SpellBonus.initial(7, SpellRecord.Difficulty.EXTRA), 7000000, "EX 面 = 2×7×50万")
	# 乘法关系：面序号翻倍 → 分翻倍（加法口径不会有这条）
	assert_eq(SpellBonus.initial(4, SpellRecord.Difficulty.HARD),
		SpellBonus.initial(2, SpellRecord.Difficulty.HARD) * 2, "面序号 ×2 → 分 ×2")


## 难度权重：E/N/H/L = 1/2/3/4；**EX = 2**（单独破例）
func test_difficulty_weight_table():
	assert_eq(SpellBonus.difficulty_weight(SpellRecord.Difficulty.EASY), 1, "Easy = 1")
	assert_eq(SpellBonus.difficulty_weight(SpellRecord.Difficulty.NORMAL), 2, "Normal = 2")
	assert_eq(SpellBonus.difficulty_weight(SpellRecord.Difficulty.HARD), 3, "Hard = 3")
	assert_eq(SpellBonus.difficulty_weight(SpellRecord.Difficulty.LUNATIC), 4, "Lunatic = 4")
	assert_eq(SpellBonus.difficulty_weight(SpellRecord.Difficulty.EXTRA), 2, "EX = 2（破例）")


## 没挂面（合成 Boss / stage_id = 0）→ 没有奖励分
func test_no_stage_no_bonus():
	assert_eq(SpellBonus.initial(0, SpellRecord.Difficulty.NORMAL), 0, "无面序号 = 0")


## 非符没有奖励分（原作口径：只有符卡报奖励分、计这笔分）
func test_nonspell_has_no_bonus():
	assert_eq(SpellBonus.initial(1, SpellRecord.Difficulty.EXTRA, false), 0, "非符 = 0")
	assert_eq(SpellBonus.initial(7, SpellRecord.Difficulty.EXTRA, false), 0, "EX 非符也是 0")


## 下限 = 初始的 30%
func test_decay_floor_is_30_percent():
	assert_eq(SpellBonus.decay_floor(5000000), 1500000, "550 万的 30% = 165 万（取整）")
	assert_eq(SpellBonus.decay_floor(1000000), 300000, "100 万的 30% = 30 万")
	assert_eq(SpellBonus.decay_floor(0), 0, "0 还是 0")


## 速率 = (初始 − 30%) / 时限 → 走满时限正好落到 30%（**不均匀就跟时限挂钩不了**）
func test_decay_per_second_is_linear_to_30_percent_over_time_limit():
	var initial := 4000000
	var time_limit := 40.0
	var rate := SpellBonus.decay_per_second(initial, time_limit, false)
	assert_almost_eq(rate, (4000000.0 - 1200000.0) / 40.0, 0.01, "速率 = (初始 − 30%) / 时限")
	assert_almost_eq(rate * time_limit, float(initial - SpellBonus.decay_floor(initial)), 0.01,
		"走满时限正好落到 30%")
	# 时长不同 → 速率不同（不是固定值）
	assert_gt(SpellBonus.decay_per_second(initial, 20.0, false), rate, "时限更短 → 速率更快")


## 时符 / 非法时限 → 不衰减
func test_decay_per_second_zero_for_timeout_only_and_bad_time_limit():
	assert_eq(SpellBonus.decay_per_second(4000000, 40.0, true), 0.0, "时符不衰减")
	assert_eq(SpellBonus.decay_per_second(4000000, 0.0, false), 0.0, "时限非法 → 不衰减（防除零）")


## 一帧的衰减量：至少 1（防小 delta 卡住）；时符恒 0
func test_decay_tick_has_minimum_one():
	var rate := SpellBonus.decay_per_second(4000000, 40.0, false)   # 7 万/秒
	assert_eq(SpellBonus.decay_tick(1.0, 4000000, 40.0, false), int(rate), "1 秒的量 = 速率")
	assert_eq(SpellBonus.decay_tick(0.0, 4000000, 40.0, false), 1, "极小 delta 也至少掉 1")
	assert_eq(SpellBonus.decay_tick(1.0, 4000000, 40.0, true), 0, "时符 0")


## 逐帧跑满时限 → 30%；全程单调不增、且不会掉成 0
func test_decayed_reaches_30_percent_at_time_limit():
	var initial := SpellBonus.initial(3, SpellRecord.Difficulty.LUNATIC)   # 300 万，下限 90 万
	var time_limit := 40.0
	var step := 1.0 / 60.0
	var current := initial
	var elapsed := 0.0
	var is_monotone := true
	while elapsed < time_limit:
		var next := SpellBonus.decayed(current, initial, time_limit, step, false)
		if next > current:
			is_monotone = false
		current = next
		elapsed += step

	assert_true(is_monotone, "全程单调不增")
	assert_almost_eq(float(current), float(SpellBonus.decay_floor(initial)), 1000.0,
		"满时限落到 30%%（%d → %d）" % [initial, current])
	assert_gt(current, 0, "不会掉成 0")


## 时符：多久都不掉
func test_timeout_only_does_not_decay():
	assert_eq(SpellBonus.decay_tick(5.0, 4000000, 40.0, true), 0, "时符不掉奖励分")
	assert_eq(SpellBonus.decayed(4000000, 4000000, 40.0, 60.0, true), 4000000, "时符原样不动")

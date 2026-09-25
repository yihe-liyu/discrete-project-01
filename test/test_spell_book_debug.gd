extends GutTest
## 调试：一键解锁所有符卡练习（SpellBookManager.debug_unlock_all_spells）—— 符卡 + 非符。
## 用独立 SpellBookManager（不碰全局 SaveData.spell_book），避免污染其它用例。


func test_debug_unlock_all_includes_spells_and_nonspells_idempotent():
	var mgr := SpellBookManager.new()
	mgr.spell_book = SpellRecordBook.new()
	var added: int = mgr.debug_unlock_all_spells()
	assert_gt(added, 0, "名册里应至少解锁一个阶段（新增 %d）" % added)
	assert_eq(mgr.spell_book.records.size(), added, "每个键只建一条")
	var spells := 0
	var nonspells := 0
	for rec in mgr.spell_book.records:
		if rec.uid != 0:
			spells += 1
			assert_eq(rec.phase_type, SpellRecord.PhaseType.SPELL, "uid!=0 → 符卡")
		else:
			nonspells += 1
			assert_eq(rec.phase_type, SpellRecord.PhaseType.NONSPELL, "uid==0 → 非符")
	assert_gt(spells, 0, "应含符卡")
	assert_gt(nonspells, 0, "应含非符（stage1 有两张非符）")
	assert_eq(mgr.debug_unlock_all_spells(), 0, "幂等：再跑不再新增")


## 非符零统计记录不能被 prune_empty 清掉（否则落不了盘 → 练习页看不到）
func test_prune_empty_keeps_zero_stat_records_with_key():
	var book := SpellRecordBook.new()
	var rec := SpellRecord.new()
	rec.stage = 1
	rec.phase_index = 0
	rec.uid = 0
	rec.attempts = 0
	book.records = [rec]
	book.prune_empty()
	assert_eq(book.records.size(), 1, "有主键（stage>=1, phase_index>=0）的零统计记录应保留")

	var ghost := SpellRecord.new()   # 默认 phase_index = -1
	book.records = [ghost]
	book.prune_empty()
	assert_eq(book.records.size(), 0, "无主键空壳应被清理")


## 难度专属符卡（最终 Boss 第 1 槽在各难度换卡）四种难度 × 两角色都要有记录且 uid 对得上
func test_debug_unlock_covers_difficulty_specific_spells():
	var mgr := SpellBookManager.new()
	mgr.spell_book = SpellRecordBook.new()
	mgr.debug_unlock_all_spells()
	var fin: BossData = BossCatalog.boss(1, 1)
	assert_not_null(fin, "stage 1 应有第二个 Boss")
	if fin == null:
		return
	var canonical := BossCatalog.phase_canonical_index(1, fin.phases_normal[1])
	assert_true(canonical >= 0, "最终 Boss 第 1 槽应能定位（%d）" % canonical)
	for diff in SpellRecord.DIFF_VALUES:
		var expected: PhaseData = BossCatalog.phase_at(1, canonical, diff)
		if expected == null:
			continue  # 该难度未配置
		for ch in [SpellRecord.Character.REIMU, SpellRecord.Character.MARISA]:
			var rec: SpellRecord = mgr.spell_book.get_record(1, canonical, 0, int(ch), diff)
			assert_not_null(rec, "难度 %d 角色 %d 应有记录" % [diff, ch])
			if rec:
				assert_eq(rec.uid, expected.uid, "uid 对应难度专属符卡（难度 %d）" % diff)

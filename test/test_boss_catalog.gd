extends GutTest
## Boss 谱（花名册）+ 符卡集合派生 测试

func _mk_phase(p_name: String) -> PhaseData:
	var p := PhaseData.new()
	p.name = p_name
	p.time_limit = 30.0
	p.hp = 1000
	return p


func _mk_spell(p_uid: int, p_name: String) -> PhaseData:
	var p := _mk_phase(p_name)
	p.uid = p_uid
	return p


## 真实内容：stage 1 名册**自洽**（不数具体阶段数、不绑卡名 —— 加符卡不应红）
func test_stage1_roster_is_self_consistent():
	var bosses: Array = BossCatalog.all().get(1, [])
	assert_gt(bosses.size(), 0, "stage 1 应有 Boss")
	for b: BossData in bosses:
		assert_gt(b.phases_normal.size(), 0, "每个 Boss 至少一个阶段（%s）" % b.boss_name)
	var order := BossCatalog.stage_phase_order(1)
	assert_gt(order.size(), 0, "规范阶段顺序非空")
	for i in order.size():
		assert_eq(BossCatalog.phase_canonical_index(1, order[i]), i, "规范序自查（%d）" % i)
		assert_eq(BossCatalog.phase_at(1, i, 1), order[i], "phase_at 取规范序第 i 个")
		var bi := BossCatalog.boss_index_of_phase(1, i)
		assert_true(bi >= 0 and bi < bosses.size(), "boss_index 在范围内（%d）" % i)


## 只有 Extra 档的 Boss（EX 面：`phases_normal` 空、`phases_extra` 有卡）：
## 槽位数 = 各难度列最大长度，规范序 / 身份 / 反查都必须能算出来。
## 回归（2026-09-26 作者报）：曾一律拿 `phases_normal.size()` 当槽位数 → 规范序 0 槽、
## `resolve_identity` 越界返回 null → 该阶段永远解不了锁，符卡练习里看不见。
func test_extra_only_boss_resolves_identity():
	var extra := _mk_spell(161, "阳符「宏辉抑世」")
	var ex := BossData.new().in_stage(9).extra_phase(extra)
	BossCatalog.set_catalog_override({9: [ex]})

	assert_eq(BossCatalog.boss_slot_count(ex), 1, "槽位数 = 各难度列最大长度（不是 phases_normal）")
	var order := BossCatalog.stage_phase_order(9)
	assert_eq(order.size(), 1, "只有 Extra 档也应有 1 个规范槽位")
	assert_eq(order[0], extra, "代表阶段从 phases_extra 回落取到")
	assert_eq(BossCatalog.phase_canonical_index(9, extra), 0, "在 phases_extra 里也能定位槽位")
	assert_eq(BossCatalog.phase_at(9, 0, SpellRecord.Difficulty.EXTRA), extra, "phase_at 按 Extra 取回同一张")
	assert_eq(BossCatalog.boss_index_of_phase(9, 0), 0, "boss_index 可解析")
	var pid := BossCatalog.resolve_identity(9, extra, -1)
	assert_not_null(pid, "身份必须解析出来（曾越界返回 null → 永不解锁）")
	if pid:
		assert_eq(pid.phase_index, 0, "规范槽位 0")
		assert_eq(pid.phase_number, 1, "第 1 张符卡")
		assert_eq(pid.uid, 161, "身份 uid 对得上")

	# 规范列非空时仍优先用它当代表（既有内容行为不变）
	var normal_phase := _mk_phase("N0")
	var mixed := BossData.new().in_stage(9).normal_phase(normal_phase).extra_phase(_mk_spell(162, "EX"))
	BossCatalog.set_catalog_override({9: [mixed]})
	assert_eq(BossCatalog.boss_slot_phases(mixed)[0], normal_phase, "代表阶段优先 phases_normal")
	BossCatalog.clear_catalog_override()


## 符卡练习 BGM：Boss 覆盖 → 面默认；两边都没有 → 空（静音），不崩不猜
func test_practice_bgm_key_boss_overrides_stage_default():
	# ① Boss 没填 → 用该面的 StageData.bgm_key（真内容：1 面 = stage1）
	assert_eq(BossCatalog.practice_bgm_key(BossCatalog.boss(1, 0), 1), "stage1", "没填则回落面默认")
	# ② Boss 填了 → 覆盖面默认（道中曲 / Boss 曲各配一首靠这条）
	var boss := BossData.new().in_stage(9)
	boss.practice_bgm_key = "stageEX_boss"
	assert_eq(BossCatalog.practice_bgm_key(boss, 9), "stageEX_boss", "Boss 覆盖优先")
	# ③ 面也没收录 / boss 为 null → 空串
	assert_eq(BossCatalog.practice_bgm_key(null, -99), "", "都没有 → 空（练习静音）")
	assert_eq(BossCatalog.practice_bgm_key(boss, -99), "stageEX_boss", "只看 Boss 覆盖，与面是否存在无关")


## 越界取 Boss → null
func test_boss_out_of_range_is_null():
	assert_null(BossCatalog.boss(1, 99), "越界 boss_index 应返回 null")
	assert_null(BossCatalog.boss(999, 0), "不存在 stage 应返回 null")


## 按规范顺序 + 难度取阶段（C 方案练习接线原语）；兼容 card() 旧入口
func test_card_lookup_by_position_and_difficulty():
	var order := BossCatalog.stage_phase_order(1)
	assert_gt(order.size(), 0, "规范顺序非空")
	var p0 := BossCatalog.phase_at(1, 0, 1)  # Normal 难度，规范序 0
	assert_not_null(p0, "规范序 0 应存在")
	assert_eq(p0, order[0], "phase_at 与规范序一致")
	# 兼容旧入口 card() 仍可用（boss 内下标）
	for bi in BossCatalog.all().get(1, []).size():
		assert_not_null(BossCatalog.card(1, bi, 0, 1), "card 旧入口 boss%d phase0 仍在" % bi)
	# 越界 / 不存在
	assert_null(BossCatalog.phase_at(1, 99, 1), "越界 phase_index 返回 null")
	assert_null(BossCatalog.phase_at(999, 0, 1), "不存在 stage 返回 null")


## 收集符卡：跳过非符，只收 uid != 0
func test_collect_spells_finds_unique_uids():
	var bosses := {
		99: [
			BossData.new().normal_phase(_mk_phase("非符")).normal_phase(_mk_spell(55, "符A")).normal_phase(_mk_spell(56, "符B")),
		],
	}
	var spells := BossCatalog.collect_spells_from(bosses)
	assert_eq(spells.size(), 2, "应收集到 2 张符卡")
	assert_eq(spells[55].name, "符A")
	assert_eq(spells[56].name, "符B")


## 同一 PhaseData 对象跨难度列出现 → 只算一张（不误报 uid 冲突）
func test_collect_spells_dedups_same_object_across_difficulties():
	var shared := _mk_spell(55, "符A")
	var bosses := {
		99: [
			BossData.new().normal_phase(shared).lunatic_phase(shared),
		],
	}
	var spells := BossCatalog.collect_spells_from(bosses)
	assert_eq(spells.size(), 1, "同对象跨难度列只算一张")


## 难度专属符卡：各难度列同槽换卡（spell001/002/003/004 各占最终 Boss 第 1 槽），身份必须按「槽位」解析。
## 回归：phase_canonical_index 曾只 find phases_normal → Easy/Hard/Lunatic 的符卡解析 null、永不解锁。
func test_difficulty_specific_spells_resolve_by_slot():
	var fin: BossData = BossCatalog.boss(1, 1)
	assert_not_null(fin, "stage 1 应有第二个 Boss")
	if fin == null:
		return
	var order := BossCatalog.stage_phase_order(1)
	var prev_diff := SaveData.selected_difficulty
	for diff in [0, 1, 2, 3]:
		var arr := fin.phases_for_difficulty(diff)
		if arr.is_empty():
			continue
		SaveData.selected_difficulty = diff
		for off in arr.size():
			var phase: PhaseData = arr[off]
			var idx := BossCatalog.phase_canonical_index(1, phase)
			assert_true(idx >= 0, "难度 %d 第 %d 槽应能定位（%s）" % [diff, off, phase.name])
			var pid := BossCatalog.resolve_identity(1, phase, -1)
			assert_not_null(pid, "难度 %d 第 %d 槽应解析出身份（%s）" % [diff, off, phase.name])
			if pid and idx >= 0:
				assert_eq(pid.phase_index, idx, "身份 phase_index == 规范槽位")
				assert_eq(pid.difficulty, diff, "身份 difficulty = 当前难度")
			if idx >= 0 and idx < order.size():
				assert_eq(BossCatalog.phase_at(1, idx, diff), phase, "phase_at 反查同一槽位")
	SaveData.selected_difficulty = prev_diff


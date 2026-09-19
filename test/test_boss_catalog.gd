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
		assert_gt(b.phases.size(), 0, "每个 Boss 至少一个阶段（%s）" % b.boss_name)
	var order := BossCatalog.stage_phase_order(1)
	assert_gt(order.size(), 0, "规范阶段顺序非空")
	for i in order.size():
		assert_eq(BossCatalog.phase_canonical_index(1, order[i]), i, "规范序自查（%d）" % i)
		assert_eq(BossCatalog.phase_at(1, i, 1), order[i], "phase_at 取规范序第 i 个")
		var bi := BossCatalog.boss_index_of_phase(1, i)
		assert_true(bi >= 0 and bi < bosses.size(), "boss_index 在范围内（%d）" % i)


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
			BossData.new().phase(_mk_phase("非符")).phase(_mk_spell(55, "符A")).phase(_mk_spell(56, "符B")),
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
			BossData.new().phase(shared).lunatic_phase(shared),
		],
	}
	var spells := BossCatalog.collect_spells_from(bosses)
	assert_eq(spells.size(), 1, "同对象跨难度列只算一张")

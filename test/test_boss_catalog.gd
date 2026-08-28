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


## 真实内容：stage 1 拆成两个 Boss（道中 + 关底）；规范阶段顺序（C）跨 boss 共 2 个阶段
func test_stage1_boss_has_two_phases():
	var mid := BossCatalog.boss(1, 0)
	var final := BossCatalog.boss(1, 1)
	assert_not_null(mid, "道中 boss 0 存在")
	assert_not_null(final, "关底 boss 1 存在")
	if mid: assert_eq(mid.phases.size(), 1, "道中只打 1 个阶段")
	if final: assert_eq(final.phases.size(), 1, "关底只打 1 个阶段")
	# 规范顺序（C：阶段身份与 Boss 拆分无关）
	assert_eq(BossCatalog.stage_phase_order(1).size(), 2, "规范顺序共 2 个阶段")
	if final:
		assert_eq(BossCatalog.phase_canonical_index(1, final.phases[0]), 1, "面非符规范序位置 1")
		assert_eq(BossCatalog.boss_index_of_phase(1, 1), 1, "规范序 1 属于关底 boss")


## 越界取 Boss → null
func test_boss_out_of_range_is_null():
	assert_null(BossCatalog.boss(1, 99), "越界 boss_index 应返回 null")
	assert_null(BossCatalog.boss(999, 0), "不存在 stage 应返回 null")


## 按规范顺序 + 难度取阶段（C 方案练习接线原语）；兼容 card() 旧入口
func test_card_lookup_by_position_and_difficulty():
	var p0 := BossCatalog.phase_at(1, 0, 1)  # Normal 难度，规范序 0（道中非符1）
	var p1 := BossCatalog.phase_at(1, 1, 1)  # Normal 难度，规范序 1（面非符2）
	assert_not_null(p0, "规范序 0 应存在")
	assert_not_null(p1, "规范序 1 应存在")
	if p0: assert_eq(p0.name, "卡摩瑞的道中非符1")
	if p1: assert_eq(p1.name, "卡摩瑞的非符1")
	# 兼容旧入口 card() 仍可用（boss 内下标）
	assert_not_null(BossCatalog.card(1, 0, 0, 1), "card 旧入口 boss0 phase0 仍在")
	assert_not_null(BossCatalog.card(1, 1, 0, 1), "card 旧入口 boss1 phase0 仍在")
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

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


## 真实内容：stage 1 只有一个 Boss（卡摩瑞），两个阶段（道中非符 + 面非符）
func test_stage1_boss_has_two_phases():
	var b: BossData = BossCatalog.boss(1, 0)
	assert_not_null(b, "stage 1 应有 boss 0")
	if b:
		assert_eq(b.phases.size(), 2, "卡摩瑞应有 2 个阶段")
		assert_eq(b.phases[0].name, "卡摩瑞的道中非符1")
		assert_eq(b.phases[1].name, "卡摩瑞的非符1")


## 越界取 Boss → null
func test_boss_out_of_range_is_null():
	assert_null(BossCatalog.boss(1, 99), "越界 boss_index 应返回 null")
	assert_null(BossCatalog.boss(999, 0), "不存在 stage 应返回 null")


## 按位置 + 难度取卡（练习接线原语）
func test_card_lookup_by_position_and_difficulty():
	var p0 := BossCatalog.card(1, 0, 0, 1)  # Normal 难度，phase 0
	var p1 := BossCatalog.card(1, 0, 1, 1)  # Normal 难度，phase 1
	assert_not_null(p0, "stage 1 boss 0 phase 0 应存在")
	assert_not_null(p1, "stage 1 boss 0 phase 1 应存在")
	if p0: assert_eq(p0.name, "卡摩瑞的道中非符1")
	if p1: assert_eq(p1.name, "卡摩瑞的非符1")
	# 越界 / 不存在
	assert_null(BossCatalog.card(1, 0, 99, 1), "越界 phase_index 返回 null")
	assert_null(BossCatalog.card(999, 0, 0, 1), "不存在 stage 返回 null")


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

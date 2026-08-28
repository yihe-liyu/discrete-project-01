class_name BossCatalog
## Boss 谱（花名册）—— 唯一权威的关卡内容表
##
## 阶段身份（phase_index / 非符N / 符卡N / boss_index）一律由"每面规范阶段顺序"
## （static func stage_phase_order）决定，与 Boss 怎么拆分/怎么命名无关 —— 这就是 C 方案：
## 阶段身份独立于 Boss 组织。
## 每个 BossData 只带它"自己打"的阶段（spawn / BossUI 分点用）；真正的编号看规范顺序。
##
## 自机差分（换卡 = 换 uid）暂未落地；未来在"取 Boss"这层按 selected_character 路由即可。

const KAMORUI = preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")
const NON_MID01 = preload("res://data/stages/stage01/phase/non_mid01/non_mid01.tres")
const NON01 = preload("res://data/stages/stage01/phase/non01/non01.tres")

static var _cache: Dictionary = {}


## 全部 Boss 谱（惰性构建，缓存）：stage -> Array[BossData]（boss_index = 数组下标）
## 注意：拆分"道中 / 关底"只影响"谁登场、ui 点数分段"，不影响阶段编号。
static func all() -> Dictionary:
	if _cache.is_empty():
		_cache = {
			1: [
				BossData.new().name("？？？").look(KAMORUI)
					.phase(NON_MID01),  # boss 0：道中，只打道中非符1
				BossData.new().name("卡摩瑞").look(KAMORUI)
					.phase(NON01),     # boss 1：关底，只打面非符2
			],
		}
	return _cache


## 取某面某 Boss（boss_index = 数组下标）；越界返回 null
static func boss(stage: int, boss_index: int) -> BossData:
	var arr: Array = all().get(stage, [])
	if boss_index < 0 or boss_index >= arr.size():
		return null
	return arr[boss_index]


# ═══════════ 规范阶段顺序（C 的核心：阶段身份与 Boss 组织解耦）═══════════

## 某面的"规范阶段顺序"：跨所有 Boss 扁平展开（每个 phase 唯一确定）。
## 这是 phase_index / 非符N·符卡N / boss_index 的唯一真相来源。
static func stage_phase_order(stage: int) -> Array[PhaseData]:
	var order: Array[PhaseData] = []
	for b: BossData in all().get(stage, []):
		for p: PhaseData in b.phases:
			order.append(p)
	return order


## 某 phase 在该面规范顺序中的位置（找不到返回 -1）。按 Resource 引用匹配（同一共享资源）。
static func phase_canonical_index(stage: int, phase: PhaseData) -> int:
	return stage_phase_order(stage).find(phase)


## 规范顺序第 phase_index 个阶段（跨越 Boss）；越界返回 null。
## 按难度列取：定位到所属 Boss + 其内部下标，再用该 Boss 的 phases_for_difficulty(difficulty) 取。
## 当前各难度共用同名阶段资源 → 各难度结果一致；未来有难度专属阶段时按此路由即可。
static func phase_at(stage: int, phase_index: int, difficulty: int) -> PhaseData:
	var order := stage_phase_order(stage)
	if phase_index < 0 or phase_index >= order.size():
		return null
	var acc := 0
	for b: BossData in all().get(stage, []):
		var sz: int = b.phases.size()
		if phase_index < acc + sz:
			var off := phase_index - acc
			var arr := b.phases_for_difficulty(difficulty)
			if off >= 0 and off < arr.size():
				return arr[off]
			return null
		acc += sz
	return null


## 规范顺序第 phase_index 个阶段属于哪个 Boss（boss_index）；找不到返回 -1
static func boss_index_of_phase(stage: int, phase_index: int) -> int:
	var order := stage_phase_order(stage)
	if phase_index < 0 or phase_index >= order.size():
		return -1
	var acc := 0
	for bi in all().get(stage, []).size():
		var sz: int = all().get(stage, [])[bi].phases.size()
		if phase_index < acc + sz:
			return bi
		acc += sz
	return -1


## 取拥有该规范 phase_index 的 BossData；越界返回 null
static func boss_of_phase(stage: int, phase_index: int) -> BossData:
	return boss(stage, boss_index_of_phase(stage, phase_index))


## 兼容旧入口：按 (stage, boss_index, phase_index, difficulty) 取阶段。
## 旧语义：boss 内 phase_index。新语义统一走 stage_phase_order（见 phase_at）。
## 保留仅供测试/调用方过渡，新代码请用 phase_at。
static func card(stage: int, boss_index: int, phase_index: int, difficulty: int) -> PhaseData:
	var b: BossData = boss(stage, boss_index)
	if not b:
		return null
	var arr := b.phases_for_difficulty(difficulty)
	if phase_index < 0 or phase_index >= arr.size():
		return null
	return arr[phase_index]


## 从全部 Boss 谱收集符卡（运行时扫描，启动调用一次即可）
static func collect_spells() -> Dictionary:
	return collect_spells_from(all())


## 从给定 Boss 谱收集符卡（uid != 0）。同对象跨难度列只算一张；uid 冲突 → push_error。
static func collect_spells_from(bosses: Dictionary) -> Dictionary:
	var spells := {}
	var seen_objects := {}  # 同一 PhaseData 对象跨难度列出现 → 去重
	for stage in bosses:
		for b: BossData in bosses[stage]:
			for arr in [b.phases, b.phases_easy, b.phases_hard, b.phases_lunatic, b.phases_extra]:
				for p: PhaseData in arr:
					if p == null or seen_objects.has(p):
						continue
					seen_objects[p] = true
					if p.uid != 0:
						if spells.has(p.uid):
							push_error("BossCatalog: 符卡 uid %d 重复登记（冲突）" % p.uid)
						else:
							spells[p.uid] = p
	return spells

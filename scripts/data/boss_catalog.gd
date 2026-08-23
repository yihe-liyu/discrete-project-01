class_name BossCatalog
## Boss 谱（花名册）—— 唯一权威的关卡内容表
##
## 结构：stage -> Array[BossData]（boss_index = 数组下标）
## 阶段数组顺序 = phase_index；符卡（uid != 0）在此登记；非符（uid == 0）只作阶段。
## 练习占位、收集率、正篇编排最终都从这里扫/取，避免内容散在 stage.gd 里。
##
## 自机差分（换卡 = 换 uid）暂未落地：当前内容无自机差分；未来在"取 Boss"这层按
## selected_character 路由到不同 BossData 即可，结构无需推翻。

const KAMORUI = preload("res://data/enemy_visual/boss/stage01/kamorui.tscn")
const NON_MID01 = preload("res://data/stages/stage01/phase/non_mid01/non_mid01.tres")
const NON01 = preload("res://data/stages/stage01/phase/non01/non01.tres")

static var _cache: Dictionary = {}


## 全部 Boss 谱（惰性构建，缓存）
static func all() -> Dictionary:
	if _cache.is_empty():
		_cache = {
			1: [
				BossData.new().name("卡摩瑞").look(KAMORUI)
					.phase(NON_MID01)  # phase 0：道中非符1
					.phase(NON01),     # phase 1：面非符2（同一 Boss 两段，序号由链定位）
			],
		}
	return _cache


## 取某面某 Boss（boss_index = 数组下标）；越界返回 null
static func boss(stage: int, boss_index: int) -> BossData:
	var arr: Array = all().get(stage, [])
	if boss_index < 0 or boss_index >= arr.size():
		return null
	return arr[boss_index]


## 取某面某 Boss 的第 N 个阶段（按难度解析到正确难度列）。越界/空 Boss 返回 null。
## 练习接线用：代替旧记录里存的 phase_data 快照（快照只记了首次解锁时的难度，跨难度会错）。
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

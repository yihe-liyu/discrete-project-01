## 符卡练习菜单的数据模型（无树 / 无 UI）。
##
## 只负责：从 [code]SaveData.spell_book[/code] 生成 stage / phase / diff 数据，解析 Boss 配置，
## 计算练习收取进度。选中项、层级、滚动窗口仍归菜单 / 列表视图。
class_name SpellPracticeData
extends RefCounted

const DIFF_NAMES = SpellRecord.DIFF_NAMES
const DIFF_VALUES = SpellRecord.DIFF_VALUES

## 菜单难度槽的标准集合（普通面 Easy~Lunatic）。
## 与 [code]phases_for_difficulty[/code] 解耦：某难度没配阶段 → 槽仍在，但锁定 [code]?[/code]、不可选。
const MENU_DIFFS: Array[int] = [0, 1, 2, 3]
const MENU_DIFFS_EXTRA: Array[int] = [SpellRecord.Difficulty.EXTRA]

var stages: Array[int] = []
## 每个 phase: {rec: SpellRecord(带配置), diffs: {diff: SpellRecord}}
var phases: Array[Dictionary] = []
## 当前 phase 的难度项：{diff: int, is_locked: bool}
var diff_entries: Array[Dictionary] = []


## 该面的练习难度槽集合：普通面 = Easy~Lunatic（固定 4 槽，未配置的锁 [code]?[/code]）；
## 只配了 Extra 的面（EX） = 仅 Extra 一槽。
func menu_diffs_for(stage: int) -> Array[int]:
	var bosses: Array = BossCatalog.all().get(stage, [])
	for b: BossData in bosses:
		for difficulty in MENU_DIFFS:
			if not b.phases_for_difficulty(difficulty).is_empty():
				return MENU_DIFFS
	for b: BossData in bosses:
		if not b.phases_for_difficulty(SpellRecord.Difficulty.EXTRA).is_empty():
			return MENU_DIFFS_EXTRA
	return MENU_DIFFS


## 难度值 → 显示名；未知值 = "?"。
func diff_name(v: int) -> String:
	var idx := DIFF_VALUES.find(v)
	return DIFF_NAMES[idx] if idx >= 0 else "?"


# ═══ 从符卡记录生成 ═══

## 从符卡簿按角色重建 stages / phases。
func build(p_char_index: int) -> void:
	stages.clear()
	phases.clear()

	var book: SpellRecordBook = SaveData.spell_book
	if book.records.is_empty():
		return
	var seen_stages: Dictionary = {}
	var phase_keys: Array[Dictionary] = []

	for rec in book.records:
		if rec.character != p_char_index:
			continue
		if not phase_keys.any(func(p): return p.stage == rec.stage and p.boss_index == rec.boss_index and p.phase_index == rec.phase_index):
			phase_keys.append({stage = rec.stage, boss_index = rec.boss_index, phase_index = rec.phase_index})
		seen_stages[rec.stage] = true

	for stage in seen_stages.keys():
		stages.append(stage)
	stages.sort()

	if stages.is_empty():
		return
	change_stage(0, p_char_index)


## 切关卡并重建 phases；越界只清空。
func change_stage(idx: int, p_char_index: int) -> void:
	phases.clear()
	if stages.is_empty() or idx < 0 or idx >= stages.size():
		return

	var st_num: int = stages[idx]
	var book: SpellRecordBook = SaveData.spell_book
	var seen_keys: Array[Dictionary] = []

	for rec in book.records:
		if rec.stage != st_num or rec.character != p_char_index:
			continue
		if not seen_keys.any(func(k): return k.boss_index == rec.boss_index and k.phase_index == rec.phase_index):
			seen_keys.append({boss_index = rec.boss_index, phase_index = rec.phase_index})

	seen_keys.sort_custom(func(a, b):
		return a.boss_index < b.boss_index or (a.boss_index == b.boss_index and a.phase_index < b.phase_index))

	for key in seen_keys:
		var phase_idx: int = key.phase_index
		# 记录即真相：用该 Boss 该 phase 的任一记录判断符卡/非符 + 提供战斗配置
		var sample: SpellRecord = null
		for rec in book.records:
			if rec.stage == st_num and rec.boss_index == key.boss_index \
					and rec.phase_index == phase_idx and rec.character == p_char_index:
				sample = rec
				break
		if not sample:
			continue
		var is_spell: bool = sample.uid != 0

		# label：二级只显示"非符N / 符卡N"（不带 Boss 前缀；不同 Boss 用三级的名字区分）
		# 同一关可能有多只 Boss（道中 / 关底）→ 用 BossData.section_label 当前缀，
		# 否则两级列表里全是"非符1/符卡1"，分不清是谁的。
		var bosses: Array = BossCatalog.all().get(sample.stage, [])
		var boss: BossData = bosses[key.boss_index] if key.boss_index >= 0 and key.boss_index < bosses.size() else null
		var prefix: String = ("%s·" % boss.section_label) if boss != null and boss.section_label != "" else ""
		# 序号**按 Boss 各自计**（道中·非符1 / 关底·非符1）——只影响显示：
		# `phase_number` 仍是**全关规范序**（记录/身份口径不动 ✗），这里减去"该 Boss 之前同类有几张"即得。
		var base_non := 0
		var base_spell := 0
		for bi in range(maxi(key.boss_index, 0)):
			for prev in BossCatalog.boss_slot_phases(bosses[bi] as BossData):
				if prev != null and prev.uid != 0:
					base_spell += 1
				else:
					base_non += 1
		var local_no: int = sample.phase_number - (base_spell if is_spell else base_non)
		var label := "%s%s%d" % [prefix, "符卡" if is_spell else "非符", local_no]

		var info := {rec = sample, boss_index = key.boss_index, phase_index = phase_idx, diffs = {}, label = label}

		# 取出这个 phase 在这角色 + 该 Boss 下所有难度的记录（防不同 Boss 同 phase_index 混入）
		for rec in book.records:
			if rec.stage == st_num and rec.boss_index == key.boss_index \
					and rec.phase_index == phase_idx and rec.character == p_char_index:
				info["diffs"][rec.difficulty] = rec

		phases.append(info)


# ═══ 难度槽 ═══

## 构建当前 phase 的难度项（只填 [code]diff_entries[/code]；选中项由菜单决定）。
func build_diff_entries(p_phase_index: int) -> void:
	diff_entries.clear()
	if p_phase_index < 0 or p_phase_index >= phases.size():
		return

	var info: Dictionary = phases[p_phase_index]
	var rec: SpellRecord = info["rec"]
	var boss: BossData = boss_for(info)
	var diffs := menu_diffs_for(rec.stage)
	var configured := configured_diffs(boss, diffs)
	# 难度槽 = 该面的标准集合（普通面 4 档 / EX 面 Extra）；「有记录 **且** 该难度有阶段」才可选，否则锁定 ?。
	for difficulty in diffs:
		var is_locked: bool = not info["diffs"].has(difficulty) or not configured.has(difficulty)
		var record: SpellRecord = info["diffs"].get(difficulty, null)
		diff_entries.append({diff = difficulty, is_locked = is_locked, record = record, card_name = _card_name(rec, difficulty, is_locked)})


## 第一个未锁定的难度下标；全锁 → -1。
func first_unlocked_index() -> int:
	for i in diff_entries.size():
		if not diff_entries[i].is_locked:
			return i
	return -1


func _card_name(rec: SpellRecord, difficulty: int, is_locked: bool) -> String:
	if is_locked:
		return "?"
	if rec.uid == 0:
		return ""
	var card: PhaseData = BossCatalog.phase_at(rec.stage, rec.phase_index, difficulty)
	return card.name if (card and card.name != "") else "-"


# ═══ 收取进度（0=无 1=部分 2=全收）═══

## phase 状态：该 phase 在花名册里所有难度槽的练习收取
## 全部收 → 2；部分 → 1；无 → 0。锁定 "?" 槽计 0 收取（该难度也收齐才整条蓝）
func phase_capture_all(stage: int, boss: int, phase_idx: int, p_char_index: int,
		boss_override: BossData = null) -> int:
	var boss_data: BossData = boss_override if boss_override != null else BossCatalog.boss_of_phase(stage, phase_idx)
	var candidate: Array = configured_diffs(boss_data, menu_diffs_for(stage))
	if candidate.is_empty():
		return 0  # 花名册未收录，无法判定
	var captured := 0
	for difficulty in candidate:
		var record: SpellRecord = SaveData.spell_book.get_record(stage, phase_idx, boss, p_char_index, difficulty)
		if record and record.practice_captures > 0:
			captured += 1
	if captured == candidate.size():
		return 2
	if captured > 0:
		return 1
	return 0


## stage 状态：所有 phase 全收 → 2；有任意收取 → 1；无 → 0
func stage_capture_state(stage: int, p_char_index: int) -> int:
	var book := SaveData.spell_book
	var keys: Array = []
	var any_captured := false
	for rec in book.records:
		if rec.stage != stage or rec.character != p_char_index:
			continue
		if rec.practice_captures > 0:
			any_captured = true
		if not keys.any(func(k): return k.boss == rec.boss_index and k.phase == rec.phase_index):
			keys.append({boss = rec.boss_index, phase = rec.phase_index})
	if keys.is_empty():
		return 0
	var total := 0
	var done_count := 0
	for key in keys:
		total += 1
		if phase_capture_all(stage, key.boss, key.phase, p_char_index) == 2:
			done_count += 1
	if done_count == total:
		return 2
	if any_captured:
		return 1
	return 0


## Boss 解析：info 注入了 boss 就用它（测试夹具），否则查花名册。
func boss_for(info: Dictionary) -> BossData:
	var injected: Variant = info.get("boss")
	if injected is BossData:
		return injected
	return BossCatalog.boss_of_phase(info["rec"].stage, info["rec"].phase_index)


## 该 Boss 实际配置的难度档（有阶段的那些；全收判定用；不回退）。
func configured_diffs(boss: BossData, diffs: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for difficulty in diffs:
		if boss and not boss.phases_for_difficulty(difficulty).is_empty():
			out.append(difficulty)
	return out

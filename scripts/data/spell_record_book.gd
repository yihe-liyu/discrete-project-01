# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

const SpellRecordClass = preload("res://scripts/data/spell_record.gd")

## 全符卡记录，主键 (stage_id, phase_index, character, difficulty)
@export var records: Array[SpellRecord] = []


## 清理幽灵记录（防御：编辑器/外部写入可能塞入 stage=0 空壳——
## 例：Godot 里编辑 .tres 删记录时块残留 + 数组引用 → 加载生成空对象）。
## 正常记录 stage>=1；空壳 = stage<1 或 无 uid/统计的空对象。
func prune_empty() -> void:
	var kept: Array[SpellRecord] = []
	for r in records:
		if r.stage < 1:
			continue
		if r.uid == 0 and r.attempts == 0 and r.captures == 0 \
				and r.practice_attempts == 0 and r.practice_captures == 0:
			continue
		kept.append(r)
	records = kept


## 以 (stage, phase_index, boss_index, character, difficulty) 查重
func get_record(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int) -> SpellRecord:
	for r in records:
		if r.stage == stage and r.phase_index == phase_index and r.boss_index == boss_index \
				and r.character == character and r.difficulty == difficulty:
			return r
	return null


func get_or_create(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		uid: int = 0, phase_type: int = 0, phase_number: int = 1) -> SpellRecord:
	var r := get_record(stage, phase_index, boss_index, character, difficulty)
	if r:
		return r
	r = SpellRecordClass.new()
	r.stage = stage
	r.phase_index = phase_index
	r.boss_index = boss_index
	r.character = character
	r.difficulty = difficulty
	if uid > 0: r.uid = uid
	r.phase_type = phase_type
	r.phase_number = phase_number
	records.append(r)
	return r


func record_attempt(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		captured: bool, score: int, elapsed: float, extra: Dictionary = {}) -> void:
	var r := get_or_create(stage, phase_index, boss_index, character, difficulty,
		extra.get("uid", 0), extra.get("phase_type", 0),
		extra.get("phase_number", 1))
	r.attempts += 1
	if captured:
		r.captures += 1
		if score > r.best_score:
			r.best_score = score
		if elapsed > 0:
			if r.best_time == 0 or elapsed < r.best_time:
				r.best_time = elapsed


## 补记一次收取（attempts 已在进入阶段时记过——只加 captures + 更新最佳成绩）
func record_capture(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		score: int, elapsed: float) -> void:
	var r := get_record(stage, phase_index, boss_index, character, difficulty)
	if not r:
		return
	r.captures += 1
	if score > r.best_score:
		r.best_score = score
	if elapsed > 0:
		if r.best_time == 0 or elapsed < r.best_time:
			r.best_time = elapsed


func record_practice(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		captured: bool) -> void:
	var r := get_record(stage, phase_index, boss_index, character, difficulty)
	if not r:
		return  # 练习只更新已有记录，首次记录由普通模式生成
	r.practice_attempts += 1
	if captured:
		r.practice_captures += 1


## 练习收取补记：只 +capture（attempt 已在开始练习时记过，防重复）
func record_practice_capture(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int) -> void:
	var r := get_record(stage, phase_index, boss_index, character, difficulty)
	if not r:
		return
	r.practice_captures += 1




# SpellRecordBook.gd
extends Resource
class_name SpellRecordBook

## 全符卡记录，主键 (stage_id, phase_index, character, difficulty)
@export var records: Array[SpellRecord] = []


## 清理幽灵记录（防御：编辑器/外部写入可能塞入 stage=0 空壳——
## 例：Godot 里编辑 .tres 删记录时块残留 + 数组引用 → 加载生成空对象）。
## 正常记录 stage>=1；空壳 = stage<1 或 无 uid/统计的空对象。
func prune_empty() -> void:
	var kept: Array[SpellRecord] = []
	for record in records:
		if record.stage < 1:
			continue
		if record.uid == 0 and record.attempts == 0 and record.captures == 0 \
				and record.practice_attempts == 0 and record.practice_captures == 0:
			continue
		kept.append(record)
	records = kept


## 记录主键 = (stage, phase_index, character, difficulty)。
## 注意：boss_index **不参与主键**（阶段身份由规范 phase_index 唯一确定；boss_index 只作归属/展示）。
## 参数仍保留 boss_index 以兼容调用方，但查找时忽略它。
func get_record(stage: int, phase_index: int, _boss_index: int, character: int, difficulty: int) -> SpellRecord:
	for record in records:
		if record.stage == stage and record.phase_index == phase_index \
				and record.character == character and record.difficulty == difficulty:
			return record
	return null


func get_or_create(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		uid: int = 0, phase_type: int = 0, phase_number: int = 1) -> SpellRecord:
	var record := get_record(stage, phase_index, boss_index, character, difficulty)
	# 命中时仍写 boss_index（归属/展示用）—— 但主键不含它，不会因此新建/拆分记录
	if record:
		return record
	record = SpellRecord.new()
	record.stage = stage
	record.phase_index = phase_index
	record.boss_index = boss_index
	record.character = character
	record.difficulty = difficulty
	if uid > 0: record.uid = uid
	record.phase_type = phase_type
	record.phase_number = phase_number
	records.append(record)
	return record


func record_attempt(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		captured: bool, score: int, elapsed: float, extra: Dictionary = {}) -> void:
	var record := get_or_create(stage, phase_index, boss_index, character, difficulty,
		extra.get("uid", 0), extra.get("phase_type", 0),
		extra.get("phase_number", 1))
	record.attempts += 1
	if captured:
		record.captures += 1
		if score > record.best_score:
			record.best_score = score
		if elapsed > 0:
			if record.best_time == 0 or elapsed < record.best_time:
				record.best_time = elapsed


## 补记一次收取（attempts 已在进入阶段时记过——只加 captures + 更新最佳成绩）
func record_capture(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		score: int, elapsed: float) -> void:
	var record := get_record(stage, phase_index, boss_index, character, difficulty)
	if not record:
		return
	record.captures += 1
	if score > record.best_score:
		record.best_score = score
	if elapsed > 0:
		if record.best_time == 0 or elapsed < record.best_time:
			record.best_time = elapsed


func record_practice(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int,
		captured: bool) -> void:
	var record := get_record(stage, phase_index, boss_index, character, difficulty)
	if not record:
		return  # 练习只更新已有记录，首次记录由普通模式生成
	record.practice_attempts += 1
	if captured:
		record.practice_captures += 1


## 练习收取补记：只 +capture（attempt 已在开始练习时记过，防重复）
func record_practice_capture(stage: int, phase_index: int, boss_index: int, character: int, difficulty: int) -> void:
	var record := get_record(stage, phase_index, boss_index, character, difficulty)
	if not record:
		return
	record.practice_captures += 1




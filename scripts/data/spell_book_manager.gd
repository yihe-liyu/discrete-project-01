class_name SpellBookManager
extends RefCounted
## 符卡簿管理：加载/保存/解锁/记录（从 GameState 拆出，职责单一）

const SPELL_BOOK_PATH := "res://data/registry/spell_records.tres"

var spell_book: SpellRecordBook


func load() -> void:
	# 全新检出/首启时文件可能不存在：ResourceLoader.load 会打 ERROR，先 exists 避免
	if not ResourceLoader.exists(SPELL_BOOK_PATH):
		spell_book = SpellRecordBook.new()  # 首启无记录文件：空簿，解锁时 save 自建
		return
	spell_book = ResourceLoader.load(SPELL_BOOK_PATH)
	if not spell_book:
		spell_book = SpellRecordBook.new()  # 加载失败也回退空簿
		return
	# 防御：清理幽灵记录并落盘（编辑器旧数据写回的空壳不留）
	var before: int = spell_book.records.size()
	spell_book.prune_empty()
	if spell_book.records.size() != before:
		save()


func save() -> void:
	if spell_book:
		spell_book.prune_empty()
	ResourceSaver.save(spell_book, SPELL_BOOK_PATH)


## 注册一张符卡（见到即记，不计 attempt；配置随解锁自动存入记录）
func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book.get_or_create(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty,
		pid.uid, pid.phase_type, pid.phase_number)
	save()


## 记录一次符卡尝试（普通模式）
func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book.record_attempt(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty,
		captured, score, elapsed, {
		"uid": pid.uid, "phase_type": pid.phase_type, "phase_number": pid.phase_number,
	})
	save()


## 补记一次收取（进入阶段时已记尝试）
func record_capture(pid: PhaseIdentity, score: int, elapsed: float) -> void:
	spell_book.record_capture(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty,
		score, elapsed)
	save()


## 记录一次练习尝试
func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book.record_practice(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty, captured)
	save()


## 练习收取补记（attempt 已在开始练习时记过，防重复）
func record_practice_capture(pid: PhaseIdentity) -> void:
	spell_book.record_practice_capture(pid.stage_id, pid.phase_index, pid.boss_index, pid.character, pid.difficulty)
	save()

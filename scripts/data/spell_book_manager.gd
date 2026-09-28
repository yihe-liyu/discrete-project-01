class_name SpellBookManager
extends RefCounted
## 符卡簿管理：加载/保存/解锁/记录（从 SaveData 拆出，职责单一）

## 运行期档（R14：不写 res://，导出包只读）。首启无文件 = 空簿。
const SPELL_BOOK_USER_PATH := "user://spell_records.tres"

var spell_book: SpellRecordBook


func load() -> void:
	# 只有 user:// 一份档；全新检出/首启时不存在 → 空簿，解锁时 save 自建。
	if not FileAccess.file_exists(SPELL_BOOK_USER_PATH):
		spell_book = SpellRecordBook.new()
		return
	spell_book = ResourceLoader.load(SPELL_BOOK_USER_PATH)
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
	ResourceSaver.save(spell_book, SPELL_BOOK_USER_PATH)


## 清空玩家数据：符卡记录归零（删 user:// 档 + 换空簿）。设置不归本层管。
func clear_player_data() -> void:
	spell_book = SpellRecordBook.new()
	if FileAccess.file_exists(SPELL_BOOK_USER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SPELL_BOOK_USER_PATH))


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


# ═══ 调试 ═══

## 一键解锁所有符卡练习：遍历名册每个 stage × Boss × 难度 × 角色，为**每个阶段**
## （符卡 + 非符）补一条空白记录（"见到即记"，不记 attempts / 不覆盖已有成绩）。返回新建条数。
## 零统计非符能落盘，靠 SpellRecordBook.prune_empty() 改按主键判活（phase_index>=0 即保留）。
func debug_unlock_all_spells() -> int:
	var added := 0
	var roster := BossCatalog.all()
	# 逐 stage 维护 Boss 槽位偏移（与规范序同源：BossCatalog.boss_slot_count = 槽位数）
	for stage in roster:
		var acc := 0
		var bosses: Array = roster[stage]
		for bi in bosses.size():
			var b: BossData = bosses[bi]
			var shape: int = BossCatalog.boss_slot_count(b)
			for diff in SpellRecord.DIFF_VALUES:
				var arr: Array = b.phases_for_difficulty(diff)
				for off in mini(arr.size(), shape):
					var phase: PhaseData = arr[off]
					if phase == null:
						continue
					var phase_index: int = acc + off
					var is_spell: bool = phase.uid != 0
					for ch in [SpellRecord.Character.REIMU, SpellRecord.Character.MARISA]:
						var character := int(ch)
						if spell_book.get_record(stage, phase_index, bi, character, diff) != null:
							continue
						spell_book.get_or_create(stage, phase_index, bi, character, diff, phase.uid,
							SpellRecord.PhaseType.SPELL if is_spell else SpellRecord.PhaseType.NONSPELL,
							_debug_phase_number(stage, phase_index, is_spell))
						added += 1
			acc += shape
	if added > 0:
		save()
	return added


## 规范顺序里第 phase_index 个位置是第几张**同类**（符卡/非符，与 resolve_identity 同源；仅调试用）。
func _debug_phase_number(stage: int, phase_index: int, is_spell: bool) -> int:
	var count := 0
	var order := BossCatalog.stage_phase_order(stage)
	for j in range(mini(phase_index + 1, order.size())):
		if order[j] != null and (order[j].uid != 0) == is_spell:
			count += 1
	return count

class_name RecordService
extends RefCounted

## 记录服务 —— 阶段身份 + 记录的单一入口。
## Boss 不再直接摸 GameState.record_*（C3：系统走注入/集中，不再散摸全局）。
## 身份经 BossCatalog.resolve_identity 解析（C5：Boss 不再自我推导）。
## 用静态方法：bare Boss（无 ctx 的测试/练习）也能直接用。

## 阶段开始：普通 = 解锁 + 记尝试；练习 = 记尝试。
static func record_phase_start(pid: PhaseIdentity) -> void:
	if not pid:
		return
	if GameState.is_practice_mode:
		GameState.spell_book_mgr.record_practice(pid, false)
	else:
		GameState.spell_book_mgr.unlock_spell(pid)
		GameState.spell_book_mgr.record_spell(pid, false, 0, 0.0)


## 阶段结束补记：练习 = 只补 capture；普通 = 干净收取才补 capture（miss 后不收）。
static func record_phase_capture(pid: PhaseIdentity, captured: bool, bonus: int, elapsed: float) -> void:
	if not pid:
		return
	if GameState.is_practice_mode:
		GameState.spell_book_mgr.record_practice_capture(pid)
	elif captured:
		GameState.spell_book_mgr.record_capture(pid, bonus, elapsed)

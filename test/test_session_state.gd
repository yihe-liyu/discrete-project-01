extends GutTest
## 会话状态契约：per-run static 必须能经 SaveData.reset_session() 一次清干净。
## 回归「先练习 / 清关后再开新游戏会带脏状态」（practice 载荷、current_stage_id、is_restarting、is_stage_practice）。


func after_each() -> void:
	SaveData.reset_session()


## 复位入口必须清掉所有 per-run 状态。
func test_reset_session_clears_all_per_run_state() -> void:
	PracticeSession.start(PhaseData.new(), null, "脏", 99, 7)   # 伪造练习载荷
	SaveData.current_stage_id = 3
	SaveData.is_restarting = true
	SaveData.is_stage_practice = true

	SaveData.reset_session()

	assert_eq(SaveData.current_stage_id, 1, "应复位关卡进度")
	assert_false(SaveData.is_restarting, "应清重开标记")
	assert_false(SaveData.is_stage_practice, "应清关卡练习标记")
	assert_false(PracticeSession.is_practice_mode, "应清练习模式")
	assert_null(PracticeSession.phase, "应清练习载荷")


## 进练习本身就是一局开始：同样要经过复位入口，不能带上一局的脏状态。
func test_start_practice_resets_session() -> void:
	SaveData.current_stage_id = 3
	SaveData.is_restarting = true
	SaveData.is_stage_practice = true

	PracticeSession.start(PhaseData.new(), null, "练习", 1, 0)

	assert_eq(SaveData.current_stage_id, 1, "进练习也应复位关卡进度")
	assert_false(SaveData.is_restarting, "进练习应清重开标记")
	assert_false(SaveData.is_stage_practice, "符卡练习不是关卡练习")
	assert_true(PracticeSession.is_practice_mode, "应进入练习模式")
	assert_not_null(PracticeSession.phase, "应装载练习阶段")


func test_reset_session_is_idempotent() -> void:
	SaveData.reset_session()
	SaveData.reset_session()
	assert_eq(SaveData.current_stage_id, 1, "复位应可重复调用")
	assert_false(PracticeSession.is_practice_mode, "复位后仍是普通态")

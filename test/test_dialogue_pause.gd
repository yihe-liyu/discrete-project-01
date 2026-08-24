extends GutTest
## 对话可暂停性测试：暂停菜单（GameManager PAUSED）期间对话的 WAIT/auto_advance 计时应冻结，
## 恢复后从原地继续（对应用户设计："对话就是要可以被暂停的"）。

func _make_profile(name: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	p.char_name = name
	return p


func after_each() -> void:
	# 防止失败时把 GameManager 状态留在 PAUSED 影响其它测试
	GameManager.current_state = GameManager.AppState.MENU


func test_pause_freezes_dialogue_wait_timer():
	var old := GameManager.current_state
	var r := _make_profile("测试")

	var d := DialogueSteps.new()
	d.say(r, "A")
	d.wait(0.5)
	d.say(r, "B")

	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps)
	await wait_seconds(0.6)  # 淡入 + runner 启动 + 第一句

	box._advance()  # "A" 说完 → 进入 WAIT 步骤
	assert_true(box._runner.is_waiting_time, "应停在 WAIT 计时")

	# 暂停：_runner.tick 应被跳过，计时冻结
	GameManager.current_state = GameManager.AppState.PAUSED
	box._process(0.6)  # 若计时未被冻结，0.6 ≥ 0.5 会到点
	assert_true(box._runner.is_waiting_time, "暂停期间 WAIT 计时应冻结（未到点）")

	# 恢复：计时继续，0.6 ≥ 0.5 → 推进到下一句
	GameManager.current_state = GameManager.AppState.PLAYING
	box._process(0.6)
	assert_true(box._runner.is_waiting_line, "恢复后应停在下一句（等待输入）")
	assert_eq(box._runner.current_line().bubbles[0].text, "B", "下一句应为 B")

	GameManager.current_state = old
	box._close()
	await box.finished
	await get_tree().process_frame

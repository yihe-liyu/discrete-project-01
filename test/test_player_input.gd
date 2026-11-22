extends GutTest
## PlayerInput：每个物理 tick 只读一次 Input，玩法/录制读同一份快照。

func before_each() -> void:
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	for action in PlayerInput.ACTIONS:
		Input.action_release(action)


func after_each() -> void:
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	for action in PlayerInput.ACTIONS:
		Input.action_release(action)


func test_latch_holds_pressed_state_for_the_tick() -> void:
	Input.action_press("shoot")
	PlayerInput.latch()
	Input.action_release("shoot")

	assert_true(PlayerInput.is_action_pressed(&"shoot"), "锁存后本 tick 仍应看到按下")
	assert_false(Input.is_action_pressed("shoot"), "真实输入已释放（确认锁存不是直接读 Input）")


func test_axis_uses_latched_state() -> void:
	Input.action_press("move_right")
	PlayerInput.latch()
	Input.action_release("move_right")

	assert_eq(PlayerInput.get_axis(&"move_left", &"move_right"), 1.0,
		"轴应来自锁存快照，而不是释放后的真实输入")


func test_input_mask_uses_canonical_action_order() -> void:
	Input.action_press("shoot")
	Input.action_press("focus")
	PlayerInput.latch()

	var shoot_idx := PlayerInput.ACTIONS.find("shoot")
	var focus_idx := PlayerInput.ACTIONS.find("focus")
	var move_idx := PlayerInput.ACTIONS.find("move_left")
	assert_eq(PlayerInput.input_mask() & (1 << shoot_idx), 1 << shoot_idx)
	assert_eq(PlayerInput.input_mask() & (1 << focus_idx), 1 << focus_idx)
	assert_eq(PlayerInput.input_mask() & (1 << move_idx), 0)
	assert_eq(ReplayRecorder.ACTIONS, PlayerInput.ACTIONS, "录制与输入必须共用同一动作表")


func test_clear_latch_falls_back_to_real_input() -> void:
	Input.action_press("shoot")
	PlayerInput.latch()
	PlayerInput.clear_latch()
	Input.action_release("shoot")

	assert_false(PlayerInput.has_latch())
	assert_false(PlayerInput.is_action_pressed(&"shoot"), "清掉锁存后应回退到真实 Input")


func test_replay_recorder_reads_the_latched_mask() -> void:
	Input.action_press("shoot")
	PlayerInput.latch()
	Input.action_release("shoot")

	var rec := ReplayRecorder.new()
	rec.start()
	rec.capture()
	rec.stop()
	assert_true(rec.is_action_pressed_at(0, "shoot"),
		"录制必须与玩法读同一份锁存，而不是重新读 Input")


func test_override_mask_bypasses_real_input() -> void:
	var shoot_idx := PlayerInput.ACTIONS.find("shoot")
	PlayerInput.set_override_mask(1 << shoot_idx)
	Input.action_release("shoot")
	PlayerInput.latch()
	assert_true(PlayerInput.is_action_pressed(&"shoot"), "注入的掩码应覆盖真实输入")

	PlayerInput.clear_override()
	PlayerInput.latch()
	assert_false(PlayerInput.is_action_pressed(&"shoot"), "关闭注入后应回退真实输入")

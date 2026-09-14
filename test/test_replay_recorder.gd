extends GutTest
## ReplayRecorder 录输入基础设施测试

func test_start_records_seed():
	var rec := ReplayRecorder.new()
	rec.start()
	assert_eq(rec.rng_seed, RNG.get_seed(), "开始录制应记录当前 RNG 种子")
	assert_true(rec.recording, "start 后应在录制中")

func test_capture_appends_frames():
	var rec := ReplayRecorder.new()
	rec.start()
	rec.capture()
	rec.capture()
	rec.capture()
	rec.stop()
	assert_eq(rec.duration_frames, 3, "应记录 3 帧")
	assert_eq(rec.frames.size(), 3, "帧缓冲应有 3 项")
	assert_false(rec.recording, "stop 后应停止录制")

func test_capture_ignored_when_not_recording():
	var rec := ReplayRecorder.new()
	rec.capture()
	assert_eq(rec.frames.size(), 0, "未录制时 capture 应被忽略")

func test_input_mask_reflects_actions():
	Input.action_press("shoot")
	Input.action_press("focus")
	var rec := ReplayRecorder.new()
	var mask := rec.input_mask()
	Input.action_release("shoot")
	Input.action_release("focus")
	var shoot_idx := ReplayRecorder.ACTIONS.find("shoot")
	var focus_idx := ReplayRecorder.ACTIONS.find("focus")
	assert_eq(mask & (1 << shoot_idx), 1 << shoot_idx, "shoot 按下时掩码对应位应为 1")
	assert_eq(mask & (1 << focus_idx), 1 << focus_idx, "focus 按下时掩码对应位应为 1")

func test_is_action_pressed_at():
	var rec := ReplayRecorder.new()
	rec.start()
	Input.action_press("shoot")
	rec.capture()  # 帧 0：shoot 按下
	Input.action_release("shoot")
	rec.capture()  # 帧 1：无输入
	rec.stop()
	assert_true(rec.is_action_pressed_at(0, "shoot"), "帧 0 应按下 shoot")
	assert_false(rec.is_action_pressed_at(1, "shoot"), "帧 1 不应按下 shoot")
	assert_false(rec.is_action_pressed_at(99, "shoot"), "越界帧应返回 false")

func test_save_load_roundtrip():
	var rec := ReplayRecorder.new()
	rec.start()
	Input.action_press("shoot")
	rec.capture()
	Input.action_press("focus")
	rec.capture()
	rec.capture()
	rec.stop()
	var path := "user://test_replay.json"
	assert_true(rec.save(path), "应能存盘")
	var rec2 := ReplayRecorder.new()
	assert_true(rec2.load_file(path), "应能读盘")
	assert_eq(rec2.rng_seed, rec.rng_seed, "种子应一致")
	assert_eq(rec2.duration_frames, rec.duration_frames, "帧数应一致")
	assert_eq(rec2.frames, rec.frames, "帧数据应一致")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_load_rejects_bad_version():
	var rec := ReplayRecorder.new()
	assert_false(rec.load_dict({"version": 99, "frames_hex": "", "duration": 0}),
		"版本不匹配应拒绝加载")

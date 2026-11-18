extends GutTest
## ReplaySession：一局录制能落盘，并出现在回放列表里。

func before_each() -> void:
	ReplaySession.cancel_run()

func after_each() -> void:
	ReplaySession.cancel_run()

func test_finish_writes_file_and_lists_it() -> void:
	assert_true(ReplaySession.start_run(), "首次 start_run 应开始录制")
	assert_true(ReplaySession.is_recording())
	ReplaySession.capture_frame()
	ReplaySession.capture_frame()
	var path := ReplaySession.finish_run({
		"difficulty": 2, "character": 1, "stage_no": 1, "score": 4321,
	})
	assert_ne(path, "", "结束时应写出回放文件")
	assert_false(ReplaySession.is_recording(), "落盘后应停止录制")
	assert_true(FileAccess.file_exists(path), "回放文件应存在")

	var entries := ReplaySession.list_replays()
	var found := false
	for e in entries:
		if e.get("path") == path:
			found = true
			assert_eq(int(e.get("duration", 0)), 2, "帧数应写进列表")
			assert_eq(int(e.get("metadata", {}).get("score", 0)), 4321)
	assert_true(found, "新回放应出现在列表里")
	if path != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_start_run_is_idempotent_while_recording() -> void:
	assert_true(ReplaySession.start_run())
	assert_false(ReplaySession.start_run(), "切面 reload 不应重置正在录的局")
	ReplaySession.cancel_run()
	assert_false(ReplaySession.is_recording())

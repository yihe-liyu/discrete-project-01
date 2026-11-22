extends GutTest
## SimClock：tick 冻结的 owner / 帧数 / 嵌套恢复语义。

func after_each() -> void:
	SimClock.reset()
	get_tree().paused = false


func test_freeze_tracks_owner_and_frames() -> void:
	assert_false(SimClock.is_frozen(), "初始不应冻结")
	assert_true(SimClock.freeze(self, 3, false), "首次 freeze 应成功")
	assert_true(SimClock.is_frozen())
	assert_eq(SimClock.frames_left(self), 3, "记录本次冻结的帧数")

	assert_true(SimClock.unfreeze(self), "owner 应能解冻")
	assert_false(SimClock.is_frozen(), "最后一个 owner 移除后应恢复")
	assert_eq(SimClock.frames_left(self), 0, "解冻后不再有帧数")


func test_nested_owners_stay_frozen_until_last_unfreeze() -> void:
	var a := Node.new()
	var b := Node.new()
	add_child_autofree(a)
	add_child_autofree(b)

	SimClock.freeze(a, 2, false)
	SimClock.freeze(b, 2, false)
	SimClock.unfreeze(a)
	assert_true(SimClock.is_frozen(), "还有一个 owner 时必须保持冻结")
	SimClock.unfreeze(b)
	assert_false(SimClock.is_frozen(), "最后一个 owner 移除后才恢复")


func test_reset_clears_all_freezes() -> void:
	SimClock.freeze(self, 5, false)
	assert_true(SimClock.is_frozen())
	SimClock.reset()
	assert_false(SimClock.is_frozen(), "reset 必须清空所有冻结")


func test_auto_unfreeze_after_recorded_frames() -> void:
	SimClock.freeze(self, 2, true)
	assert_true(SimClock.is_frozen())
	for _i in 3:
		await get_tree().physics_frame
	assert_false(SimClock.is_frozen(), "auto 冻结应在帧数到点后自己恢复")

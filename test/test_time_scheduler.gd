extends GutTest
## TimeScheduler：只改变每帧 tick 数，不改变每个 tick 的 DT。

func test_speed_changes_tick_count_not_dt() -> void:
	var scheduler := TimeScheduler.new(1.0)
	assert_eq(scheduler.advance(1.0 / 60.0), 1)
	assert_almost_eq(scheduler.alpha(), 0.0, 0.0001)

	scheduler.reset()
	scheduler.set_speed(2.0)
	assert_eq(scheduler.advance(1.0 / 60.0), 2, "2x 应消费 2 个固定 tick")

	scheduler.reset()
	scheduler.set_speed(0.5)
	assert_eq(scheduler.advance(1.0 / 60.0), 0, "0.5x 第一帧不够一个 tick")
	assert_eq(scheduler.advance(1.0 / 60.0), 1, "0.5x 两帧凑一个 tick")


func test_scheduler_caps_catch_up() -> void:
	var scheduler := TimeScheduler.new(10.0)
	scheduler.max_steps_per_advance = 3
	assert_eq(scheduler.advance(1.0), 3, "单帧最多补 max_steps_per_advance 个 tick")
	assert_lt(scheduler.alpha(), 1.0)

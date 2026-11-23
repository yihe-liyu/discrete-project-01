extends GutTest
## TickMover 由 SimClock 统一推进：在 tick_prepare 里新增的 mover 也必须真的动。

func after_each() -> void:
	SimClock.reset()


func test_mover_attached_in_prepare_advances() -> void:
	var target := Node2D.new()
	add_child_autofree(target)
	var attach_tick := SimClock.tick + 1
	var attached := [false]
	SimClock.set_tick_hooks(func(tick: int) -> void:
		if tick == attach_tick and not attached[0]:
			attached[0] = true
			var mover := TickMover.attach(target)
			mover.tween_property(target, "position", Vector2(60.0, 0.0), 1.0)
	, Callable())
	for _i in 5:
		await get_tree().physics_frame
	assert_true(attached[0], "prepare 中应已挂上 mover")
	assert_gt(target.position.x, 0.0, "SimClock 必须推进 prepare 中新挂的 mover")
	var frozen_x := target.position.x
	SimClock.freeze(target, 3)
	for _i in 3:
		await get_tree().physics_frame
	assert_eq(target.position.x, frozen_x, "冻结期间 mover 不应前进")
	SimClock.unfreeze(target)
	SimClock.clear_tick_hooks()

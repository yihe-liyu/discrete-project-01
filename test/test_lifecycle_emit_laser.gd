extends GutTest
## lifecycle.emit_laser：相位结束后把激光请求交给宿主队列。

const BEHAVIOR_HOST := preload("res://scripts/kernel_bridge/kernel_behavior_host.gd")


class FakeBackend:
	var lasers: Array = []

	func spawn_behavior_laser(skeleton: LaserSkeleton, color: Color,
			opts: Dictionary, offset: Vector2) -> LaserBeam:
		lasers.append({"skeleton": skeleton, "color": color, "opts": opts, "offset": offset})
		return null


func test_emit_laser_is_phase_end_call() -> void:
	var lc := BulletLifecycle.new()
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2.ZERO, Vector2(0, 300))
	lc.until_elapsed(0.1).emit_laser(sk, Color.RED, {"lifetime": 1.0})
	var actions: Array = lc.phases[0][&"on_end"]
	assert_eq(actions.size(), 1)
	assert_eq(actions[0][&"op"], BulletLifecycle.A_CALL)


func test_behavior_host_flushes_laser() -> void:
	var backend := FakeBackend.new()
	var host = BEHAVIOR_HOST.new()
	host.setup(backend)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2.ZERO, Vector2(0, 300))
	host.queue_laser(sk, Color.AQUA, {"lifetime": 2.0}, Vector2(10, 0))
	host.flush()
	assert_eq(backend.lasers.size(), 1)
	assert_eq(backend.lasers[0]["offset"], Vector2(10, 0))
	assert_eq(backend.lasers[0]["color"], Color.AQUA)

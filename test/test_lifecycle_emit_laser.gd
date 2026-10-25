extends GutTest
## lifecycle.emit_laser：相位结束后把激光请求交给宿主队列。

const BEHAVIOR_HOST := preload("res://scripts/kernel_bridge/kernel_behavior_host.gd")


class FakeBackend:
	var lasers: Array = []

	func spawn_behavior_laser(skeleton: LaserSkeleton, color: Color,
			opts: Dictionary, offset: Vector2, direction: Vector2 = Vector2.ZERO) -> LaserBeam:
		lasers.append({"skeleton": skeleton, "color": color, "opts": opts,
			"offset": offset, "direction": direction})
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


func test_emit_laser_dir_is_native_action() -> void:
	var lc := BulletLifecycle.new()
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2.ZERO, Vector2(0, 300))
	lc.until_elapsed(0.1).emit_laser_dir(
		sk, Color.GOLD, BulletLifecycle.forward())
	var actions: Array = lc.phases[0][&"on_end"]
	assert_eq(actions[0][&"op"], BulletLifecycle.A_EMIT_LASER)
	var program := lc.compile_program()
	assert_true(program["ops"].has(LifecycleCompiler.OP_A_EMIT_LASER), "应编译成原生激光 action")


func test_behavior_host_queues_directed_laser() -> void:
	var backend := FakeBackend.new()
	var host = BEHAVIOR_HOST.new()
	host.setup(backend)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2.ZERO, Vector2(0, 300))
	host.queue_laser_dir({
		&"skeleton": sk,
		&"color": Color.GOLD,
		&"opts": {},
		&"offset": Vector2(0, -10),
		&"at_current": true,
	}, Vector2(100, 200), Vector2.DOWN)
	host.flush()
	assert_eq(backend.lasers.size(), 1)
	assert_eq(backend.lasers[0]["offset"], Vector2(100, 190))
	assert_eq(backend.lasers[0]["direction"], Vector2.DOWN)


func test_native_emit_laser_dir_event() -> void:
	var backend := FakeBackend.new()
	var host = BEHAVIOR_HOST.new()
	host.setup(backend)
	var sys := KernelNativeSystem.new()
	add_child_autofree(sys)
	sys.set_physics_process(false)
	sys.cull_rect = Rect2(-10000, -10000, 20000, 20000)
	sys.enable_native_behaviors = true
	sys.behavior_host = host
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2.ZERO, Vector2(0, 300))
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.0).emit_laser_dir(sk, Color.GOLD, BulletLifecycle.forward())
	sys.spawn(BulletType.new(), Vector2(100, 200), Vector2.ZERO, Color.WHITE,
		LifecycleCatalog.MOVE_LIFECYCLE, {&"lifecycle": lc})
	sys.step(0.1)
	host.flush()
	assert_eq(backend.lasers.size(), 1, "原生 action 应把激光交给宿主")
	assert_eq(backend.lasers[0]["direction"], Vector2.DOWN)

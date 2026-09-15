extends GutTest
## 激光性能基准：100 条激光每帧 step 开销
## 记录数字供对比（静止激光应接近 0，因为 _is_dirty 不重建）

var _holder: Node

## 激光池 beams 挂 holder，随测试结束释放（LaserEngine.setup 每测试 64 条）
func before_each():
	_holder = Node.new()
	add_child_autofree(_holder)

func _spawn_many(engine: LaserEngine, count: int, grow: bool) -> void:
	for i in count:
		var sk: LaserSkeleton
		match i % 3:
			0:
				sk = LaserPresets.straight(Vector2(100, 100 + i * 3), Vector2(900, 100 + i * 3))
			1:
				sk = LaserPresets.wave(Vector2(100, 200 + i * 3), Vector2(1, 0), 800.0, 60.0, 200.0)
			_:
				sk = LaserPresets.spiral(Vector2(448, 480), 300.0, 1.5, float(i) * 0.1)
		engine.spawn(sk, Color(1, 0, 0), {"grow": grow, "grow_speed": 400.0, "tail": 200.0, "lifetime": 120.0})

func _bench_steps(engine: LaserEngine, frames: int) -> float:
	var t0 := Time.get_ticks_usec()
	for f in frames:
		engine.step(0.016)
	return float(Time.get_ticks_usec() - t0) / float(frames)

func test_100_static_lasers_bench():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(_holder)
	_spawn_many(engine, 100, false)
	var us := _bench_steps(engine, 120)
	print("激光基准 [100 静止]: %.1f us/帧 (%.2f ms)" % [us, us / 1000.0])
	assert_gt(us, 0.0, "100 静止激光基准应完成有效计时")
	assert_lt(us, 50000.0, "100 静止激光基准异常：%.1f us/帧（>50ms）" % us)

func test_100_growing_lasers_bench():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(_holder)
	_spawn_many(engine, 100, true)
	var us := _bench_steps(engine, 60)
	print("激光基准 [100 生长]: %.1f us/帧 (%.2f ms)" % [us, us / 1000.0])
	assert_gt(us, 0.0, "100 生长激光基准应完成有效计时")
	assert_lt(us, 50000.0, "100 生长激光基准异常：%.1f us/帧（>50ms）" % us)

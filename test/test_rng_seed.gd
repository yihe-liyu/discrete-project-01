extends GutTest
## RNG 可复现性测试 —— Replay 系统的基础保证

func _make_rng(seed_value: int):
	var rng = load("res://scripts/autoload/rng.gd").new()
	autofree(rng)  # rng.gd extends Node，裸 new 不释放会成孤儿
	rng.set_seed(seed_value)
	return rng


func test_same_seed_same_sequence():
	var a = _make_rng(42)
	var b = _make_rng(42)
	for i in 200:
		assert_eq(a.randf(), b.randf(), "randf 序列在种子 %d 下不可复现" % 42)


func test_different_seeds_different_sequence():
	var a = _make_rng(42)
	var b = _make_rng(43)
	var same := true
	for i in 100:
		if not is_equal_approx(a.randf(), b.randf()):
			same = false
			break
	assert_false(same, "不同种子应该产生不同序列")


func test_seed_reproducible_after_reset():
	var a = _make_rng(7)
	var first: float = a.randf()
	# 重新设置相同种子，序列从头开始
	a.set_seed(7)
	var second: float = a.randf()
	assert_eq(first, second, "重设相同种子后应从头开始")


func test_randf_range_bounds():
	var rng = _make_rng(12345)
	for i in 500:
		var v: float = rng.randf_range(-10.0, 10.0)
		assert_gte(v, -10.0, "randf_range 下界越界")
		assert_lte(v, 10.0, "randf_range 上界越界")


func test_randi_range_bounds():
	var rng = _make_rng(999)
	for i in 500:
		var v: int = rng.randi_range(3, 7)
		assert_gte(v, 3, "randi_range 下界越界")
		assert_lte(v, 7, "randi_range 上界越界")


func test_snapshot_restore_state():
	var rng = _make_rng(20261024)
	for i in 5:
		rng.randf()
	var snapshot: Dictionary = rng.snapshot_state()
	var next: float = rng.randf()
	rng.restore_state(snapshot)
	assert_eq(rng.randf(), next, "快照恢复后应回到同一 RNG 状态")

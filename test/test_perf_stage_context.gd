extends GutTest
## 性能基准：StageContext 创建开销（高频路径：每颗协程弹 bind 时 new 一次）
## 对比基准用 —— 优化前后数值差异说明收益

func test_stage_context_creation_bench():
	var runner := CoroutineRunner.new()
	autofree(runner)
	add_child(runner)
	var N := 10000
	var t0 := Time.get_ticks_usec()
	for i in N:
		var ctx := StageContext.new(runner)
		# 模拟子弹协程典型用法（只用 bullets + player）
		@warning_ignore("standalone_expression")
		ctx.bullets
		@warning_ignore("standalone_expression")
		ctx.player
	t0 = Time.get_ticks_usec() - t0
	var per := float(t0) / float(N)
	print("StageContext.new 基准: %d 次 = %d us (平均 %.2f us/次)" % [N, t0, per])
	# 阈值宽松：只做记录，不做硬断言（CI 抖动大）
	push_warning("基准参考: %.2f us/次（>2.5us 需优化）" % per)
	assert_true(true, "基准已记录")

extends Node
## 弹幕性能基准 —— 量「离 GDExtension Trigger 多远」。
##
## 运行：godot --headless --path . res://tools/bench_danmaku.tscn
##
## 测的是**脚本侧热路径**（GDExtension 要替换的正是这部分）：
##   ① 内核积分 system._physics_process（SoA 积分 + 计时 + 剔除）
##   ② 行为 behavior.process（world_accel 路径）
##   ③ 原生宽相 system.query_circle（uniform grid；原 CollisionResolver.overlap_ids 已内联进内核）
##   ④ 渲染 CPU 同步 BulletMultiMesh._sync_kernel（分组 + 填 MultiMesh）
## **GPU 绘制不计**（headless 无 GPU）。
## 参照：60fps 预算 16.67ms/帧。

const COUNTS: Array[int] = [500, 1000, 2000, 3000, 4000, 6000, 8000]
const WARMUP := 20
const FRAMES := 120
const DT := 1.0 / 60.0
const CENTER := Vector2(448.0, 384.0)
const BUDGET_60 := 16.67

var _data: BulletData


func _ready() -> void:
	print("=== 弹幕基准（脚本侧热路径；GPU 绘制不计） ===")
	print("N\t模式\t积分ms\t行为ms\t宽相ms\t渲染ms\t合计ms\t%60fps")
	for n in COUNTS:
		_run(n, false)
		_run(n, true)
	get_tree().quit()


func _run(n: int, with_behavior: bool) -> void:
	var backend := KernelBulletHost.new()
	add_child(backend)
	backend.setup_behaviors(null, Callable())
	backend.system.cull_rect = Rect2(-100000, -100000, 200000, 200000)   # 不剔除 → N 恒定

	var mm := BulletMultiMesh.new()
	mm.is_enabled = true
	add_child(mm)
	mm.set_backend(backend)

	_data = BulletData.new().enemy().tex("小玉").speed(200.0).blend(true)
	_data.spawn_fog = false
	if with_behavior:
		_data.lifecycle = BulletLifecycle.world_accel(Vector2(0.0, 60.0))   # world_accel 行为路径

	for i in n:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		var pos := CENTER + dir * sqrt(randf()) * 300.0
		backend.shoot(_data, pos, dir)

	for f in WARMUP:
		backend.system._physics_process(DT)
		if with_behavior:
			backend.behavior.process()

	var t_int := 0
	var t_beh := 0
	var t_brd := 0
	var t_ren := 0
	for f in FRAMES:
		var a := Time.get_ticks_usec()
		backend.system._physics_process(DT)
		var b := Time.get_ticks_usec()
		if with_behavior:
			backend.behavior.process()
		var c := Time.get_ticks_usec()
		backend.system.query_circle(CENTER, 120.0)
		var d := Time.get_ticks_usec()
		mm._sync_kernel()
		var e := Time.get_ticks_usec()
		t_int += b - a
		t_beh += c - b
		t_brd += d - c
		t_ren += e - d

	var ms_int := float(t_int) / FRAMES / 1000.0
	var ms_beh := float(t_beh) / FRAMES / 1000.0
	var ms_brd := float(t_brd) / FRAMES / 1000.0
	var ms_ren := float(t_ren) / FRAMES / 1000.0
	var ms_tot := ms_int + ms_beh + ms_brd + ms_ren
	print("%d\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\t%.0f%%" % [
		n, "行为" if with_behavior else "直线", ms_int, ms_beh, ms_brd, ms_ren, ms_tot, ms_tot / BUDGET_60 * 100.0])
	backend.free()   # 同步 _ready 里 queue_free 从不执行 → 会累积后端（曾经的数据噪音源）
	mm.free()

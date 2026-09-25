extends Node
## N2/N4 探针基准：原生 DanmakuStore（SoA 积分 + 剔除 + MultiMesh 写入）
## 对照 game 项目里的 GDScript 基准 tools/bench_danmaku.gd。
const NS: Array[int] = [3000, 6000, 8000]
const FRAMES := 120
const DT := 1.0 / 60.0
const CENTER := Vector2(448.0, 384.0)


func _ready() -> void:
	print("=== 原生探针：DanmakuStore（SoA 积分 + 剔除 + 实例缓冲写入）===")
	print("N\t积分ms\t渲染ms\t合计ms")
	if not ClassDB.class_exists("DanmakuStore"):
		print("DanmakuStore 未注册 —— 扩展没加载")
		get_tree().quit()
		return
	for n in NS:
		_bench(n)
	get_tree().quit()


func _bench(n: int) -> void:
	var store: Object = ClassDB.instantiate("DanmakuStore")
	store.setup(n + 16, Rect2(-100000, -100000, 200000, 200000))
	for i in n:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		store.spawn(CENTER + dir * sqrt(randf()) * 300.0, dir * 200.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = n + 16

	for f in 20:
		store.integrate(DT)
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		store.integrate(DT)
	var t1 := Time.get_ticks_usec()
	for f in FRAMES:
		store.fill_multimesh(mm, Color.WHITE)
	var t2 := Time.get_ticks_usec()

	print("%d\t%.3f\t%.3f\t%.3f" % [
		n,
		float(t1 - t0) / FRAMES / 1000.0,
		float(t2 - t1) / FRAMES / 1000.0,
		float(t2 - t0) / FRAMES / 1000.0,
	])

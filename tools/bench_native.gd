extends Node
## 原生 DanmakuStore 基准（需先 ./tools/build_gdextension.sh + 编辑器导入一次）。
## 与 tools/bench_danmaku.gd（GDScript 内核）对照。
## 运行：godot --headless --path . res://tools/bench_native.tscn

const NS: Array[int] = [3000, 6000, 8000]
const FRAMES := 120
const DT := 1.0 / 60.0
const CENTER := Vector2(448.0, 384.0)


func _ready() -> void:
	if not ClassDB.class_exists("DanmakuStore"):
		print("DanmakuStore 未注册 —— 先 ./tools/build_gdextension.sh 并让编辑器导入一次")
		get_tree().quit()
		return
	print("=== 原生 DanmakuStore 基准（批量 spawn；每弹 type/faction/color）===")
	print("N\t积分ms\t渲染ms\t合计ms")
	for n in NS:
		_bench(n)
	get_tree().quit()


func _bench(n: int) -> void:
	var store: Object = ClassDB.instantiate("DanmakuStore")
	store.setup(n + 16, Rect2(-100000, -100000, 200000, 200000))

	var positions := PackedVector2Array()
	var velocities := PackedVector2Array()
	var types := PackedInt32Array()
	var factions := PackedInt32Array()
	var colors := PackedColorArray()
	positions.resize(n)
	velocities.resize(n)
	types.resize(n)
	factions.resize(n)
	colors.resize(n)
	for i in n:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		positions[i] = CENTER + dir * sqrt(randf()) * 300.0
		velocities[i] = dir * 200.0
		types[i] = i % 8
		factions[i] = i % 2
		colors[i] = Color(randf(), randf(), randf())
	store.spawn_batch(positions, velocities, types, factions, colors)

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
		store.fill_multimesh(mm)
	var t2 := Time.get_ticks_usec()

	print("%d\t%.3f\t%.3f\t%.3f" % [
		n,
		float(t1 - t0) / FRAMES / 1000.0,
		float(t2 - t1) / FRAMES / 1000.0,
		float(t2 - t0) / FRAMES / 1000.0,
	])

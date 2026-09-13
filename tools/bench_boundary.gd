extends Node
## 边界成本微基准：GDScript Packed 数组逐元素访问 vs 原生方法逐次调用。
## 决定 N2.2 存储搬原生后，行为循环是否必须走批量接口（N2.3）。
## 运行：godot --headless --path . res://tools/bench_boundary.tscn

const N := 6000
const FRAMES := 60


func _ready() -> void:
	if not ClassDB.class_exists("DanmakuStore"):
		print("DanmakuStore 未注册 —— 先 ./tools/build_gdextension.sh 并让编辑器导入一次")
		get_tree().quit()
		return
	var store: Object = ClassDB.instantiate("DanmakuStore")
	store.setup(N + 16, Rect2(-100000, -100000, 200000, 200000))
	var pos := PackedVector2Array(); pos.resize(N)
	var vel := PackedVector2Array(); vel.resize(N)
	var types := PackedInt32Array(); types.resize(N)
	var facs := PackedInt32Array(); facs.resize(N)
	var cols := PackedColorArray(); cols.resize(N)
	for i in N:
		pos[i] = Vector2(i, i * 0.5)
		vel[i] = Vector2(1, 2)
		types[i] = i % 8
		facs[i] = i % 2
		cols[i] = Color(1, 1, 1)
	store.spawn_batch(pos, vel, types, facs, cols)

	print("=== 边界微基准 N=%d, %d 帧 ===" % [N, FRAMES])
	print("场景\tms/帧\tns/次")
	_time("gd  PackedVector2Array[i]", func() -> float:
		var acc := 0.0
		for i in N:
			acc += pos[i].x
		return acc)
	_time("native get_position(i)", func() -> float:
		var acc := 0.0
		for i in N:
			var p: Vector2 = store.get_position(i)
			acc += p.x
		return acc)
	_time("gd  PackedInt32Array[i]", func() -> float:
		var acc := 0
		for i in N:
			acc += types[i]
		return float(acc))
	_time("native get_type(i)", func() -> float:
		var acc := 0
		for i in N:
			acc += store.get_type(i)
		return float(acc))
	_time("gd  PackedColorArray[i]", func() -> float:
		var acc := 0.0
		for i in N:
			acc += cols[i].r
		return acc)
	_time("native get_color(i)", func() -> float:
		var acc := 0.0
		for i in N:
			var c: Color = store.get_color(i)
			acc += c.r
		return acc)
	_time("native get_positions() 批量", func() -> float:
		var arr: PackedVector2Array = store.get_positions()
		var acc := 0.0
		for i in N:
			acc += arr[i].x
		return acc)
	get_tree().quit()


func _time(label: String, fn: Callable) -> void:
	for w in 5:
		fn.call()
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		fn.call()
	var t1 := Time.get_ticks_usec()
	var ms := float(t1 - t0) / FRAMES / 1000.0
	print("%s\t%.3f\t%.1f" % [label, ms, ms * 1e6 / N])

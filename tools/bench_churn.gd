extends Node
## N2.2 ROI 补测：GDScript 内核的「发射 + 回收」churn 成本（原生存储会一并吃掉）。
## 运行：godot --headless --path . res://tools/bench_churn.tscn

const N := 6000
const WAVES := 10


func _ready() -> void:
	var bt := BulletType.new()
	var pos := Vector2(448, 384)
	var vel := Vector2(0, -200)
	var col := Color.WHITE

	print("=== churn 基准 N=%d, %d 波 ===" % [N, WAVES])

	# GDScript 内核：逐发 spawn + 反向 despawn
	var sys := BulletSystem.new()
	var t0 := Time.get_ticks_usec()
	for w in WAVES:
		for i in N:
			sys.spawn(bt, pos, vel, col)
		for i in range(sys.get_active_count() - 1, -1, -1):
			sys.despawn(i)
	var t1 := Time.get_ticks_usec()
	print("GDScript spawn+despawn\t%.3f ms/波" % (float(t1 - t0) / WAVES / 1000.0))

	# 原生：逐发 spawn（无 despawn，用 setup 复位代替）
	if ClassDB.class_exists("DanmakuStore"):
		var store: Object = ClassDB.instantiate("DanmakuStore")
		var t2 := Time.get_ticks_usec()
		for w in WAVES:
			store.setup(N + 16, Rect2(-1e6, -1e6, 2e6, 2e6))
			for i in N:
				store.spawn(pos, vel, 0, 0, col)
		var t3 := Time.get_ticks_usec()
		print("原生 spawn(+setup 复位)\t%.3f ms/波" % (float(t3 - t2) / WAVES / 1000.0))
	else:
		print("DanmakuStore 未注册（跳过原生）")
	sys.free()
	get_tree().quit()

extends Node
## N2.2 端到端（类路径）：KernelNativeSystem._physics_process vs BulletSystem._physics_process。
## 含 Dictionary 取字段 + 数组 adopt + dead 重放的真实开销。
## 运行：godot --headless --path . res://tools/bench_native_system.tscn

const N := 6000
const FRAMES := 60
const DT := 1.0 / 60.0


func _ready() -> void:
	var bt := BulletType.new()
	var gs := BulletSystem.new()
	var nt := KernelNativeSystem.new()
	for s in [gs, nt]:
		s.default_lifetime = 100.0
		s.cull_rect = Rect2(-100000, -100000, 200000, 200000)
		s.cull_margin = 0.0
	for i in N:
		var pos := Vector2(448 + (i % 100) * 4, 384 + (i / 100) * 4)
		var vel := Vector2.RIGHT.rotated(i * 0.13) * 180.0
		gs.spawn(bt, pos, vel, Color.WHITE)
		nt.spawn(bt, pos, vel, Color.WHITE)

	print("=== N2.2 积分类路径 N=%d, %d 帧 ===" % [N, FRAMES])
	print("实现\tms/帧")
	_bench("GDScript BulletSystem", gs)
	if nt.is_native_ready():
		_bench("原生 KernelNativeSystem", nt)
	else:
		print("原生 KernelNativeSystem\t（未加载扩展）")
	gs.free(); nt.free()
	get_tree().quit()


func _bench(label: String, s: BulletSystem) -> void:
	for w in 5:
		s._physics_process(DT)
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		s._physics_process(DT)
	var t1 := Time.get_ticks_usec()
	print("%s\t%.3f" % [label, float(t1 - t0) / FRAMES / 1000.0])

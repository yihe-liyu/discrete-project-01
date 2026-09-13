extends Node
## 渲染同步对照：同进程、同数据，原生整段（分组+旋转+fade+填充）on / off 直接比。
## 运行：godot --headless --path . res://tools/bench_render.tscn
const NS: Array[int] = [3000, 6000, 8000]
const FRAMES := 150
const DT := 1.0 / 60.0
const CENTER := Vector2(448.0, 384.0)


func _ready() -> void:
	print("N\t原生(ms)\tGDScript(ms)\t倍数")
	for n in NS:
		_run(n)
	get_tree().quit()


func _run(n: int) -> void:
	var backend := KernelBulletBackend.new()
	add_child(backend)
	backend.setup_behaviors(null, Callable())
	backend.system.cull_rect = Rect2(-100000, -100000, 200000, 200000)

	var data := BulletData.new().enemy().tex("小玉").speed(200.0).blend(true)
	data.spawn_fog = false
	for i in n:
		var dir := Vector2.RIGHT.rotated(randf() * TAU)
		backend.shoot(data, CENTER + dir * sqrt(randf()) * 300.0, dir)

	var mm := BulletMultiMesh.new()
	mm.enabled = true
	add_child(mm)
	mm.set_backend(backend)

	for f in 30:
		backend.system._physics_process(DT)
		mm._sync_kernel()

	var t_native := _time(mm, true)
	var t_gd := _time(mm, false)
	print("%d\t%.3f\t%.3f\t%.2fx" % [n, t_native, t_gd, (t_gd / t_native) if t_native > 0.0 else 0.0])
	backend.free()
	mm.free()


func _time(mm: BulletMultiMesh, native_on: bool) -> float:
	mm.use_native_sync = native_on
	mm._sync_kernel()   # 预热该分支
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		mm._sync_kernel()
	return float(Time.get_ticks_usec() - t0) / FRAMES / 1000.0

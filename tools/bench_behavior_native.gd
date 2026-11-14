extends Node
## 原生 behavior_tick 在 6000 弹的每帧成本。
const N := 6000
const FRAMES := 120
const DT := 1.0 / 60.0


func _ready() -> void:
	if not ClassDB.class_exists("DanmakuStore"):
		print("DanmakuStore 未注册")
		get_tree().quit()
		return
	print("=== 原生 behavior_tick N=%d ===" % N)
	_bench("accel", "accel", PackedFloat32Array([0.0, 200.0]))
	_bench("homing", "homing", PackedFloat32Array([
		500.0, deg_to_rad(720.0), 1.0, 2000.0, 1.0, 2.0, 150.0, 2.0,
	]))


func _bench(tag: String, behavior_name: String, params: PackedFloat32Array) -> void:
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(N + 16, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(64.0, 832.0, 32.0)
	var bid: int = store.get_behavior_id(behavior_name)
	for i in N:
		var dir := Vector2.RIGHT.rotated(i * 0.13)
		var id: int = store.spawn(Vector2(448.0, 400.0) + dir * 100.0, dir * 200.0, 0, 0, Color.WHITE)
		store.set_behavior(id, bid, params)
	var enemies := PackedVector2Array([Vector2(448.0, 100.0)])
	for f in 10:
		store.behavior_tick(DT, Vector2(448.0, 600.0), Vector2(448.0, 100.0), true, enemies)
	var t0 := Time.get_ticks_usec()
	for f in FRAMES:
		store.behavior_tick(DT, Vector2(448.0, 600.0), Vector2(448.0, 100.0), true, enemies)
	var t1 := Time.get_ticks_usec()
	print("%s\t%.3f ms/帧（6000 弹）" % [tag, float(t1 - t0) / FRAMES / 1000.0])
	store.free()
	get_tree().quit()

extends GutTest
## L3.5-1：原生 set_hitbox / hit_test / query_circle / grazed ↔ GDScript 内核 1:1。

func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _gs() -> BulletSystem:
	var s: BulletSystem = autofree(BulletSystem.new())
	s.cull_rect = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
	s.cull_margin = 0.0
	s.default_lifetime = 100.0
	return s


func _pair(bt: BulletType, n: int) -> Array:
	var gs := _gs()
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(1024, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(64.0, 832.0, 32.0)
	for i in n:
		var pos := Vector2(100.0 + (i % 10) * 40.0, 100.0 + (i / 10) * 40.0)
		var vel := Vector2.RIGHT.rotated(i * 0.4) * 200.0
		gs.spawn(bt, pos, vel, Color.WHITE)
		var id: int = store.spawn(pos, vel, i % 4, 0, Color.WHITE)
		store.set_hitbox(id, bt.hitbox_radius, bt.hitbox_offset, bt.hitbox_size, bt.follow_dir, bt.dir_offset)
	return [gs, store]


func _sorted(a: PackedInt32Array) -> Array:
	var out: Array = []
	for v in a:
		out.append(v)
	out.sort()
	return out


func _check(bt: BulletType, tag: String) -> void:
	var p := _pair(bt, 40)
	var gs: BulletSystem = p[0]
	var store = p[1]
	var centers: Array = [Vector2(200.0, 200.0), Vector2(400.0, 300.0), Vector2(0.0, 0.0), Vector2(448.0, 384.0)]
	for c in centers:
		for r in [40.0, 120.0, 300.0]:
			assert_eq(_sorted(store.query_circle(c, r)), _sorted(gs.query_circle(c, r)), "%s query @%s r=%.0f" % [tag, c, r])
	for i in 40:
		for c in [Vector2(200.0, 200.0), Vector2(400.0, 300.0)]:
			assert_eq(store.hit_test(i, c, 30.0), gs.hit_test(i, c, 30.0), "%s hit_test %d @%s" % [tag, i, c])


func test_native_query_circle_parity_circle() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	_check(bt, "circle")


func test_native_query_circle_parity_offset() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_offset = Vector2(3.0, 0.0)
	_check(bt, "offset")


func test_native_query_circle_parity_rect() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_offset = Vector2(3.0, 0.0)
	bt.hitbox_size = Vector2(10.0, 6.0)
	bt.follow_dir = true
	bt.dir_offset = 0.4
	_check(bt, "rect")


func test_native_grazed_parity() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	var p := _pair(bt, 8)
	var gs: BulletSystem = p[0]
	var store = p[1]
	for i in 8:
		assert_eq(store.is_grazed(i), gs.is_grazed(i), "grazed 初值 %d" % i)
	gs.mark_grazed(2); store.mark_grazed(2)
	assert_true(store.is_grazed(2), "原生标记生效")
	for i in 8:
		assert_eq(store.is_grazed(i), gs.is_grazed(i), "grazed %d" % i)

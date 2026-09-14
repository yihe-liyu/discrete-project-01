extends GutTest
## L3.5-4b-pre：原生宽相 uniform grid ↔ GDScript `BulletSystem` 1:1。
## 目的：让原生 query_circle 在大弹量下不再线性扫描（GDScript 早有网格）。

const FIELD := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
	GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _build(bt: BulletType, n: int, cull: Rect2) -> Array:
	var gs: BulletSystem = autofree(BulletSystem.new())
	gs.cull_rect = cull
	gs.cull_margin = 0.0
	gs.default_lifetime = 100.0
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(1024, cull)
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
	for i in n:
		@warning_ignore("integer_division")   # 网格行号，故意整除
		var pos := Vector2(GameConfig.FIELD_LEFT + (i % 16) * 45.0, GameConfig.FIELD_TOP + (i / 16) * 45.0)
		if i % 17 == 0:
			pos = Vector2(-200.0 + i, 1300.0 + i)   # 界外：单元钳到边缘（两路同规则）
		var vel := Vector2.RIGHT.rotated(i * 0.37) * 200.0
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


## 暴力参考：逐行 hit_test（与网格实现无关），证明网格不漏/不重。
func _brute(store, center: Vector2, radius: float) -> Array:
	var out: Array = []
	for i in store.get_active_count():
		if store.hit_test(i, center, radius):
			out.append(i)
	out.sort()
	return out


func _check(bt: BulletType, tag: String) -> void:
	var p := _build(bt, 96, FIELD)
	var gs: BulletSystem = p[0]
	var store = p[1]
	var centers: Array = [
		Vector2(200.0, 200.0), Vector2(448.0, 384.0), Vector2(700.0, 800.0),
		Vector2(GameConfig.FIELD_LEFT - 100.0, GameConfig.FIELD_TOP - 100.0),
	]
	for c in centers:
		for r in [10.0, 40.0, 120.0, 300.0, 1000.0]:
			assert_eq(_sorted(store.query_circle(c, r)), _sorted(gs.query_circle(c, r)), "%s @%s r=%.0f" % [tag, c, r])
			# 网格路径必须与暴力逐行一致（漏一即失败）
			assert_eq(_sorted(store.query_circle(c, r)), _brute(store, c, r), "%s 网格↔暴力 @%s r=%.0f" % [tag, c, r])
	# 网格确实启用（非空洞）
	store.query_circle(Vector2(448.0, 384.0), 50.0)
	assert_true(store.is_broadphase_active(), "%s 场地 cull + 96 弹应启用网格" % tag)
	# 弹少 / cull 过大 → 线性回退
	var small := _build(bt, 20, FIELD)
	var st_small = small[1]
	st_small.query_circle(Vector2(448.0, 384.0), 50.0)
	assert_false(st_small.is_broadphase_active(), "%s <64 弹应回退线性" % tag)
	var huge := _build(bt, 96, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	var st_huge = huge[1]
	st_huge.query_circle(Vector2(0.0, 0.0), 50.0)
	assert_false(st_huge.is_broadphase_active(), "%s cull 过大应回退线性" % tag)


func test_broadphase_circle() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	_check(bt, "circle")


func test_broadphase_offset() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_offset = Vector2(4.0, 0.0)
	_check(bt, "offset")


func test_broadphase_rect() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_size = Vector2(48.0, 12.0)
	bt.follow_dir = true
	_check(bt, "rect")

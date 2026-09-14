extends GutTest
## L3.5-4a：原生批量重叠 `overlap_pairs` ↔ GDScript 内核 `hit_test` 1:1。
## 目的：几何整体下沉（一次跨界返回全部命中对），供判定层避免 O(弹×目标) 次跨界。


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _build(bt: BulletType, n: int) -> Array:
	var gs: BulletSystem = autofree(BulletSystem.new())
	gs.cull_rect = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
	gs.cull_margin = 0.0
	gs.default_lifetime = 100.0
	var store = ClassDB.instantiate("DanmakuStore")
	store.setup(1024, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	store.set_margin(0.0)
	store.set_default_life(100.0)
	store.set_field(64.0, 832.0, 32.0)
	for i in n:
		var pos := Vector2(100.0 + (i % 10) * 40.0, 100.0 + (i / 10) * 40.0)
		var vel := Vector2.RIGHT.rotated(i * 0.4) * 200.0
		var fac: int = i % 3
		bt.faction = BulletType.Faction.values()[fac]   # 每行不同阵营（spawn 时拷进行）
		gs.spawn(bt, pos, vel, Color.WHITE)
		var id: int = store.spawn(pos, vel, i % 4, fac, Color.WHITE)
		store.set_hitbox(id, bt.hitbox_radius, bt.hitbox_offset, bt.hitbox_size, bt.follow_dir, bt.dir_offset)
	return [gs, store]


## 参考实现：逐弹 × 逐目标，用 GDScript 内核 `hit_test`（几何唯一真相）。
func _ref(gs: BulletSystem, faction: int, targets: PackedVector2Array, radii: PackedFloat32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	var facs := gs.get_factions()
	for i in gs.get_active_count():
		if faction >= 0 and int(facs[i]) != faction:
			continue
		for t in targets.size():
			if gs.hit_test(i, targets[t], radii[t]):
				out.append(i)
				out.append(t)
	return out


func _check(bt: BulletType, tag: String) -> void:
	var p := _build(bt, 40)
	var gs: BulletSystem = p[0]
	var store = p[1]
	var targets := PackedVector2Array([Vector2(200.0, 200.0), Vector2(400.0, 300.0), Vector2(0.0, 0.0), Vector2(448.0, 384.0)])
	var radii := PackedFloat32Array([40.0, 120.0, 300.0, 60.0])
	# 非空洞：至少要有命中，否则 parity 可能是 0==0 假过
	assert_gt(store.overlap_pairs(-1, targets, radii).size(), 0, "%s 应产生命中对" % tag)
	for faction in [-1, 0, 1, 2, 3]:
		assert_eq(store.overlap_pairs(faction, targets, radii), _ref(gs, faction, targets, radii), "%s faction=%d" % [tag, faction])
	# 单点双阈值（玩家命中 + 擦弹的一次调用形态）
	var one := PackedVector2Array([Vector2(200.0, 200.0), Vector2(200.0, 200.0)])
	var two := PackedFloat32Array([4.0, 30.0])
	assert_eq(store.overlap_pairs(0, one, two), _ref(gs, 0, one, two), "%s 双阈值" % tag)
	assert_eq(store.overlap_pairs(0, PackedVector2Array(), PackedFloat32Array()), PackedInt32Array(), "%s 空目标" % tag)


func test_overlap_pairs_circle() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	_check(bt, "circle")


func test_overlap_pairs_offset() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_offset = Vector2(3.0, 0.0)
	_check(bt, "offset")


func test_overlap_pairs_rect() -> void:
	if not _available(): pending("无扩展"); return
	var bt := BulletType.new()
	bt.hitbox_radius = 5.0
	bt.hitbox_size = Vector2(32.0, 8.0)
	bt.follow_dir = true
	_check(bt, "rect")

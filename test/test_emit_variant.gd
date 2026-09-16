extends GutTest
## 变体发射：\`chance_toward\` 的概率分支号随 emit 事件回传，宿主据此选模板
## （orbit_probe 的"自机狙转红"就是它的第一个用户）。

const DT := 1.0 / 60.0
const CULL := Rect2(-100000.0, -100000.0, 200000.0, 200000.0)


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store(seed_value: int):
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(64, CULL)
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(-100000.0, 100000.0, -100000.0)
	s.set_seed(seed_value)
	return s


func _reg(store, lc: BulletLifecycle) -> int:
	var c: Dictionary = lc.compile()
	return store.register_program(c["ops"], c["args"], c["move_start"], c["move_count"], c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])


func _variant_lc(p: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.01)
	lc.emit_variant([BulletData.new(), BulletData.new()],
		BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, p, 0.5), 100.0)
	return lc


## 跑一帧，返回第一个 emit 事件的分支号（无事件 → -1）。
func _branch(seed_value: int, p: float) -> int:
	var s = _store(seed_value)
	var pid: int = _reg(s, _variant_lc(p))
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	var res: Dictionary = s.behavior_tick(DT, Vector2(1000.0, 0.0), Vector2.ZERO, false, PackedVector2Array())
	var kinds: PackedInt32Array = res["kind"]
	var variants: PackedInt32Array = res["variant"]
	for k in kinds.size():
		if kinds[k] == 0:
			return variants[k]
	return -1


func test_event_dict_has_variant_key() -> void:
	if not _available(): pending("无扩展"); return
	var res: Dictionary = _store(1).behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_true(res.has("variant"), "事件字典应带 variant 键")


func test_chance_hit_selects_second_template() -> void:
	if not _available(): pending("无扩展"); return
	assert_eq(_branch(7, 1.0), 1, "p=1 必命中 → 第 2 个模板")


func test_chance_miss_selects_first_template() -> void:
	if not _available(): pending("无扩展"); return
	assert_eq(_branch(7, 0.0), 0, "p=0 必不中 → 第 1 个模板")


func test_plain_emit_branch_is_zero() -> void:
	if not _available(): pending("无扩展"); return
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.01)
	lc.emit(BulletData.new(), BulletLifecycle.heading(0.0), 100.0)
	var s = _store(7)
	var pid: int = _reg(s, lc)
	var id: int = s.spawn(Vector2.ZERO, Vector2(0, -100), 0, 0, Color.WHITE)
	s.set_program(id, pid)
	var res: Dictionary = s.behavior_tick(DT, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	var kinds: PackedInt32Array = res["kind"]
	var variants: PackedInt32Array = res["variant"]
	for k in kinds.size():
		if kinds[k] == 0:
			assert_eq(variants[k], 0, "普通 emit 分支号恒 0")
			return
	fail_test("未产生 emit 事件")


func test_host_pick_variant_clamps() -> void:
	var arr: Array = [&"a", &"b"]
	assert_eq(KernelNativeSystem.pick_variant(arr, 0), &"a")
	assert_eq(KernelNativeSystem.pick_variant(arr, 1), &"b")
	assert_eq(KernelNativeSystem.pick_variant(arr, 5), &"b", "越界钳到末项")
	assert_eq(KernelNativeSystem.pick_variant(&"x", 1), &"x", "非数组原样返回")
	assert_eq(KernelNativeSystem.pick_variant([], 0), null, "空数组 → null")


func test_signature_distinguishes_variant_templates() -> void:
	var a := BulletLifecycle.new()
	a.until_elapsed(0.01)
	a.emit_variant([BulletData.new(), BulletData.new()], BulletLifecycle.heading(0.0), 100.0)
	var b := BulletLifecycle.new()
	b.until_elapsed(0.01)
	b.emit_variant([BulletData.new(), BulletData.new()], BulletLifecycle.heading(0.0), 100.0)
	assert_ne(a.content_signature(), b.content_signature(), "不同模板实例 → 不同 program 签名")

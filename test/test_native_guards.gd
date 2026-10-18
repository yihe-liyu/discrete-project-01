extends GutTest
## NK1/NK3：逐弹原生入口的 id 边界 + 重复 dead 去重。

const DT := 1.0 / 60.0


func _available() -> bool:
	return ClassDB.class_exists("DanmakuStore")


func _store():
	var s = ClassDB.instantiate("DanmakuStore")
	s.setup(16, Rect2(-100000.0, -100000.0, 200000.0, 200000.0))
	s.set_margin(0.0)
	s.set_default_life(100.0)
	s.set_field(-100000.0, 100000.0, -100000.0)
	return s


func test_invalid_ids_are_guarded() -> void:
	if not _available():
		pending("未构建原生扩展")
		return
	var s = _store()
	s.spawn(Vector2(10.0, 20.0), Vector2(1.0, 2.0), 0, 0, Color.RED)
	for id in [-1, 1, 999]:
		s.set_life(id, 1.0)
		s.set_fx(id, 2.0)
		s.set_fx_type(id, 3)
		s.set_timer(id, 4.0)
		s.set_velocity(id, Vector2(5.0, 6.0))
		s.set_position(id, Vector2(7.0, 8.0))
		s.set_forward(id, Vector2.UP)
		s.set_hitbox(id, 9.0, Vector2.ZERO, Vector2.ZERO, false, 0.0)
		s.set_program(id, 0)
		s.mark_grazed(id)
		assert_eq(s.get_life_left(id), 0.0, "越界 life 返回 0")
		assert_eq(s.get_fx_phase(id), 0.0, "越界 fx 返回 0")
		assert_eq(s.get_timer(id), 0.0, "越界 timer 返回 0")
		assert_eq(s.get_fx_type(id), -1, "越界 fx_type 返回 -1")
		assert_eq(s.get_position(id), Vector2.ZERO, "越界位置返回 ZERO")
		assert_eq(s.get_velocity(id), Vector2.ZERO, "越界速度返回 ZERO")
		assert_eq(s.get_forward(id), Vector2.ZERO, "越界朝向返回 ZERO")
		assert_eq(s.get_type(id), -1, "越界 type 返回 -1")
		assert_eq(s.get_faction(id), -1, "越界 faction 返回 -1")
		assert_eq(s.get_color(id), Color(1, 1, 1, 1), "越界颜色返回白")
		assert_eq(s.get_program(id), -2, "越界 program 返回 -2")
		assert_false(s.hit_test(id, Vector2.ZERO, 1.0), "越界 hit_test 返回 false")
		assert_false(s.is_grazed(id), "越界 grazed 返回 false")
		assert_eq(s.despawn(id), -1, "越界 despawn 返回 -1")


func test_duplicate_dead_does_not_remove_innocent_bullet() -> void:
	if not _available():
		pending("未构建原生扩展")
		return
	var lc := BulletLifecycle.new()
	lc.until_elapsed(0.01)
	lc.despawn()
	lc.despawn()
	var c: Dictionary = lc.compile()
	var s = _store()
	var pid: int = s.register_program(c["ops"], c["args"], c["move_start"], c["move_count"],
		c["until_idx"], c["act_start"], c["act_count"], c["phase_count"], c["slots"])
	s.spawn(Vector2(0.0, 0.0), Vector2.ZERO, 0, 0, Color.WHITE)
	s.spawn(Vector2(1.0, 0.0), Vector2.ZERO, 0, 0, Color.WHITE)
	s.spawn(Vector2(2.0, 0.0), Vector2.ZERO, 0, 0, Color.WHITE)
	s.set_program(1, pid)   # 只让中间那颗死，且 despawn 两次
	s.behavior_tick(DT * 2.0, Vector2.ZERO, Vector2.ZERO, false, PackedVector2Array())
	assert_eq(s.get_active_count(), 2, "重复 dead id 必须去重，不能二次 swap-remove 误删无辜弹")


func _register(store, c: Dictionary, phase_count: int = -1, args_override = null, ops_override = null) -> int:
	var ops = ops_override if ops_override != null else c["ops"]
	var args = args_override if args_override != null else c["args"]
	var pc: int = int(c["phase_count"]) if phase_count < 0 else phase_count
	return store.register_program(ops, args, c["move_start"], c["move_count"],
		c["until_idx"], c["act_start"], c["act_count"], pc, c["slots"])


## NK4：原生 register_program 对并行数组 / opcode / slot 操作数 fail-closed。
func test_register_program_rejects_malformed_inputs() -> void:
	if not _available():
		pending("未构建原生扩展")
		return
	var lc := BulletLifecycle.new()
	lc.rotate(1.0, 0.0).until_elapsed(1.0)
	var c: Dictionary = lc.compile()
	var s = _store()
	assert_gte(_register(s, c), 0, "合法 program 应注册")

	assert_eq(_register(s, c, 2), -1, "phase_count 与并行数组长度不一致 → 拒绝")

	var short_args: PackedFloat32Array = c["args"].duplicate()
	short_args.resize(short_args.size() - 1)
	assert_eq(_register(s, c, -1, short_args), -1, "args 长度不匹配 → 拒绝")

	var bad_ops: PackedInt32Array = c["ops"].duplicate()
	bad_ops[0] = 999
	assert_eq(_register(s, c, -1, null, bad_ops), -1, "未知 opcode → 拒绝")

	var bad_slot_args: PackedFloat32Array = c["args"].duplicate()
	bad_slot_args[2] = 99.0   # first rotate slot operand
	assert_eq(_register(s, c, -1, bad_slot_args), -1, "slot 操作数越界 → 拒绝")

	assert_gte(_register(s, c), 0, "拒绝坏输入后仍能注册合法 program")

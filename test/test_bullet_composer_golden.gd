extends GutTest
const FIX := preload("res://test/fixtures/lifecycle_fixtures.gd")
## F10a golden：用真实内容脚本的 lifecycle 对照 BulletComposer。
##
## 取 4 张最复杂的卡（含难度分支 / 表达式 / emit 循环 / emit_variant）：
##   卡摩瑞一符、卡摩瑞二符、卡摩瑞道中一非、哆来咪三符
## 每张卡在 Easy / Lunatic 各建一次，逐字段比较 `compile()` 的 ops/args——
## 证明拼装器不是“看起来能拼”，而是**和现有内容编译结果逐位一致**。
##
## 简单内容（enemy world_accel / radial、自机 homing、stage02 多相位）另在
## test_bullet_composer_model.gd 覆盖；本文件只打硬仗。

const COMPOSER = preload("res://scripts/workbench/bullet_composer.gd")
const CATALOG = preload("res://scripts/workbench/descriptor_catalog.gd")
const ONE_FU = preload("res://data/stages/stage01/phase/卡摩瑞一符/卡摩瑞一符.gd")
const TWO_FU = preload("res://data/stages/stage01/phase/卡摩瑞二符/卡摩瑞二符.gd")
const MID_NON = preload("res://data/stages/stage01/phase/卡摩瑞道中一非/卡摩瑞道中一非.gd")
const DOREMY = preload("res://data/stages/stage03B/phase/哆来咪三符/哆来咪三符.gd")

var _saved_diff: int


func before_each() -> void:
	_saved_diff = SaveData.selected_difficulty
	RNG.set_seed(20261017)


func after_each() -> void:
	SaveData.selected_difficulty = _saved_diff


# ═══════════════════════════════════════════════ 一符 ═══

func test_one_fu_golden() -> void:
	for diff in [0, 3]:
		SaveData.selected_difficulty = diff
		var s = _open(ONE_FU)
		var 反射弹 = s.get("反射弹")
		var 开花弹 = s.get("开花弹")
		var 个数: int = int(s.get("个数"))
		var 开花弹速度: float = [50.0, 35.0, 20.0, 5.0][diff]

		var reflect_phase := _phase([], {}, [])
		if diff >= 2:
			reflect_phase["moves"].append({"op": "accel_world", "v": Vector2(0, [0, 0, 25, 35][diff])})
		_assert_same("一符/反射弹 d%d" % diff, _lc(s, "反射弹"), _compose({"phases": [reflect_phase]}))

		var bloom_phase := _phase(
			[{"op": "accel_heading", "a": 200.0}],
			{"op": "at_wall", "mask": BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP},
			[
				{"op": "sfx", "key": &"kira"},
				{"op": "emit", "spawn": 反射弹, "dir": BulletLifecycle.toward(BulletLifecycle.T_BOSS),
				 "speed": 150.0, "at": BulletLifecycle.AT_PHASE_END},
				{"op": "despawn"},
			])
		_assert_same("一符/开花弹 d%d" % diff, _lc(s, "开花弹"), _compose({"phases": [bloom_phase]}))

		var seed_actions: Array = [{"op": "sfx", "key": &"shoot"}]
		for i in 个数:
			seed_actions.append({"op": "emit", "spawn": 开花弹,
				"dir": BulletLifecycle.forward(TAU * i / 个数), "speed": 开花弹速度})
		seed_actions.append({"op": "despawn"})
		var seed_phase := _phase(
			[{"op": "speed_lerp", "from": 260.0, "to": 0.0, "ramp": 2.0 * 160.0 / 260.0}],
			{"op": "elapsed", "t": 2.0 * 160.0 / 260.0},
			seed_actions)
		_assert_same("一符/种子弹 d%d" % diff, _lc(s, "种子弹"), _compose({"phases": [seed_phase]}))


# ═══════════════════════════════════════════════ 二符 ═══

func test_two_fu_golden() -> void:
	for diff in [0, 3]:
		SaveData.selected_difficulty = diff
		var s = _open(TWO_FU)
		var 反射弹 = s.get("反射弹")

		var reflect_phase := _phase([{"op": "accel_heading", "a": 100.0}], {}, [])
		_assert_same("二符/反射弹 d%d" % diff, _lc(s, "反射弹"), _compose({"phases": [reflect_phase]}))

		var bloom_phase := _phase(
			[],
			{"op": "at_wall", "mask": BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP},
			[
				{"op": "sfx", "key": &"kira"},
				{"op": "emit", "spawn": 反射弹, "dir": BulletLifecycle.reflect(),
				 "speed": 0.01, "at": BulletLifecycle.AT_PHASE_END},
				{"op": "despawn"},
			])
		_assert_same("二符/开花弹 d%d" % diff, _lc(s, "开花弹"), _compose({"phases": [bloom_phase]}))

		if diff >= 2:
			var 反射弹2 = s.get("反射弹2")
			_assert_same("二符/反射弹2 d%d" % diff, _lc(s, "反射弹2"), _compose({"phases": [reflect_phase]}))
			var bloom2_phase := _phase(
				[],
				{"op": "at_wall", "mask": BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP},
				[
					{"op": "sfx", "key": &"kira"},
					{"op": "emit", "spawn": 反射弹2, "dir": BulletLifecycle.reflect(),
					 "speed": 0.01, "at": BulletLifecycle.AT_PHASE_END},
					{"op": "despawn"},
				])
			_assert_same("二符/开花弹2 d%d" % diff, _lc(s, "开花弹2"), _compose({"phases": [bloom2_phase]}))


# ═══════════════════════════════════════════════ 道中一非 ═══

func test_midboss_non_golden() -> void:
	for diff in [0, 3]:
		SaveData.selected_difficulty = diff
		var s = _open(MID_NON)
		var 开花弹 = s.get("开花弹")
		var 串型弹 = s.get("串型弹")
		var n: int = int(s.get("开花弹个数"))
		var boss_r: float = [175.0, 150.0, 125.0, 100.0][diff]

		var emits: Array = []
		for i in n:
			emits.append({"op": "emit", "spawn": 开花弹,
				"dir": BulletLifecycle.forward(TAU * i / n), "speed": 400.0})
		if diff == 2:
			for i in 4:
				emits.append({"op": "emit", "spawn": 串型弹,
					"dir": BulletLifecycle.away(BulletLifecycle.T_BOSS), "speed": 400.0 + i * 50})
		elif diff == 3:
			for i in 8:
				emits.append({"op": "emit", "spawn": 串型弹,
					"dir": BulletLifecycle.away(BulletLifecycle.T_BOSS, 1.0 / TAU / 6.0),
					"speed": 400.0 + i * 50})
			for i in 8:
				emits.append({"op": "emit", "spawn": 串型弹,
					"dir": BulletLifecycle.away(BulletLifecycle.T_BOSS, -1.0 / TAU / 6.0),
					"speed": 400.0 + i * 50})

		var phase0 := _phase(
			[],
			{"op": "near", "target": BulletLifecycle.T_PLAYER, "r": 150.0, "every_ticks": 3},
			[{"op": "on_end_heading", "dir": BulletLifecycle.away(BulletLifecycle.T_PLAYER)}])
		var phase1_actions: Array = [
			{"op": "sfx", "key": &"kira"},
			{"op": "on_end_heading", "dir": BulletLifecycle.random_dir(PI)},
		]
		phase1_actions.append_array(emits)
		phase1_actions.append({"op": "despawn"})
		var phase1 := _phase(
			[],
			{"op": "near", "target": BulletLifecycle.T_BOSS, "r": boss_r, "every_ticks": 3},
			phase1_actions)
		_assert_same("道中一非/声呐弹 d%d" % diff, _lc(s, "声呐弹"),
			_compose({"phases": [phase0, phase1]}))


# ═══════════════════════════════════════════════ 哆来咪三符 ═══

func test_doremy_golden() -> void:
	for diff in [0, 3]:
		SaveData.selected_difficulty = diff
		var s = _open(DOREMY)
		var p: float = 0.075 if diff >= 2 else 0.0
		var n: int = int(s.get("个数"))

		var angle_phase := _phase([{"op": "accel_heading", "a": 40.0}], {}, [])
		var angle_snipe_phase := _phase([{"op": "accel_heading", "a": 40.0}], {}, [])
		if diff >= 2:
			angle_phase["until"] = {"op": "elapsed", "t": 3.0}
			angle_phase["on_end"] = [{"op": "despawn_clear"}]
			angle_snipe_phase["until"] = {"op": "elapsed", "t": 6.0}
			angle_snipe_phase["on_end"] = [{"op": "despawn_clear"}]
		_assert_same("哆来咪/夹角弹 d%d" % diff, _lc(s, "夹角弹"), _compose({"phases": [angle_phase]}))
		_assert_same("哆来咪/夹角狙 d%d" % diff, _lc(s, "夹角狙"), _compose({"phases": [angle_snipe_phase]}))

		var round_phase := _phase(
			[{"op": "accel_heading", "a": -150.0}],
			{"op": "elapsed", "t": 2.0 * 175.0 / 150.0},
			[
				{"op": "sfx", "key": &"kira"},
				{"op": "emit_variant",
				 "spawns": [s.get("夹角弹"), s.get("夹角狙")],
				 "dir": BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, p, TAU / float(n) / 2.0),
				 "speed": 60.0},
				{"op": "despawn"},
			])
		_assert_same("哆来咪/往返弹 d%d" % diff, _lc(s, "往返弹"), _compose({"phases": [round_phase]}))


# ═══════════════════════════════════════════════ 简单内容 / 预设 ═══

func test_world_and_radial_composition_golden() -> void:
	var world := FIX.world_accel(Vector2(0.0, 300.0))
	_assert_same("world_accel", world, _compose({"phases": [
		_phase([{"op": "accel_world", "v": Vector2(0.0, 300.0)}], {}, []),
	]}))

	var spawn = BulletData.new().enemy().tex("米弹")
	var radial := FIX.radial_accel(150.0, spawn, &"kira", -18.0)
	var radial_phase := _phase(
		[{"op": "accel_heading", "a": 150.0}],
		{"op": "at_wall", "mask": BulletLifecycle.WALL_TOP},
		[
			{"op": "sfx", "key": &"kira", "db": -18.0},
			{"op": "emit", "spawn": spawn, "dir": BulletLifecycle.heading(PI),
			 "speed": 0.0, "at": BulletLifecycle.AT_PHASE_END},
			{"op": "despawn"},
		])
	_assert_same("radial_accel", radial, _compose({"phases": [radial_phase]}))


func test_homing_and_laser_composition_golden() -> void:
	var homing := FIX.homing()
	var homing_phase := _phase(
		[
			{"op": "steer", "target": BulletLifecycle.T_NEAREST_ENEMY,
			 "max_turn": deg_to_rad(720.0), "ramp": 2.0, "dist_weight": 150.0, "steer_until": 2.0},
			{"op": "speed_lerp", "from": 500.0, "to": 2000.0, "ramp": 2.0},
		], {}, [])
	_assert_same("homing", homing, _compose({"phases": [homing_phase]}))

	var laser := FIX.marisa_laser(0, Vector2.ZERO, 0.3, 800.0, 0.0)
	var laser_phase := _phase(
		[{"op": "anchor_drift", "anchor_id": 0, "offset": Vector2.ZERO,
		  "angle": 0.3, "speed": 800.0, "use_global": true,
		  "initial": 0.0, "render_heading": true}], {}, [])
	_assert_same("marisa_laser", laser, _compose({"phases": [laser_phase]}))


func test_stage02_two_phase_golden() -> void:
	var lc := BulletLifecycle.new()
	lc.rotate(6.0)
	lc.until_elapsed(2.0)
	lc.then()
	lc.rotate(-3.0)
	lc.accel_heading(-500.0)
	lc.until_elapsed(0.5)
	lc.despawn_clear()
	var spec := {"phases": [
		_phase([{"op": "rotate", "w": 6.0}], {"op": "elapsed", "t": 2.0}, []),
		_phase([{"op": "rotate", "w": -3.0}, {"op": "accel_heading", "a": -500.0}],
			{"op": "elapsed", "t": 0.5}, [{"op": "despawn_clear"}]),
	]}
	_assert_same("stage02/enemy02", lc, _compose(spec))


# ═══════════════════════════════════════════════ 模型校验 ═══

func test_composer_validate_until_turned_without_rotate() -> void:
	var c = COMPOSER.new()
	c.set_until(0, &"turned", {})
	var errors: Array = c.validate()
	assert_gt(errors.size(), 0, "until_turned 前没有 rotate 必须报错")


func test_composer_validate_emit_variant_requires_chance() -> void:
	var c = COMPOSER.new()
	c.add_action(0, &"emit_variant", {
		"spawns": [], "dir": BulletLifecycle.toward(BulletLifecycle.T_PLAYER), "speed": 0.0,
	})
	var errors: Array = c.validate()
	assert_gt(errors.size(), 0, "emit_variant 的 dir 不是 chance_toward 必须报错")


func test_composer_codegen_contains_ops() -> void:
	var spawn = BulletData.new().enemy().tex("米弹")
	var c = COMPOSER.new()
	c.from_spec({"phases": [
		_phase(
			[{"op": "accel_heading", "a": -150.0},
			 {"op": "speed_lerp", "from": 100.0, "to": 300.0, "ramp": 1.0}],
			{"op": "elapsed", "t": 2.0, "every_ticks": 3},
			[
				{"op": "sfx", "key": &"kira", "db": -12.0},
				{"op": "emit", "spawn": spawn, "dir": BulletLifecycle.toward(BulletLifecycle.T_BOSS),
				 "speed": 150.0, "at": BulletLifecycle.AT_PHASE_END},
				{"op": "despawn"},
			]),
	]})
	var code := c.to_code()
	assert_true(code.contains("var lc := BulletLifecycle.new()"), "代码应有 lifecycle 声明")
	assert_true(code.contains("lc.accel_heading(-150.0)"), "代码应含 accel_heading")
	assert_true(code.contains("lc.until_elapsed(2.0)"), "代码应含 until_elapsed")
	assert_true(code.contains(".every_ticks(3)"), "代码应含 every_ticks")
	assert_true(code.contains("lc.emit(_spawn, BulletLifecycle.toward(BulletLifecycle.T_BOSS"),
		"代码应含 emit + 占位 spawn")
	assert_true(code.contains("lc.despawn()"), "代码应含 despawn")
	assert_true(code.contains("data.trajectory(lc)"), "代码应以 trajectory 收尾")


func test_catalog_covers_content_ops() -> void:
	for id in [&"accel_world", &"accel_heading", &"rotate", &"steer", &"speed_lerp",
			&"anchor_drift", &"set_heading", &"set_speed", &"speed_mul", &"drift"]:
		assert_true(CATALOG.has_op(&"move", id), "缺 Move %s" % id)
	for id in [&"never", &"elapsed", &"near", &"at_wall", &"speed", &"turned"]:
		assert_true(CATALOG.has_op(&"until", id), "缺 Until %s" % id)
	for id in [&"emit", &"emit_variant", &"sfx", &"despawn", &"clear_fx",
			&"despawn_clear", &"on_end_heading", &"on_end_call"]:
		assert_true(CATALOG.has_op(&"action", id), "缺 Action %s" % id)
	for id in [&"heading", &"toward", &"away", &"forward", &"random", &"chance", &"reflect"]:
		assert_true(CATALOG.has_op(&"dir", id), "缺 Dir %s" % id)


# ═══════════════════════════════════════════════ 工具 ═══

func _open(script: Script) -> Object:
	# 成员初始化（diff_pick / 难度缓存）在 new() 时发生 → 先设难度再 new。
	var s = script.new()
	autofree(s)
	s.call("_on_start")
	return s


func _lc(s: Object, member: String) -> BulletLifecycle:
	var data = s.get(member)
	assert_not_null(data, "内容缺成员 %s" % member)
	if data == null:
		return null
	return data.lifecycle


func _compose(spec: Dictionary) -> BulletLifecycle:
	var c = COMPOSER.new()
	c.from_spec(spec)
	return c.to_lifecycle()


func _phase(moves: Array, until: Dictionary, on_end: Array) -> Dictionary:
	var u := until
	if u.is_empty():
		u = {"op": "never"}
	return {"moves": moves, "until": u, "on_end": on_end}


func _assert_same(tag: String, original: BulletLifecycle, composed: BulletLifecycle) -> void:
	assert_not_null(original, tag + " original")
	assert_not_null(composed, tag + " composed")
	if original == null or composed == null:
		return
	var a: Dictionary = original.compile()
	var b: Dictionary = composed.compile()
	assert_eq(b["ops"], a["ops"], tag + " ops")
	assert_eq(b["args"], a["args"], tag + " args")
	assert_eq(b["move_start"], a["move_start"], tag + " move_start")
	assert_eq(b["move_count"], a["move_count"], tag + " move_count")
	assert_eq(b["until_idx"], a["until_idx"], tag + " until_idx")
	assert_eq(b["act_start"], a["act_start"], tag + " act_start")
	assert_eq(b["act_count"], a["act_count"], tag + " act_count")
	assert_eq(b["phase_count"], a["phase_count"], tag + " phase_count")
	assert_eq(b["slots"], a["slots"], tag + " slots")
	assert_eq(b["sfx"], a["sfx"], tag + " sfx")
	assert_eq((b["actions"] as Array).size(), (a["actions"] as Array).size(), tag + " actions size")
	var aa: Array = a["actions"]
	var ba: Array = b["actions"]
	for i in mini(aa.size(), ba.size()):
		_assert_action_same(tag + " action %d" % i, aa[i], ba[i])


func _assert_action_same(tag: String, a_ref: Variant, b_ref: Variant) -> void:
	assert_eq(typeof(b_ref), typeof(a_ref), tag + " type")
	if a_ref is BulletData and b_ref is BulletData:
		assert_eq(b_ref.get_instance_id(), a_ref.get_instance_id(), tag + " bullet identity")
	elif a_ref is Array and b_ref is Array:
		assert_eq(b_ref.size(), a_ref.size(), tag + " array size")
		for j in mini(a_ref.size(), b_ref.size()):
			_assert_action_same(tag + "[%d]" % j, a_ref[j], b_ref[j])
	elif a_ref is Callable and b_ref is Callable:
		assert_eq(str(b_ref), str(a_ref), tag + " callable")

extends GutTest
## Laser 2.0 骨架 + 状态机 + 判定测试（第 1 步：测试地基）

var _holder: Node
var _refs: EntityRegistry

## 激光池 beams 挂在 holder 上，随测试结束 autofree 释放
## （LaserEngine.setup 每测试建 64 条 beam，直接挂测试脚本会累计成 unfreed children）
func before_each():
	_holder = Node.new()
	add_child_autofree(_holder)
	_refs = EntityRegistry.new()

# ── 骨架 ──

func test_skeleton_line_sampling():
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 100))
	assert_eq(sk.total_length, 100.0, "直线骨架总长 = 100")
	assert_eq(sk.sample_at(0), Vector2(0, 0), "起点")
	assert_eq(sk.sample_at(100), Vector2(0, 100), "终点")
	assert_eq(sk.sample_at(50), Vector2(0, 50), "中点")
	assert_eq(sk.tangent_at(50), Vector2(0, 1), "竖直切线向下")

func test_skeleton_curve_uniform_sampling():
	# S 形曲线：均匀采样后任意两相邻点距离 ≈ 段长
	var curve := Curve2D.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(200, 200), Vector2(-50, 0), Vector2(50, 0))
	curve.add_point(Vector2(400, 0))
	var sk := LaserSkeleton.new()
	sk.from_curve(curve, 32.0)
	assert_gt(sk.total_length, 400.0, "S 形曲线长度应大于直线距离")
	assert_gt(sk.points.size(), 10, "32px 段长应有多段")
	# 相邻采样点间距 ≈ 均匀
	var pts := sk.points
	for i in range(1, pts.size()):
		var d := pts[i].distance_to(pts[i - 1])
		assert_between(d, 20.0, 45.0, "相邻点间距应接近均匀（段长 32 附近）")

func test_skeleton_sample_range_single_safe():
	# count=1 不除零
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 100))
	var pts := sk.sample_range(0, 50, 1)
	assert_eq(pts.size(), 1, "count=1 只返回 1 点")
	assert_eq(pts[0], Vector2(0, 0), "返回起始点")

# ── 状态机 ──

func _make_beam() -> LaserBeam:
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 600))
	beam.grow_speed = 300.0
	beam.tail_distance = 100.0
	beam.max_lifetime = 5.0
	beam.spawn(sk, Color.RED)
	return beam

func test_grow_moves_head():
	var beam := _make_beam()
	beam._physics_process(0.1)
	assert_eq(beam.head_dist, 30.0, "0.1s × 300 = 30px")
	beam._physics_process(0.1)
	assert_eq(beam.head_dist, 60.0, "再 0.1s = 60px")
	beam._physics_process(0.1)
	assert_eq(beam.tail_dist, 0.0, "head=90 < tail_distance=100 → 尾部仍在起点")
	beam._physics_process(0.1)
	assert_eq(beam.tail_dist, 20.0, "head=120 → 尾部滞后 100 = 20")

func test_grow_reaches_sustain():
	var beam := _make_beam()
	for i in 25:  # 2.5s > 600/300
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "到顶转 SUSTAIN")
	assert_eq(beam.head_dist, 600.0, "头部到顶")

func test_sustain_then_contract_to_dead():
	var beam := _make_beam()
	for i in 25:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "到顶后 SUSTAIN")
	# 推到超时：应经过 CONTRACT 再 DEAD（尾部追上）
	var saw_contract := false
	for i in 40:
		beam._physics_process(0.1)
		if beam.phase == LaserBeam.Phase.CONTRACT:
			saw_contract = true
	assert_true(saw_contract, "超时后应经过 CONTRACT 阶段")
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "最终 DEAD（尾部追上消失）")

func test_fixed_beam_fades_on_timeout():
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 300))
	beam.grow_on_spawn = false  # 瞬间全开
	beam.max_lifetime = 0.5
	beam.spawn(sk, Color.BLUE)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "非生长型直接 SUSTAIN")
	assert_eq(beam.head_dist, 300.0, "非生长型 head = 全长（瞬间全开）")
	assert_eq(beam.tail_dist, 0.0, "尾部从 0 开始")
	# 0.6s 后应 FADE
	for i in 6:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.FADE, "超时转 FADE")
	for i in 3:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "淡完 → DEAD")

func test_dirty_flag_only_on_change():
	var beam := _make_beam()
	# 生长中：dirty
	beam._physics_process(0.1)
	assert_true(beam._dirty, "生长中应 dirty")
	# 到顶 SUSTAIN 后静止：不 dirty
	for i in 25:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "已 SUSTAIN")
	beam._physics_process(0.1)
	assert_false(beam._dirty, "SUSTAIN 静止时不应重建（dirty=false）")

# ── 判定 ──

## 全长可见的光束（FIXED 型）—— 判定测试用
func _make_full_beam() -> LaserBeam:
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 600))
	beam.grow_on_spawn = false
	beam.max_lifetime = 5.0
	beam.spawn(sk, Color.RED)
	return beam

func test_distance_and_hit():
	var beam := _make_full_beam()
	# 玩家在激光旁 3px → 命中；旁 10px → 不命中
	assert_true(beam.is_hitting(Vector2(3, 300)), "旁 3px 命中（hitbox 6）")
	assert_false(beam.is_hitting(Vector2(10, 300)), "旁 10px 不命中")
	# 线段外 → 不命中
	assert_false(beam.is_hitting(Vector2(0, 650)), "超出尾部不命中")

func test_graze():
	var beam := _make_full_beam()
	# 旁 20px：不命中但擦弹
	assert_false(beam.is_hitting(Vector2(20, 300)), "旁 20px 不命中")
	assert_true(beam.is_grazing(Vector2(20, 300), 10.0), "旁 20px 擦弹（graze 22 + 10）")
	assert_false(beam.is_grazing(Vector2(40, 300), 10.0), "旁 40px 不擦弹")

# ── 引擎池 ──

func test_engine_pool_reuse():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(_holder)
	for i in 10:
		var beam := engine.spawn_line(Vector2(0, 0), Vector2(0, 100), Color.RED)
		assert_not_null(beam, "第 %d 条应生成" % i)
	assert_eq(engine.get_active().size(), 10, "10 条活动")
	engine.clear()
	assert_eq(engine.get_active().size(), 0, "清空")
	# 复用：再生成（池中复用无泄漏）
	for i in 10:
		var beam := engine.spawn_line(Vector2(0, 0), Vector2(0, 100), Color.RED)
		assert_not_null(beam, "复用第 %d 条" % i)

func test_engine_spawn_curve():
	var engine := LaserEngine.new()
	autofree(engine)
	engine.setup(_holder)
	var curve := Curve2D.new()
	curve.add_point(Vector2(100, 100))
	curve.add_point(Vector2(300, 300))
	var beam := engine.spawn_curve(curve, Color.GREEN)
	assert_not_null(beam, "曲线激光应生成")
	assert_gt(beam.skeleton.total_length, 0.0, "曲线骨架应有长度")

# ── 第 2 步：cut_head + 引擎判定 ──

func test_cut_head_freezes_then_dies():
	var beam := _make_beam()
	beam._physics_process(0.5)  # head = 150
	assert_eq(beam.head_dist, 150.0, "生长中 head=150")
	beam.cut_head()
	beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.CONTRACT, "切头后转 CONTRACT（不再前进）")
	assert_eq(beam.head_dist, 180.0, "切头前已生成的部分保留")
	# 尾部追上消失
	for i in 20:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "尾部追上 → DEAD")

func test_cut_head_ignored_on_fixed():
	var beam := _make_full_beam()
	beam.cut_head()
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "固定型切头无效（保持 SUSTAIN）")

func _make_engine() -> LaserEngine:
	var engine := LaserEngine.new()
	autofree(engine)
	# W4a-2：LaserEngine 不再依赖 BulletPhysics；擦弹结算走注入 Callable（内核规则）
	engine.setup(_holder, Callable(BulletManager, "_on_laser_graze"))
	engine.refs = _refs
	return engine

func _make_engine_player(x: float) -> Player:
	var player = preload("res://scenes/player.tscn").instantiate()
	autofree(player)
	player.player_data = load("res://data/player_data/marisa_data.tres")
	add_child(player)
	player._reinit_shoot()
	player.global_position = Vector2(x, 300)
	player.is_invincible = false
	_refs.bind_player(player)
	BulletManager.inject_world_refs(_refs)  # 擦弹结算走 autoload 内核物理：显式注入本用例注册表
	return player

func test_engine_step_detects_hit_and_graze():
	var engine := _make_engine()
	var player := _make_engine_player(3.0)  # 命中线内（hitbox 6）
	# 竖直线激光在 x=0（瞬间全开）
	engine.spawn_line(Vector2(0, 0), Vector2(0, 600), Color.RED, {"grow": false})
	engine.step(0.016)
	assert_true(player.is_invincible, "激光命中 → 玩家 miss（进入无敌帧）")

func test_engine_graze():
	var engine := _make_engine()
	var player := _make_engine_player(30.0)  # 擦弹范围（22+graze 40）
	var beam: LaserBeam = engine.spawn_line(Vector2(0, 0), Vector2(0, 600), Color.RED, {"grow": false})
	assert_eq(beam.phase, LaserBeam.Phase.SUSTAIN, "opts 生效：瞬间全开")
	var g0 := GameState.graze_count
	engine.step(0.016)
	assert_gt(GameState.graze_count, g0, "擦弹应计数")

# ── 第 3 步：MultiMesh 渲染 ──

func test_rendering_segments_and_rotation():
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 320))  # 320px → 10 段
	beam.grow_on_spawn = false
	beam.spawn(sk, Color.RED)
	assert_eq(beam._core_line.points.size(), 10, "320px/32 = 10 渲染点")
	# 段旋转 = 骨架切线角（垂直激光切线角 = PI/2）
	var dir := sk.tangent_at(16.0)
	assert_almost_eq(atan2(dir.y, dir.x), PI / 2.0, 0.02, "垂直激光切线角 = 90°")
	# head 距离驱动渲染范围
	assert_eq(beam.head_dist, 320.0, "head 到全长")

func test_rendering_zero_when_dead():
	var beam := LaserBeam.new()
	autofree(beam)
	add_child(beam)
	var sk := LaserSkeleton.new()
	sk.from_line(Vector2(0, 0), Vector2(0, 320))
	beam.grow_on_spawn = false
	beam.max_lifetime = 0.2
	beam.spawn(sk, Color.RED)
	for i in 5:
		beam._physics_process(0.1)
	assert_eq(beam.phase, LaserBeam.Phase.DEAD, "激光已死")
	assert_eq(beam._core_line.points.size(), 0, "死亡后点集清空（不泄漏）")

# ── 第 4 步：形态预设 ──

func test_preset_straight():
	var sk := LaserPresets.straight(Vector2(0, 0), Vector2(0, 300))
	assert_eq(sk.total_length, 300.0, "直线预设长度正确")

func test_preset_wave():
	var sk := LaserPresets.wave(Vector2(0, 0), Vector2(1, 0), 400.0, 50.0, 100.0)
	assert_gt(sk.total_length, 400.0, "波动使长度大于直线距离")
	assert_gt(sk.points.size(), 10, "波应有足够采样点")
	# 起点在 origin，终点在 x=400
	assert_almost_eq(sk.points[0].x, 0.0, 0.5, "波起点 x=0")
	assert_almost_eq(sk.points[sk.points.size()-1].x, 400.0, 0.5, "波终点 x=400")

func test_preset_spiral():
	var sk := LaserPresets.spiral(Vector2(200, 200), 150.0, 2.0)
	assert_gt(sk.points.size(), 20, "螺旋应有足够点")
	var first: Vector2 = sk.points[0]
	var last: Vector2 = sk.points[sk.points.size()-1]
	assert_almost_eq(first.distance_to(Vector2(200, 200)), 0.0, 0.5, "螺旋从中心出发")
	assert_almost_eq(last.distance_to(Vector2(200, 200)), 150.0, 2.0, "螺旋终点 = 外径")

func test_preset_sweep():
	var sk := LaserPresets.sweep(Vector2(100, 100), Vector2(0, -1), PI / 2.0, 300.0)
	assert_almost_eq(sk.points[0].distance_to(Vector2(100, -200)), 0.0, 0.5, "扫起点 = 向上 300px")
	var end_dir := Vector2(0, -1).rotated(PI / 2.0)  # 右
	assert_almost_eq(sk.points[sk.points.size()-1].distance_to(Vector2(100, 100) + end_dir * 300.0), 0.0, 1.0, "扫终点 = 右向 300px")

func test_preset_bezier():
	var sk := LaserPresets.bezier(Vector2(0, 0), Vector2(100, -100), Vector2(300, 100), Vector2(400, 0))
	assert_gt(sk.total_length, 400.0, "弯曲贝塞尔比直线长")
	assert_almost_eq(sk.points[0].distance_to(Vector2(0, 0)), 0.0, 0.5, "起点")
	assert_almost_eq(sk.points[sk.points.size()-1].distance_to(Vector2(400, 0)), 0.0, 0.5, "终点")

extends GutTest
## KernelMistBomb：分阶段展开（长→保持→宽→保持→淡出）+ 跟随自机 + 椭圆持续伤害/清弹。
## 用测试自带短时长 MistBombData（不依赖 .tres 的可调时长）。

const MARISA_DATA = preload("res://data/player_data/marisa_data.tres")


class FakeEnemy extends Node2D:
	var hitbox_radius: float = 8.0
	var taken: float = 0.0
	func take_damage(amount: float) -> void:
		taken += amount


func before_each() -> void:
	var bullet_manager := BulletManager.new()
	bullet_manager.name = "BulletManager"
	add_child_autofree(bullet_manager)


func after_each() -> void:
	BulletManager.current.clear_all()
	BulletManager.current.inject_entity_registry(null)


func _short_mist() -> MistBombData:
	var bd := MistBombData.new()
	bd.count = 1
	bd.grow_length_time = 0.1
	bd.hold_length_time = 0.1
	bd.grow_width_time = 0.1
	bd.hold_width_time = 0.1
	bd.fade_time = 0.1
	bd.follow_player = true
	bd.rotation_deg = -90.0
	bd.pivot_ratio = Vector2(0.0, 0.5)
	return bd


func test_marisa_bomb_data_is_mist() -> void:
	var bd: BombData = MARISA_DATA.bomb
	assert_not_null(bd, "marisa 应配 bomb")
	assert_true(bd is MistBombData, "应是 MistBombData（后端据此分派 KernelMistBomb）")
	assert_eq(bd.count, 1, "单颗")
	assert_not_null(bd.texture, "应有贴图（marisa_bomb01）")


func test_mist_start_size_comes_from_ranges() -> void:
	var bd := _short_mist()
	bd.texture = MARISA_DATA.bomb.texture
	bd.length_range = Vector2(0.5, 1.0)
	bd.width_range = Vector2(0.25, 1.0)
	var full := bd.texture.get_size()
	var bomb = BulletManager.current.shoot_bomb_bullet(bd, Vector2(448.0, 700.0), Vector2.RIGHT)
	bomb._physics_process(1.0 / 60.0)   # 仍在阶段1（长）
	assert_gt(bomb.length_now(), full.x * 0.5, "阶段1 的长应从 length_range.x 起，不是 0")
	assert_almost_eq(bomb.width_now(), full.y * 0.25, 0.01, "阶段1 的宽 = 贴图宽 × width_range.x（初始宽度）")
	bomb.queue_free()


func test_mist_clear_shape_is_exact_ellipse() -> void:
	# 满尺寸椭圆（贴图 256×128 → 半轴 128/64）。椭圆中心在本地 c（pivot 造成的偏移），
	# 两颗敌弹都落在**外接圆(半径 128)内**：
	#   ① 椭圆内
	#   ② 椭圆四角之外（到 c 距离 ≈114 < 128，但 x²/a²+y²/b² ≈1.35 > 1）
	# 旧的外接圆清弹会把 ①② 全清；精确椭圆只清 ①。
	var bd := _short_mist()
	bd.texture = MARISA_DATA.bomb.texture
	bd.length_range = Vector2(1.0, 1.0)
	bd.width_range = Vector2(1.0, 1.0)
	var tex: Vector2 = bd.texture.get_size()
	var half: Vector2 = tex * 0.5
	var c: Vector2 = tex * (Vector2(0.5, 0.5) - bd.pivot_ratio)   # 椭圆中心（bomb 本地）
	var bomb = BulletManager.current.shoot_bomb_bullet(bd, Vector2(448.0, 700.0), Vector2.RIGHT)
	bomb._physics_process(1.0 / 60.0)
	var inside_pt: Vector2 = bomb.to_global(c + Vector2(0.0, half.y * 0.78))
	var corner_pt: Vector2 = bomb.to_global(c + Vector2(half.x * 0.78, half.y * 0.86))
	for p in [inside_pt, corner_pt]:
		var ed := BulletData.new().enemy().tex("小玉")
		ed.velocity = Vector2.ZERO
		BulletManager.current.shoot_bullet(ed, p, Vector2.UP)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 2, "先有 2 颗敌弹")
	bomb._physics_process(1.0 / 60.0)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "只清椭圆内的那颗")
	var survivor: Vector2 = BulletManager.current.kernel_system().get_position(0)
	assert_almost_eq(survivor.distance_to(corner_pt), 0.0, 0.5, "留下的是椭圆四角外那颗")
	bomb.queue_free()


func test_mist_bomb_stages_grow_follow_and_expire() -> void:
	var bd := _short_mist()
	bd.texture = MARISA_DATA.bomb.texture
	var reg := EntityRegistry.new()
	BulletManager.current.inject_entity_registry(reg)

	var player := Node2D.new()
	add_child_autofree(player)
	player.global_position = Vector2(448.0, 700.0)
	reg.bind_player(player)

	var near_enemy := FakeEnemy.new()
	add_child_autofree(near_enemy)
	near_enemy.global_position = player.global_position + Vector2(0.0, -64.0)   # 长轴上
	reg.register_enemy(near_enemy)
	var far_enemy := FakeEnemy.new()
	add_child_autofree(far_enemy)
	far_enemy.global_position = player.global_position + Vector2(0.0, -500.0)   # 长轴外
	reg.register_enemy(far_enemy)

	var ed := BulletData.new().enemy().tex("小玉")
	ed.velocity = Vector2.UP * 10.0
	BulletManager.current.shoot_bullet(ed, player.global_position, Vector2.UP)

	var bomb = BulletManager.current.shoot_bomb_bullet(bd, player.global_position, Vector2.RIGHT)
	assert_true(bomb is BombEntity, "应是宿主 bomb 实体")

	# 阶段1（长）：只有"长"在涨，"宽"仍为 0
	for _f in 3:
		bomb._physics_process(1.0 / 60.0)
	# 注：Godot 把 scale 的 0 夹到 CMP_EPSILON(1e-5) → "宽=0" 实际是 0.0013px，按"远小于 1px"断
	assert_gt(bomb.length_now(), 0.0, "长应开始展开")
	assert_lt(bomb.width_now(), 0.01, "此时宽仍应≈0（未到阶段3）")

	# 跟随自机
	player.global_position = Vector2(500.0, 640.0)
	bomb._physics_process(1.0 / 60.0)
	assert_true(bomb.global_position.is_equal_approx(player.global_position), "锚点应跟随自机")

	# 走完宽展开（阶段3-4），断言伤害 / 清弹
	for _f in 20:
		if bomb.is_queued_for_deletion():
			break
		bomb._physics_process(1.0 / 60.0)
	assert_gt(bomb.width_now(), 0.0, "宽应已展开")
	assert_gt(near_enemy.taken, 0.0, "椭圆内（长轴上）敌机应持续受伤")
	assert_eq(far_enemy.taken, 0.0, "长轴外敌机不应受伤")
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 0, "范围内敌弹应被清")

	# 生命周期：淡出后回收
	for _f in 120:
		if bomb.is_queued_for_deletion():
			break
		bomb._physics_process(1.0 / 60.0)
	assert_true(bomb.is_queued_for_deletion(), "长→保持→宽→保持→淡出 后应回收")

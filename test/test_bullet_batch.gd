extends GutTest
## 批量渲染与回收（>4000 池复用）回归：Sprite 双份叠加修复 + 混合方式分组

const BULLET_SCENE := preload("res://scenes/bullet.tscn")


func test_batch_mode_sprite_hidden_as_data_source():
	BulletManager.use_multi_mesh = true
	BulletManager.clear_all()
	var bd := BulletData.new()
	bd.tex("环玉")
	bd.speed(300.0)
	bd.enemy()
	bd.spawn_fog = false  # 测试去掉雾：is_ready 立即为 true
	var bullet := BulletManager.shoot_enemy_bullet(bd, Vector2(400, 200), Vector2.DOWN) as Bullet
	assert_not_null(bullet, "射出子弹")
	if bullet:
		assert_false(bullet.get_node("Sprite2D").visible, "批量模式：Sprite 隐藏（只作数据源）")
		assert_eq(bullet.sprite.modulate, Color.WHITE, "Modulate 仍数据源（mesh 着色用）")
	# 关闭批量：Sprite 显示
	BulletManager.use_multi_mesh = false
	BulletManager.clear_all()
	var b2d := BulletData.new()
	b2d.tex("环玉")
	b2d.speed(300.0)
	b2d.enemy()
	b2d.spawn_fog = false
	var bullet2 := BulletManager.shoot_enemy_bullet(b2d, Vector2(400, 200), Vector2.DOWN) as Bullet
	if bullet2:
		assert_true(bullet2.get_node("Sprite2D").visible, "非批量模式：Sprite 显示")
	BulletManager.use_multi_mesh = true
	BulletManager.clear_all()


func test_additive_and_multiply_separate_groups():
	BulletManager.use_multi_mesh = true
	BulletManager.clear_all()
	var add := BulletData.new()
	add.tex("环玉")
	add.speed(200.0)
	add.blend(true)
	add.enemy()
	add.spawn_fog = false
	BulletManager.shoot_enemy_bullet(add, Vector2(400, 200), Vector2.RIGHT)
	var mul := BulletData.new()
	mul.tex("环玉")
	mul.speed(200.0)
	mul.blend(false)
	mul.enemy()
	mul.spawn_fog = false
	BulletManager.shoot_enemy_bullet(mul, Vector2(400, 200), Vector2.LEFT)
	await get_tree().process_frame
	await get_tree().process_frame  # process_frame 先于 _process：等两帧让 _sync 建组
	var mm = BulletManager.get_node_or_null("BulletMultiMesh")
	if not mm:
		# BulletManager 的子节点（_multi_mesh）
		mm = BulletManager.get("_multi_mesh")
	if mm and mm.get("_groups") != null:
		var groups: Dictionary = mm._groups
		var t0 := -1
		var t1 := -1
		for k in groups:
			# _groups[k] = {mm, mmi}；tint_mode 在材质参数上
			var eg: Dictionary = groups[k]
			var tm: int = int(eg.get("mmi").material.get_shader_parameter("tint_mode"))
			if tm == 0:
				t0 = k
			elif tm == 1:
				t1 = k
		assert_eq(groups.size(), 2, "两种 tint_mode 应为 2 组（实际 %d）" % groups.size())
		assert_true(t0 != -1 and t1 != -1, "t0=%s t1=%s" % [str(t0), str(t1)])
	BulletManager.clear_all()
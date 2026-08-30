extends GutTest
## BulletShell（弹幕试验台"壳"）测试（M2a）

const SHELL = preload("res://scripts/workbench/bullet_shell.gd")


func test_shell_builds_enemy_bullet_bundle():
	var s = SHELL.new()
	s.tex_key = "小玉"
	s.tint = Color(1, 0, 0)
	s.blend = true
	s.speed = 500.0
	s.dir_index = 2  # 右
	var d: BulletData = s.build()
	assert_eq(d.faction, BulletData.Faction.ENEMY, "敌弹阵营")
	assert_eq(d.texture, AssetRegistry.get_bullet_tex("小玉"), "贴图对应")
	assert_eq(d.hitbox_shape, BulletData.HitboxShape.CIRCLE, "小玉判定=圆")
	assert_eq(d.hitbox_radius, 6.0, "贴图≡判定：小玉判定 6.0（engine 现行为，enemy() 不覆盖）")
	assert_true(d.can_be_canceled, "可被 Bomb 消除")
	assert_eq(d.tint_mode, BulletData.TintMode.BLEND, "加色混合模式")
	assert_eq(d.velocity.length(), 500.0, "初速")
	assert_null(d.coroutine_script, "无行为脚本 = 纯直线弹")


func test_shell_dir_mapping():
	var s = SHELL.new()
	s.dir_index = 0
	assert_true(s.get_dir().is_equal_approx(Vector2.DOWN), "0=下")
	s.dir_index = 2
	assert_true(s.get_dir().is_equal_approx(Vector2.RIGHT), "2=右")
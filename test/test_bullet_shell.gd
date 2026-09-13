extends GutTest
## BulletShell（弹幕试验台"壳"）测试—— 自由方向 + 显示辅助

const SHELL = preload("res://scripts/workbench/bullet_shell.gd")


func test_shell_builds_enemy_bullet_bundle():
	var s = SHELL.new()
	s.tex_key = "小玉"
	s.tint = Color(1, 0, 0)
	s.blend = true
	s.speed = 500.0
	var d: BulletData = s.build()
	assert_eq(d.faction, BulletData.Faction.ENEMY, "敌弹阵营")
	assert_eq(d.texture, AssetRegistry.get_bullet_tex("小玉"), "贴图对应")
	assert_eq(d.hitbox_shape, BulletData.HitboxShape.CIRCLE, "小玉判定=圆")
	assert_eq(d.hitbox_radius, 6.0, "贴图≡判定：小玉判定 6.0（engine 现行为，enemy() 不覆盖）")
	assert_true(d.can_be_canceled, "可被 Bomb 消除")
	assert_eq(d.tint_mode, BulletData.TintMode.BLEND, "加色混合模式")
	assert_eq(d.velocity.length(), 500.0, "初速")
	assert_null(d.coroutine_script, "无行为脚本 = 纯直线弹")


func test_shell_dir_free_vector():
	var s = SHELL.new()
	assert_true(s.get_dir().is_equal_approx(Vector2.DOWN), "默认向下")
	s.dir = Vector2.RIGHT
	assert_true(s.get_dir().is_equal_approx(Vector2.RIGHT), "自由方向=右")
	var v := Vector2(0.5, -0.5).normalized()
	s.dir = v
	assert_true(s.get_dir().is_equal_approx(v), "任意角度保存")


func test_shell_dir_display():
	assert_eq(SHELL.DIR_NAMES.size(), 8, "8 方位标签")
	assert_true(SHELL.preset(0).is_equal_approx(Vector2.DOWN), "preset 0 = 下")
	assert_true(SHELL.preset(2).is_equal_approx(Vector2.RIGHT), "preset 2 = 右")
	assert_eq(SHELL.dir_name(Vector2.DOWN), "下", "正方位=名字")
	assert_eq(SHELL.dir_name(Vector2.RIGHT), "右", "正方位=右")
	assert_eq(SHELL.angle_text(Vector2.RIGHT), "90°", "角度(自下顺时针)")
	assert_eq(SHELL.angle_text(Vector2.DOWN), "0°", "角度 0° = 下")
	assert_eq(SHELL.angle_text(Vector2.LEFT), "270°", "角度 270° = 左")
	var w := Vector2.RIGHT.rotated(0.3)
	assert_true(SHELL.dir_name(w).begins_with("自选"), "任意角度标记自选")

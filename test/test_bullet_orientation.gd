extends GutTest
## 弹型朝向契约（F7·B）：`rotation_for` 语义 + `BulletData` → 内核弹型 的朝向字段传递。
## 原生 `_hit_rot` 与冻结参照 `BulletSystem` 的 1:1 由 test_native_collision.gd 锁定。


func test_rotation_for_semantics() -> void:
	var bt := BulletType.new()   # 默认 follow_dir=true, dir_offset=0
	assert_almost_eq(bt.rotation_for(Vector2.RIGHT), 0.0, 0.0001, "朝右：速度角 0")
	assert_almost_eq(bt.rotation_for(Vector2.UP), -PI / 2.0, 0.0001, "朝上：速度角 -PI/2")
	assert_almost_eq(bt.rotation_for(Vector2.ZERO), 0.0, 0.0001, "零速度：轴对齐")
	bt.dir_offset = 0.5
	assert_almost_eq(bt.rotation_for(Vector2.RIGHT), 0.5, 0.0001, "dir_offset 叠加")
	bt.follow_dir = false
	assert_almost_eq(bt.rotation_for(Vector2.UP), 0.0, 0.0001, "关跟随：恒轴对齐（dir_offset 被忽略）")
	assert_almost_eq(bt.rotation_for(Vector2.ZERO), 0.0, 0.0001, "关跟随 + 零速度")


func test_bullet_data_reads_orientation_from_config() -> void:
	# 小玉 / 点弹 → 内容表显式标了 follow_dir=false（表驱动，非硬编码）
	var round_bullet := BulletData.new().tex("小玉")
	assert_false(round_bullet.follow_dir, "小玉应读内容表的 follow_dir=false")
	assert_false(round_bullet.to_bullet_type().follow_dir, "应传到内核弹型")
	var dot_bullet := BulletData.new().tex("点弹")
	assert_false(dot_bullet.follow_dir, "点弹应读内容表的 follow_dir=false")
	# 星弹 → 内容表未标 → 默认跟随
	var oriented := BulletData.new().tex("星弹")
	assert_true(oriented.follow_dir, "星弹默认 follow_dir=true")
	assert_almost_eq(oriented.dir_offset, 0.0, 0.0001, "默认 dir_offset=0")
	assert_true(oriented.to_bullet_type().follow_dir, "应传到内核弹型")


func test_bullet_data_direct_orientation_override() -> void:
	var d := BulletData.new()
	d.follow_dir = false
	d.dir_offset = 0.4
	var bt := d.to_bullet_type()
	assert_false(bt.follow_dir, "实例直赋 follow_dir 有效")
	assert_almost_eq(bt.dir_offset, 0.4, 0.0001, "实例直赋 dir_offset 有效")

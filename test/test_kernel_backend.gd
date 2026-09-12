extends GutTest
## S1：KernelBulletBackend —— BulletData→BulletType 映射 / 内容签名复用 / 纹理旁表 / 速度语义。
## 目的：证明「原项目内容 API」能被内核驱动，而不改原项目任何现有路径（纯增量）。


func _make_backend() -> KernelBulletBackend:
	var b := KernelBulletBackend.new()
	add_child_autofree(b)
	return b


func _enemy_data() -> BulletData:
	return BulletData.new().enemy().blend(true).tex("小玉")


func test_type_reused_by_content_signature() -> void:
	var b := _make_backend()
	# 两次「不同实例、同内容」——必须复用同一个内核弹型（原项目每发都 new BulletData）
	var t1 := b.type_for(_enemy_data())
	var t2 := b.type_for(_enemy_data())
	assert_same(t1, t2, "同内容应复用内核弹型")
	b.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	b.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system.get_type_registry().size(), 1, "内核弹型表不应随发射增长")
	assert_eq(b.system.get_active_count(), 2, "两发应占两行")


func test_shoot_velocity_follows_direction_not_data_axis() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	d.velocity = Vector2.UP * 200.0   # 原项目 speed() 只写 y，方向另给
	var id := b.shoot(d, Vector2(100, 100), Vector2.RIGHT)
	assert_eq(b.system.get_position(id), Vector2(100, 100), "出生位置应等于传入 pos")
	assert_eq(b.system.get_velocity(id), Vector2(200, 0), "方向取 direction，速度取 data.velocity 的长度")
	assert_eq(b.system.get_color(id), d.tint, "颜色取 data.tint")


func test_texture_side_table() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	var id := b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	var ti: int = b.system.get_type_indices()[id]
	assert_eq(b.texture_for_index(ti), d.texture, "旁表应给出该弹型的贴图（内核弹型不含 Texture2D）")
	assert_null(b.texture_for_index(999), "越界应返回 null")


func test_faction_mapping() -> void:
	var b := _make_backend()
	assert_eq(b.type_for(BulletData.new().enemy()).faction, BulletType.Faction.ENEMY, "enemy → ENEMY")
	assert_eq(b.type_for(BulletData.new().player()).faction, BulletType.Faction.PLAYER, "player → PLAYER")
	assert_eq(b.type_for(BulletData.new().bomb()).faction, BulletType.Faction.NONE, "bomb → NONE（S4 再接）")


func test_rect_hitbox_only_when_rect_shape() -> void:
	var b := _make_backend()
	var circle := BulletData.new().enemy()
	circle.hitbox_shape = BulletData.HitboxShape.CIRCLE
	circle.hitbox_size = Vector2(8, 8)   # 原项目默认值，但判定是圆
	assert_eq(b.type_for(circle).hitbox_size, Vector2.ZERO, "圆判定时内核 hitbox_size 必须归零")
	var rect := BulletData.new().enemy()
	rect.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	rect.hitbox_size = Vector2(48, 24)
	assert_eq(b.type_for(rect).hitbox_size, Vector2(48, 24), "矩形判定时保留尺寸")


## S4a：`BulletData.accel` 已映射到 `world_accel`，不再计未映射。
func test_accel_field_mapped_since_s4a() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	d.accel = Vector2(0, -100)
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.unmapped_behavior_count, 0, "S4a 起 accel 已映射，不应计未映射")
	assert_eq(b.system.get_move_name(b.system.get_behavior_id(0)), &"world_accel", "应挂 world_accel")


## 无内核端口的行为应计数并走直线（测试夹具，独立于 S4 进度）。
func test_unmapped_behavior_counted() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	d.coroutine_script = preload("res://test/fixtures/no_port_behavior.gd")
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.unmapped_behavior_count, 1, "无端口行为应计数（供 S4 覆盖率观察）")
	assert_eq(b.system.get_behavior_id(0), BulletSystem.BEHAVIOR_NONE, "未映射应无行为（直线）")

extends GutTest
## KernelBulletBackend —— BulletData→BulletType 映射 / 内容签名复用 / 纹理旁表 / 速度语义。
## 目的：证明「原项目内容 API」能被内核驱动，而不改原项目任何现有路径（纯增量）。


func _make_backend() -> KernelBulletBackend:
	var b := KernelBulletBackend.new()
	add_child_autofree(b)
	return b


func _enemy_data() -> BulletData:
	return BulletData.new().enemy().blend(true).tex("小玉")


func test_type_reused_per_bullet_data() -> void:
	var b := _make_backend()
	# M2：弹型缓存在 BulletData **实例**上 —— 同实例复用同一内核弹型
	var d := _enemy_data()
	assert_same(d.to_bullet_type(), d.to_bullet_type(), "同一 BulletData 应复用内核弹型")
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system.get_type_registry().size(), 1, "复用实例 → 弹型表不随发射增长")
	assert_eq(b.system.get_active_count(), 2, "两发应占两行")


func test_distinct_instances_own_distinct_types() -> void:
	var b := _make_backend()
	# 契约收紧：不再按内容签名兜底 —— 内容**必须复用实例**，不得每发 new
	b.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	b.shoot(_enemy_data(), Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system.get_type_registry().size(), 2, "每发 new 实例 = 各自弹型")


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
	var _b := _make_backend()
	assert_eq(BulletData.new().enemy().to_bullet_type().faction, BulletType.Faction.ENEMY, "enemy → ENEMY")
	assert_eq(BulletData.new().player().to_bullet_type().faction, BulletType.Faction.PLAYER, "player → PLAYER")
	assert_eq(BulletData.new().bomb().to_bullet_type().faction, BulletType.Faction.NONE, "bomb → NONE（炸弹走宿主节点）")


func test_rect_hitbox_only_when_rect_shape() -> void:
	var _b := _make_backend()
	var circle := BulletData.new().enemy()
	circle.hitbox_shape = BulletData.HitboxShape.CIRCLE
	circle.hitbox_size = Vector2(8, 8)   # 原项目默认值，但判定是圆
	assert_eq(circle.to_bullet_type().hitbox_size, Vector2.ZERO, "圆判定时内核 hitbox_size 必须归零")
	var rect := BulletData.new().enemy()
	rect.hitbox_shape = BulletData.HitboxShape.RECTANGLE
	rect.hitbox_size = Vector2(48, 24)
	assert_eq(rect.to_bullet_type().hitbox_size, Vector2(48, 24), "矩形判定时保留尺寸")


## `BulletData.accel` 已映射到 `world_accel`，不再计未映射。
func test_accel_field_mapped_since_s4a() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	d.accel = Vector2(0, -100)
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.unmapped_behavior_count, 0, "accel 已映射，不应计未映射")
	# 4f：行为全原生 → 断言已注册一个 program（原「move 槽」概念已随 GDScript 内核删除）
	assert_eq(b.system._program_data.size(), 1, "应注册 world_accel program")


## 无内核端口的行为应计数并走直线（测试夹具，独立于进度）。
func test_unmapped_behavior_counted() -> void:
	var b := _make_backend()
	var d := _enemy_data()
	d.coroutine_script = preload("res://test/fixtures/no_port_behavior.gd")
	b.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.unmapped_behavior_count, 1, "无端口行为应计数（覆盖率观察）")
	assert_eq(b.system._program_data.size(), 0, "未映射应无 program（直线）")

extends GutTest
const FIX := preload("res://test/fixtures/lifecycle_fixtures.gd")
## KernelBulletHost —— SpawnSpec→BulletType 映射 / 实例复用 / 纹理旁表 / 速度语义。


func _make_backend() -> KernelBulletHost:
	var b := KernelBulletHost.new()
	add_child_autofree(b)
	return b


func _enemy_spec() -> SpawnSpec:
	return SpawnSpec.new().enemy().blend(true).tex("小玉")


func test_type_reused_per_spawn_spec() -> void:
	var b := _make_backend()
	# 弹型缓存在 SpawnSpec **实例**上 —— 同实例复用同一内核弹型
	var d := _enemy_spec()
	assert_same(d.to_bullet_type(), d.to_bullet_type(), "同一 SpawnSpec 应复用内核弹型")
	b.shoot_spec(d, Vector2.ZERO, Vector2.RIGHT)
	b.shoot_spec(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system.get_type_registry().size(), 1, "复用实例 → 弹型表不随发射增长")
	assert_eq(b.system.get_active_count(), 2, "两发应占两行")


func test_distinct_instances_own_distinct_types() -> void:
	var b := _make_backend()
	# 契约收紧：内容**必须复用实例**，不得每发 new
	b.shoot_spec(_enemy_spec(), Vector2.ZERO, Vector2.RIGHT)
	b.shoot_spec(_enemy_spec(), Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system.get_type_registry().size(), 2, "每发 new 实例 = 各自弹型")


func test_shoot_velocity_follows_direction_not_spec_axis() -> void:
	var b := _make_backend()
	var d := _enemy_spec()
	d.velocity = Vector2.UP * 200.0   # speed() 只写 y，方向另给
	var id := b.shoot_spec(d, Vector2(100, 100), Vector2.RIGHT)
	assert_eq(b.system.get_position(id), Vector2(100, 100), "出生位置应等于传入 pos")
	assert_eq(b.system.get_velocity(id), Vector2(200, 0), "方向取 direction，速度取 spec.velocity 的长度")
	assert_eq(b.system.get_color(id), d.tint, "颜色取 spec.tint")


func test_texture_side_table() -> void:
	var b := _make_backend()
	var d := _enemy_spec()
	var id := b.shoot_spec(d, Vector2.ZERO, Vector2.RIGHT)
	var ti: int = b.system.get_type_indices()[id]
	assert_eq(b.texture_for_index(ti), d.texture, "旁表应给出该弹型的贴图（内核弹型不含 Texture2D）")
	assert_null(b.texture_for_index(999), "越界应返回 null")


func test_faction_mapping() -> void:
	var _b := _make_backend()
	assert_eq(SpawnSpec.new().enemy().to_bullet_type().faction, BulletType.Faction.ENEMY, "enemy → ENEMY")
	assert_eq(SpawnSpec.new().player().to_bullet_type().faction, BulletType.Faction.PLAYER, "player → PLAYER")


func test_rect_hitbox() -> void:
	var _b := _make_backend()
	var circle := SpawnSpec.new().enemy().hitbox_circle(4.0)
	assert_eq(circle.to_bullet_type().hitbox_size, Vector2.ZERO, "圆判定时内核 hitbox_size 必须归零")
	var rect := SpawnSpec.new().enemy().hitbox_rect(Vector2(48, 24))
	assert_eq(rect.to_bullet_type().hitbox_size, Vector2(48, 24), "矩形判定时保留尺寸")


## SpawnSpec.lifecycle 走 `{lifecycle}` 入口。
func test_lifecycle_mapped() -> void:
	var b := _make_backend()
	var d := _enemy_spec()
	d.lifecycle = FIX.world_accel(Vector2(0, -100))
	b.shoot_spec(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(b.system._program_data.size(), 1, "应注册 world_accel program")

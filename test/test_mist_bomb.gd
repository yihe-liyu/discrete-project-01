extends GutTest
## KernelMistBomb：单贴图横向展开（宽 0 → 满宽）+ 椭圆持续伤害 + 清敌弹 + 到点自灭。

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


func test_marisa_bomb_data_is_mist() -> void:
	var bd: BombData = MARISA_DATA.bomb
	assert_not_null(bd, "marisa 应配 bomb")
	assert_eq(bd.kind, BombData.Kind.MIST, "应是 MIST")
	assert_eq(bd.count, 1, "单颗")
	assert_not_null(bd.texture, "应有贴图（marisa_bomb01）")


func test_mist_bomb_grows_damages_clears_and_expires() -> void:
	var bd: BombData = MARISA_DATA.bomb
	var reg := EntityRegistry.new()
	BulletManager.current.inject_entity_registry(reg)

	var near_enemy := FakeEnemy.new()
	add_child_autofree(near_enemy)
	near_enemy.global_position = Vector2(448.0, 700.0)
	reg.register_enemy(near_enemy)
	var far_enemy := FakeEnemy.new()
	add_child_autofree(far_enemy)
	far_enemy.global_position = Vector2(448.0 + 200.0, 700.0)   # 满宽半长轴 128 → 在椭圆外
	reg.register_enemy(far_enemy)

	var ed := BulletData.new().enemy().tex("小玉")
	ed.velocity = Vector2.UP * 10.0
	BulletManager.current.shoot_bullet(ed, Vector2(448.0, 700.0), Vector2.UP)
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 1, "先有 1 颗敌弹")

	var bomb = BulletManager.current.shoot_bomb_bullet(bd, Vector2(448.0, 700.0), Vector2.RIGHT)
	assert_true(bomb is BombEntity, "应是宿主 bomb 实体")
	for _f in 30:
		bomb._physics_process(1.0 / 60.0)
	assert_gt(bomb.half_width(), 0.0, "宽应从 0 展开")
	assert_gt(near_enemy.taken, 0.0, "椭圆内敌机应持续受伤")
	assert_eq(far_enemy.taken, 0.0, "椭圆外敌机不应受伤")
	assert_eq(BulletManager.current.kernel_system().get_active_count(), 0, "范围内敌弹应被清")

	for _f in 120:
		if bomb.is_queued_for_deletion():
			break
		bomb._physics_process(1.0 / 60.0)
	assert_true(bomb.is_queued_for_deletion(), "grow+hold+fade 后应回收")

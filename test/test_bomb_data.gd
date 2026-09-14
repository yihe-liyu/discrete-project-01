extends GutTest
## BombData：自机 bomb 的内容数据（外观/编队/运动/爆炸）；KernelBomb 只读它做机制。

func test_bomb_ring_tres_loads() -> void:
	var bd := load("res://data/player_data/bomb_ring.tres") as BombData
	assert_not_null(bd, "bomb_ring.tres 应加载为 BombData")
	assert_eq(bd.count, 8, "8 颗")
	assert_almost_eq(bd.explode_damage, 150.0, 0.001, "爆炸伤害")
	assert_almost_eq(bd.clear_radius, 90.0, 0.001, "持续清弹半径")
	assert_not_null(bd.texture, "应有贴图")


func test_player_data_has_bomb() -> void:
	var pd := load("res://data/player_data/reimu_data.tres") as PlayerData
	assert_not_null(pd, "reimu_data 应加载")
	assert_not_null(pd.bomb, "reimu 应配了 bomb（BombData）")


func test_kernel_bomb_reads_data() -> void:
	var bd := BombData.new()
	bd.explode_radius = 123.0
	bd.orbit_speed_deg = 90.0
	bd.hitbox_radius = 33.0
	bd.clear_radius = 77.0
	var bomb = load("res://scripts/kernel_bridge/kernel_bomb.gd").new()
	bomb.setup(bd, Vector2.ZERO, Vector2.RIGHT, Color.RED, 0.25)
	assert_almost_eq(bomb.explode_radius, 123.0, 0.001, "爆炸半径来自 data")
	assert_almost_eq(bomb.orbit_speed, deg_to_rad(90.0), 0.001, "环绕角速度来自 data")
	assert_almost_eq(bomb.clear_radius, 77.0, 0.001, "清弹半径来自 data")
	assert_almost_eq(bomb.spawn_delay, 0.25, 0.001, "spawn_delay 来自生成参数")
	assert_eq(bomb.z_index, bd.z_index, "z_index 来自 data")
	bomb.free()

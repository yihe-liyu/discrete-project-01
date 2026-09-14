extends GutTest
## BombData 家族：基类（外观 / 编队 / 无敌）+ 子类。
## RingBombData → KernelBomb（环绕炸）；MistBombData → KernelMistBomb（分阶段展开）。


func test_ring_tres_loads_as_ring() -> void:
	var bd := load("res://data/player_data/bomb_ring.tres") as RingBombData
	assert_not_null(bd, "bomb_ring.tres 应加载为 RingBombData")
	assert_true(bd is BombData, "子类应满足基类契约")
	assert_eq(bd.count, 8, "8 颗")
	assert_almost_eq(bd.explode_damage, 150.0, 0.001, "爆炸伤害")
	assert_almost_eq(bd.clear_radius, 90.0, 0.001, "持续清弹半径")
	assert_not_null(bd.texture, "应有贴图")


func test_mist_tres_loads_as_mist() -> void:
	var bd: BombData = load("res://data/player_data/marisa_bomb.tres") as MistBombData
	assert_not_null(bd, "marisa_bomb.tres 应加载为 MistBombData")
	assert_true(bd is BombData, "子类应满足基类契约")
	assert_false(bd is RingBombData, "mist 不应被当成 ring（否则会被分派成 KernelBomb）")
	assert_eq(bd.count, 1, "单颗")
	assert_not_null(bd.texture, "应有贴图")


func test_player_data_has_bomb() -> void:
	var pd := load("res://data/player_data/reimu_data.tres") as PlayerData
	assert_not_null(pd, "reimu_data 应加载")
	assert_not_null(pd.bomb, "reimu 应配了 bomb（BombData）")


func test_kernel_bomb_reads_data() -> void:
	var bd := RingBombData.new()
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

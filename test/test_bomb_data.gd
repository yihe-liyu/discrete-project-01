extends GutTest

## 只测 bomb 编队调度，不打开真实 Player 场景。
class SpyPlayer extends Player:
	var events: Array[int] = []
	var now: int = 0

	func _spawn_bomb_bullet(_i: int, _hue: float) -> void:
		events.append(now)

	func step() -> void:
		now += 1
		_tick_bomb_spawns()
## BombData 家族：基类（外观 / 编队 / 无敌）+ 子类。
## RingBombData → KernelBomb（环绕炸）；MistBombData → KernelMistBomb（分阶段展开）。
##
## ⚠️ 前三条（`*_tres_loads_as_*` / `player_data_has_bomb`）**故意绑真实内容** —— 它们验的是
## 「**已出货**的 bomb 资源类型/结构对不对」（换错子类会让 `spawn_bomb` 按实际类型分派时静默变质）。
## 属**内容校验**，内容改名时**该红**（契约见 docs/TEST_INDEX.md「内容绑定契约」）。后两条是纯机制。


func test_ring_tres_loads_as_ring() -> void:
	var bd := load("res://data/player_data/reimu_bomb.tres") as RingBombData
	assert_not_null(bd, "reimu_bomb.tres 应加载为 RingBombData")
	assert_true(bd is BombData, "子类应满足基类契约")
	# 数值都属内容（.tres 可调），这里只锁结构：数量非空、伤害/清弹为正、有贴图。
	assert_true(bd.count >= 1, "至少 1 颗")
	assert_true(bd.explode_damage > 0.0, "爆炸伤害 > 0")
	assert_true(bd.clear_radius > 0.0, "持续清弹半径 > 0")
	assert_not_null(bd.texture, "应有贴图")


func test_mist_tres_loads_as_mist() -> void:
	var bd: BombData = load("res://data/player_data/marisa_bomb.tres") as MistBombData
	assert_not_null(bd, "marisa_bomb.tres 应加载为 MistBombData")
	assert_true(bd is BombData, "子类应满足基类契约")
	assert_false(bd is RingBombData, "mist 不应被当成 ring（否则会被分派成 KernelBomb）")
	assert_true(bd.count >= 1, "至少 1 颗（数量属内容）")
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


func test_tint_for_keeps_texture_by_default() -> void:
	assert_eq(BombData.new().tint_for(0, 0.31), Color.WHITE, "基类默认不染色（保留贴图原色）")
	assert_eq(MistBombData.new().tint_for(0, 0.31), Color.WHITE, "mist 默认不染色（贴图自带颜色）")
	var ring := RingBombData.new()
	assert_eq(ring.count, 8, "环状炸默认 8 颗")
	assert_eq(ring.tint_for(0, 0.0), Color.from_hsv(0.0, 1.0, 1.0), "第 0 颗 = 起始色相")
	assert_eq(ring.tint_for(4, 0.0), Color.from_hsv(0.5, 1.0, 1.0), "i/count 均匀铺满色环")


func test_ring_bomb_spawn_interval_matches_angle_compensation() -> void:
	var p := SpyPlayer.new()
	p._bomb_spawn_count = 8
	p._bomb_spawn_index = 0
	p._bomb_spawn_interval = 9
	p._bomb_spawn_wait = 1
	for _i in 100:
		p.step()
	assert_eq(p.events, [1, 10, 19, 28, 37, 46, 55, 64], "实际出弹间隔应严格等于 interval_ticks")
	assert_almost_eq(p._bomb_spawn_delay(1), 9.0 * SimClock.DT, 0.0001, "角度补偿用实际 tick 间隔")
	assert_almost_eq(p._bomb_spawn_delay(4), 36.0 * SimClock.DT, 0.0001, "逐颗补偿不漂移")
	p.free()

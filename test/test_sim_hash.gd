extends GutTest
## SimHash：位置量化 + 同输入双跑逐 tick 哈希一致。

const PLAYER_SCENE = preload("res://scenes/player.tscn")
const FIXTURES = preload("res://test/fixtures/fixture_lib.gd")


func after_each() -> void:
	PlayerInput.clear_override()
	PlayerInput.clear_latch()
	SimClock.reset()


func test_nearby_positions_quantize_to_same_hash() -> void:
	var reg := EntityRegistry.new()
	var player := Node2D.new()
	add_child_autofree(player)
	reg.bind_player(player)

	player.global_position = Vector2(100.0, 200.0)
	var base := SimHash.of(reg, null, 0)
	player.global_position = Vector2(100.0001, 200.0001)
	assert_eq(SimHash.of(reg, null, 0), base, "1/1000 像素以内的噪声不应改变哈希")

	player.global_position = Vector2(100.01, 200.0)
	assert_ne(SimHash.of(reg, null, 0), base, "超过量化精度必须改变哈希")
	assert_ne(SimHash.of(reg, null, 1), base, "tick 必须进哈希")


## 同一段输入 / 同一 seed / 同一 tick 脚本跑两次，逐 tick 哈希必须一致。
func test_two_runs_with_same_script_produce_same_hashes() -> void:
	var first := _run_once(12345)
	var second := _run_once(12345)
	assert_eq(first.size(), second.size(), "两次跑应产生同样多的 tick")
	for i in first.size():
		if first[i] != second[i]:
			assert_eq(first[i], second[i], "首个分歧 tick=%d" % i)
			return
	assert_eq(first, second, "同输入双跑必须逐 tick 一致")


func _run_once(p_seed: int) -> Array[int]:
	RNG.set_seed(p_seed)

	var host := KernelBulletHost.new()
	add_child_autofree(host)
	var physics := KernelBulletPhysics.new()
	physics.setup(host)

	var player: Player = PLAYER_SCENE.instantiate()
	player.player_data = FIXTURES.player_data()
	add_child_autofree(player)
	player.global_position = Vector2(448, 640)
	player.is_invincible = false

	var reg := EntityRegistry.new()
	reg.bind_player(player)
	physics.entity_registry = reg
	host.system.set_seed(p_seed)

	var move_right := 1 << PlayerInput.ACTIONS.find("move_right")
	var shoot := 1 << PlayerInput.ACTIONS.find("shoot")
	var hashes: Array[int] = []
	for tick in 120:
		var mask := 0
		if tick < 80:
			mask |= move_right
		if tick % 20 < 10:
			mask |= shoot
		PlayerInput.set_override_mask(mask)
		PlayerInput.latch()

		player._physics_process(1.0 / 60.0)
		if tick % 9 == 0:
			var spec := SpawnSpec.new().enemy().tex("小玉")
			spec.velocity = Vector2.DOWN * 180.0
			host.shoot(spec, Vector2(320 + (tick % 5) * 32, 100), Vector2.DOWN)
		host.system.step(1.0 / 60.0)
		physics.process()
		hashes.append(SimHash.of(reg, host.system, tick))

	PlayerInput.clear_override()
	return hashes

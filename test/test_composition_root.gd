extends GutTest
## 组合根冒烟：GameScene 应创建 Miss 圈 / 特效层并注入（两者都不再是 autoload）。

func test_removed_autoloads_stay_removed() -> void:
	# 收敛守卫：这些都不是 autoload 了
	for setting in ["LayerConfig", "MissCircleLayer", "StageObjects", "HitEffectPool", "AssetRegistry", "StageManager"]:
		assert_false(ProjectSettings.has_setting("autoload/" + setting), "%s 不应再是 autoload" % setting)


func test_game_scene_binds_stage_runtime() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var rt: StageRuntime = inst.get_node_or_null("World/StageRuntime")
	assert_not_null(rt, "应在 World 下声明 StageRuntime（R21）")
	assert_eq(rt.world, inst.get_node("World"), "应注入 world（不再全树找 World）")
	assert_not_null(rt.current_stage_script(), "关卡脚本应经 StageRuntime 真正加载")
	var bullet_manager: BulletManager = inst.get_node_or_null("World/BulletManager")
	assert_not_null(bullet_manager, "应在 World 下声明 BulletManager（R21）")
	assert_eq(rt.bullet_manager, bullet_manager, "StageRuntime 应拿到场景里的弹幕世界")
	assert_eq(BulletManager.current, bullet_manager, "BulletManager.current 应指向场景节点")
	assert_eq(GameManager.entity_registry, rt.entity_registry,
		"GameScene 应把实体注册表登记到 GameManager（回归：register_world 形参曾自赋值 no-op）")


func test_game_scene_refreshes_kernel_player() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Node2D = inst.get_node("World/Player")
	var ctx = BulletManager.current._kernel_bullet_host.behavior_ctx
	assert_eq(ctx.get_player_position(), player.global_position,
		"内核行为管道应拿到场景自机（回归：非默认内核时 autoload._ready 早于自机）")


func test_game_scene_injects_player_stage_context() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Player = inst.get_node("World/Player")
	var rt: StageRuntime = inst.get_node("World/StageRuntime")
	assert_not_null(player.ctx, "自机应拿到关卡 ctx")
	assert_eq(player.ctx.stage, rt, "自机 ctx 应指向关卡 StageRuntime")
	assert_eq(player.ctx.effects.miss_layer, rt.miss_layer, "ctx.effects 应拿到注入的 MissCircleLayer")
	assert_eq(player.ctx.entity_registry, rt.entity_registry, "ctx.entity_registry 应指向关卡注册表")


func test_player_miss_adds_miss_circle() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Player = inst.get_node("World/Player")
	var layer: MissCircleLayer = inst.get_node("MissCircleLayer")
	player.is_invincible = false
	player.miss()
	assert_gt(layer._circles.size(), 0, "miss 后应加入反色圈")


func test_context_effects_read_bound_stage() -> void:
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	var miss := MissCircleLayer.new()
	rt.add_child(miss)
	rt.miss_layer = miss
	var fx_pool := FxPool.new()
	rt.add_child(fx_pool)
	rt.fx_pool = fx_pool
	var runner := CoroutineRunner.new()
	var ctx := StageContext.new(runner)
	ctx.stage = rt   # 显式绑定，不再回退全局
	assert_eq(ctx.effects.miss_layer, miss, "ctx.effects 应取绑定 stage 的 Miss 层")
	assert_eq(ctx.effects.fx_pool, fx_pool, "ctx.effects 应取绑定 stage 的 FX 层")
	runner.free()


func test_game_scene_creates_and_injects_miss_layer() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var layer: MissCircleLayer = inst.get_node_or_null("MissCircleLayer")
	assert_not_null(layer, "GameScene 应创建 MissCircleLayer 子节点")
	assert_eq(inst.get_node("World/StageRuntime").miss_layer, layer, "应注入 StageRuntime.miss_layer")
	assert_eq(layer.get_script().resource_path,
		"res://scripts/effect/miss_circle_layer.gd", "应挂场景节点脚本")


func test_game_scene_creates_and_injects_fx_pool() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var fx_pool: FxPool = inst.get_node_or_null("World/FxPool")
	assert_not_null(fx_pool, "GameScene 应在 World 下创建 FxPool")
	assert_eq(inst.get_node("World/StageRuntime").fx_pool, fx_pool, "应注入 StageRuntime.fx_pool")
	assert_eq(BulletManager.current.fx_pool, fx_pool, "应注入 BulletManager.current.fx_pool")
	assert_eq(fx_pool.get_script().resource_path,
		"res://scripts/effect/fx_pool.gd", "应挂 FxPool 脚本")

extends GutTest
## W1/W2 组合根冒烟：GameScene 应创建 Miss 圈 / 特效层并注入（两者都不再是 autoload）。

func test_removed_autoloads_stay_removed() -> void:
	# Track B 收敛守卫：这些都不是 autoload 了（W1/W2/W3a）
	for name in ["LayerConfig", "MissEffectManager", "StageObjects", "HitEffectPool", "AssetRegistry", "StageManager"]:
		assert_false(ProjectSettings.has_setting("autoload/" + name), "%s 不应再是 autoload" % name)


func test_game_scene_binds_stage_runtime() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var rt: StageRuntime = inst.get_node_or_null("World/StageRuntime")
	assert_not_null(rt, "应在 World 下声明 StageRuntime（R21）")
	assert_eq(rt.world, inst.get_node("World"), "应注入 world（不再全树找 World）")
	assert_not_null(rt.current_stage_script(), "关卡脚本应经 StageRuntime 真正加载")


func test_game_scene_refreshes_kernel_player() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Node2D = inst.get_node("World/Player")
	var ctx = BulletManager.current._kernel.behavior_ctx
	assert_eq(ctx.get_player_position(), player.global_position,
		"内核行为管道应拿到场景自机（W4a-1 回归：非默认内核时 autoload._ready 早于自机）")


func test_game_scene_injects_player_stage_context() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Player = inst.get_node("World/Player")
	var rt: StageRuntime = inst.get_node("World/StageRuntime")
	assert_not_null(player.ctx, "自机应拿到关卡 ctx")
	assert_eq(player.ctx.stage, rt, "自机 ctx 应指向关卡 StageRuntime")
	assert_eq(player.ctx.effects.miss_layer, rt.miss_layer, "ctx.effects 应拿到注入的 MissEffectManager")
	assert_eq(player.ctx.refs, rt.refs, "ctx.refs 应指向关卡注册表")


func test_player_miss_adds_miss_circle() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var player: Player = inst.get_node("World/Player")
	var layer: MissEffectManager = inst.get_node("MissEffectManager")
	player.is_invincible = false
	player.miss()
	assert_gt(layer._circles.size(), 0, "miss 后应加入反色圈")


func test_stageless_context_effects_fall_back_to_current_stage() -> void:
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	var miss := MissEffectManager.new()
	rt.add_child(miss)
	rt.miss_layer = miss
	var fx := FxLayer.new()
	rt.add_child(fx)
	rt.fx_layer = fx
	var runner := CoroutineRunner.new()
	var ctx := StageContext.new(runner)
	assert_eq(ctx.effects.miss_layer, miss, "无 stage 的 ctx 回退当前关卡的 Miss 层")
	assert_eq(ctx.effects.fx_layer, fx, "无 stage 的 ctx 回退当前关卡的 FX 层")
	runner.free()


func test_game_scene_creates_and_injects_miss_layer() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var layer: MissEffectManager = inst.get_node_or_null("MissEffectManager")
	assert_not_null(layer, "GameScene 应创建 MissEffectManager 子节点")
	assert_eq(inst.get_node("World/StageRuntime").miss_layer, layer, "应注入 StageRuntime.miss_layer")
	assert_eq(layer.get_script().resource_path,
		"res://scripts/effect/miss_effect_manager.gd", "应挂场景节点脚本")


func test_game_scene_creates_and_injects_fx_layer() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var fx: FxLayer = inst.get_node_or_null("World/FxLayer")
	assert_not_null(fx, "GameScene 应在 World 下创建 FxLayer")
	assert_eq(inst.get_node("World/StageRuntime").fx_layer, fx, "应注入 StageRuntime.fx_layer")
	assert_eq(BulletManager.current.fx_layer, fx, "应注入 BulletManager.current.fx_layer")
	assert_eq(fx.get_script().resource_path,
		"res://scripts/effect/fx_layer.gd", "应挂 FxLayer 脚本")

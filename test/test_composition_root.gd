extends GutTest
## W1/W2 组合根冒烟：GameScene 应创建 Miss 圈 / 特效层并注入（两者都不再是 autoload）。

func test_removed_autoloads_stay_removed() -> void:
	# Track B 收敛守卫：这些都不是 autoload 了（W1/W2/W3a）
	for name in ["LayerConfig", "MissEffectManager", "StageObjects", "HitEffectPool", "AssetRegistry"]:
		assert_false(ProjectSettings.has_setting("autoload/" + name), "%s 不应再是 autoload" % name)


func test_game_scene_binds_stage_runtime() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var rt: StageRuntime = inst.get_node_or_null("World/StageRuntime")
	assert_not_null(rt, "应在 World 下声明 StageRuntime（R21）")
	assert_same(StageManager.runtime(), rt, "应绑定到 StageManager 门面")
	assert_eq(rt.world, inst.get_node("World"), "应注入 world（不再全树找 World）")


func test_game_scene_creates_and_injects_miss_layer() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var layer: MissEffectManager = inst.get_node_or_null("MissEffectManager")
	assert_not_null(layer, "GameScene 应创建 MissEffectManager 子节点")
	assert_eq(StageManager.miss_layer, layer, "应注入 StageManager.miss_layer")
	assert_eq(layer.get_script().resource_path,
		"res://scripts/effect/miss_effect_manager.gd", "应挂场景节点脚本")


func test_game_scene_creates_and_injects_fx_layer() -> void:
	var scene: PackedScene = load("res://scenes/game_scene.tscn")
	var inst: Node = scene.instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	var fx: FxLayer = inst.get_node_or_null("World/FxLayer")
	assert_not_null(fx, "GameScene 应在 World 下创建 FxLayer")
	assert_eq(StageManager.fx_layer, fx, "应注入 StageManager.fx_layer")
	assert_eq(BulletManager.fx_layer, fx, "应注入 BulletManager.fx_layer")
	assert_eq(fx.get_script().resource_path,
		"res://scripts/effect/fx_layer.gd", "应挂 FxLayer 脚本")

extends GutTest
## W1 组合根冒烟：GameScene 应创建 Miss 圈节点并注入 StageManager（不再是 autoload）。

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

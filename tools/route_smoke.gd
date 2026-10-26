extends Node
## 路线静态冒烟：校验每条 Route 引用的 StageData / 脚本 / 背景 / BGM。
## 用法：godot --headless --path . -s tools/route_smoke.gd

func _ready() -> void:
	StageCatalog.load_registry()
	StageRouteCatalog.load_routes()
	var errors: Array[String] = []
	var routes := StageRouteCatalog.all()
	if routes.is_empty():
		errors.append("没有任何 StageRoute")
	for route in routes:
		for err in route.validate():
			errors.append("StageRoute[%s]: %s" % [route.route_id, err])
		for stage in route.stages:
			if stage.create_script == null:
				errors.append("StageRoute[%s]: stage_id=%d 没有 create_script" % [route.route_id, stage.stage_id])
			if stage.background_scene == null:
				errors.append("StageRoute[%s]: stage_id=%d 没有 background_scene" % [route.route_id, stage.stage_id])
			if stage.bgm_key != "" and AssetRegistry.get_bgm(stage.bgm_key) == null:
				errors.append("StageRoute[%s]: stage_id=%d 的 BGM '%s' 无法加载" % [route.route_id, stage.stage_id, stage.bgm_key])
		print("ROUTE %s diff=%s -> %s" % [route.route_id, Difficulty.display_name(route.difficulty),
			", ".join(PackedStringArray(route.stages.map(func(s): return str(s.stage_id))))])
	if errors.is_empty():
		print("✅ route smoke 通过（%d 条路线）" % routes.size())
		get_tree().quit(0)
	else:
		for err in errors:
			push_error(err)
		get_tree().quit(1)

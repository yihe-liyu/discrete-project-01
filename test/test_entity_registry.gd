extends GutTest
## W4b-3：EntityRegistry —— 自机 / 敌机 / Boss 的运行时单一真源 + GameState 过渡门面。


func test_register_unregister_and_query():
	var reg := EntityRegistry.new()
	var e := Enemy.new()
	reg.register_enemy(e)
	assert_eq(reg.get_active_enemies().size(), 1, "注册入表")
	reg.register_enemy(e)
	assert_eq(reg.get_active_enemies().size(), 1, "重复注册不重复入表")
	reg.unregister_enemy(e)
	assert_eq(reg.get_active_enemies().size(), 0, "注销出表")
	e.free()


func test_get_boss_matches_script_type():
	var reg := EntityRegistry.new()
	var enemy := Enemy.new()
	var boss := Boss.new()
	reg.register_enemy(enemy)
	assert_null(reg.get_boss(), "杂兵不算 Boss")
	reg.register_enemy(boss)
	assert_eq(reg.get_boss(), boss, "按脚本类型识别 Boss")
	enemy.free()
	boss.free()


func test_clear_frees_enemies_keeps_player():
	var reg := EntityRegistry.new()
	var e := Enemy.new()
	add_child_autofree(e)
	reg.register_enemy(e)
	var p: Player = load("res://scenes/player.tscn").instantiate()
	reg.bind_player(p)
	reg.clear()
	assert_true(reg.get_active_enemies().is_empty(), "清场后敌机表空")
	assert_true(e.is_queued_for_deletion(), "敌机被 queue_free")
	assert_eq(reg.player, p, "自机不清（跨关存活）")
	p.free()


func test_stageless_context_falls_back_to_current_world():
	var saved: EntityRegistry = EntityRegistry.current
	var reg := EntityRegistry.new()
	EntityRegistry.current = reg
	var runner := CoroutineRunner.new()
	var ctx := StageContext.new(runner)
	assert_eq(ctx.refs, reg, "无 stage 的 ctx 回退到当前世界注册表")
	var p: Player = load("res://scenes/player.tscn").instantiate()
	reg.bind_player(p)
	assert_eq(ctx.player.get_player(), p, "自机射击 ctx 能解析到自机")
	EntityRegistry.current = saved   # 还原
	runner.free()
	p.free()


func test_game_state_facade_forwards_to_registry():
	var saved: EntityRegistry = GameState._refs
	var reg := EntityRegistry.new()
	GameState.bind_refs(reg)
	var e := Enemy.new()
	GameState.active_enemies.append(e)
	assert_eq(reg.get_active_enemies().size(), 1, "active_enemies 门面读写同一数组")
	assert_eq(GameState.get_active_enemies(), reg.get_active_enemies(), "get_active_enemies 同源")
	GameState.bind_refs(saved)   # 还原，避免污染其他用例
	e.free()
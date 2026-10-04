extends GutTest
## 4：EntityRegistry —— 自机 / 敌机 / Boss 的运行时单一真源（经 StageContext.stage 显式绑定解析）。


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


func test_context_refs_read_bound_stage():
	var reg := EntityRegistry.new()
	var rt := StageRuntime.new()
	autofree(rt)
	rt.entity_registry = reg
	var runner := CoroutineRunner.new()
	var ctx := StageContext.new(runner)
	ctx.stage = rt   # 显式绑定，不再回退全局
	assert_eq(ctx.entity_registry, reg, "ctx.entity_registry 应取绑定 stage 的注册表")
	var p: Player = load("res://scenes/player.tscn").instantiate()
	reg.bind_player(p)
	assert_eq(ctx.player.get_player(), p, "自机射击 ctx 能解析到自机")
	runner.free()
	p.free()


## ═══ B6 守卫：资源读取走 `PlayerBase` **类型化接口**，不认 `get("resources")` 字符串键 ═══

## 长得像（有同名 `resources` 属性）、但**不是** PlayerBase 的节点：
## 旧实现 `player.get("resources")` 会认它，新实现必须拒绝。
class BareNodeWithResources extends Node2D:
	var resources: PlayerResources


func test_player_resources_require_typed_player_interface():
	var reg := EntityRegistry.new()
	var bare := BareNodeWithResources.new()
	bare.resources = PlayerResources.new()
	add_child_autofree(bare)
	reg.bind_player(bare)
	assert_null(reg.get_player_resources(),
		"裸 Node2D 不该凭 `resources` 属性名被当成自机接口（旧 get(\"resources\") 会认）")


## 真自机走 `PlayerBase.resources`：取到同一实例
func test_player_resources_come_from_typed_interface():
	var reg := EntityRegistry.new()
	var p: Player = load("res://scenes/player.tscn").instantiate()
	autofree(p)
	var res := PlayerResources.new()
	p.resources = res
	reg.bind_player(p)
	assert_eq(reg.get_player_resources(), res, "应经 PlayerBase.resources 取到同一实例")
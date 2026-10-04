extends GutTest
## `StageHost`（舞台世界装配）—— S4 把"真游戏 / 工作台整关预览 / 三个组合台"各写一份的
## 接线收成**一条实现**。本文件既验 StageHost 自己，也**锁住四个宿主真的在用它**：
## 组合台 / 工作台 / 真游戏各装一个真场景，断言同一条不变量
## （注册表里是自机 / 内核后端拿到同一张注册表 / 特效挂舞台）。

const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const REIMU := preload("res://data/player_data/reimu_data.tres")

var _stage_runtime: StageRuntime
var _world: Node2D


func before_each() -> void:
	_world = Node2D.new()
	add_child_autofree(_world)
	_stage_runtime = StageRuntime.new()
	add_child_autofree(_stage_runtime)
	_stage_runtime.world = _world


## 四宿主共用的不变量：装配完就该是这个样子
func _assert_wired(rt: StageRuntime, bm: BulletManager, fx_expected: Node) -> void:
	assert_eq(rt.bullet_manager, bm, "运行时认领的子弹世界就是场上那一个")
	assert_eq(bm.fx_parent, fx_expected, "特效归属舞台（炸弹贴图不再全树找）")
	assert_not_null(rt.entity_registry.player, "注册表里应有自机（内核自机狙靠它）")
	assert_eq(bm.entity_registry, rt.entity_registry, "内核弹幕后端拿到同一张注册表")


# ═══ StageHost 自己 ═══

func test_make_bullet_world_is_named_parented_and_flags_top_level() -> void:
	var bm := StageHost.make_bullet_world(_world, true)
	assert_not_null(bm)
	assert_eq(String(bm.name), "BulletManager")
	assert_eq(bm.get_parent(), _world)
	assert_true(bm.top_level, "嵌入页面的宿主（组合台）需要画布坐标")


func test_make_player_applies_script_name_and_data() -> void:
	var player := StageHost.make_player(_world, GHOST, "Player", REIMU)
	assert_eq(String(player.name), "Player")
	assert_eq(player.get_parent(), _world)
	assert_eq(player.get_script(), GHOST, "换的是预览用的幽灵脚本（继承 Player，类型兼容）")
	assert_eq(player.player_data, REIMU, "必须给 PlayerData —— Player._ready 靠它应用角色数据")


func test_wire_world_claims_bullet_world_and_fx_parent() -> void:
	var bm := StageHost.make_bullet_world(_world)
	StageHost.wire_world(_stage_runtime, bm, _world)
	assert_eq(_stage_runtime.bullet_manager, bm, "运行时认领子弹世界")
	assert_eq(bm.fx_parent, _world)


func test_wire_player_binds_registry_and_kernel_backend() -> void:
	var bm := StageHost.make_bullet_world(_world)
	StageHost.wire_world(_stage_runtime, bm, _world)
	var player := StageHost.make_player(_world, GHOST, "GhostPlayer", REIMU)
	StageHost.wire_player(_stage_runtime, player)
	assert_eq(_stage_runtime.player, player, "运行时显式认领自机（_inject_player_ctx 只认它）")
	assert_eq(_stage_runtime.entity_registry.player, player, "自机进注册表")
	assert_eq(bm.entity_registry, _stage_runtime.entity_registry, "内核后端拿到注册表")


func test_wire_does_both_halves() -> void:
	var bm := StageHost.make_bullet_world(_world)
	var player := StageHost.make_player(_world, GHOST, "GhostPlayer", REIMU)
	StageHost.wire(_stage_runtime, bm, player, _world)
	_assert_wired(_stage_runtime, bm, _world)


## 只交注册表（不绑自机）：真游戏"选机体失败 / 没有 Player"的异常路径走它
func test_wire_registry_injects_without_binding_player() -> void:
	var bm := StageHost.make_bullet_world(_world)
	StageHost.wire_world(_stage_runtime, bm, _world)
	StageHost.wire_registry(_stage_runtime)
	assert_eq(bm.entity_registry, _stage_runtime.entity_registry, "内核后端拿到注册表")
	assert_null(_stage_runtime.entity_registry.player, "这条路径不绑自机（没有自机可绑）")


func test_wire_registry_without_bullet_world_is_loud() -> void:
	StageHost.wire_registry(_stage_runtime)
	assert_push_error("子弹世界还没接上")


## 没有子弹世界就接自机 = 装配顺序错了：要**响亮地**报错，且不许偷偷绑一半
func test_wire_player_without_bullet_world_is_loud_and_inert() -> void:
	var player := StageHost.make_player(_world, GHOST, "GhostPlayer", REIMU)
	StageHost.wire_player(_stage_runtime, player)
	assert_push_error("子弹世界还没接上")
	assert_null(_stage_runtime.entity_registry.player, "没接上就不该绑一半")


# ═══ 四个宿主：真的在用这条接线 ═══

func test_bench_scene_uses_stage_host() -> void:
	var bench = preload("res://scenes/workbench/phase_bench.tscn").instantiate()
	add_child_autofree(bench)
	await get_tree().process_frame
	var rt: StageRuntime = bench.stage_runtime()
	_assert_wired(rt, bench.bullet_manager(), rt.world)


func test_workbench_scene_uses_stage_host() -> void:
	# 真装配整关预览（会真加载 stage01；user:// 由 run_tests.sh 隔离）
	var wb: Node = load("res://scenes/workbench.tscn").instantiate()
	add_child_autofree(wb)
	await get_tree().process_frame
	_assert_wired(
		wb.get_node("World/StageRuntime"),
		wb.get_node("BulletManager"),
		wb.get_node("World"))


func test_game_scene_uses_stage_host() -> void:
	var inst: Node = load("res://scenes/game_scene.tscn").instantiate()
	add_child_autofree(inst)
	await get_tree().process_frame
	_assert_wired(
		inst.get_node("World/StageRuntime"),
		inst.get_node("World/BulletManager"),
		inst.get_node("World"))

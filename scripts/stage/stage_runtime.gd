class_name StageRuntime
extends Node
## 关卡运行时 —— 关卡生命周期 + 生成敌人/Boss（World 下的场景节点）。
## StageManager autoload 已删除；本节点是关卡生命周期的唯一实现（World 下声明）。
## 依赖由组合根注入 `world`（敌人生成 / 自机 ctx 注入的父节点），不再 get_tree().current_scene 全树找（R2）。
## 运行时引用归 EntityRegistry / SaveData，运行时字段已清空。

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")


var world: Node2D							## 敌人生成 / 自机 ctx 注入的父节点（World；组合根注入）
var entity_registry := EntityRegistry.new()	## 战场实体注册表（自机 / 敌机 / Boss 的单一真源）
var bullet_manager: BulletManager			## 弹幕世界（组合根注入；供关卡发弹 / 清弹）
var miss_layer: MissCircleLayer				## 注入槽（组合根 / 工作台设置）
var fx_pool: FxPool
## 道具池（组合根注入；消费端经 ctx.stage.item_pool，不再全树搜 World/ItemPool）
var item_pool: ItemPool
var ui_layer: CanvasLayer					## Boss 位置指示器所属 HUD 层（组合根注入）
var current_background: StageBackground		## 背景场景实例（组合根在 load_stage 前注入）
var current_stage: StageData
var _is_stage_active: bool = false
var _coroutine_script: CoroutineScript		##关卡协程脚本


## 获取当前关卡协程脚本（工作台/调试读取运行时间用）
func current_stage_script() -> CoroutineScript:
	return _coroutine_script


## 加载关卡；背景实例由 current_background 注入（会启动背景里挂的协程脚本）
func load_stage(data: StageData) -> void:
	var background := current_background
	if _is_stage_active:
		stop_stage()

	# 配置校验：非法数据拒绝启动，防止除零/空脚本崩溃
	var errs := data.validate()
	for e in errs:
		push_error("StageRuntime 配置错误: " + e)
	if not errs.is_empty():
		return

	SaveData.reset_all(entity_registry)   # 注册表显式传入，不再读全局

	current_stage = data
	_is_stage_active = true

	var stage_script: CoroutineScript = data.create_script.new()
	assert(stage_script is CoroutineScript, "StageRuntime: create_script must be a CoroutineScript")
	add_child(stage_script)
	_coroutine_script = stage_script
	stage_script.finished.connect(_on_stage_finished)

	var ctx := StageContext.new(stage_script)
	ctx.stage = self
	stage_script.start(ctx)
	_inject_player_ctx(ctx)

	# 自动启动背景场景里挂的所有协程脚本
	if is_instance_valid(background):
		for child in background.get_children():
			if child is CoroutineScript:
				var bctx := StageContext.new(child)
				bctx.stage = self
				child.start(bctx)

	stage_started.emit()


func stop_stage() -> void:
	_is_stage_active = false
	current_stage = null
	if _coroutine_script and is_instance_valid(_coroutine_script):
		_coroutine_script.stop()
		_coroutine_script.queue_free()
		_coroutine_script = null
	entity_registry.clear()
	if bullet_manager:
		bullet_manager.clear_bullets()  # 清弹幕，激光自己淡出


func _on_stage_finished() -> void:
	if not current_stage:
		return
	_is_stage_active = false
	stage_cleared.emit()
	all_enemies_defeated.emit()
	var score := 0
	var res: PlayerResources = entity_registry.get_player_resources()
	if res != null:
		score = res.current_score
	SaveData.save_high_score(current_stage.stage_id, score)


## 从 EnemyData 生成敌人（实例化/挂载协程/入场景）
func spawn_enemy_data(data: EnemyData, p_ctx: StageContext = null) -> Enemy:
	if not p_ctx or not p_ctx.active():
		return null
	if not data.has_script():
		push_warning("StageRuntime.spawn_enemy_data: no script set")
		return null
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.global_position = data.get_spawn_pos()
	enemy.enemy_data = data
	enemy.ctx = p_ctx
	var cs: CoroutineScript = data.make_script()
	if not cs:
		push_warning("StageRuntime.spawn_enemy_data: script is not a CoroutineScript")
		enemy.queue_free()
		return null
	cs.target = enemy
	var params: Dictionary = data.get_params()
	PARAM_VALIDATOR_SCRIPT.apply(cs, params)   # 校验 + 只设合法键 + 打错键名/类型响亮报错
	if cs.has_method("setup_custom"):
		cs.setup_custom(params)
	enemy.add_child(cs)
	cs.start(p_ctx, enemy)
	add_enemy_to_scene(enemy)
	return enemy


func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = position
	add_enemy_to_scene(enemy)
	if auto_start:
		enemy.start.call_deferred()
	return enemy


func spawn_boss(data: BossData, position: Vector2, p_ctx: StageContext = null) -> Boss:
	var boss := Boss.new()
	boss.global_position = position
	if data.visual:
		var vis := data.visual.instantiate()
		boss.add_child(vis)
	add_enemy_to_scene(boss)
	boss.setup(data, p_ctx)
	boss.start_boss()
	return boss


## 开一场"仅单个阶段"的战（符卡练习）：自建一个可运行的协程时钟作 ctx，
## 生成对应 Boss 并直接让它进入该阶段。
## 与 load_stage（整关编排）不同：本方法只服务"点杀单阶段"，故自建 clock，不复用整关脚本。
## 返回 Boss；Boss.ctx.runner 即本次时钟（可 stop/queue_free 清理）。
func start_spell_card(p_phase: PhaseData, boss_scene: PackedScene, boss_name: String, position: Vector2) -> Boss:
	var runner := CoroutineRunner.new()
	runner.run(func(): return true)  # 保活：让 ctx.runner 保持 is_running（ctx.active/clock 依赖）
	var ctx := StageContext.new(runner)
	ctx.stage = self   # 符卡练习 ctx 也要绑 StageRuntime：ctx.effects/entity_registry 才能解析 Miss 层与自机
	var single := BossData.new()
	single.boss_name = boss_name
	single.visual = boss_scene
	single.phases = [p_phase]
	var boss := spawn_boss(single, position, ctx) as Boss
	if boss:
		boss.get_parent().add_child(runner)  # 把时钟放进场景树（Boss 所在 World），随场景一起释放
		boss.start_phase(p_phase)
	return boss


## 把关卡上下文注入给场景中的自机（供系统操作服务）
func _inject_player_ctx(p_ctx: StageContext) -> void:
	if not is_instance_valid(world):
		return
	var player := world.get_node_or_null("Player") as Player
	if player:
		player.bind_ctx(p_ctx)   # 把 stage 一并转发给射击 ctx
		entity_registry.bind_player(player)


func add_enemy_to_scene(node: Node2D) -> void:
	# 注入注册表：Enemy 在 _ready 自注册、Boss 在 start_boss 注册（都在 add_child 之后，故先给引用）
	if "registry" in node:
		node.registry = entity_registry
	if "ui_layer" in node:
		node.ui_layer = ui_layer
	var parent: Node = null
	if is_instance_valid(world):
		parent = world
	else:
		parent = get_tree().root
	if parent:
		parent.add_child(node)
	else:
		node.queue_free()

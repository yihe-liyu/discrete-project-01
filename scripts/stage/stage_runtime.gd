## 关卡运行时 —— 关卡生命周期 + 生成敌人/Boss（World 下的场景节点）。
## W3b-2：StageManager autoload 已删除；本节点是关卡生命周期的唯一实现（World 下声明）。
## 依赖由组合根注入 `world`（敌人生成 / 自机 ctx 注入的父节点），不再 get_tree().current_scene 全树找（R2）。
## W4b-4：运行时引用归 EntityRegistry / SaveData，运行时字段已清空。
class_name StageRuntime
extends Node

const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BossClass = preload("res://scripts/enemy/boss.gd")
const ParamValidator = preload("res://scripts/data/param_validator.gd")

signal stage_started()
signal stage_cleared()
signal all_enemies_defeated()

## 敌人生成 / 自机 ctx 注入的父节点（World；组合根注入）
var world: Node2D

## 战场实体注册表（自机 / 敌机 / Boss 的单一真源；W4b-3）
var refs := EntityRegistry.new()

## 弹幕世界（W4c：组合根注入；供关卡发弹 / 清弹）
var bullets: BulletManager

## "当前关卡"（R8 static var）：供无 stage 的 ctx（自机射击 / 子弹共享 ctx）
## 回退解析 Miss / FX 层。
static var current: StageRuntime

## 注入槽（组合根 / 工作台设置）
var miss_layer: MissEffectManager
var fx_layer: FxLayer
var current_background: StageBackground

var current_stage: StageData
var _stage_active: bool = false
var _stage_script: CoroutineScript


## 入场即把本关卡的注册表登记为「当前世界」（先于任何实体 _ready）
func _enter_tree() -> void:
	StageRuntime.current = self
	EntityRegistry.current = refs


func _exit_tree() -> void:
	if StageRuntime.current == self:
		StageRuntime.current = null


## 当前关卡协程脚本（工作台/调试读取运行时间用）
func current_stage_script() -> CoroutineScript:
	return _stage_script


## 加载关卡；background = 背景场景实例（由门面/组合根传入，用于启动背景里的协程脚本）
func load_stage(data: StageData) -> void:
	var background := current_background
	if _stage_active:
		stop_stage()

	# 配置校验：非法数据拒绝启动，防止除零/空脚本崩溃
	var errs := data.validate()
	for e in errs:
		push_error("StageRuntime 配置错误: " + e)
	if not errs.is_empty():
		return

	SaveData.reset_all()

	current_stage = data
	_stage_active = true

	var stage_script: CoroutineScript = data.create_script.new()
	assert(stage_script is CoroutineScript, "StageRuntime: create_script must be a CoroutineScript")
	add_child(stage_script)
	_stage_script = stage_script
	stage_script.finished.connect(_on_stage_finished)

	var ctx := StageContext.new(stage_script)
	ctx.stage = self
	stage_script.start(ctx)
	_inject_player_ctx(ctx)

	# 自动启动背景场景里挂的所有协程脚本
	if background:
		for child in background.get_children():
			if child is CoroutineScript:
				var bctx := StageContext.new(child)
				bctx.stage = self
				child.start(bctx)

	stage_started.emit()


func stop_stage() -> void:
	_stage_active = false
	current_stage = null
	if _stage_script and is_instance_valid(_stage_script):
		_stage_script.stop()
		_stage_script.queue_free()
		_stage_script = null
	refs.clear()
	if bullets:
		bullets.clear_bullets()  # 清弹幕，激光自己淡出


func _on_stage_finished() -> void:
	if not current_stage:
		return
	_stage_active = false
	stage_cleared.emit()
	all_enemies_defeated.emit()
	var score := 0
	var res: PlayerResources = refs.get_player_resources()
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
	ParamValidator.apply(cs, params)   # C4：校验 + 只设合法键 + 打错键名/类型响亮报错
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


func spawn_boss(data: BossData, position: Vector2, p_ctx: StageContext = null) -> Node:
	var boss := BossClass.new()
	boss.global_position = position
	if data.visual:
		var vis := data.visual.instantiate()
		boss.add_child(vis)
	add_enemy_to_scene(boss)
	boss.setup(data, p_ctx)
	boss.start_boss()
	return boss


## 返回类型同 BulletService.shoot_spread：旧池 = Bullet，内核路径 = int id（Track A / S3）。
func spawn_bullet(data: BulletData, position: Vector2, direction: Vector2):
	return bullets.shoot_enemy_bullet(data, position, direction) if bullets else null


## 开一场"仅单个阶段"的战（符卡练习）：自建一个可运行的协程时钟作 ctx，
## 生成对应 Boss 并直接让它进入该阶段。
## 与 load_stage（整关编排）不同：本方法只服务"点杀单阶段"，故自建 clock，不复用整关脚本。
## 返回 Boss；Boss.ctx.runner 即本次时钟（可 stop/queue_free 清理）。
func start_spell_card(p_phase: PhaseData, boss_scene: PackedScene, boss_name: String, position: Vector2) -> Boss:
	var runner := CoroutineRunner.new()
	runner.run(func(): return true)  # 保活：让 ctx.runner 保持 is_running（ctx.active/clock 依赖）
	var ctx := StageContext.new(runner)
	ctx.stage = self   # 符卡练习 ctx 也要绑 StageRuntime：ctx.effects/refs 才能解析 Miss 层与自机
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
		player.ctx = p_ctx
		refs.bind_player(player)


func add_enemy_to_scene(node: Node2D) -> void:
	# 注入注册表：Enemy 在 _ready 自注册、Boss 在 start_boss 注册（都在 add_child 之后，故先给引用）
	if "registry" in node:
		node.registry = refs
	var parent: Node = null
	if is_instance_valid(world):
		parent = world
	else:
		parent = get_tree().root
	if parent:
		parent.add_child(node)
	else:
		node.queue_free()

## 关卡运行时：关卡生命周期 + 生成敌人 / Boss（World 下的场景节点）。
## StageManager autoload 已删除；本节点是关卡生命周期的唯一实现。
##
## [b]模型[/b][br]
## 组合根把本节点放进游戏场景，并注入 world / player / bullet_manager / ui_layer / 背景；
## load_stage 创建关卡协程，spawn_* 负责实体落地，finish_stage / stop_stage 收尾。
## [codeblock]
## load_stage(data) → 校验 → reset → 启动当前难度脚本（变体优先）+ 背景协程 → stage_started
## finish_stage()  → stage_cleared + all_enemies_defeated + 高分
## stop_stage()    → 停脚本 / 清实体 / 清弹（不发信号，拆场景用）
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 依赖由组合根注入，不按节点名 / 全树找 Player。[br]
## - stop_stage 是拆场景路径，不发 stage_cleared；正常收尾用 finish_stage。[br]
## - spawn_enemy_data 要求 ctx active + 行为脚本；spawn_enemy 是简化版（不挂脚本）。[br]
## - add_enemy_to_scene 只做注入 + 挂树，注册由实体自己完成。
class_name StageRuntime
extends Node

## 关卡成功启动后发。
signal stage_started()
## 正常收尾（finish_stage / 关卡脚本自然结束）后发；拆场景的 stop_stage 不发。
signal stage_cleared()
## 整关结束时与 stage_cleared 同时发；不要拿它当“场上敌人清空”的实时信号。
signal all_enemies_defeated()

## 敌人场景。
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
## 阶段参数校验脚本。
const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")


## 敌人生成 / 自机 ctx 注入的父节点（World；组合根注入）。
var world: Node2D
## 本关自机（组合根注入的显式引用；只认它，不按名字在 World 下找）。
var player: Player
## 战场实体注册表（自机 / 敌机 / Boss 的单一真源）。
var entity_registry := EntityRegistry.new()
## 弹幕世界（组合根注入；供关卡发弹 / 清弹）。
var bullet_manager: BulletManager
## Miss 圈层（组合根 / 工作台注入）。
var miss_layer: MissCircleLayer
## 特效池（组合根注入）。
var fx_pool: FxPool
## 道具池（组合根注入；消费端经 ctx.stage.item_pool）。
var item_pool: ItemPool
## Boss 位置指示器所属 HUD 层（组合根注入）。
var ui_layer: CanvasLayer
## 背景场景实例（组合根在 load_stage 前注入）。
var current_background: StageBackground
## 当前关卡数据；stop_stage 后为 null。
var current_stage: StageData
var _is_stage_active: bool = false
var _coroutine_script: CoroutineScript


## 获取当前关卡协程脚本（工作台/调试读取运行时间用）
func current_stage_script() -> CoroutineScript:
	return _coroutine_script


## 加载关卡：校验 → 重置资源（+ 关卡练习火力）→ 启动关卡脚本与背景协程 → stage_started。
## 背景实例由 current_background 注入；非法数据 push_error 并拒绝启动。
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
	# 关卡练习的起始火力：紧跟在复位之后（复位会把火力归 0；放别处会被这里冲掉）。
	# 非关卡练习 / 第 1 面 ⇒ 空跑。
	SaveData.apply_stage_practice_power(entity_registry)

	current_stage = data
	_is_stage_active = true

	var stage_script_resource: Script = data.script_for_difficulty(SaveData.selected_difficulty)
	if stage_script_resource == null:
		push_error("StageRuntime: 难度 %s 没有可用的关卡脚本" % Difficulty.display_name(SaveData.selected_difficulty))
		return
	var stage_script: CoroutineScript = stage_script_resource.new()
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


## 拆场景 / 中止：停脚本、清实体注册表、清弹幕（激光自行淡出）；不发 stage_cleared。
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


## 关卡正常收尾（StageDirector.finish_stage 的落点）：发 stage_cleared + all_enemies_defeated、
## 存高分，然后停掉 / 回收关卡脚本。
## 不能改用 stop_stage（它会先清 current_stage，导致不发信号），也不能靠 stop() 触发 finished。
func finish_stage() -> void:
	if not _is_stage_active:
		return
	_on_stage_finished()
	if _coroutine_script and is_instance_valid(_coroutine_script):
		_coroutine_script.stop()
		_coroutine_script.queue_free()
		_coroutine_script = null


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


## 从 EnemyData 生成敌人：实例化、挂行为协程、严格注入 params、入场景。
## 要求 ctx active + 行为脚本；配置非法 / 无 ctx 时返回 null。
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
	PARAM_VALIDATOR_SCRIPT.apply(cs, params, true)   # 严格：EnemyData.params 只灌一个行为脚本，未知键 = 打错
	if cs.has_method("setup_custom"):
		cs.setup_custom(params)
	enemy.add_child(cs)
	cs.start(p_ctx, enemy)
	add_enemy_to_scene(enemy)
	return enemy


## 简化生成：只实例化 Enemy + 设数据 / 位置 / 入场景，不挂行为协程。
func spawn_enemy(data: EnemyData, position: Vector2, auto_start: bool = true) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_data = data
	enemy.global_position = position
	add_enemy_to_scene(enemy)
	if auto_start:
		enemy.start.call_deferred()
	return enemy


## 生成 Boss：Boss.new + 外观场景 + 入场景 + setup + start_boss。
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


## 关卡 Logo：在 top_center 处淡入 → 停留 → 淡出，然后释放整层。
## 内容只给纹理与位置；tween / CanvasLayer 机制留在这里。
func show_logo(texture: Texture2D, top_center: Vector2, fade_in: float = 2.0,
		hold: float = 3.0, fade_out: float = 1.0) -> void:
	if texture == null:
		push_warning("StageRuntime.show_logo: texture 为 null，跳过")
		return
	var layer := CanvasLayer.new()
	layer.layer = 32
	layer.follow_viewport_enabled = true
	var logo := TextureRect.new()
	logo.texture = texture
	logo.global_position = top_center - Vector2(texture.get_size().x * 0.5, 0.0)
	logo.modulate.a = 0.0
	layer.add_child(logo)
	# 挂到本关协程脚本下：关卡停止时随它一起释放（与旧实现的生命周期一致）。
	var owner_node: Node = current_stage_script()
	if not is_instance_valid(owner_node):
		owner_node = self
	owner_node.add_child(layer)
	var tween := layer.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(logo, "modulate:a", 1.0, fade_in)
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(logo, "modulate:a", 0.0, fade_out)
	tween.tween_callback(layer.queue_free)


## 开一场仅单个阶段的战（符卡练习）：自建保活时钟作 ctx，生成 Boss 并直接进入该阶段。
## 与 load_stage（整关编排）不同，本方法只服务“点杀单阶段”，不复用整关脚本。
## 返回 Boss；Boss.ctx.runner 即本次时钟（可 stop / queue_free 清理）。
func start_spell_card(p_phase: PhaseData, boss_scene: PackedScene, boss_name: String, position: Vector2,
		p_data: BossData = null) -> Boss:
	var runner := CoroutineRunner.new()
	runner.run(func(): return true)  # 保活：让 ctx.runner 保持 is_running（ctx.active/clock 依赖）
	var ctx := StageContext.new(runner)
	ctx.stage = self   # 符卡练习 ctx 也要绑 StageRuntime：ctx.effects/entity_registry 才能解析 Miss 层与自机
	# 用真 BossData（调用方给）→ spell_background / portrait 等字段不会被丢掉；
	# 阶段表收敛成"就这一张卡"（练习是单阶段战）。没给则退回自建（工作台等场景）。
	var single: BossData
	if p_data != null:
		single = p_data.duplicate() as BossData
		single.phases_easy = [p_phase]
		single.phases_normal = [p_phase]
		single.phases_hard = [p_phase]
		single.phases_lunatic = [p_phase]
		single.phases_extra = [p_phase]
	else:
		single = BossData.new()
		single.boss_name = boss_name
		single.visual = boss_scene
		single.phases_normal = [p_phase]
	var boss := spawn_boss(single, position, ctx) as Boss
	if boss:
		boss.get_parent().add_child(runner)  # 把时钟放进场景树（Boss 所在 World），随场景一起释放
		boss.start_phase(p_phase)
	return boss


## 把关卡上下文注入给组合根注入的自机（供系统操作服务）；只认显式的 player 引用。
func _inject_player_ctx(p_ctx: StageContext) -> void:
	if not is_instance_valid(player):
		return
	player.bind_ctx(p_ctx)   # 把 stage 一并转发给射击 ctx
	entity_registry.bind_player(player)


## 把敌人 / Boss 挂进 World：先按类型注入注册表（Boss 还有 HUD 层），再 add_child。
## 无 world 时挂到场景根；两者都不可用则 queue_free。
func add_enemy_to_scene(node: Node2D) -> void:
	# 注入注册表：Enemy 在 _ready 自注册、Boss 在 start_boss 注册（都在 add_child 之后，故先给引用）。
	# 显式类型化接口：Enemy.set_registry / Boss.set_registry / Boss.set_ui_layer。
	var enemy := node as Enemy
	if enemy != null:
		enemy.set_registry(entity_registry)
	var boss := node as Boss
	if boss != null:
		boss.set_registry(entity_registry)
		boss.set_ui_layer(ui_layer)
	var parent: Node = null
	if is_instance_valid(world):
		parent = world
	else:
		parent = get_tree().root
	if parent:
		parent.add_child(node)
	else:
		node.queue_free()

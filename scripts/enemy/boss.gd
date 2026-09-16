# Boss.gd
class_name Boss
extends Area2D

const BOSS_HP_RING_SCRIPT = preload("res://scripts/scenes/boss_hp_ring.gd")
const POS_INDICATOR_TEX := preload("res://assets/Textures/front/boss_position.png")
const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")

## Boss 位置指示器距离淡出：离自机 x 越远越清晰（近处半透明，远处醒目）
const INDICATOR_FADE_NEAR := 60.0    ## |dx| ≤ 60px 时最淡
const INDICATOR_FADE_FAR := 400.0    ## |dx| ≥ 400px 时完全清晰（更早变亮）
const INDICATOR_ALPHA_NEAR := 0.25   ## 最近处透明度（半透明但可见）
const INDICATOR_FADE_POW := 0.5      ## 透明度缓动指数：<1 → 越近透明得越快（近处斜率陡）

signal phase_cleared(captured: bool, bonus: int)
signal display_name_changed(display_name: String)
signal name_visibility_changed(is_shown: bool)
signal phase_dots_visibility_changed(is_shown: bool)
signal hp_changed(hp: int, max_hp: int)

var _boss_data: BossData
var _display_name: String = ""   ## 运行时显示名覆盖（空 = 用 _boss_data.boss_name）
var _is_name_shown: bool = false  ## 名字节点是否可见（默认隐藏：只有关底 reveal / 手动 show 才显示）
var _is_phase_dots_shown: bool = false  ## 阶段进度点是否可见（默认隐藏，手动控制）
var _hp: int = 0
var _hitbox_radius: float

## 只读访问器：hp / boss_data / hitbox_radius 外部只读，改写只经本类方法（封装，防作弊/防割裂）
var boss_data: BossData:
	get: return _boss_data
var hp: int:
	get: return _hp
var hitbox_radius: float:
	get: return _hitbox_radius

var _stage_context: StageContext
## 战场实体注册表（StageRuntime 注入；直接实例化时为 null）——自机 / 资源 / 敌机登记
var registry
## HUD 层（StageRuntime 注入；工作台/测试可为 null）——位置指示器挂此
var ui_layer: CanvasLayer
var _phase_data: PhaseData
var _pos_indicator: Sprite2D  # Boss 位置指示器（x 跟随 Boss，y 固定游戏框底）
var _bonus: int = 0
var _elapsed: float = 0.0
var _is_invincible: bool = false
var _is_phase_missed: bool = false   # 本阶段内玩家是否 miss 过（东方规则：miss 即失败尝试、miss 后击破不算收取）
var _open_reduce_left: float = 0.0   # 开局减伤剩余时长（秒）
var _open_reduce_ratio: float = 0.0  # 开局减伤比例（0~1）
var _move_coroutine_runner: CoroutineRunner
var _shoot_coroutine_runner: CoroutineRunner
var _stage_id: int
var _phase_identity: PhaseIdentity
var _is_exit_controlled: bool = false
var _is_cleared: bool = false

func current_phase() -> PhaseData: return _phase_data

## 关卡上下文（含本次时钟 ctx.runner —— 练习/工作台清理用）。只读。
var ctx: StageContext:
	get: return _stage_context


## 战场实体注册表：优先注入的 `registry`，否则关卡 ctx 自带的
func _refs():
	if registry != null:
		return registry
	return _stage_context.entity_registry if _stage_context else null


## Boss 残血（供命中音效等）：血量 < 当前阶段满血的 45%，且非无敌/非时符
func is_low_hp() -> bool:
	if _is_invincible or not _phase_data or _phase_data.is_timeout_only:
		return false
	return _phase_data.hp > 0 and float(_hp) < _phase_data.hp * 0.45
func current_bonus() -> int: return _bonus
func get_elapsed() -> float: return _elapsed
func get_phase_id() -> PhaseIdentity: return _phase_identity


## 显示名：运行时覆盖优先，否则用 boss_data.boss_name（UI/外部系统只读这个）
func get_boss_name() -> String:
	return _display_name if _display_name != "" else (_boss_data.boss_name if _boss_data else "")


## 运行时改显示名（外部系统可调用 —— 揭示真名 / 练习显示卡名 等；改名会发 display_name_changed，BossUI 订阅同步）
func set_boss_name(n: String) -> void:
	if _display_name == n:
		return
	_display_name = n
	display_name_changed.emit(get_boss_name())   # 用有效名：清空覆盖时回退 boss_data.boss_name


## 名字节点是否可见（BossUI 订阅）——默认 false：只在关底 reveal（或手动 show_name）时出现。
func is_name_shown() -> bool:
	return _is_name_shown


## 手动开关名字节点（默认隐藏；只切可见性，不改名）。
func set_name_shown(v: bool) -> void:
	if _is_name_shown == v:
		return
	_is_name_shown = v
	name_visibility_changed.emit(v)


## 阶段进度点（BossUI 的 History 行）是否可见 —— 默认 false，手动控制。
func is_phase_dots_shown() -> bool:
	return _is_phase_dots_shown


## 手动开关阶段进度点（默认隐藏）。
func set_phase_dots_shown(v: bool) -> void:
	if _is_phase_dots_shown == v:
		return
	_is_phase_dots_shown = v
	phase_dots_visibility_changed.emit(v)
func is_in_gap() -> bool:
	return _is_cleared


## 是否已进入战斗、可作为自机弹的目标。对话 / 进场期间（还没 start_phase）为 false ——
## 自机诱导弹（steer 最近敌）因此不会追一位还没开打的 Boss。
func is_targetable() -> bool:
	return _phase_data != null

func set_exit_controlled() -> void:
	_is_exit_controlled = true


func setup(data: BossData, p_ctx: StageContext = null) -> void:
	_boss_data = data
	_stage_context = p_ctx
	z_index = LayerConfig.BOSS
	if not GameEvents.player_missed.is_connected(_on_player_death):
		GameEvents.player_missed.connect(_on_player_death)

	if PracticeSession.is_practice_mode:
		_stage_id = PracticeSession.stage_id
	else:
		_stage_id = SaveData.current_stage_id

	var ring := BOSS_HP_RING_SCRIPT.new()
	ring.setup(self)
	add_child(ring)

	_hitbox_radius = data.hitbox_radius
	var shape := CircleShape2D.new()
	shape.radius = _hitbox_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)

	collision_layer = 0
	collision_mask = 0

	_set_ring_visible(false)

func start_boss() -> void:
	set_process(true)
	if registry != null:
		registry.register_enemy(self)
		tree_exited.connect(func():
			if registry != null:
				registry.unregister_enemy(self))
	tree_exited.connect(_free_pos_indicator)
	GameEvents.boss_spawned.emit(self)
	collision_layer = 4
	collision_mask = 2
	_create_pos_indicator()


## 创建 Boss 位置指示器：挂 UI 层（CanvasLayer 32，层级高于所有游戏元素），
## x 跟随 Boss，y 在游戏框底线之下（完全在框外）
func _create_pos_indicator() -> void:
	if _pos_indicator:
		return
	var ui: CanvasLayer = ui_layer
	if ui == null:
		return  # 无 UI 层注入（工作台/测试）不显示指示器
	var spr := Sprite2D.new()
	spr.name = "PosIndicator"
	spr.texture = POS_INDICATOR_TEX
	spr.z_index = LayerConfig.UI_TOP
	# 完全在游戏框外：贴图整体在 FIELD_BOTTOM 之下（上边缘贴框底线）
	spr.position = Vector2(global_position.x, GameConfig.FIELD_BOTTOM + POS_INDICATOR_TEX.get_height() / 2.0)
	ui.add_child(spr)
	_pos_indicator = spr


func _free_pos_indicator() -> void:
	if _pos_indicator and is_instance_valid(_pos_indicator):
		_pos_indicator.queue_free()
	_pos_indicator = null


## 指示器透明度随 |boss.x - 自机.x| 变化：越远越清晰
func _update_indicator_alpha() -> void:
	var r = _refs()
	var raw = r.player if r else null
	var player: Player = raw if is_instance_valid(raw) else null
	if player == null or not is_instance_valid(player):
		_pos_indicator.modulate.a = 1.0
		return
	var dx := absf(global_position.x - player.global_position.x)
	var t := clampf((dx - INDICATOR_FADE_NEAR) / maxf(INDICATOR_FADE_FAR - INDICATOR_FADE_NEAR, 1.0), 0.0, 1.0)
	# 缓动：pow<1 → 低 t 区间（Boss 靠近）斜率陡，透明得越快；远处保持清晰
	t = pow(t, INDICATOR_FADE_POW)
	_pos_indicator.modulate.a = lerpf(INDICATOR_ALPHA_NEAR, 1.0, t)


func start_phase(data: PhaseData) -> void:
	# 配置校验：time_limit<=0 会除零/立即超时，防御性拒绝
	for e in data.validate():
		push_error("Boss.start_phase 配置错误: " + e)
	_is_cleared = false
	_is_phase_missed = false  # 每阶段独立判定 miss
	_phase_data = data
	_elapsed = 0.0
	_bonus = data.bonus
	_is_invincible = true
	_set_hp(0)
	# 开局减伤参数暂存，计时从"无敌解除"（涨血完，玩家能打伤）开始
	_open_reduce_ratio = data.open_reduce_ratio
	_open_reduce_left = 0.0

	# 显示血条
	_set_ring_visible(true)

	_phase_identity = BossCatalog.resolve_identity(_stage_id, data, PracticeSession.phase_index if PracticeSession.is_practice_mode else -1)   # 身份统一由目录解析（练习用记录键兜底）
	if _phase_identity:
		RecordService.record_phase_start(_phase_identity)   # 记录服务：解锁/记尝试（Boss 不再摸 SaveData.record_*）

	if data.name != "":
		GameEvents.phase_start.emit(data)

	# HP 从 0 涨到满
	var twn := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	twn.tween_method(_set_hp, 0, data.hp, 1.0)
	twn.tween_callback(func():
		if data.is_timeout_only:
			_is_invincible = true
			_set_hp(999999)
		else:
			_is_invincible = false
			# 玩家能打伤时才开始减伤计时（完整 open_reduce_time 秒）
			_open_reduce_left = data.open_reduce_time if _open_reduce_ratio > 0.0 else 0.0

		if data.move_script:
			_move_coroutine_runner = data.move_script.new()
			add_child(_move_coroutine_runner)
			_apply_phase_params(_move_coroutine_runner, data.params)
			_move_coroutine_runner.start(_stage_context, self)
		if data.shoot_script:
			_shoot_coroutine_runner = data.shoot_script.new()
			add_child(_shoot_coroutine_runner)
			_apply_phase_params(_shoot_coroutine_runner, data.params)
			_shoot_coroutine_runner.start(_stage_context, self)
	)


func _process(delta: float) -> void:
	# Boss 位置指示器：x 始终跟随 Boss，y 固定游戏框底（在 phase 开始前也显示）
	if _pos_indicator and is_instance_valid(_pos_indicator):
		_pos_indicator.global_position.x = global_position.x
		_update_indicator_alpha()
	if not _phase_data: return
	_elapsed += delta

	if _bonus > 0:
		# maxf 防御：time_limit 非法为 0 时优雅降级（正常配置由 validate 拦截）
		var t := maxf(_phase_data.time_limit, 0.001)
		var tick := maxi(1, int(float(_phase_data.bonus) / t * delta))
		_bonus = maxi(0, _bonus - tick)

	GameEvents.phase_bonus_tick.emit(_bonus)

	if _open_reduce_left > 0.0:
		_open_reduce_left = maxf(_open_reduce_left - delta, 0.0)

	if _elapsed >= _phase_data.time_limit:
		clear_phase(_phase_data.is_timeout_only)


## 小数伤害累积器（0.5×2 次 = 1 → 扣 1 血）
var _dmg_acc: float = 0.0

func take_damage(damage: float) -> void:
	if _is_invincible: return
	if not _phase_data: return
	if _open_reduce_left > 0.0 and _open_reduce_ratio > 0.0:
		damage *= 1.0 - _open_reduce_ratio  # 开局减伤
	_dmg_acc += damage
	var full: int = int(_dmg_acc)
	if full <= 0:
		return
	_dmg_acc -= full
	_set_hp(_hp - full)
	if _hp <= 0 and not _phase_data.is_timeout_only:
		clear_phase(true)


## 玩家 miss（正篇）：只标记——东方规则：miss 后击破不算收取（尝试次数已在进入阶段时记过）
func _on_player_death() -> void:
	if PracticeSession.is_practice_mode:
		return  # 练习 miss 走 _die 逻辑
	if not _phase_data or _is_cleared or _is_phase_missed:
		return
	_is_phase_missed = true


func clear_phase(captured: bool) -> void:
	if _is_cleared: return
	_is_cleared = true
	_is_invincible = true
	if _move_coroutine_runner: _move_coroutine_runner.stop(); _move_coroutine_runner.queue_free(); _move_coroutine_runner = null
	if _shoot_coroutine_runner: _shoot_coroutine_runner.stop(); _shoot_coroutine_runner.queue_free(); _shoot_coroutine_runner = null

	if _phase_identity:
		# 阶段已开始（_phase_identity 已生成）才记录；Ctrl+G 在阶段开始前触发时只跳阶段不落盘
		if PracticeSession.is_practice_mode:
			RecordService.record_phase_capture(_phase_identity, false, 0, 0.0)  # 练习收取
		elif captured and not _is_phase_missed:
			RecordService.record_phase_capture(_phase_identity, true, _bonus, _elapsed)  # 干净收取

	GameEvents.phase_end.emit(captured, _bonus)
	if captured and _bonus > 0:
		var r = _refs()
		var res: PlayerResources = r.get_player_resources() if r else null
		if res != null:
			res.add_score(_bonus)

	_drop_items()
	if _stage_context:
		_stage_context.bullets.death_clear(global_position, 960, 0.75, 30)
	phase_cleared.emit(captured, _bonus)


## 外部受控死亡（练习模式等场景调用）
func die() -> void:
	_die()


func _die() -> void:
	# 注意：不停 _process——指示器 x 跟随在其中，死后离场演出期间仍需跟随 Boss
	# （阶段逻辑由 _process 开头的 `if not _phase_data: return` 自然跳过）
	_phase_data = null
	_set_ring_visible(false)
	if PracticeSession.is_practice_mode and _phase_identity and not _is_cleared:
		pass  # 练习 attempt 已在进入阶段时记过（玩家 miss/超时退出也覆盖），这里不再重复记
	if registry != null:
		registry.unregister_enemy(self)
	GameEvents.boss_defeated.emit(self)
	if not _is_exit_controlled:
		queue_free()

## 血量改写唯一入口（封装）：改 _hp 并发 hp_changed 供 UI 订阅
func _set_hp(v) -> void:
	_hp = int(v)
	hp_changed.emit(_hp, _phase_data.hp if _phase_data else 0)

## 血条显隐（统一）
func _set_ring_visible(v: bool) -> void:
	for child in get_children():
		if child.get_script() == BOSS_HP_RING_SCRIPT:
			child.visible = v
			break


func _drop_items() -> void:
	if not _phase_data: return
	if PracticeSession.is_practice_mode: return
	var pos := global_position
	var phase := _phase_data
	var scatter := 50.0

	var drops: Array[int] = []
	for _i in range(phase.item_power): drops.append(Item.Type.POWER)
	for _i in range(phase.item_point): drops.append(Item.Type.POINT)
	for _i in range(phase.item_life): drops.append(Item.Type.LIFE_FRAGMENT)
	for _i in range(phase.item_bomb): drops.append(Item.Type.BOMB_FRAGMENT)
	for _i in range(phase.item_life_full): drops.append(Item.Type.LIFE_FULL)
	for _i in range(phase.item_bomb_full): drops.append(Item.Type.BOMB_FULL)

	for t in drops:
		var offset := Vector2(RNG.randf_range(-scatter, scatter), RNG.randf_range(-scatter, scatter))
		if _stage_context: _stage_context.spawn_item(t, pos + offset)


## 阶段脚本参数注入（工作台编辑的 PhaseData.params → 脚本同名属性）
## 注意：这里只有参数注入，掉落逻辑在 _drop_items（clear_phase 击破时）——
## 曾经残留过一份掉落代码导致 start_phase 时误掉道具（已删，勿再贴回）
func _apply_phase_params(script: Node, params: Dictionary) -> void:
	PARAM_VALIDATOR_SCRIPT.apply(script, params)   # 校验 + 只设合法键 + 打错键名/类型响亮报错

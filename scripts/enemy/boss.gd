# Boss.gd
class_name Boss
extends Area2D

const HPRingClass = preload("res://scripts/scenes/boss_hp_ring.gd")
const POS_INDICATOR_TEX := preload("res://assets/Textures/front/boss_position.png")
const RecordService = preload("res://scripts/coroutine/services/record_service.gd")   # 记录服务（显式 preload，不依赖全局类缓存）

## Boss 位置指示器距离淡出：离自机 x 越远越清晰（近处半透明，远处醒目）
const INDICATOR_FADE_NEAR := 60.0    ## |dx| ≤ 60px 时最淡
const INDICATOR_FADE_FAR := 400.0    ## |dx| ≥ 400px 时完全清晰（更早变亮）
const INDICATOR_ALPHA_NEAR := 0.25   ## 最近处透明度（半透明但可见）
const INDICATOR_FADE_POW := 0.5      ## 透明度缓动指数：<1 → 越近透明得越快（近处斜率陡）

signal phase_cleared(captured: bool, bonus: int)
signal display_name_changed(name: String)

var boss_data: BossData
var _display_name: String = ""   ## 运行时显示名覆盖（空 = 用 boss_data.boss_name）
var hp: int = 0
var hitbox_radius: float

var _ctx: StageContext
var _current_phase: PhaseData
var _pos_indicator: Sprite2D  # Boss 位置指示器（x 跟随 Boss，y 固定游戏框底）
var _bonus: int = 0
var _elapsed: float = 0.0
var _invincible: bool = false
var _phase_missed: bool = false   # 本阶段内玩家是否 miss 过（东方规则：miss 即失败尝试、miss 后击破不算收取）
var _open_reduce_left: float = 0.0   # 开局减伤剩余时长（秒）
var _open_reduce_ratio: float = 0.0  # 开局减伤比例（0~1）
var _move: CoroutineRunner
var _shoot: CoroutineRunner
var _stage_id: int
var _pid: PhaseIdentity
var _exit_controlled: bool = false
var _cleared: bool = false

func current_phase() -> PhaseData: return _current_phase

## 关卡上下文（含本次时钟 ctx.runner —— 练习/工作台清理用）。只读。
var ctx: StageContext:
	get: return _ctx


## Boss 残血（供命中音效等）：血量 < 当前阶段满血的 45%，且非无敌/非时符
func is_low_hp() -> bool:
	if _invincible or not _current_phase or _current_phase.is_timeout_only:
		return false
	return _current_phase.hp > 0 and float(hp) < _current_phase.hp * 0.45
func current_bonus() -> int: return _bonus
func get_elapsed() -> float: return _elapsed
func get_phase_id() -> PhaseIdentity: return _pid


## 显示名：运行时覆盖优先，否则用 boss_data.boss_name（UI/外部系统只读这个）
func get_boss_name() -> String:
	return _display_name if _display_name != "" else (boss_data.boss_name if boss_data else "")


## 运行时改显示名（外部系统可调用 —— 揭示真名 / 练习显示卡名 等；改名会发 display_name_changed，BossUI 订阅同步）
func set_boss_name(n: String) -> void:
	if _display_name == n:
		return
	_display_name = n
	display_name_changed.emit(get_boss_name())   # 用有效名：清空覆盖时回退 boss_data.boss_name
func is_in_gap() -> bool:
	return _cleared

func set_exit_controlled() -> void:
	_exit_controlled = true


func setup(data: BossData, p_ctx: StageContext = null) -> void:
	boss_data = data
	_ctx = p_ctx
	z_index = LayerConfig.BOSS
	if not GameEvents.player_missed.is_connected(_on_player_death):
		GameEvents.player_missed.connect(_on_player_death)
	
	if GameState.is_practice_mode:
		_stage_id = GameState.practice_stage_id
	else:
		_stage_id = GameState.current_stage_id
	
	var ring := HPRingClass.new()
	ring.setup(self)
	add_child(ring)
	
	hitbox_radius = data.hitbox_radius
	var shape := CircleShape2D.new()
	shape.radius = hitbox_radius
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	
	collision_layer = 0
	collision_mask = 0

	for child in get_children():
		if child.get_script() == HPRingClass:
			child.visible = false
			break

func start_boss() -> void:
	set_process(true)
	GameState.active_enemies.append(self)
	tree_exited.connect(func(): GameState.active_enemies.erase(self))
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
	var scene := get_tree().current_scene
	var ui: CanvasLayer = scene.get_node_or_null("UI") if scene else null
	if ui == null:
		ui = get_tree().root.find_child("UI", true, false) as CanvasLayer
	if ui == null:
		return  # 无 UI 层的场景（工作台等）不显示指示器
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
	var player: Player = GameState.player
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
	_cleared = false
	_phase_missed = false  # 每阶段独立判定 miss
	_current_phase = data
	_elapsed = 0.0
	_bonus = data.bonus
	_invincible = true
	hp = 0
	# 开局减伤参数暂存，计时从"无敌解除"（涨血完，玩家能打伤）开始
	_open_reduce_ratio = data.open_reduce_ratio
	_open_reduce_left = 0.0
	
	# 显示血条
	for child in get_children():
		if child.get_script() == HPRingClass:
			child.visible = true
			break
	
	_pid = BossCatalog.resolve_identity(_stage_id, data, GameState.practice_phase_index if GameState.is_practice_mode else -1)   # 身份统一由目录解析（练习用记录键兜底）
	if _pid:
		RecordService.record_phase_start(_pid)   # 记录服务：解锁/记尝试（Boss 不再摸 GameState.record_*）
	
	if data.name != "":
		GameEvents.phase_start.emit(data)
	
	# HP 从 0 涨到满
	var twn := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	twn.tween_property(self, "hp", data.hp, 1.0)
	twn.tween_callback(func():
		if data.is_timeout_only:
			_invincible = true
			hp = 999999
		else:
			_invincible = false
			# 玩家能打伤时才开始减伤计时（完整 open_reduce_time 秒）
			_open_reduce_left = data.open_reduce_time if _open_reduce_ratio > 0.0 else 0.0
		
		if data.move_script:
			_move = data.move_script.new()
			add_child(_move)
			_apply_phase_params(_move, data.params)
			_move.start(_ctx, self)
		if data.shoot_script:
			_shoot = data.shoot_script.new()
			add_child(_shoot)
			_apply_phase_params(_shoot, data.params)
			_shoot.start(_ctx, self)
	)


func _process(delta: float) -> void:
	# Boss 位置指示器：x 始终跟随 Boss，y 固定游戏框底（在 phase 开始前也显示）
	if _pos_indicator and is_instance_valid(_pos_indicator):
		_pos_indicator.global_position.x = global_position.x
		_update_indicator_alpha()
	if not _current_phase: return
	_elapsed += delta
	
	if _bonus > 0:
		# maxf 防御：time_limit 非法为 0 时优雅降级（正常配置由 validate 拦截）
		var t := maxf(_current_phase.time_limit, 0.001)
		var tick := maxi(1, int(float(_current_phase.bonus) / t * delta))
		_bonus = maxi(0, _bonus - tick)
	
	GameEvents.phase_bonus_tick.emit(_bonus)

	if _open_reduce_left > 0.0:
		_open_reduce_left = maxf(_open_reduce_left - delta, 0.0)

	if _elapsed >= _current_phase.time_limit:
		_clear_phase(_current_phase.is_timeout_only)


## 小数伤害累积器（0.5×2 次 = 1 → 扣 1 血）
var _dmg_acc: float = 0.0

func take_damage(damage: float) -> void:
	if _invincible: return
	if not _current_phase: return
	if _open_reduce_left > 0.0 and _open_reduce_ratio > 0.0:
		damage *= 1.0 - _open_reduce_ratio  # 开局减伤
	_dmg_acc += damage
	var full: int = int(_dmg_acc)
	if full <= 0:
		return
	_dmg_acc -= full
	hp -= full
	if hp <= 0 and not _current_phase.is_timeout_only:
		_clear_phase(true)


## 玩家 miss（正篇）：只标记——东方规则：miss 后击破不算收取（尝试次数已在进入阶段时记过）
func _on_player_death() -> void:
	if GameState.is_practice_mode:
		return  # 练习 miss 走 _die 逻辑
	if not _current_phase or _cleared or _phase_missed:
		return
	_phase_missed = true


func _clear_phase(captured: bool) -> void:
	if _cleared: return
	_cleared = true
	_invincible = true
	if _move: _move.stop(); _move.queue_free(); _move = null
	if _shoot: _shoot.stop(); _shoot.queue_free(); _shoot = null
	
	if _pid:
		# 阶段已开始（_pid 已生成）才记录；Ctrl+G 在阶段开始前触发时只跳阶段不落盘
		if GameState.is_practice_mode:
			RecordService.record_phase_capture(_pid, false, 0, 0.0)  # 练习收取
		elif captured and not _phase_missed:
			RecordService.record_phase_capture(_pid, true, _bonus, _elapsed)  # 干净收取
	
	GameEvents.phase_end.emit(captured, _bonus)
	if captured and _bonus > 0:
		GameState.add_score(_bonus)
	
	_drop_items()
	if _ctx:
		_ctx.bullets.death_clear(global_position, 960, 0.75, 30)
	else:
		BulletManager.start_death_clear(global_position, 960, 0.75, 30)
	phase_cleared.emit(captured, _bonus)


## 外部受控死亡（练习模式等场景调用）
func die() -> void:
	_die()


func _die() -> void:
	# 注意：不停 _process——指示器 x 跟随在其中，死后离场演出期间仍需跟随 Boss
	# （阶段逻辑由 _process 开头的 `if not _current_phase: return` 自然跳过）
	_current_phase = null
	if GameState.is_practice_mode and _pid and not _cleared:
		pass  # 练习 attempt 已在进入阶段时记过（玩家 miss/超时退出也覆盖），这里不再重复记
	GameState.active_enemies.erase(self)
	GameEvents.boss_defeated.emit(self)
	if not _exit_controlled:
		queue_free()


func _drop_items() -> void:
	if not _current_phase: return
	if GameState.is_practice_mode: return
	var pos := global_position
	var phase := _current_phase
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
		if _ctx: _ctx.spawn_item(t, pos + offset)


## 阶段脚本参数注入（工作台编辑的 PhaseData.params → 脚本同名属性）
## 注意：这里只有参数注入，掉落逻辑在 _drop_items（_clear_phase 击破时）——
## 曾经残留过一份掉落代码导致 start_phase 时误掉道具（已删，勿再贴回）
func _apply_phase_params(script: Node, params: Dictionary) -> void:
	for k in params:
		if k in script:  # 脚本有该属性才设置（避免乱设）
			script.set(k, params[k])

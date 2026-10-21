## 掉落物：P 点 / 点 / 命碎片 / 雷碎片 / 整命 / 整雷。
## Area2D，池化于 ItemPool；自行下落 / 吸附 / 收取，收完回收。
##
## [b]模型[/b][br]
## ItemPool.spawn() 调 [method setup]（上抛初速）→ 重力下落；
## 靠近自机或过收点线 → 吸附；碰到自机 → [method collect] 改 PlayerResources → 回收。
## [br]
## [b]边界[/b][br]
## - 金色只对 POINT 生效：过收点线 / 强收拿满 max_point；P 点、碎片、整命整雷不吃这套。[br]
## - 非金色 POINT 按拾取高度在 max_point 与 MIN_POINT_SCORE 之间线性递减。[br]
## - [method burst] 宽限内不重力 / 不吸附 / 碰到不收；宽限结束径向速度清零，竖直下落。[br]
## - [method collect] 只生效一次（重复调用无效）。
class_name Item
extends Area2D

## 道具类型。
enum Type {
	## P 点：火力 +1、分数 +POWER_SCORE。
	POWER,
	## 点：按 max_point / 拾取高度给分；过收点线为金色。
	POINT,
	## 命碎片：满 5 合 1 命。
	LIFE_FRAGMENT,
	## 雷碎片：满 5 合 1 雷。
	BOMB_FRAGMENT,
	## 整命：直接 +1 命。
	LIFE_FULL,
	## 整雷：直接 +1 雷。
	BOMB_FULL,
}

## P 点吃下给的分（东方规则：+1 火力并 +10 分）。
const POWER_SCORE: int = 10
## 非金色点的最低分（越靠近框底越接近它；收点线附近 = max_point）。
const MIN_POINT_SCORE: int = 5000
## 拿到完整残机时的回报音 key（AssetRegistry.sounds）：第 5 片碎片合成 / 整命道具。
## 只在真的多了一条命时播（8 命上限不播）。
const EXTEND_SFX := &"get_player"

## 道具类型；由 [method setup] 设置。
var item_type: Type = Type.POINT
## 吃下时给的分数（POWER 用；POINT 的分是动态 max_point，不吃这个字段）。
var value: int = 0
## 实体注册表（ItemPool 注入）——取自机与单局资源。
var entity_registry: EntityRegistry
## 碰到自机收取的判定半径（像素）；_ready 写进 CircleShape2D。
var collect_radius: float = 32.0

## 靠近自机自动吸附的半径（像素）；focus 时 ×1.5。
## burst() 的爆发半径必须大于它，否则弧向飞行一结束就被吸走、没有“下落”那一段。
const PROXIMITY_RANGE: float = 128.0

var _velocity: Vector2
var _gravity: float = 240.0
var _max_fall_speed: float = 180.0
var _collect_speed: float = 800.0
var _auto_collect: bool = false
## 收取是否该金色：过收点线 / 强收（靠近吸附不算）；只对 POINT 生效。
var _is_highlight: bool = false
## 爆发宽限（秒）：> 0 时只按 _velocity 径向飞，不落重力 / 不吸附 / 碰到不收。
## 到 0 后立刻恢复吸附 + 重力 + 碰到收。
var _collect_grace: float = 0.0
var _auto_collect_line: float = 256.0
var _proximity_range: float = PROXIMITY_RANGE  # 靠近自机即吸
var _is_dead: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	z_index = LayerConfig.ITEM
	area_entered.connect(_on_area_entered)
	if _collision and _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = collect_radius


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if _collect_grace > 0.0:
		# 阶段 1 · 弧向飞：只按初速径向飞（不落重力、不吸附），弧形才看得见
		_collect_grace = maxf(_collect_grace - delta, 0.0)
		if _collect_grace > 0.0:
			global_position += _velocity * delta
		else:
			# 阶段 2 · 交还常规物理：清掉径向初速 → 之后只受重力 = 竖直下落
			# （横向不再飘；下落途中回到吸附范围/收点线时才被正常收走）
			_velocity = Vector2.ZERO
			_tick_collect_or_fall(delta)
	else:
		_tick_collect_or_fall(delta)

	# 出屏回收
	if global_position.y > GameConfig.VIEW_HEIGHT:
		_is_dead = true
		set_physics_process(false)
		_recycle()


## 正常状态：过收点线 / 靠近自机 → 吸附；否则重力下落。宽限期结束后走这里。
func _tick_collect_or_fall(delta: float) -> void:
	var player: Node2D = entity_registry.player if entity_registry else null
	var to_player: Vector2 = player.global_position - global_position if player and is_instance_valid(player) else Vector2.ZERO

	# 自动吸附两起因：过收点线（金色）/ 靠近自机（白色；focus 时范围翻倍）
	if player and is_instance_valid(player):
		var prox: float = _proximity_range * 1.5 if player.is_focused else _proximity_range
		if player.global_position.y < _auto_collect_line:
			_auto_collect = true
			_mark_highlight()
		elif to_player.length() < prox:
			_auto_collect = true

	if _auto_collect and player and is_instance_valid(player):
		var dir: Vector2 = to_player.normalized()
		global_position += dir * _collect_speed * delta
		# 近距离保险：飞过头也能吃到
		if to_player.length() < 8.0:
			collect()
			return
	else:
		# 重力 + 终端速度
		_velocity.y = min(_velocity.y + _gravity * delta, _max_fall_speed)
		global_position += _velocity * delta


## 池化初始化：设类型 / 位置 / 上抛初速，清掉上一轮的金色与爆发宽限，按类型换贴图。
## 由 [code]ItemPool.spawn()[/code] 调用。
func setup(type: Type, pos: Vector2) -> void:
	_is_dead = false
	item_type = type
	value = POWER_SCORE if type == Type.POWER else 0
	global_position = pos
	_velocity = Vector2(0, -180)  # 上抛初速
	_auto_collect = false
	_is_highlight = false   # 池复用：必须清掉上一轮的金色标记
	_collect_grace = 0.0    # 池复用：必须清掉上一轮的爆发宽限（否则复用后白飞一段）

	match type:
		Type.POWER:
			_sprite.texture = preload("res://assets/Textures/item/power.png")
		Type.POINT:
			_sprite.texture = preload("res://assets/Textures/item/point.png")
		Type.LIFE_FRAGMENT:
			_sprite.texture = preload("res://assets/Textures/item/life_part.png")
		Type.BOMB_FRAGMENT:
			_sprite.texture = preload("res://assets/Textures/item/spell_part.png")
		Type.LIFE_FULL:
			_sprite.texture = preload("res://assets/Textures/item/life_full.png")
		Type.BOMB_FULL:
			_sprite.texture = preload("res://assets/Textures/item/spell_full.png")
	_sprite.modulate = Color.WHITE


## 标记为金色收取：只有 POINT 有金色，过收点线 / 强收拿满 max_point 并弹金色浮字。
## P 点、碎片、整命整雷不吃这套。
func _mark_highlight() -> void:
	if item_type == Type.POINT:
		_is_highlight = true


## 强制收取（记忆释放技能 / 它炸出的道具）；金色仍只对 POINT 生效。
func force_collect() -> void:
	_auto_collect = true
	_mark_highlight()


## 爆发初速：沿 direction 以 speed 飞 grace 秒（期间不吸附 / 不受重力 / 碰到不收）。
## 用来在自机处一次撒出一圈 / 一弧道具（[code]ItemService.spawn_fan()[/code]）。
## 宽限结束的那一刻径向初速归零 → 接着只受重力，竖直下落。
func burst(direction: Vector2, speed: float, grace: float) -> void:
	_velocity = direction.normalized() * speed
	_collect_grace = maxf(grace, 0.0)


## 收取一次：按类型改 PlayerResources、播 item 音 / 弹分数浮字，然后回收。
## 已收取的道具重复调用无效。
func collect() -> void:
	if _is_dead:
		return
	_is_dead = true
	AudioManager.play_sfx(AssetRegistry.sounds["item"])
	visible = false
	set_physics_process(false)
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	# 本次吃到的分（P 点 = value，点 = 当前 max_point）；>0 才弹浮字。
	var gained := 0
	# 本次是否真的多了一条命（碎片集满 5 片 / 整命道具且未到 8 命上限）
	var got_life := false
	if res != null:
		match item_type:
			Type.POWER:
				res.add_power(1)
				gained = value
				res.add_score(gained)
			Type.POINT:
				var pts := res.max_point
				gained = res.add_max_point(pts if _is_highlight else _point_score_at(pts))
			Type.LIFE_FRAGMENT:
				got_life = res.collect_life_fragment()
			Type.BOMB_FRAGMENT:
				res.collect_bomb_fragment()
			Type.LIFE_FULL:
				got_life = res.collect_life_full()
			Type.BOMB_FULL:
				res.collect_bomb_full()
	# 拿到完整残机 = 里程碑事件，单独给一声（与上面那声 item 不冲突：两道不同的流）
	if got_life:
		AudioManager.play_sfx(AssetRegistry.sounds[EXTEND_SFX])
	if gained > 0:
		GameEvents.item_score.emit(gained, global_position, _is_highlight)
	_recycle()


## 非金色的点：拾取点越远离收点线（越靠近框底）分越少。
## 收点线处 = max_point，框底 = MIN_POINT_SCORE（max_point 恒 >= 10000 > 5000）。
func _point_score_at(pts: int) -> int:
	var span: float = GameConfig.FIELD_BOTTOM - _auto_collect_line
	if span <= 0.0:
		return pts
	var t: float = clampf((global_position.y - _auto_collect_line) / span, 0.0, 1.0)
	return roundi(lerpf(float(pts), float(MIN_POINT_SCORE), t))


func _on_area_entered(area: Area2D) -> void:
	if _is_dead or _collect_grace > 0.0:
		return  # 宽限内不因"贴着自机"被收走（否则在自机处撒的点当帧就没了）
	if area is Player:
		collect()


func _recycle() -> void:
	var pool: ItemPool = get_parent() as ItemPool
	if pool:
		pool.recycle(self)

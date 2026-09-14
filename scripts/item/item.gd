class_name Item
extends Area2D

enum Type { POWER, POINT, LIFE_FRAGMENT, BOMB_FRAGMENT, LIFE_FULL, BOMB_FULL }

var item_type: Type = Type.POINT
var value: int = 100
## 实体注册表（ItemPool 注入）——取自机与单局资源
var entity_registry: EntityRegistry
## 吸附半径（像素）
var collect_radius: float = 32.0

var _velocity: Vector2
var _gravity: float = 240.0
var _max_fall_speed: float = 180.0
var _collect_speed: float = 800.0
var _auto_collect: bool = false
var _auto_collect_line: float = 256.0
var _proximity_range: float = 128.0  # 靠近自机即吸
var _dead: bool = false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	z_index = LayerConfig.ITEM
	area_entered.connect(_on_area_entered)
	if _collision and _collision.shape is CircleShape2D:
		(_collision.shape as CircleShape2D).radius = collect_radius


func _physics_process(delta: float) -> void:
	if _dead:
		return

	var player: Node2D = entity_registry.player if entity_registry else null
	var to_player: Vector2 = player.global_position - global_position if player and is_instance_valid(player) else Vector2.ZERO

	# 玩家过收点线 或 靠近自机 → 自动吸附（focus 时范围翻倍）
	if player and is_instance_valid(player):
		var prox: float = _proximity_range * 1.5 if player.is_focused else _proximity_range
		if player.global_position.y < _auto_collect_line or to_player.length() < prox:
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

	# 出屏回收
	if global_position.y > GameConfig.VIEW_HEIGHT:
		_dead = true
		set_physics_process(false)
		_recycle()


func setup(type: Type, pos: Vector2) -> void:
	_dead = false
	item_type = type
	global_position = pos
	_velocity = Vector2(0, -180)  # 上抛初速
	_auto_collect = false

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


func force_collect() -> void:
	_auto_collect = true


func collect() -> void:
	if _dead:
		return
	_dead = true
	AudioManager.play_sfx(AssetRegistry.sounds["item"], -6.0)
	visible = false
	set_physics_process(false)
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if res != null:
		match item_type:
			Type.POWER:
				res.add_power(1)
			Type.POINT:
				res.add_max_point()
			Type.LIFE_FRAGMENT:
				res.collect_life_fragment()
			Type.BOMB_FRAGMENT:
				res.collect_bomb_fragment()
			Type.LIFE_FULL:
				res.collect_life_full()
			Type.BOMB_FULL:
				res.collect_bomb_full()
	_recycle()


func _on_area_entered(area: Area2D) -> void:
	if _dead:
		return
	if area is Player:
		collect()


func _recycle() -> void:
	var pool: Node = get_parent()
	if pool and pool.has_method("recycle"):
		pool.recycle(self)

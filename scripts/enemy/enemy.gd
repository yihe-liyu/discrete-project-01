# Enemy.gd
extends Area2D
class_name Enemy

## 敌人配置数据（生命、判定、弹幕模式等）
var enemy_data: EnemyData

## 运行时上下文（EnemyData.spawn 注入，用于走服务而非全局）
var ctx: StageContext

var _visual: Node2D          # 外观实例（可能不是 AnimatedSprite2D）
var max_hp: int
var hitbox_radius: float
var score_value: int
var death_effect: PackedScene
var hp: int

var _last_pos: Vector2


func _ready():
	z_index = LayerConfig.ENEMY
	z_as_relative = false
	if enemy_data: _apply_enemy_data(enemy_data)
	_last_pos = global_position
	
	GameState.active_enemies.append(self)
	if not tree_exited.is_connected(_on_tree_exited):
		tree_exited.connect(_on_tree_exited)


func _on_tree_exited():
	GameState.active_enemies.erase(self)


func _process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
	_last_pos = global_position


func _apply_enemy_data(data: EnemyData):
	max_hp = data.max_hp
	score_value = data.score_value
	death_effect = data.death_effect
	hp = max_hp
	
	# 外观：直接实例化 visual_scene
	if data.visual_scene:
		_visual = data.visual_scene.instantiate()
		add_child(_visual)
	if data.hitbox_radius > 0:
		hitbox_radius = data.hitbox_radius
	
	# 碰撞形状
	var cs := $CollisionShape2D if has_node("CollisionShape2D") else CollisionShape2D.new()
	if not cs.get_parent():
		add_child(cs)
	if cs.shape is CircleShape2D:
		cs.shape.radius = hitbox_radius


func start() -> void:
	pass


## 小数伤害累积器（0.3×4 次 = 1.2 → 扣 1 血余 0.2）
var _dmg_acc: float = 0.0

func take_damage(damage: float):
	if is_queued_for_deletion():
		return
	_dmg_acc += damage
	var full: int = int(_dmg_acc)
	if full <= 0:
		return
	_dmg_acc -= full
	hp -= full
	if hp <= 0: die()


func die():
	# 系统操作统一走 ctx 服务；ctx 为 null 时跳过（不回退全局）
	if ctx:
		ctx.audio.play_sfx(AssetRegistry.sounds["enemy_die"], -6.0)
		if death_effect:
			ctx.effects.play_hit_effect(death_effect, global_position)
	GameState.active_enemies.erase(self)
	
	# 掉落 item
	_drop_item()
	
	GameEvents.enemy_killed.emit(score_value, global_position)
	queue_free()

func _drop_item() -> void:
	if not enemy_data:
		return
	var pool := _find_item_pool()
	if not pool:
		return
	
	_spawn_items(pool, Item.Type.POWER, enemy_data.item_power)
	_spawn_items(pool, Item.Type.POINT, enemy_data.item_point)
	_spawn_items(pool, Item.Type.LIFE_FRAGMENT, enemy_data.item_life)
	_spawn_items(pool, Item.Type.BOMB_FRAGMENT, enemy_data.item_bomb)
	_spawn_items(pool, Item.Type.LIFE_FULL, enemy_data.item_life_full)
	_spawn_items(pool, Item.Type.BOMB_FULL, enemy_data.item_bomb_full)

func _spawn_items(pool: Node, type: int, count: int) -> void:
	for i in range(count):
		var offset := Vector2(
			RNG.randf_range(-enemy_data.item_scatter, enemy_data.item_scatter),
			RNG.randf_range(-enemy_data.item_scatter * 0.5, 0)
		)
		pool.spawn(global_position + offset, type)

func _find_item_pool() -> Node:
	var world := get_parent()
	if world:
		return world.get_node_or_null("ItemPool")
	return null

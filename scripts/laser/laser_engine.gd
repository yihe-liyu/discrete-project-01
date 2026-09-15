## 激光引擎（新）—— 池 + 生成 + 每帧推进
## 替换旧 LaserSystem（第 3 步接入渲染后正式替换）
class_name LaserEngine
extends RefCounted

const POOL_SIZE := 64
const GRAZE_COOLDOWN_FRAMES := 3

var _pool: Array[LaserBeam] = []
var _active: Array[LaserBeam] = []
var _parent: Node
var _pool_index: int = 0
var on_graze: Callable = Callable()  ## 擦弹结算回调（BulletManager 注入；命名契约：回调值用 on_x）
## 实体注册表（BulletManager 注入）——自机判定用；空则跳过
var entity_registry: EntityRegistry
var _graze_cooldown: int = 0


func setup(p_parent: Node, p_on_graze: Callable = Callable()) -> void:
	on_graze = p_on_graze
	_parent = p_parent
	for i in POOL_SIZE:
		var beam := LaserBeam.new()
		beam.name = "LaserBeam_%d" % i
		beam.process_mode = Node.PROCESS_MODE_DISABLED
		beam.visible = false
		_parent.add_child(beam)
		_pool.append(beam)


## 取一条可用的光束（全活时踢最老）
func _acquire() -> LaserBeam:
	for i in POOL_SIZE:
		var idx := (_pool_index + i) % POOL_SIZE
		if _pool[idx].phase == LaserBeam.Phase.DEAD:
			_pool_index = (idx + 1) % POOL_SIZE
			return _pool[idx]
	var reuse: LaserBeam = _active.pop_front()
	return reuse


## 统一生成入口：骨架 + 颜色 + 配置（opts：grow/grow_speed/tail/lifetime/宽度等）
func spawn(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	var beam := _acquire()
	if beam == null:
		return null
	beam.grow_on_spawn = opts.get("grow", beam.grow_on_spawn)
	beam.grow_speed = opts.get("grow_speed", beam.grow_speed)
	beam.tail_distance = opts.get("tail", beam.tail_distance)
	beam.max_lifetime = opts.get("lifetime", beam.max_lifetime)
	beam.core_width = opts.get("core_width", beam.core_width)
	beam.hitbox_width = opts.get("hitbox_width", beam.hitbox_width)
	beam.graze_width = opts.get("graze_width", beam.graze_width)
	beam.laser_texture = opts.get("tex", opts.get("texture", beam.laser_texture))
	beam.spawn(skeleton, color)
	_active.append(beam)
	return beam


## 便捷：直线激光（opts 同上）
func spawn_line(a: Vector2, b: Vector2, color: Color, opts: Dictionary = {}) -> LaserBeam:
	var sk := LaserSkeleton.new()
	sk.from_line(a, b)
	return spawn(sk, color, opts)


## 便捷：曲线激光（Curve2D，均匀采样；opts 同上）
func spawn_curve(curve: Curve2D, color: Color, opts: Dictionary = {}, seg_len: float = 32.0) -> LaserBeam:
	var sk := LaserSkeleton.new()
	sk.from_curve(curve, seg_len)
	return spawn(sk, color, opts)


## 每帧推进所有活动激光 + 玩家判定（回收 DEAD）
func step(delta: float) -> void:
	var p = entity_registry.player if entity_registry else null
	var player: Player = p if is_instance_valid(p) else null
	var has_player: bool = is_instance_valid(player) and not player.is_invincible
	var missed: bool = false
	for i in range(_active.size() - 1, -1, -1):
		var beam := _active[i]
		beam.step(delta)
		if beam.phase == LaserBeam.Phase.DEAD:
			beam.reset()
			_active.remove_at(i)
			continue
		# 玩家判定：命中（每帧最多一次 miss）/ 擦弹（冷却）
		if has_player and beam.phase != LaserBeam.Phase.FADE and not missed:
			var pos := player.global_position
			if beam.is_hitting(pos):
				missed = true
				player.miss()
			elif _graze_cooldown <= 0 and beam.is_grazing(pos, player.graze_radius):
				_graze_cooldown = GRAZE_COOLDOWN_FRAMES
				if on_graze.is_valid():
					on_graze.call()
	if _graze_cooldown > 0:
		_graze_cooldown -= 1


func clear() -> void:
	for beam in _active:
		beam.reset()
	_active.clear()


func get_active() -> Array[LaserBeam]:
	return _active

extends CoroutineScript
## 弹丸行为：飞行 → 靠近自机时转向逃跑 → 靠近 Boss 时消失并散开一圈
## auto_stop = true

const PLAYER_PROXIMITY: float = 150.0
const RING_COUNT: int = 8
const RING_SPEED: float = 400.0

enum State { TRAVEL, FLEE }
var _state: State = State.TRAVEL
var _flee_dir: Vector2
var _skip: int = 0  # 距离检测跳帧计数


func _tick(p_ctx: StageContext):
	if not target:
		return false
	
	# 移动每帧都做（用引擎时钟：time_scale 快进时弹丸同步加速）
	target.global_position += target.velocity * get_dt()
	
	# 距离检测每 3 帧跑一次，省开销
	_skip += 1
	if _skip % 3 != 0:
		return true
	
	match _state:
		State.TRAVEL:
			_tick_travel(p_ctx)
		State.FLEE:
			_tick_flee(p_ctx)
	
	return true


func _tick_travel(p_ctx: StageContext):
	var player_pos := p_ctx.player.get_position()
	var dist := target.global_position.distance_to(player_pos)
	
	if dist < PLAYER_PROXIMITY:
		_flee_dir = (target.global_position - player_pos).normalized()
		target.velocity = _flee_dir * target.velocity.length()
		_state = State.FLEE


func _tick_flee(p_ctx: StageContext):
	var boss: Boss = GameState.get_boss()
	if not is_instance_valid(boss):
		return
	
	var dist := target.global_position.distance_to(boss.global_position)
	
	if dist < diff_pick([175, 150, 125, 100]):
		# 散开一圈普通弹（默认 linear_move 自动挂载）
		var normal := BulletData.new()\
			.tex("小玉")\
			.speed(RING_SPEED)\
			.color(Color(0.349, 0.584, 0.798, 1.0))\
			.blend(true)\
			.enemy()
		
		var rand_dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.bullets.shoot_spread(normal, diff_pick([2, 4, 6, 8]), TAU, rand_dir, target.global_position, AssetRegistry.sounds["kira"])
		
		# Hard 以上：额外射红色弹丸，远离 Boss
		if GameState.selected_difficulty >= 2:
			var away := (target.global_position - boss.global_position).normalized()
			var num: int = diff_pick([0, 0, 1, 2])
			var count: int = diff_pick([0, 0, 4, 8])
			var red := BulletData.new()\
				.tex("棱弹")\
				.color(Color.RED)\
				.blend(true)\
				.enemy()
			for i in count:
				red.speed(RING_SPEED + i * 50)
				p_ctx.bullets.shoot_spread(red, num, 1 / TAU / 3, away, target.global_position)
		
		# 自己消失
		BulletManager.return_bullet(target)

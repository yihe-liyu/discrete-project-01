## BounceBehavior（Track A / S4c-2）—— 非符1 反弹弹：沿飞行方向加速；碰左/右/上框后
## 转向「朝 Boss + bounce_angle」，原地换成直线弹（下墙穿出不反弹）。
## 移植旧 data/stages/stage01/bullet/bounce_bullet.gd。
## 只 set_velocity；re_fire 走 KernelBehaviorHost 延后队列。
## params：accel | bounce_angle | spawn_factory | spawn_speed | sfx | sfx_db
extends Behavior

var host   # KernelBehaviorHost


func process(system: BulletSystem, bullet_id: int, _ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var delta: float = system.get_delta()
	if delta <= 0.0:
		return
	# 沿飞行方向加速（行为只改 velocity；位移由系统积分）
	var accel: float = params.get(&"accel", 0.0)
	if accel != 0.0:
		var dir: Vector2 = system.get_velocity(bullet_id).normalized()
		if dir != Vector2.ZERO:
			system.set_velocity(bullet_id, system.get_velocity(bullet_id) + dir * accel * delta)
	# 碰框检测（用积分后的位置；左/右/上反弹，下墙穿出）
	var pos: Vector2 = system.get_position(bullet_id)
	var bounced := false
	if pos.x <= GameConfig.FIELD_LEFT:
		pos.x = GameConfig.FIELD_LEFT
		bounced = true
	elif pos.x >= GameConfig.FIELD_RIGHT:
		pos.x = GameConfig.FIELD_RIGHT
		bounced = true
	if pos.y <= GameConfig.FIELD_TOP:
		pos.y = GameConfig.FIELD_TOP
		bounced = true
	if not bounced:
		return
	_re_fire(system, bullet_id, params, pos)


## 碰框：朝 Boss（无 Boss 退化向下）转 bounce_angle，换成直线弹。
func _re_fire(system: BulletSystem, bullet_id: int, params: Dictionary, at: Vector2) -> void:
	var speed: float = system.get_velocity(bullet_id).length()
	var spawn_speed: float = params.get(&"spawn_speed", 0.0)
	if spawn_speed > 0.0:
		speed = spawn_speed
	var boss = host.get_boss() if host != null else null
	var aim := Vector2.DOWN
	if is_instance_valid(boss):
		aim = (boss.global_position - at).normalized()
	var dir: Vector2 = aim.rotated(params.get(&"bounce_angle", 0.0))
	var sfx: String = params.get(&"sfx", "")
	if sfx != "":
		var stream: AudioStream = AssetRegistry.sounds.get(sfx, null)
		if stream != null:
			AudioManager.play_sfx(stream, params.get(&"sfx_db", 0.0))
	var factory: Callable = params.get(&"spawn_factory", Callable())
	if factory.is_valid() and host != null:
		var b: BulletData = factory.call()
		if b != null:
			b.velocity = Vector2(0, speed)
			host.queue_spawn(b, at, dir)
	system.request_despawn(bullet_id)

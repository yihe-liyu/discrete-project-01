## RadialAccelBehavior—— 沿初发射方向加速；碰顶边原地换成向下弹。
## 移植旧 data/stages/stage01/bullet/radial_accel_bullet.gd。
## 只 set_velocity；re_fire 走 KernelBehaviorHost 延后队列（内核循环中途禁止增删行）。
## params（内容给的）：accel_rate | spawn_data(BulletData 模板) | sfx | sfx_db
extends Behavior

var host   # KernelBehaviorHost（桥接；untyped 以免依赖全局 class_name）


func process(system: BulletSystem, bullet_id: int, _ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var delta: float = system.get_delta()
	if delta <= 0.0:
		return
	var behavior_state: Variant = system.get_behavior_state(bullet_id)
	if not (behavior_state is Dictionary):
		var dir0: Vector2 = system.get_velocity(bullet_id).normalized()
		if dir0 == Vector2.ZERO:
			return   # 无初速：保持静止（与旧行为一致）
		behavior_state = {&"dir": dir0}
		system.set_behavior_state(bullet_id, behavior_state)
	if system.get_position(bullet_id).y <= GameConfig.FIELD_TOP:
		_re_fire_down(system, bullet_id, params)
		return
	var accel_rate: float = params.get(&"accel_rate", 0.0)
	system.set_velocity(bullet_id, system.get_velocity(bullet_id) + behavior_state[&"dir"] * accel_rate * delta)


## 碰顶边：入队一颗向下匀速弹（保留速度大小），并请求回收自己。
func _re_fire_down(system: BulletSystem, bullet_id: int, params: Dictionary) -> void:
	var speed: float = system.get_velocity(bullet_id).length()
	var sfx: String = params.get(&"sfx", "")
	if sfx != "":
		var stream: AudioStream = AssetRegistry.sounds.get(sfx, null)
		if stream != null:
			AudioManager.play_sfx(stream, params.get(&"sfx_db", 0.0))
	var factory: Callable = params.get(&"spawn_factory", Callable())
	if factory.is_valid() and host != null:
		var b: BulletData = factory.call()
		if b != null:
			b.velocity = Vector2(0, speed)   # 保留速度大小，竖直向下
			host.queue_spawn(b, Vector2(system.get_position(bullet_id).x, GameConfig.FIELD_TOP), Vector2.DOWN)
	system.request_despawn(bullet_id)

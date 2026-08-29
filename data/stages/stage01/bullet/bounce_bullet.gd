extends CoroutineScript
## 非符1 专用反弹弹：碰到游戏框（左/右/上，下墙穿出）时，
## 转向朝向 Boss 并旋转 bounce_angle，然后消除自己，原地生成一颗直线弹
## 带加速度 accel（沿飞行方向加速；0 = 匀速）
## auto_stop = true

var bounce_angle: float = 0.0  ## 反弹附加角（弧度），发射时决定并固定
var accel: float = 0.0         ## 加速度（px/s²），沿当前飞行方向（0 = 匀速）

var spawn_tex: String = "棱弹"      ## 直线弹贴图 key
var spawn_color: Color = Color.AQUA  ## 直线弹颜色
var spawn_speed: float = 0.0        ## 直线弹速度（0 = 沿用反弹瞬间速度）


func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target) or not target is Bullet:
		return false
	var bullet: Bullet = target
	var dt := get_dt()
	if accel != 0.0:
		var dir := bullet.velocity.normalized()
		if dir != Vector2.ZERO:
			bullet.velocity += dir * accel * dt  # 沿飞行方向加速
	bullet.global_position += bullet.velocity * dt
	if _bounce_and_split(_ctx, bullet):
		return false  # 已重新发射：消除自己，协程结束
	bullet.rotation = bullet.velocity.angle()
	return true


## 碰框：位置夹回框边，转向朝向 Boss + 旋转 bounce_angle，原地重新发射成直线弹
func _bounce_and_split(p_ctx: StageContext, bullet: Bullet) -> bool:
	var pos := bullet.global_position
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
	# 下墙不反弹（穿出）

	if not bounced:
		bullet.global_position = pos
		return false

	var boss: Boss = p_ctx.boss.current()
	var aim := Vector2.DOWN  # 无 Boss 时退化为竖直向下
	if is_instance_valid(boss):
		aim = (boss.global_position - pos).normalized()
	var dir := aim.rotated(bounce_angle)
	_re_fire(p_ctx, bullet, pos, dir, bullet.velocity.length())
	return true


## 原地重新发射：把当前弹重配置成直线弹（复用原弹，不回收不新建）
func _re_fire(p_ctx: StageContext, bullet: Bullet, at: Vector2, dir: Vector2, cur_speed: float) -> void:
	var b := BulletData.new()\
		.tex("米弹")\
		.speed(spawn_speed if spawn_speed > 0.0 else cur_speed)\
		.color(Color.GOLD)\
		.blend(true)\
		.enemy()
	BulletManager.re_fire(bullet, b, dir, at)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["kira"], -8.0)

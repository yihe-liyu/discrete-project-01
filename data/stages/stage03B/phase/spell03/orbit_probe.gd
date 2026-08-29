extends CoroutineScript
## 往返探测弹 v2（匀减速滑行版）
## 青弹以初速发射，加速度恒为 -decel（沿初方向反向）：
##   减速滑行到停（最远点）→ 继续反向加速飞回 → 沿初方向位移过零（回到生成位置）
##   → 分裂 90° 红弹 → 自身消失
## 全程加速度方向不变，无需掉头/取反；往返由 decel 决定（v0/decel 秒内完成）
## auto_stop = true

var decel: float = 150.0     # 反向加速度（px/s²）：越大滑行越短、往返越快
var split_speed: float = 60.0    # 分裂弹初速（慢，配合缓慢加速出屏）
var split_accel: float = 40.0    # 分裂弹加速度（缓慢加速）
var split_dir: Array = [TAU/4, TAU/8, TAU/12, TAU/20]      # 分裂方向：相对初方向旋转角度
var split_aim_chance: float = 0.1 # 分裂弹 10% 变自机狙
var hold_aim_probe: bool = false  # 由发射方注入（orbit_spiral hold 阶段 + H/L 才为 true）

enum State { OUT, BACK }
var _state: int = State.OUT
var _dir0: Vector2 = Vector2.ZERO  # 发射初方向（首帧记录）
var _dist: float = 0.0             # 沿初方向累计位移（OUT 正增 / BACK 递减）


func _tick(p_ctx: StageContext):
	var bullet: Bullet = target
	if not bullet:
		return false
	var dt := get_dt()
	if _dir0 == Vector2.ZERO:
		_dir0 = bullet.velocity.normalized()
	# 加速度恒为反向（沿 -dir0）→ 减速滑行 → 停 → 反向加速飞回
	bullet.velocity -= _dir0 * decel * dt
	_dist += bullet.velocity.dot(_dir0) * dt
	match _state:
		State.OUT:
			if bullet.velocity.dot(_dir0) <= 0.0:
				_state = State.BACK  # 减速到停，开始飞回
		State.BACK:
			if _dist <= 1.0:  # 位移过零 = 回到生成位置附近
				_spawn_split(p_ctx)
				BulletManager.return_bullet(bullet)
				return false
	bullet.global_position += bullet.velocity * dt
	return true


## 分裂：普通分裂弹（蓝紫色）+ 15% 概率自机狙（红橙色，朝玩家）
func _spawn_split(p_ctx: StageContext) -> void:
	var dir := _dir0.rotated(diff_pick(split_dir))
	# 仅"hold 阶段发射的探测弹"（发射方注入 hold_aim_probe）+ H/L：15% 变自机狙
	var hold_aim: bool = p_ctx.diff.at_least(2) and hold_aim_probe
	var is_aim: bool = hold_aim and RNG.randf() < split_aim_chance
	var fire_dir := dir
	if is_aim:
		var p := p_ctx.player.get_player()
		if p:
			fire_dir = (p.global_position - target.global_position).normalized()
		else:
			is_aim = false  # 无玩家时退回普通分裂
	var red := BulletData.new() \
		.tex("环玉") \
		.speed(split_speed) \
		.accelerate(fire_dir.x * split_accel, fire_dir.y * split_accel) \
		.color(Color.RED if is_aim else Color.AQUA) \
		.blend(true) \
		.enemy() \
		.grace(diff_pick([4, 4, 0.75, 0.75]))
	p_ctx.audio.play_sfx(AssetRegistry.sounds["kira"], -8.0)
	p_ctx.bullets.shoot_spread(red, 1, 0.0, fire_dir, target.global_position)

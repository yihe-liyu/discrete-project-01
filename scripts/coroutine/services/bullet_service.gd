class_name BulletService
## 子弹服务 —— ctx.bullets 下的弹幕/激光 API
extends RefCounted

var active: bool = true
## 弹幕世界（StageContext 从绑定的 stage 取；起不再回退 BulletManager.current）。
## 无 stage 绑定 = null：方法静默 no-op（测试 / 无场景上下文），不崩。
var bullet_manager: BulletManager


## 扇形散弹。count == 1 打一发（忽略 spread_angle）；不发弹（active=false / count ≤ 0）时静默返回。
func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2, sfx: AudioStream = null) -> void:
	if not active or count <= 0 or bullet_manager == null:
		return
	if sfx:
		AudioManager.play_sfx(sfx, -8.0)
	if count == 1:
		bullet_manager.shoot_bullet(bullet_data, at, base_dir)
		return
	var step := spread_angle / (count - 1) if spread_angle < TAU - 0.001 else spread_angle / count
	for i in count:
		var dir := base_dir.rotated(-spread_angle / 2.0 + step * i)
		bullet_manager.shoot_bullet(bullet_data, at, dir)


# ── 激光 ──

## 骨架级生成（配合 LaserPresets 预设）：最灵活入口
func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	if not active or bullet_manager == null: return null
	return bullet_manager.spawn_laser(skeleton, color, opts)

## 沿 Curve2D 生长的激光
func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	if not active or bullet_manager == null: return null
	return bullet_manager.fire_growing_laser(curve, color, speed, tail, lifetime, tex)

## 两点间直线激光（瞬间全开）
func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	if not active or bullet_manager == null: return null
	return bullet_manager.fire_line_laser(a, b, color, lifetime, tex)

## 固定路径激光（沿 Curve2D 瞬间全开）
func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	if not active or bullet_manager == null: return null
	return bullet_manager.fire_fixed_laser(curve, color, lifetime, tex)

## 自机导向激光
func fire_homing_laser(origin: Vector2, player_pos: Vector2, color: Color, bend: float = 100.0, length: float = 500.0, lifetime: float = 5.0) -> LaserBeam:
	if not active or bullet_manager == null or player_pos == Vector2.ZERO:
		return null
	var dir := (player_pos - origin).normalized()
	var end := origin + dir * length
	var mid := (origin + end) / 2.0
	var ctrl := mid + dir.orthogonal() * bend
	return fire_growing_laser(_bezier_curve(origin, ctrl, end), color, length / 0.5, length * 0.6, lifetime)

func clear_all_lasers() -> void:
	if bullet_manager: bullet_manager.clear_all_lasers()


## 死亡清弹圈：从 start_radius 膨胀到 max_radius 消除敌弹
func death_clear(pos: Vector2, max_radius: float, duration: float,
		start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	if bullet_manager: bullet_manager.start_death_clear(pos, max_radius, duration, start_radius, on_clear)


## 炸弹（宿主节点版，不进内核池）——玩家炸弹用；数据是 BombData（不是弹幕的 BulletData）
func shoot_bomb(data: BombData, pos: Vector2, direction: Vector2, tint: Color = Color.WHITE, spawn_delay: float = 0.0):
	return bullet_manager.shoot_bomb_bullet(data, pos, direction, tint, spawn_delay) if bullet_manager else null


func _bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2) -> Curve2D:
	const SAMPLES := 60
	var curve := Curve2D.new()
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		curve.add_point(u * u * p0 + 2 * u * t * p1 + t * t * p2)
	return curve

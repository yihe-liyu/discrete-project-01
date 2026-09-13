class_name BulletService
## 子弹服务 —— ctx.bullets 下的弹幕/激光 API
extends RefCounted

var active: bool = true
## W4c：弹幕世界（StageContext 注入；无 stage 的共享 ctx 回退 BulletManager.current）
var world: BulletManager


## 扇形散弹；count == 1 时返回该弹的引用（旧池 = Bullet 节点；内核路径 = int id），否则返回 null。
## ATTENTION：**不声明返回类型**——两条路返回不同东西（Track A / S3）；用之前先 `is Bullet` 判断。
func shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2, sfx: AudioStream = null):
	if not active or count <= 0:
		return null
	if sfx:
		AudioManager.play_sfx(sfx, -8.0)
	if count == 1:
		return world.shoot_bullet(bullet_data, at, base_dir)
	var step := spread_angle / (count - 1) if spread_angle < TAU - 0.001 else spread_angle / count
	for i in count:
		var dir := base_dir.rotated(-spread_angle / 2.0 + step * i)
		world.shoot_bullet(bullet_data, at, dir)
	return null


# ── 激光 ──

## 骨架级生成（配合 LaserPresets 预设）：最灵活入口
func spawn_laser(skeleton: LaserSkeleton, color: Color, opts: Dictionary = {}) -> LaserBeam:
	if not active: return null
	return world.spawn_laser(skeleton, color, opts)

## 沿 Curve2D 生长的激光
func fire_growing_laser(curve: Curve2D, color: Color, speed: float = 600.0, tail: float = 300.0, lifetime: float = 8.0, tex: Texture2D = null) -> LaserBeam:
	if not active: return null
	return world.fire_growing_laser(curve, color, speed, tail, lifetime, tex)

## 两点间直线激光（瞬间全开）
func fire_line_laser(a: Vector2, b: Vector2, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	if not active: return null
	return world.fire_line_laser(a, b, color, lifetime, tex)

## 固定路径激光（沿 Curve2D 瞬间全开）
func fire_fixed_laser(curve: Curve2D, color: Color, lifetime: float = 3.0, tex: Texture2D = null) -> LaserBeam:
	if not active: return null
	return world.fire_fixed_laser(curve, color, lifetime, tex)

## 自机导向激光
func fire_homing_laser(origin: Vector2, player_pos: Vector2, color: Color, bend: float = 100.0, length: float = 500.0, lifetime: float = 5.0) -> LaserBeam:
	if not active or player_pos == Vector2.ZERO:
		return null
	var dir := (player_pos - origin).normalized()
	var end := origin + dir * length
	var mid := (origin + end) / 2.0
	var ctrl := mid + dir.orthogonal() * bend
	return fire_growing_laser(_bezier_curve(origin, ctrl, end), color, length / 0.5, length * 0.6, lifetime)

func clear_all_lasers() -> void:
	world.clear_all_lasers()


## 死亡清弹圈：从 start_radius 膨胀到 max_radius 消除敌弹
func death_clear(pos: Vector2, max_radius: float, duration: float,
		start_radius: float = 30.0, on_clear: Callable = Callable()) -> void:
	world.start_death_clear(pos, max_radius, duration, start_radius, on_clear)


## 炸弹弹（宿主节点版，不进内核池）——玩家炸弹用
func shoot_bomb(data: BulletData, pos: Vector2, direction: Vector2):
	return world.shoot_bomb_bullet(data, pos, direction) if world else null


## 回收一颗弹（内核行 id）
func return_bullet(id) -> void:
	if world:
		world.return_bullet(id)


## 原地重发：回收旧行 + 按新配置重发
func re_fire(bullet, data: BulletData, dir: Vector2, at: Vector2) -> void:
	if world:
		world.re_fire(bullet, data, dir, at)


func _bezier_curve(p0: Vector2, p1: Vector2, p2: Vector2) -> Curve2D:
	const SAMPLES := 60
	var curve := Curve2D.new()
	for i in SAMPLES + 1:
		var t := float(i) / SAMPLES
		var u := 1.0 - t
		curve.add_point(u * u * p0 + 2 * u * t * p1 + t * t * p2)
	return curve

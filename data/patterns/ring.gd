extends BulletPattern
## 环形弹（瞬时 pattern）：以 origin 为圆心，向 count 个方向等角发射。
##
## 用法：
##   const RING := preload("res://data/patterns/ring.gd")
##   var p := RING_PARAMS.new()
##   p.bullet_def = BULLET_DEF
##   p.count = 24
##   p.speed = 180.0
##   RING.new().fire(ctx, p, boss.global_position, Vector2.DOWN)
##
## 不写 class_name：具体 pattern 不进全局类表；由内容 preload / 目录扫描。

## 纯方向计算（便于测试，也避免和 `shoot_spread` 的步长语义各写一份）。
static func spread_directions(p_count: int, p_spread: float, p_base_dir: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if p_count <= 0:
		return out
	var base := p_base_dir.normalized()
	if base == Vector2.ZERO:
		base = Vector2.UP
	if p_count == 1:
		out.append(base)
		return out
	# 整圈：步长 = 张角 / 数量；扇形：步长 = 张角 / (数量 - 1)（含两端点）。
	var step := p_spread / p_count if absf(p_spread) >= TAU - 0.001 else p_spread / float(p_count - 1)
	var start := -p_spread * 0.5
	for i in p_count:
		out.append(base.rotated(start + step * float(i)))
	return out


func fire(p_ctx: StageContext, p: PatternParams, origin: Vector2, direction: Vector2) -> void:
	if p_ctx == null or not p_ctx.active():
		return
	if p == null:
		push_warning("RingPattern.fire(): params 为 null，跳过")
		return
	if p.bullet_def == null and p.template == null:
		push_warning("RingPattern.fire(): params.bullet_def / template 未设置，跳过")
		return
	if p.count <= 0:
		return

	var base_dir := direction
	if p.aim:
		var player := p_ctx.player.get_player()
		if is_instance_valid(player):
			base_dir = (player.global_position - origin).normalized()

	var directions := spread_directions(p.count, p.spread, base_dir)
	if directions.is_empty():
		return
	# template 路径按引用使用：与旧 content 共享同一个 BulletData，保留 faction/tint/lifecycle 与类型缓存。
	# 只改 velocity（旧 content 也是每波 set speed），不重建实例。
	var shot: BulletData
	if p.template != null:
		shot = p.template
	else:
		shot = BulletData.new().def(p.bullet_def).color(p.color).blend(p.blend)
		if p.enemy:
			shot.enemy()
		else:
			shot.player()
	if shot == null:
		push_warning("RingPattern.fire(): BulletData 构造失败，跳过")
		return
	if p.speed > 0.0:
		shot.velocity = Vector2(p.speed, 0.0)
	p_ctx.bullets.shoot_directions(shot, directions, origin)

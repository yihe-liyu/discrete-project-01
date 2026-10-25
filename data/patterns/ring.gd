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
## 不写 class_name：具体 pattern 不进全局类表；由内容 preload。

## 纯方向计算（便于测试，也避免和 [code]shoot_spread[/code] 的步长语义各写一份）。
static func spread_directions(p_count: int, p_spread: float, p_base_dir: Vector2) -> Array[Vector2]:
	var 方向列表: Array[Vector2] = []
	if p_count <= 0:
		return 方向列表

	var 基准方向 := p_base_dir.normalized()
	if 基准方向 == Vector2.ZERO:
		基准方向 = Vector2.UP
	if p_count == 1:
		方向列表.append(基准方向)
		return 方向列表

	# 整圈：步长 = 张角 / 数量；扇形：步长 = 张角 / (数量 - 1)（含两端点）。
	var 步长 := p_spread / p_count if absf(p_spread) >= TAU - 0.001 else p_spread / float(p_count - 1)
	var 起始角 := -p_spread * 0.5
	for i in p_count:
		方向列表.append(基准方向.rotated(起始角 + 步长 * float(i)))
	return 方向列表


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

	var 基准方向 := direction
	if p.aim:
		var 自机 := p_ctx.player.get_player()
		if is_instance_valid(自机):
			基准方向 = (自机.global_position - origin).normalized()

	var 方向列表 := spread_directions(p.count, p.spread, 基准方向)
	if 方向列表.is_empty():
		return

	# template 路径按引用使用：与旧 content 共享同一个 BulletData，保留 faction/tint/lifecycle 与类型缓存。
	# 只改 velocity（旧 content 也是每波 set speed），不重建实例。
	var 弹型: BulletData
	if p.template != null:
		弹型 = p.template
	else:
		弹型 = BulletData.new().def(p.bullet_def).color(p.color).blend(p.blend)
		if p.enemy:
			弹型.enemy()
		else:
			弹型.player()
	if 弹型 == null:
		push_warning("RingPattern.fire(): BulletData 构造失败，跳过")
		return
	if p.speed > 0.0:
		弹型.velocity = Vector2(p.speed, 0.0)
	p_ctx.bullets.shoot_directions(弹型, 方向列表, origin)

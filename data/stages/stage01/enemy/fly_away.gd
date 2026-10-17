extends CoroutineScript
## 让 target 沿随机方向加速飘走退场

var _dir: Vector2
var _speed: float = 0.0


func _init() -> void:
	auto_stop = true


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target: target = p_target

	_dir = Vector2.UP.rotated(RNG.randf_range(-PI / 3, PI / 3))
	super.start(ctx, target)


func _tick(_ctx: StageContext) -> Variant:
	var dt := get_dt()
	target.global_position += _dir * _speed * dt
	_speed += 50.0 * dt
	# 出屏后自动消除
	var r := target.get_viewport().get_visible_rect()
	var margin := 90.0
	if target.global_position.x < -margin or target.global_position.x > r.size.x + margin \
		or target.global_position.y < -margin or target.global_position.y > r.size.y + margin:
		if is_instance_valid(target):
			ctx.enemies.despawn(target)   # 静默回收（内容动词；注销由 Enemy 自动做）
		return false
	return true

## 子机跟随协程：以指数追赶 leader + offset；失效时结束。
extends CoroutineScript
class_name OptionFollow

var leader: Node2D
var offset: Vector2

## 追赶速度（单位：1/秒），值越大跟随越紧
const FOLLOW_SPEED: float = 13.39

var _lerp_factor: float

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	# start() 可能在物理循环外调用（_ready 阶段）→ get_dt()/_physics_delta 都是 0
	# 追赶系数用恒定步长（time_scale 差异对跟随效果无感知）
	var delta := 1.0 / Engine.physics_ticks_per_second
	_lerp_factor = 1.0 - exp(-FOLLOW_SPEED * delta)
	super.start(ctx, target)

func _tick(_ctx: StageContext) -> Variant:
	if not ctx.active() or not is_instance_valid(leader) or not is_instance_valid(target):
		return false
	var goal := leader.global_position + offset
	target.global_position = target.global_position.lerp(goal, _lerp_factor)
	return true

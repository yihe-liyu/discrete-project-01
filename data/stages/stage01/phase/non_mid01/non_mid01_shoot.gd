extends CoroutineScript
## 非符1 弹幕：每隔一段时间射一圈特殊弹丸
## auto_stop = false

const LIFECYCLE_HOOKS_SCRIPT = preload("res://scripts/kernel_bridge/lifecycle/lifecycle_hooks.gd")
const FLEE_HOOK_SCRIPT = preload("res://data/stages/stage01/phase/non_mid01/non_mid_flee_hook.gd")
const FLEE_HOOK := &"non_mid01_flee_burst"

var _interval: float = 0.2  # 发射间隔（秒）
## 复用弹型实例（M2）
var _bullet_data: BulletData
## 散圈钩子实例（static：注册一次，跨实例共用）
static var _flee_hook


func _init() -> void:
	if _flee_hook == null:
		_flee_hook = FLEE_HOOK_SCRIPT.new()
	LIFECYCLE_HOOKS_SCRIPT.register(FLEE_HOOK, Callable(_flee_hook, "burst"))


func _tick(p_ctx: StageContext):
	if not target: return p_ctx.clock.wait(_interval)

	if _bullet_data == null:
		_bullet_data = BulletData.new().tex("小玉").speed(1000)\
			.color(Color(0.0, 0.906, 1.353, 0.25)).blend(true).enemy().no_spawn_fog()\
			.trajectory(BulletLifecycle.non_mid_flee(
			150.0, diff_pick(FLEE_HOOK_SCRIPT.BOSS_RADIUS), FLEE_HOOK))

	# 射一圈，随机初始旋转
	var rand_dir := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread(_bullet_data, diff_pick([32, 48, 64, 72]), TAU, rand_dir, target.global_position)

	return p_ctx.clock.wait(_interval)

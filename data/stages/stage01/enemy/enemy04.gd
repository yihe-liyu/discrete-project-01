extends CoroutineScript

## 匀速下移 + 棱弹径向扩散
## 扇形棱弹（米弹作替换弹型，沿各自发射角加速扩散）；匀速下移直到出屏。

## 匀速下移速度（px/s），外部可用 param("move_speed", v) 覆盖。
var move_speed: float = 120.0

## 复用弹型实例（M2）。
var _radial_bullet_data: SpawnSpec
## 换向替换弹（米弹/FUCHSIA）：共享实例（static）。
static var _radial_spawn_bullet_data: SpawnSpec
var _top_template: EmitTemplate


## 一次性初始化：ctx / target 已就绪，且 Enemy 已入树。
func _on_start() -> void:
	if not target:
		return

	# 弹幕：复用弹型实例。
	if _radial_bullet_data == null:
		if _radial_spawn_bullet_data == null:
			_radial_spawn_bullet_data = SpawnSpec.new().enemy().blend(true).tex("米弹").color(Color.FUCHSIA)
		_radial_bullet_data = SpawnSpec.new().enemy().blend(true).tex("棱弹").color(Color.FUCHSIA)
		_top_template = EmitTemplate.new(&"stage01_enemy04_top", _radial_spawn_bullet_data)

	var timeline := start_timeline()

	# 两轮径向弹：每轮随机起始方向，按难度叠 1~2 层速度、15~30 颗一圈。
	timeline.at(1.5).every(2.0).times(2).do(func():
		if not _ensure_top_behavior(ctx):
			return
		var 发射方向 := Vector2.ONE.rotated(RNG.randf_range(-PI, PI))
		var 每圈弹数: int = diff_pick([15, 20, 20, 30])
		for i in diff_pick([1, 1, 2, 2]):
			_radial_bullet_data.velocity = Vector2(0, 50 + i * 50)
			ctx.bullets.shoot_spread(
				_radial_bullet_data, 每圈弹数,
				TAU, 发射方向,
				target.global_position, AssetRegistry.sounds["shoot"])
			# 下一层错开半格，避免两层完全重叠。
			发射方向 = 发射方向.rotated(TAU / 每圈弹数 / 2.0)
	)

	# timeline 发完后自动停；移动由下面的 _tick 继续推进，直到出屏。
	auto_stop = true


## 移动：匀速下移直到离开屏幕（弹幕 timeline 并行推进，发完后移动不中断）。
func _ensure_top_behavior(p_ctx: StageContext) -> bool:
	if _radial_bullet_data == null or _top_template == null:
		return false
	# 无 stage / 无弹幕管理器 = 彩排或移动测试：发射整体静默 no-op。
	if p_ctx.bullets.bullet_manager == null:
		return true
	if not p_ctx.bullets.register_emit_template(_top_template):
		push_error("[enemy04] top 模板注册失败")
		return false
	if _radial_bullet_data.behavior == null:
		_radial_bullet_data.with_behavior(
			BulletBehaviors.top_emit(_top_template, 150.0, PI, 0.0))
	return true


func _tick(_ctx: StageContext) -> Variant:
	if target and is_instance_valid(target):
		target.global_position.y += move_speed * get_dt()
		# 离开屏幕（下缘 + 32px 宽限）：静默回收。
		if target.global_position.y > GameConfig.VIEW_HEIGHT + 32.0:
			ctx.enemies.despawn(target)
			return false
	# 弹幕 timeline 照常推进（事件发完即停，但移动持续到出屏）。
	if _timeline:
		_timeline.tick(get_dt())
	return true

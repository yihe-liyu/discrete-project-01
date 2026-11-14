extends CoroutineScript
## 卡摩瑞道中一非「道中非符」
##
## 声呐弹以高速向外铺开，靠近自机时折返、再飞回 Boss；回到 Boss 附近时
## 向四周炸开一圈水色小玉，Hard / Lunatic 还会额外向 Boss 背后甩出一串红色棱弹。
##
## 整段 sonar behavior 只有一颗“声呐弹”模板：数量、折返半径、尾段开花数都由这里传入。

## 两轮声呐弹之间的间隔（秒）。
var 发射间隔: float = 0.2
## 每轮声呐弹的数量。
var 声呐弹个数: int = diff_pick([32, 48, 64, 72])
## 声呐弹回到 Boss 附近时炸开的小玉数量。
var 开花弹个数: int = diff_pick([2, 4, 6, 8])

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 声呐弹: SpawnSpec
var 开花弹: SpawnSpec
var 串型弹: SpawnSpec
var 开花模板: EmitTemplate
var 串型模板: EmitTemplate


func _on_start() -> void:
	# 尾段开花：水色小玉，从声呐弹的终点向四周均匀铺开。
	开花弹 = SpawnSpec.new().tex("小玉").color(Color(0.35, 0.6, 0.8, 1.0)).blend(true).enemy()

	# Hard / Lunatic 追加的串型弹：红色棱弹，沿 Boss 背后甩出。
	串型弹 = SpawnSpec.new().tex("棱弹").color(Color.RED).blend(true).enemy()

	# 声呐弹：高速、半透明、不起雾；靠近自机后折返，再飞回 Boss。
	声呐弹 = SpawnSpec.new().tex("小玉").speed(1000.0) \
		.color(Color(0.0, 0.906, 1.353, 0.25)).blend(true).enemy().no_spawn_fog()

	开花模板 = EmitTemplate.new(&"卡摩瑞道中一非_flower", 开花弹)
	串型模板 = EmitTemplate.new(&"卡摩瑞道中一非_string", 串型弹)


func _ensure_sonar(p_ctx: StageContext) -> bool:
	if 开花模板 == null or 串型模板 == null:
		return false
	for tpl in [开花模板, 串型模板]:
		if not p_ctx.bullets.has_emit_template(tpl.id):
			if not p_ctx.bullets.register_emit_template(tpl):
				push_error("[卡摩瑞道中一非] 模板注册失败：%s" % tpl.id)
				return false
	if 声呐弹.behavior_spec == null:
		var mode := 0
		if SaveData.selected_difficulty == Difficulty.HARD:
			mode = 1
		elif SaveData.selected_difficulty == Difficulty.LUNATIC:
			mode = 2
		声呐弹.with_behavior(BulletBehaviors.sonar(
			开花模板, 串型模板,
			diff_pick([175.0, 150.0, 125.0, 100.0]),
			开花弹个数, mode))
	return true


func _tick(p_ctx: StageContext) -> Variant:
	if not _ensure_sonar(p_ctx):
		return false
	if not target:
		return p_ctx.clock.wait(发射间隔)

	# 每轮整体随机旋转，避免声呐弹总从同一个方向起飞。
	var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
	p_ctx.bullets.shoot_spread_spec(声呐弹, 声呐弹个数, TAU, 随机角度, target.global_position)

	return p_ctx.clock.wait(发射间隔)

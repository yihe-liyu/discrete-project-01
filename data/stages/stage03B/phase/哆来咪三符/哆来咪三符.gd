extends CoroutineScript
## 哆来咪三符「黄粱「不可测之梦」」
##
## 一个围绕 Boss 公转的“发弹点”，每帧向四周铺一圈往返弹。往返弹先向外减速，
## 速度归零时按概率分裂成两种夹弹：
## - 水色夹角弹：撞墙后靠宽限时间自然清理。
## - 红色夹角狙：Hard 以上会朝自机方向偏转，分裂后仍带收尾。
##
## 难度分派：
## - Easy / Normal：发弹点从中心向外扩张，到上限后停住 `保持旋转时间` 秒，再缩回中心重来。
## - Hard / Lunatic：发弹点直接钉在半径上限，整段保持公转，不再收回。

## 往返弹向外减速的加速度（像素/秒²）。
var 往返弹加速度: float = 150.0
## 分裂弹的初速度与沿朝向的加速度。
var 夹角弹初速度: float = 60.0
var 夹角弹加速度: float = 40.0
## Hard 以上，往返弹分裂成“自机狙”的概率。
var 变自机狙概率: float = 0.075

## 发弹点的公转角速度（弧度/秒；12 ≈ 0.52 秒一圈）。
var 发弹点角速度: float = 12.0
## 公转角加速度（弧度/秒²；正 = 加速，负 = 减速）。
var 发弹点角加速度: float = diff_pick([0.0, 0.0, 4.0, 8.0])
## 发弹点起始半径与半径上限（像素）。
var 发弹点起始半径: float = 0.0
var 发弹点半径上限: float = diff_pick([250.0, 300.0, 625.0, 625.0])
## 发弹点与自机的最小安全距离；太近就跳过这一发。
var 发弹安全距离: float = 125.0
## 发弹点向外扩张的速度与加速度。
var 发弹点半径增加速度: float = 120.0
var 发弹点半径增加加速度: float = 15.0
## 发弹点到达上限后保持旋转的时间（秒）。
var 保持旋转时间: float = 7.5
## 两次发射的间隔（秒）。
var 发弹间隔: float = diff_pick([0.07, 0.07, 0.06, 0.06])
## 每圈往返弹的数量。
var 个数: int = diff_pick([2, 4, 6, 10])
## 往返弹的初速度。
var 往返弹初速度: float = 175.0

## 发弹点的当前角度 / 角速度（弧度、弧度/秒）。
var 发弹点当前角度: float = 0.0
var 发弹点当前角速度: float = -1.0
## 当前半径 / 当前扩张速度。
var 发弹点当前半径: float = 60.0
var 发弹点当前半径增加速度: float = -1.0
## 距离“缩回中心”还剩多少秒；Hard 以上为 INF。
var 剩余保持时间: float = 0.0

## `难度为Hard以上` 在脚本实例化时读取一次；中途改难度不会重新分派。
var 难度为Hard以上: bool = SaveData.selected_difficulty >= Difficulty.HARD

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 往返弹: SpawnSpec
var 夹角弹: SpawnSpec
var 夹角狙: SpawnSpec
var 夹角模板: EmitTemplate
var 夹角狙模板: EmitTemplate


func _on_start() -> void:
	发弹点当前角速度 = 发弹点角速度
	发弹点当前半径增加速度 = 发弹点半径增加速度

	# Hard 以上：发弹点直接钉在外圈，整段保持公转。
	if 难度为Hard以上:
		发弹点当前半径 = 发弹点半径上限
		剩余保持时间 = INF
		发弹点当前角度 = RNG.randf() * TAU

	# 水色夹角弹：沿朝向外扩；Hard 以上加一个短寿命，到点自动清弹。
	var 夹角寿命: float = diff_pick([0.0, 0.0, 3.0, 3.0]) if 难度为Hard以上 else 0.0
	夹角弹 = SpawnSpec.new().tex("环玉").blend(true).enemy() \
		.grace(4) \
		.color(Color.AQUA)
	夹角弹.with_behavior(BulletBehaviors.accel_heading(
		夹角弹加速度, 夹角寿命, 难度为Hard以上))

	# 红色夹角狙：同样外扩；Hard 以上寿命更长，并带清弹收尾。
	var 夹角狙寿命: float = diff_pick([0.0, 0.0, 5.0, 6.0]) if 难度为Hard以上 else 0.0
	夹角狙 = SpawnSpec.new().tex("环玉").blend(true).enemy() \
		.grace(4) \
		.color(Color.RED)
	夹角狙.with_behavior(BulletBehaviors.accel_heading(
		夹角弹加速度, 夹角狙寿命, 难度为Hard以上))

	# 往返弹：向外减速到 0，在终点按概率分裂成上面两种夹弹。
	往返弹 = SpawnSpec.new().tex("环玉").speed(往返弹初速度) \
		.color(Color.BLUE_VIOLET).blend(true).enemy() \
		.grace(4)
	夹角模板 = EmitTemplate.new(&"哆来咪三符_aqua", 夹角弹)
	夹角狙模板 = EmitTemplate.new(&"哆来咪三符_red", 夹角狙)
	# 往返弹的行为在 _tick 里注册模板后再绑定。


func _ensure_split_resources(p_ctx: StageContext) -> bool:
	if not p_ctx.bullets.has_emit_template(&"哆来咪三符_aqua"):
		if not p_ctx.bullets.register_emit_template(夹角模板):
			push_error("[哆来咪三符] aqua 模板注册失败")
			return false
	if not p_ctx.bullets.has_emit_template(&"哆来咪三符_red"):
		if not p_ctx.bullets.register_emit_template(夹角狙模板):
			push_error("[哆来咪三符] red 模板注册失败")
			return false
	_bind_parent_behavior()
	return true


## 模板注册后绑定父弹行为；拆出来让内容形状测试可以单独验证。
func _bind_parent_behavior() -> void:
	if 往返弹.behavior_spec != null:
		return
	往返弹.with_behavior(BulletBehaviors.split_after(
		夹角模板, 夹角狙模板,
		2.0 * 往返弹初速度 / 往返弹加速度,
		-往返弹加速度,
		变自机狙概率 if 难度为Hard以上 else 0.0,
		夹角弹初速度, TAU / 个数 / 2.0))


func _tick(p_ctx: StageContext) -> Variant:
	if not _ensure_split_resources(p_ctx):
		return false
	if not target:
		return p_ctx.clock.wait(发弹间隔)

	var 帧间隔 := get_dt()

	发弹点当前角速度 += 发弹点角加速度 * 帧间隔
	发弹点当前角度 += 发弹点当前角速度 * 帧间隔

	if 剩余保持时间 > 0.0:
		# 保持阶段：Easy / Normal 倒计时，到点缩回中心；Hard 以上 INF，永不进入。
		if not 难度为Hard以上:
			剩余保持时间 -= 帧间隔
			if 剩余保持时间 <= 0.0:
				发弹点当前半径 = 发弹点起始半径
				发弹点当前半径增加速度 = 发弹点半径增加速度
				发弹点当前角度 = RNG.randf() * TAU
	else:
		# 扩张阶段：半径加速外扩，到上限后转入保持。
		发弹点当前半径增加速度 += 发弹点半径增加加速度 * 帧间隔
		发弹点当前半径 += 发弹点当前半径增加速度 * 帧间隔
		if 发弹点当前半径 >= 发弹点半径上限:
			发弹点当前半径 = 发弹点半径上限
			剩余保持时间 = 保持旋转时间

	# 发弹点 = Boss 中心 + 半径方向 × 当前半径；跟着 Boss 一起移动。
	var 发弹点坐标: Vector2 = target.global_position \
		+ Vector2(cos(发弹点当前角度), sin(发弹点当前角度)) * 发弹点当前半径

	# 防近身：发弹点离自机太近时，这一发直接跳过。
	var player := p_ctx.player.get_player()
	if player and 发弹点坐标.distance_to(player.global_position) < 发弹安全距离:
		return p_ctx.clock.wait(发弹间隔)

	# 主发射：把 `个数` 颗往返弹铺满一圈。
	# 基准方向：Easy / Normal 指向 Boss；Hard 以上取发弹点前进方向的切线。
	var 往返弹方向: Vector2
	if 难度为Hard以上:
		往返弹方向 = Vector2(-sin(发弹点当前角度), cos(发弹点当前角度))
	else:
		往返弹方向 = Vector2(-cos(发弹点当前角度), -sin(发弹点当前角度))

	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
	var 夹角弹角度间隔 := TAU / 个数
	for i in 个数:
		p_ctx.bullets.shoot_spread_spec(
			往返弹, 1, 0.0,
			往返弹方向.rotated(夹角弹角度间隔 * i),
			发弹点坐标)

	return p_ctx.clock.wait(发弹间隔)

extends CoroutineScript
## 卡摩瑞二非「非符二」
##
## 金色米弹每波向外开一圈，每开一圈速度略增；米弹撞到左/右/上墙后，
## 生成一颗沿 Boss 方向缓慢回弹的水色棱弹。
##
## 波与波之间靠 `波次正负交替` 翻转回弹的附加角，让相邻两波的反弹方向相反。

## 两波之间的等待（秒）。
var 波间隔: float = 3.0
## 每波发射的圈数。
var 开花弹次数: int = diff_pick([6, 10, 14, 18])
## 圈与圈之间的间隔（秒）；很小，观感上接近连续开花。
var 波内两次开花间隔: float = 0.01

## Easy / Normal 的波次计时。
var 距下一波计时: float = 2.4
var 波内距下次开花计时: float = 0.0
var 波内剩余开花弹次数: int = 0
## 当前波已经发到第几圈。
var 本波已发圈数: int = 0
## 回弹附加角的符号：每波翻转一次，取 +1 / -1。
var 波次正负交替: int = 1
## 每一圈的整体旋转角。
var 随机角度: Vector2

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 开花弹: SpawnSpec
var 反弹弹: SpawnSpec
## 撞墙后回弹的子弹出模板；首次 _tick 注册。
var 回弹模板: EmitTemplate


func _on_start() -> void:
	开花弹 = SpawnSpec.new().tex("米弹").color(Color.GOLD).blend(true).enemy()
	反弹弹 = SpawnSpec.new().tex("棱弹").color(Color.AQUA).blend(true).enemy()
	回弹模板 = EmitTemplate.new(&"卡摩瑞二非_rebound", 反弹弹)


func _tick(p_ctx: StageContext) -> Variant:
	if not p_ctx.bullets.has_emit_template(&"卡摩瑞二非_rebound"):
		if not p_ctx.bullets.register_emit_template(回弹模板):
			push_error("[卡摩瑞二非] 回弹模板注册失败")
			return false
	if not target:
		return p_ctx.clock.wait(波间隔)

	var 帧间隔 := get_dt()

	if 波内剩余开花弹次数 > 0:
		# 波内：按间隔逐圈发射。
		波内距下次开花计时 += 帧间隔
		if 波内距下次开花计时 >= 波内两次开花间隔:
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 -= 1
			发射一圈(p_ctx)
	else:
		# 波间：等下一波。
		距下一波计时 += 帧间隔
		if 距下一波计时 >= 波间隔:
			波次正负交替 = -波次正负交替
			距下一波计时 = 0.0
			波内距下次开花计时 = 0.0
			波内剩余开花弹次数 = 开花弹次数
			本波已发圈数 = 0
			随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
			p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])

	return true


## 发射当前波的一圈：米弹向外扩散，撞墙后生成回弹棱弹。
func 发射一圈(p_ctx: StageContext) -> void:
	var 个数: int = diff_pick([10, 15, 20, 25])
	# 每多开一圈，初速度提高；Hard 以上增得更快。
	var 速度: float = 5.0 + 本波已发圈数 * diff_pick([35.0, 30.0, 25.0, 20.0])
	本波已发圈数 += 1

	var 单圈附加角: float = 波次正负交替 * 本波已发圈数 * (TAU / 开花弹次数)
	开花弹.speed(速度)
	开花弹.with_behavior(BulletBehaviors.bounce_emit(
		回弹模板, 150.0, 100.0 - 本波已发圈数 * 4.0, 单圈附加角, false))

	p_ctx.bullets.shoot_spread_spec(开花弹, 个数, TAU, 随机角度, target.global_position)

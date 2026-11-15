extends AsyncCoroutineScript
## 卡摩瑞一非「非符一」
##
## 水色棱弹一圈一圈向外扩，速度逐圈提高；棱弹撞到左/右/上墙后，
## 生成一颗金色米弹，朝 Boss 方向回弹。回弹角按“当前圈相对本波中点”偏移，
## 所以同一波里前半圈与后半圈的反弹方向是镜像的。
##
## 这里用 `data/patterns/ring.gd` 作为可复用的“开环”模式：模板、数量、速度
## 每次由本脚本传入，模式本身不持有卡牌身份。

const 环弹模式脚本 := preload("res://data/patterns/ring.gd")
const 环弹参数脚本 := preload("res://scripts/patterns/pattern_params.gd")

## 两波之间的等待（秒）。
var 波间隔: float = 2.4
## 每波发射的圈数（按难度取）。
var 开花弹次数: Array = [3, 5, 7, 9]
## 圈与圈之间的间隔（秒）；很小，观感上接近连续。
var 波内两次开花间隔: float = 0.01
## 每圈回弹附加角的基准增量（按难度取）。
var 反弹附加角递增: Array = [0.1, 0.1, 0.075, 0.075]

## 当前波已经发到第几圈。
var 本波已发圈数: int = 0
## 回弹附加角的符号：每波翻转一次，取 +1 / -1。
var 波次正负交替: int = 1
## 每一圈的整体旋转角。
var 随机角度: Vector2

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 开花弹: SpawnSpec
var 反弹弹: SpawnSpec
var 环弹模式: BulletPattern
var 环弹参数: PatternParams
## 撞墙后回弹的子弹出模板；run_async 注册到 ctx.bullets。
var 回弹模板: EmitTemplate
## 撞墙音效的 behavior sfx id。


func _on_start() -> void:
	开花弹 = SpawnSpec.new().tex("棱弹").color(Color.AQUA).blend(true).enemy()
	反弹弹 = SpawnSpec.new().tex("米弹").color(Color.GOLD).blend(true).enemy()
	环弹模式 = 环弹模式脚本.new()
	环弹参数 = 环弹参数脚本.new()
	回弹模板 = EmitTemplate.new(&"卡摩瑞一非_rebound", 反弹弹)


## 模板 / 音效是卡级资源；与每波发弹解耦，失败时响亮返回。
func _ensure_rebound_resources(p_ctx: StageContext) -> bool:
	if not p_ctx.bullets.register_emit_template(回弹模板):
		push_error("[卡摩瑞一非] 回弹模板注册失败：%s" % p_ctx.bullets.bullet_manager.system.emit_templates.last_errors())
		return false
	return true


func run_async(p_ctx: StageContext) -> void:
	if not _ensure_rebound_resources(p_ctx):
		return
	while p_ctx.active():
		if not await p_ctx.clock.delay(波间隔):
			return
		if not target:
			continue

		波次正负交替 = -波次正负交替
		本波已发圈数 = 0
		随机角度 = Vector2.DOWN.rotated(RNG.randf() * TAU)
		p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])

		var 本波开花次数: int = diff_pick(开花弹次数)
		for _i in 本波开花次数:
			发射一圈(p_ctx, 本波开花次数)
			if not await p_ctx.clock.delay(波内两次开花间隔):
				return


## 发射当前波的一圈：棱弹向外扩，撞墙后生成回弹米弹。
func 发射一圈(p_ctx: StageContext, 本波开花次数: int) -> void:
	var 个数: int = diff_pick([15, 20, 25, 30])
	# 每多开一圈，初速度提高；Hard 以上增得更快。
	var 速度: float = 5.0 + 本波已发圈数 * diff_pick([55.0, 50.0, 45.0, 40.0])
	# 相对本波中点偏移：前半圈为负、后半圈为正，再乘波次方向。
	var 单圈反弹附加角: float = diff_pick(反弹附加角递增) \
		* (本波已发圈数 - 本波开花次数 / 2.0) * 波次正负交替
	本波已发圈数 += 1

	var 本圈加速度: float = 100.0 - 本波已发圈数 * 4.0
	开花弹.speed(速度)
	开花弹.with_behavior(BulletBehaviors.bounce_emit(
		回弹模板, 0.0, 本圈加速度, 单圈反弹附加角, true))

	# 环弹模式复用同一份 SpawnSpec：颜色 / 阵营 / 运动都不变，只换本次数量与速度。
	环弹参数.template = 开花弹
	环弹参数.count = 个数
	环弹参数.speed = 速度
	环弹模式.fire(p_ctx, 环弹参数, target.global_position, 随机角度)

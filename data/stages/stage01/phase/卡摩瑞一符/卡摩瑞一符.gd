extends CoroutineScript
## 卡摩瑞一符「音符「定点扩散」」
##
## 三颗弹的分工：
## - 开花弹：红鳞弹，沿当前朝向加速，撞到左/右/上墙后向 Boss 反射一颗，再消失。
## - 反射弹：蓝鳞弹，Hard 以上额外受向下重力；由开花弹撞墙时生成。
## - 种子弹：中玉，飞行途中减速到 0，并在减速过程中向四周吐出开花弹。
##
## 难度分派：Hard 以上直接撒一圈开花弹；Easy / Normal 只发一颗种子弹，
## 让开花弹沿着种子弹的飞行路径自然展开。

## 两次发射的间隔（秒）。
var 发射间隔: float = diff_pick([2.0, 1.75, 1.5, 1.25])
## Hard 以上一圈开花弹的数量。
var 个数: int = diff_pick([25, 35, 45, 50])
## 开花弹沿当前朝向的加速度（像素/秒²）。
const 开花弹加速度: float = 200.0
## 开花弹撞墙后生成的反射弹速度。
const 反射弹速度: float = 150.0
## 种子弹初速度与总飞行距离；飞行时间由这两项算出。
const 种子弹速度: float = 260.0
const 种子弹飞行距离: float = 160.0

## 复用弹型实例：弹型缓存在 SpawnSpec 上，禁止每发 new。
var 种子弹: SpawnSpec
var 开花弹: SpawnSpec
var 反射弹: SpawnSpec
var 反射模板: EmitTemplate
var 开花模板: EmitTemplate
var 种子模板: EmitTemplate


func _on_start() -> void:
	# 反射弹：由开花弹撞墙时生成；Hard 以上带一点下坠。
	反射弹 = SpawnSpec.new().tex("鳞弹").color(Color.CORNFLOWER_BLUE).blend(true).enemy()
	if SaveData.selected_difficulty >= Difficulty.HARD:
		var 反射弹重力: float = diff_pick([0.0, 0.0, 25.0, 35.0])
		反射弹.with_behavior(BulletBehaviors.accel(Vector2(0.0, 反射弹重力)))

	# 开花弹：撞墙后生成反射弹。
	开花弹 = SpawnSpec.new().tex("鳞弹").color(Color.RED).blend(true).enemy()

	# 种子弹：线性减速到 0，结束时向四周生成开花弹。
	var 开花弹速度: float = diff_pick([50.0, 35.0, 20.0, 5.0])
	var 种子弹飞行时间: float = 2.0 * 种子弹飞行距离 / 种子弹速度
	种子弹 = SpawnSpec.new().tex("中玉").speed(种子弹速度).color(Color.RED).blend(true).enemy()

	反射模板 = EmitTemplate.new(&"卡摩瑞一符_reflect", 反射弹)
	开花模板 = EmitTemplate.new(&"卡摩瑞一符_flower", 开花弹)
	种子模板 = EmitTemplate.new(&"卡摩瑞一符_seed", 种子弹)
	_种子飞行时间 = 种子弹飞行时间
	_开花弹速度 = 开花弹速度


var _种子飞行时间: float = 0.0
var _开花弹速度: float = 0.0


func _ensure_card_behaviors(p_ctx: StageContext) -> bool:
	if 反射模板 == null or 开花模板 == null or 种子模板 == null:
		return false
	for tpl in [反射模板, 开花模板, 种子模板]:
		if not p_ctx.bullets.register_emit_template(tpl):
			push_error("[卡摩瑞一符] 模板注册失败：%s" % tpl.id)
			return false
	if 开花弹.behavior == null:
		开花弹.with_behavior(BulletBehaviors.bounce_emit(反射模板, 反射弹速度, 开花弹加速度, 0.0, true))
	if 种子弹.behavior == null:
		种子弹.with_behavior(BulletBehaviors.seed_burst(
			开花模板, _种子飞行时间, 种子弹速度, 个数, _开花弹速度, TAU))
	return true


func _tick(p_ctx: StageContext) -> Variant:
	if not _ensure_card_behaviors(p_ctx):
		return false
	if not target:
		return p_ctx.clock.wait(发射间隔)

	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"])
	if SaveData.selected_difficulty >= Difficulty.HARD:
		# Hard 以上：一圈开花弹；整圈随机旋转，避免每次都从同一角度开始。
		var 随机角度 := Vector2.DOWN.rotated(RNG.randf() * TAU)
		# 路径预测试验：一行发射 + 跟踪整圈真实弹。
		p_ctx.bullets.shoot_spread(
			开花弹, 个数, TAU, 随机角度, target.global_position)
	else:
		# Easy / Normal：只发一颗种子弹，落点略随机；开花弹由种子弹自己生成。
		var 随机角度 := Vector2.DOWN.rotated(deg_to_rad(RNG.randf_range(-30.0, 30.0)))
		p_ctx.bullets.shoot(种子弹, target.global_position, 随机角度)

	return p_ctx.clock.wait(发射间隔)

extends CoroutineScript
## 符卡一：先射一颗种子弹，沿发射方向飞一段距离后原地炸开成一圈弹，种子自灭。
##
## 炸圈完全由描述符相位结束时的多个 `emit` 完成 —— 全程原生，内容零回调：
## 每颗圈弹方向 = `forward(i/n · TAU)`（以种子弹自身朝向为 0 起 n 等分），
## 所以每轮只要随机种子的发射方向，整圈就跟着转，**program 不随随机角增长**。

## —— 可调参数（可经 PhaseData.params 同名注入）——
var _interval: float = 1.2        # 发射间隔（秒）
var _seed_speed: float = 260.0    # 种子弹速度（px/s）
var _seed_dist: float = 160.0     # 种子弹飞行距离（px），到点炸圈
var _ring_count: Array = [14, 18, 22, 26]              # 每圈弹数（Easy/Normal/Hard/Lunatic）
var _ring_speed: Array = [150.0, 180.0, 210.0, 240.0]  # 圈弹速度（px/s）

## 复用实例（弹型缓存在实例上；禁止每发 new）
var _seed_bullet_data: BulletData
var _ring_bullet_data: BulletData


func _tick(p_ctx: StageContext) -> Variant:
	if not target:
		return p_ctx.clock.wait(_interval)
	if _seed_bullet_data == null:
		_build()

	var dir := Vector2.DOWN.rotated(RNG.randf() * TAU)   # 随机种子方向（RNG 可复现）
	p_ctx.bullets.shoot_spread(_seed_bullet_data, 1, 0.0, dir, target.global_position)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -12.0)
	return p_ctx.clock.wait(_interval)


func _build() -> void:
	_seed_bullet_data = BulletData.new().tex("小玉").speed(_seed_speed)\
		.color(Color(0.45, 0.9, 1.5)).blend(true).enemy()
	_ring_bullet_data = BulletData.new().tex("鳞弹")\
		.color(Color(0.45, 0.9, 1.5)).blend(true).enemy()

	var count: int = int(diff_pick(_ring_count))
	var speed: float = float(diff_pick(_ring_speed))
	var lc := BulletLifecycle.new()
	lc.until_elapsed(_seed_dist / _seed_speed)   # 相位：沿出生方向自由飞（无 move）
	for i in count:
		lc.emit(_ring_bullet_data, BulletLifecycle.forward(TAU * float(i) / float(count)), speed)
	lc.despawn()   # 炸完自灭
	_seed_bullet_data.trajectory(lc)

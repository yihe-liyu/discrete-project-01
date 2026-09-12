extends CoroutineScript
## 沿初始发射方向加速（径向扩散弹）
## 用法：挂到 BulletData.coroutine_script 上
## 首次 tick 记录子弹发射方向（初始速度方向 = 发射角度），此后沿该方向恒定加速

var accel_rate: float = 150.0  ## 加速度（px/s²），可用 param("accel_rate", v) 注入
var _dir := Vector2.ZERO       ## 发射方向（首次 tick 记录并固定）


func _tick(_ctx: StageContext) -> Variant:
	if not is_instance_valid(target):
		return false
	var bullet = target
	var dt := get_dt()
	if _dir == Vector2.ZERO:
		_dir = bullet.velocity.normalized()  # 初始速度方向 = 发射角度
	if _dir == Vector2.ZERO:
		return true  # 无初速子弹保持静止
	# 击中上版边：删除自己 + 生成竖直向下匀速弹（保留速度大小）
	if bullet.global_position.y <= GameConfig.FIELD_TOP:
		_spawn_downward(bullet, _ctx)
		return false
	bullet.velocity += _dir * accel_rate * dt
	bullet.global_position += bullet.velocity * dt
	bullet.rotation = bullet.velocity.angle()
	return true


## 原地重新发射成竖直向下匀速弹（复用原弹，保留速度大小），回收自己（行为协程结束）
func _spawn_downward(bullet, _ctx: StageContext) -> void:
	var b := BulletData.new().enemy()
	b.tex("米弹").color(Color.FUCHSIA).blend(true)
	b.velocity = Vector2(0, bullet.velocity.length())  # 保留速度大小，方向竖直向下
	_ctx.audio.play_sfx(AssetRegistry.sounds["kira"], -6)
	BulletManager.re_fire(bullet, b, Vector2.DOWN, Vector2(bullet.global_position.x, GameConfig.FIELD_TOP))


## 内核端口（Track A / S4c-1）：加速 + 顶边换向下弹。替换弹用**工厂**（每次新对象）。
func kernel_port() -> Dictionary:
	return {
		"move": &"radial_accel",
		"params": {
			&"accel_rate": accel_rate,
			&"spawn_factory": Callable(self, "_kernel_make_down"),
			&"sfx": "kira",
			&"sfx_db": -6.0,
		},
	}


## 替换弹工厂：每次调用返回一颗**新** BulletData（不复用共享模板，避免 duplicate 丢贴图）。
func _kernel_make_down() -> BulletData:
	var b := BulletData.new()
	b.tex("米弹").color(Color.FUCHSIA).blend(true).enemy()
	return b

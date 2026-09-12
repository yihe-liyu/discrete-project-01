extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：从发射口（子机）生成，向上漂移
## 每段 drift 从 0 开始（根部在子机），段间距 = 漂移速度 × 生成间隔（自动无缝）
## 松开射击（非 focus）时整条激光渐隐消失
## bullet.extra：
##   anchor_node   发射口节点（子机），无效时回退自机
##   laser_offset  相对锚点偏移（默认 (0,0) = 在发射口生成）
##   drift_speed   向上漂移速度

const FADE_TIME: float = 0.2   # 渐隐时长（秒）

var _drift: float = 0.0
var _fading: bool = false
var _fade_t: float = 0.0

## 内核端口参数（由 BulletData.params 注入；旧池路径可不用）。
## 命名 port_* 避开旧 lambda 里的局部 drift_speed / drift_angle（否则 shadow 警告）。
var port_anchor_id: int = 0
var port_anchor_offset: Vector2 = Vector2.ZERO
var port_drift_speed: float = 2000.0
var port_drift_angle: float = 0.0


func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target:
		target = p_target
	_drift = 0.0
	_fading = false
	_fade_t = 0.0

	var tl := start_timeline()
	tl.every(0).do(func():
		if not ctx.active() or not is_instance_valid(target):
			return false
		var dt := get_dt()

		# 位置更新：持续向上漂移（包括渐隐期间，激光边淡出边飞走）
		var extra: Variant = target.get("extra")
		var off: Vector2 = Vector2.ZERO
		var drift_speed: float = 0.0
		var drift_angle: float = 0.0
		var anchor: Vector2 = Vector2.ZERO
		var anchor_found := false
		if extra is Dictionary:
			off = extra.get("laser_offset", Vector2.ZERO)
			drift_speed = extra.get("drift_speed", 0.0)
			drift_angle = extra.get("drift_angle", 0.0)  # 弧度，0=垂直向上
			var anchor_node: Variant = extra.get("anchor_node")
			if anchor_node != null and is_instance_valid(anchor_node):
				anchor = anchor_node.global_position
				anchor_found = true
		if not anchor_found:
			var player := ctx.player.get_player()
			if not is_instance_valid(player):
				return false
			anchor = player.global_position
		# 沿角度方向漂移（0=垂直向上，正角=右偏）
		var dir := Vector2(sin(drift_angle), -cos(drift_angle))
		target.global_position = anchor + off + dir * _drift
		_drift += drift_speed * dt
		# 击中特效继承激光移动方向（bullet_physics 用 velocity 做特效方向；
		# HitEffect.set_velocity 只取 normalized 方向，量级无所谓）
		target.velocity = dir

		# 松开射击 或 进入 focus → 开始渐隐（激光只在"非focus+按住射击"时存在）
		if not _fading and (not Input.is_action_pressed("shoot") or Input.is_action_pressed("focus")):
			_fading = true
			_fade_t = FADE_TIME

		if _fading:
			_fade_t -= dt
			var alpha := clampf(_fade_t / FADE_TIME, 0.0, 1.0)
			var sprite: Sprite2D = target.get_node_or_null("Sprite2D")
			if sprite:
				sprite.modulate.a = alpha  # MultiMesh 用 sprite.modulate 上色 → 淡出生效
			if _fade_t <= 0.0:
				BulletManager.return_bullet(target)  # 淡完回收
				return false  # 协程结束
		return true
	)
	super.start(ctx, target)


## 内核端口（Track A / S4c-4）：漂移复用内核 laser_follow；整批渐隐由 MarisaLaserFade 管。
func kernel_port() -> Dictionary:
	return {
		"move": &"marisa_laser",
		"params": {
			&"anchor_id": port_anchor_id,
			&"anchor_offset": port_anchor_offset,
			&"drift_speed": port_drift_speed,
			&"angle": port_drift_angle,
		},
	}

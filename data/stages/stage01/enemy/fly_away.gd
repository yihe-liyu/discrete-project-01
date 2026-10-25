extends CoroutineScript
## 让 target 沿随机方向加速飘走退场。
##
## 只负责“离开画面”，不做死亡演出、不掉道具；出屏后静默回收。
## 方向在上方 ±60° 内随机，速度从 0 开始缓慢增加，观感像被吹飞。

## 出屏宽限（像素）：完全离开视口再多飞一点，避免边缘残留。
const OUT_OF_SCREEN_MARGIN: float = 90.0

var _退场方向: Vector2
var _退场速度: float = 0.0


func _init() -> void:
	auto_stop = true


func _on_start() -> void:
	_退场方向 = Vector2.UP.rotated(RNG.randf_range(-PI / 3.0, PI / 3.0))


func _tick(_ctx: StageContext) -> Variant:
	var 帧间隔 := get_dt()
	target.global_position += _退场方向 * _退场速度 * 帧间隔
	_退场速度 += 50.0 * 帧间隔

	# 出屏后自动消除。视口尺寸取当前 target 所在视口，兼容不同宿主。
	var 视口矩形 := target.get_viewport().get_visible_rect()
	if target.global_position.x < -OUT_OF_SCREEN_MARGIN \
		or target.global_position.x > 视口矩形.size.x + OUT_OF_SCREEN_MARGIN \
		or target.global_position.y < -OUT_OF_SCREEN_MARGIN \
		or target.global_position.y > 视口矩形.size.y + OUT_OF_SCREEN_MARGIN:
		if is_instance_valid(target):
			ctx.enemies.despawn(target)   # 静默回收；注销由 Enemy 自动做。
		return false
	return true

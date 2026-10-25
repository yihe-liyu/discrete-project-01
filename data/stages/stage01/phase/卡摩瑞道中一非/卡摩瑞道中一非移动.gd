extends CoroutineScript
## 卡摩瑞道中一非 · 移动
##
## Boss 沿正弦波左右漂移，y 坐标保持不变。正弦在两端斜率最小、在中心斜率最大，
## 所以观感是“到边上自然减速、回中间自然加速”，不需要额外的缓动曲线。

## 漂移中心（场地中线）。
const 中心x: float = 448.0
## 左右振幅（像素）。
const 振幅: float = 200.0
## 一个完整来回的周期（秒）。
const 周期: float = 6.0

var _计时: float = 0.0


func _tick(_ctx: StageContext) -> Variant:
	if not target:
		return true

	_计时 += get_dt()
	target.global_position.x = 中心x + sin(_计时 * TAU / 周期) * 振幅

	return true

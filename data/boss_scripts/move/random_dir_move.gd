extends CoroutineScript
## 随机方向移动：每隔 jump_interval 秒随机选一个方向（360°），移动固定距离
## 目标点 clamp 在游戏框上方区域（x 留边距、y 限制 top_min_y~top_max_y）
## RNG 可复现；tween 物理模式
## auto_stop = false（持续运行直到 phase 结束）


var jump_interval: float = 5   # 移动间隔（秒）
var move_time: float = 1.2       # 单次移动耗时（秒，tween 时长）
var move_distance: float = 120.0 # 单次移动距离（像素）
var margin: float = 180.0         # 左右边界留白（像素，防贴边）
var top_min_y: float = 240.0     # y 下限（上方区域）
var top_max_y: float = 320.0     # y 上限

var _计时: float = 0.0


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(jump_interval)
	_计时 += get_dt()
	if _计时 >= jump_interval:
		_计时 = 0.0
		_jump(p_ctx)
	return true


## 随机方向 + 固定距离 → 目标点 clamp 到游戏框上方区域
func _jump(p_ctx: StageContext) -> void:
	var 移动方向 := Vector2.RIGHT.rotated(RNG.randf() * TAU)
	var 目标点 := target.global_position + 移动方向 * move_distance
	目标点.x = clampf(目标点.x, GameConfig.FIELD_LEFT + margin, GameConfig.FIELD_RIGHT - margin)
	目标点.y = clampf(目标点.y, top_min_y, top_max_y)
	p_ctx.boss.move_to(target, 目标点, move_time, Tween.EASE_IN_OUT, Tween.TRANS_QUAD)

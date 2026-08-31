extends CoroutineScript
## 随机方向移动：每隔 jump_interval 秒随机选一个方向（360°），移动固定距离
## 目标点 clamp 在游戏框上方区域（x 留边距、y 限制 top_min_y~top_max_y）
## RNG 可复现；tween 物理模式
## auto_stop = false（持续运行直到 phase 结束）

const META := {
	"name": "随机方向移动",
	"desc": "每隔 jump_interval 秒随机选一个方向（360°），移动固定距离；目标点限制在框上方。",
}

var jump_interval: float = 5   # 移动间隔（秒）
var move_time: float = 1.2       # 单次移动耗时（秒，tween 时长）
var move_distance: float = 120.0 # 单次移动距离（像素）
var margin: float = 120.0         # 左右边界留白（像素，防贴边）
var top_min_y: float = 180.0     # y 下限（上方区域）
var top_max_y: float = 380.0     # y 上限

var _t: float = 0.0


func _tick(p_ctx: StageContext):
	if not target:
		return p_ctx.clock.wait(jump_interval)
	_t += get_dt()
	if _t >= jump_interval:
		_t = 0.0
		_jump()
	return true


## 随机方向 + 固定距离 → 目标点 clamp 到游戏框上方区域
func _jump() -> void:
	var dir := Vector2.RIGHT.rotated(RNG.randf() * TAU)
	var dest := target.global_position + dir * move_distance
	dest.x = clampf(dest.x, GameConfig.FIELD_LEFT + margin, GameConfig.FIELD_RIGHT - margin)
	dest.y = clampf(dest.y, top_min_y, top_max_y)
	var tw := target.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "global_position", dest, move_time)

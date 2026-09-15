extends CoroutineRunner
class_name CoroutineScript
## 通用协程脚本 —— 替代 CreateScript / MoveScript / EnemyScript / StageScript / BackgroundScript
##
## auto_stop = true  → _tick 返回 false 时自动结束（原 CreateScript 语义）
## auto_stop = false → 持续运行直到被 stop()（原 MoveScript/EnemyScript 语义）
##
## 用法：
##   var s := CoroutineScript.new()
##   s.auto_stop = true
##   s.target = enemy           # 可选，要控制的节点
##   add_child(s)
##   s.start(ctx)
##   s.start_timeline().at(0.0).every(0.5).do(func(): shoot())

var ctx: StageContext
## 要控制的节点（可选）。设置后可在 _tick/timeline 中访问。
var target: Node2D
## true=播完即止，false=持续运行
var auto_stop: bool = false
var _timeline: Timeline


## 创建 Timeline（纯排程器；动作由内容在 do(callable) 里自带环境）
func start_timeline() -> Timeline:
	_timeline = Timeline.new()
	return _timeline


## 启动协程
func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target != null:
		target = p_target
	run(_tick.bind(ctx))


## 每帧回调。覆写此方法可实现自定义逻辑（不用 Timeline）
func _tick(_ctx: StageContext) -> Variant:
	if _timeline:
		var is_alive := _timeline.tick(get_dt())
		if not is_alive and auto_stop:
			return false
		return true
	return not auto_stop


## 根据当前难度从数组取对应值
func diff_pick(arr: Array) -> Variant:
	return arr[SaveData.selected_difficulty]


## 根据当前难度从嵌套字典取对应值
func diff_get(dict: Dictionary, key: String, default = null):
	return dict.get(SaveData.selected_difficulty, {}).get(key, default)

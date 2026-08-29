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
var _tl: Timeline


## 创建并绑定 Timeline（stage 关卡传入导演，便捷动词由导演统一承担）
func start_timeline(p_director: StageDirector = null) -> Timeline:
	_tl = Timeline.new(ctx)
	_tl.director = p_director
	return _tl


## 当前时间线（工作台书签收集/调试用）
func get_timeline() -> Timeline:
	return _tl


## 启动协程
func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	if p_target != null:
		target = p_target
	run(_tick.bind(ctx))


# ═══ 快速模式（子弹协程专用）═══
# 常规模式：Task + Callable + 调度循环（wait/并行/暂停 全支持）
# 快速模式：直接调 _tick，绕过全部调度层（快 2-3 倍）——适合"每帧型"子弹协程

var _fast_wait_left: float = 0.0


## 快速模式启动（子弹协程）：不创建 Task、不依赖 runner 调度
## 关键：调用子类覆写的 start()（初始化/建 timeline 照常），只是 run() 跳过 Task
func start_fast(p_ctx: StageContext, p_target: Node2D = null) -> void:
	_fast_mode = true
	start(p_ctx, p_target)
	is_running = true
	_fast_wait_left = 0.0


## 快速模式每帧推进：直接调 _tick（返回约定同 _tick：true=继续 / false=结束 / float=等待）
func tick_fast(dt: float) -> bool:
	_last_dt = dt
	if _fast_wait_left > 0.0:
		_fast_wait_left -= dt
		return true
	var result = _tick(ctx)
	if typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
		if result > 0:
			_fast_wait_left = result
			return true
		is_running = false
		return false
	if result == true:
		return true
	is_running = false
	return false


## 每帧回调。覆写此方法可实现自定义逻辑（不用 Timeline）
func _tick(_ctx: StageContext) -> Variant:
	if _tl:
		var alive := _tl.tick(get_dt())
		if not alive and auto_stop:
			return false
		return true
	return not auto_stop


## 根据当前难度从数组取对应值
func diff_pick(arr: Array) -> Variant:
	return arr[GameState.selected_difficulty]


## 根据当前难度从嵌套字典取对应值
func diff_get(dict: Dictionary, key: String, default = null):
	return dict.get(GameState.selected_difficulty, {}).get(key, default)

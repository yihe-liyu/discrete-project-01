extends Node
class_name CoroutineRunner
## 协程调度器 —— 所有任务在 _physics_process 里步进
##
## 为什么用这个代替 Tween/Timer？
## 1. 暂停不追帧：_clock 只在 _physics_process 中累加，tree.paused 时自动冻结
## 2. Replay 可复现：_clock 从 0 开始，可通过外部设置 _clock 实现快进
## 3. 复杂时序：run_parallel 支持多任务并行，返回值约定可表达等待/条件
##
## 每个任务是一个 callable，每帧被调用，返回值约定：
##   float/int > 0  → 等待这么秒后再次调用
##   true           → 下帧立即再次调用（等价于等待 0 帧）
##   false / null   → 任务结束，移除
##
## run()      — 先清掉所有旧任务再启动
## run_parallel() — 追加一个并行任务
## pause()/resume() — 临时冻结时钟（任务保留），对话/演出期间使用
##
## 计时方式：累积 _physics_process 的 delta，暂停时不累积。
## 恢复后不会追帧，时钟从暂停处继续。

signal finished()

var is_running: bool = false
var _is_paused: bool = false
var _tasks: Array[Task] = []
var _clock: float = 0.0  # 游戏内时间（物理帧累积，暂停时冻结）
var _last_dt: float = 0.0  # 当前帧物理步长（time_scale 生效；节点/无节点模式一致）


## 当前帧物理步长（协程脚本用这个代替 get_physics_process_delta_time()：
## 无节点模式（子弹协程）下引擎不更新树外节点的 delta，直接调会返回 0！）
func get_dt() -> float:
	return _last_dt


## 游戏内时间访问器（工作台/调试/Replay 用）
func game_time() -> float:
	return _clock


class Task extends RefCounted:
	var callable: Callable
	var wake_time: float = 0.0


func run(method: Callable):
	stop()
	_clock = 0.0
	_start_task(method)

func run_parallel(method: Callable):
	_start_task(method)

func _start_task(method: Callable):
	var task := Task.new()
	task.callable = method
	task.wake_time = _clock  # 第一帧立即执行
	_tasks.append(task)
	is_running = true

func stop():
	if not is_running:
		return
	_is_paused = false
	for task in _tasks:
		task.callable = Callable()
	_tasks.clear()
	is_running = false


## 临时暂停：冻结时钟，任务保留（恢复后继续）
func pause() -> void:
	if not is_running:
		return
	_is_paused = true


## 恢复运行（时钟从暂停处继续）
func resume() -> void:
	_is_paused = false


func _physics_process(_delta: float) -> void:
	if not is_running:
		return
	if _is_paused:
		return  # 暂停时不累积时钟
	_last_dt = get_physics_process_delta_time()  # 用引擎时钟（time_scale 生效，快进/慢动作正确）
	_clock += _last_dt
	_advance_tasks()


## 无树驱动：宿主（测试 / 工具）每帧手动推帧，不依赖引擎 _physics_process 回调。
## 返回 false = 已结束；true = 仍在运行。
func tick_manual(dt: float) -> bool:
	if not is_running:
		return false
	if _is_paused:
		return true
	_last_dt = dt
	_clock += dt
	_advance_tasks()
	return is_running


func _advance_tasks() -> void:
	for i in range(_tasks.size() - 1, -1, -1):
		var task := _tasks[i]
		if not task.callable.is_valid():
			_tasks.remove_at(i)
			continue

		if task.wake_time > _clock:
			continue

		var result = task.callable.call()

		if typeof(result) == TYPE_FLOAT or typeof(result) == TYPE_INT:
			if result > 0:
				task.wake_time = _clock + result
			else:
				_tasks.remove_at(i)
		elif result == true:
			pass  # 下帧立即再次调用
		else:
			_tasks.remove_at(i)

	if _tasks.is_empty() and is_running:
		is_running = false
		finished.emit()

func _exit_tree():
	stop()

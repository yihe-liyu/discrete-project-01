## 时间服务 —— 协程等待的唯一时钟。
##
## 两种用法共用同一个 [CoroutineRunner] 时钟：
##   - 旧 [code]_tick[/code] 风格：[code]return ctx.clock.wait(0.5)[/code]（返回秒数给 runner）
##   - 新 async 风格：[code]await ctx.clock.delay(0.5)[/code]（等 runner.ticked，暂停/逐帧/快进都一致）
##
## 不要用 [code]get_tree().create_timer()[/code] 代替 —— 那是引擎时间，不是内容时钟。
class_name ClockService
extends RefCounted

## 共用的协程时钟；[method delay] / [method next_tick] 都等它的 ticked，null 时立即返回 false。
var runner: CoroutineRunner


## 旧 _tick 风格：返回 seconds，交给 runner 计时。
func wait(seconds: float) -> float:
	return seconds


## 返回 count 个物理帧对应的秒数。
func wait_frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second


## 等一个物理 tick。返回 false = runner 已停（调用方应退出）。
func next_tick() -> bool:
	if runner == null or not runner.is_running:
		return false
	await runner.ticked
	return runner.is_running


## 等 seconds 个游戏秒。返回 false = 等待期间 runner 被停。
## 只等 [code]runner.ticked[/code]，所以 runner.pause()/tree.paused 会挂起，tick_manual/快进会推进。
func delay(seconds: float) -> bool:
	if runner == null or not runner.is_running:
		return false
	if seconds <= 0.0:
		return true
	var target := runner.game_time() + seconds
	while runner.is_running and runner.game_time() < target:
		await runner.ticked
	return runner.is_running

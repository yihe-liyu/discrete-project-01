## 时间服务 —— 协程等待的**唯一时钟**。
##
## 两种用法共用同一个 [CoroutineRunner] 时钟：
##   - 旧 `_tick` 风格：`return ctx.clock.wait(0.5)`（返回秒数给 runner）
##   - 新 async 风格：`await ctx.clock.delay(0.5)`（等 runner.ticked，暂停/逐帧/快进都一致）
##
## ⚠️ 不要用 `get_tree().create_timer()` 代替 —— 那是引擎时间，不是内容时钟。
class_name ClockService
extends RefCounted

var runner: CoroutineRunner


func wait(seconds: float) -> float:
	return seconds


func wait_frames(count: int) -> float:
	return float(count) / Engine.physics_ticks_per_second


## 等一个物理 tick。返回 false = runner 已停（调用方应退出）。
func next_tick() -> bool:
	if runner == null or not runner.is_running:
		return false
	await runner.ticked
	return runner.is_running


## 等 seconds 个**游戏秒**。返回 false = 等待期间 runner 被停。
## 只等 `runner.ticked`，所以 runner.pause()/tree.paused 会挂起，tick_manual/快进会推进。
func delay(seconds: float) -> bool:
	if runner == null or not runner.is_running:
		return false
	if seconds <= 0.0:
		return true
	var target := runner.game_time() + seconds
	while runner.is_running and runner.game_time() < target:
		await runner.ticked
	return runner.is_running

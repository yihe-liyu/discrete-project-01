extends CoroutineScript
## 测试夹具：`kernel_port()` 直接返回预先拼好的 BulletLifecycle（`{lifecycle}` 入口）。
## 组合不是任何 preset：先 rotate 到转角上限，再沿方向加速，最后 despawn。

var curve_w: float = 2.0
var turn_limit: float = 0.5
var accel_rate: float = 300.0


func kernel_port() -> Dictionary:
	var lc := BulletLifecycle.new()
	lc.rotate(curve_w, turn_limit)
	lc.until_turned()
	lc.then()
	lc.accel_heading(accel_rate)
	lc.until_elapsed(1.0)
	lc.despawn()
	return {"lifecycle": lc}

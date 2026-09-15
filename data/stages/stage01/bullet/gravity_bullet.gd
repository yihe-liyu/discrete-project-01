extends CoroutineScript
## 竖直向下匀加速（重力弹）。
##
## **内核端口载体**：行为实现已移到桥接 `test/reference/behavior/world_accel_behavior.gd`；
## 删旧池后，弹的协程体不再由本项目启动，本文件只把参数翻译成内核端口。

var gravity: float = 200.0  ## 竖直加速度（px/s²，y 向下为正），可用 param("gravity", v) 注入


## 内核端口：竖直向下匀加速 = 世界 accel 行为。
func kernel_port() -> Dictionary:
	return {"move": &"world_accel", "params": {&"world_accel": Vector2(0, gravity)}}

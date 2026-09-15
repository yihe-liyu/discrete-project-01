extends CoroutineScript
class_name MoveHoming
## 诱导弹：转向最近敌人并加速（自机非焦点散射弹）。
##
## **内核端口载体**：行为实现已移到桥接 `test/reference/behavior/homing_behavior.gd`（移植自本文件旧协程体）；
## 删旧池后，弹的协程体不再由本项目启动，本文件只把参数翻译成内核端口。

## 诱导角度每秒（弧度）
var homing_angle_per_sec: float = deg_to_rad(720)
## 从当前速度加速到最高速所需时间（秒），0 表示瞬间满速
var accel_time: float = 2.0
## 最低速度（诱导开始时）
var min_speed: float = 500.0
## 最高速度（0 表示保持初始速度）
var max_speed: float = 2000.0
## 诱导持续多久（秒），0 表示直到离开场景
var homing_duration: float = 2.0
## 距离越近转弯越激进——值越大，远距离诱导越强
var proximity_boost: float = 150.0


## 内核端口：参数交给桥接 HomingBehavior（语义 1:1）。
func kernel_port() -> Dictionary:
	return {
		"move": &"homing",
		"params": {
			&"homing_angle_per_sec": homing_angle_per_sec,
			&"accel_time": accel_time,
			&"min_speed": min_speed,
			&"max_speed": max_speed,
			&"homing_duration": homing_duration,
			&"proximity_boost": proximity_boost,
		},
	}

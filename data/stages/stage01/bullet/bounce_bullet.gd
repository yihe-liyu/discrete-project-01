extends CoroutineScript
## 非符1 专用反弹弹：碰到游戏框（左/右/上，下墙穿出）时，
## 转向朝向 Boss 并旋转 bounce_angle，然后消除自己，原地生成一颗直线弹
## 带加速度 accel（沿飞行方向加速；0 = 匀速）
##
## **内核端口载体**：行为实现已移到桥接 `scripts/kernel_bridge/behavior/bounce_behavior.gd`；
## W4a-2 删旧池后，弹的协程体不再由本项目启动，本文件只把参数翻译成内核端口。

var bounce_angle: float = 0.0  ## 反弹附加角（弧度），发射时决定并固定
var accel: float = 0.0         ## 加速度（px/s²），沿当前飞行方向（0 = 匀速）
var spawn_speed: float = 0.0   ## 替换弹速度（0 = 沿用反弹瞬间速度）


## 内核端口（Track A / S4c-2）：加速 + 碰框换向（朝 Boss）。替换弹用工厂。
func kernel_port() -> Dictionary:
	return {
		"move": &"bounce",
		"params": {
			&"accel": accel,
			&"bounce_angle": bounce_angle,
			&"spawn_factory": Callable(self, "_kernel_make_replacement"),
			&"spawn_speed": spawn_speed,
			&"sfx": "kira",
			&"sfx_db": -8.0,
		},
	}


## 替换弹工厂（每次返回新 BulletData：米弹 / GOLD / blend）。
func _kernel_make_replacement() -> BulletData:
	var b := BulletData.new()
	b.tex("米弹").color(Color.GOLD).blend(true).enemy()
	return b

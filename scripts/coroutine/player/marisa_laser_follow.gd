extends CoroutineScript
class_name MarisaLaserFollow
## 魔理沙非 focus 激光段：从发射口（子机）生成，向上漂移
## 每段 drift 从 0 开始（根部在子机），段间距 = 漂移速度 × 生成间隔（自动无缝）
## 松开射击（非 focus）时整条激光渐隐消失
##
## **内核端口载体**：漂移与整批渐隐的内核实现见桥接
## `scripts/kernel_bridge/behavior/marisa_laser_behavior.gd` + `marisa_laser_fade.gd`；
## 删旧池后，弹的协程体不再由本项目启动。
##
## 端口参数由 `BulletData.params` 注入（见 `scripts/coroutine/player/marisa_shoot.gd`）。

## 内核端口参数（命名 port_* 避开旧 lambda 局部变量 shadow）。
var port_anchor_id: int = 0
var port_anchor_offset: Vector2 = Vector2.ZERO
var port_drift_speed: float = 2000.0
var port_drift_angle: float = 0.0


## 内核端口：漂移复用内核 laser_follow；整批渐隐由 MarisaLaserFade 管。
func kernel_port() -> Dictionary:
	return {
		"move": &"marisa_laser",
		"params": {
			&"anchor_id": port_anchor_id,
			&"anchor_offset": port_anchor_offset,
			&"drift_speed": port_drift_speed,
			&"angle": port_drift_angle,
		},
	}

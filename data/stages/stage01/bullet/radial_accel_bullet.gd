extends CoroutineScript
## 沿初始发射方向加速（径向扩散弹）
## 首次 tick 记录子弹发射方向（初始速度方向 = 发射角度），此后沿该方向恒定加速
##
## **内核端口载体**：行为实现已移到桥接 `scripts/kernel_bridge/behavior/radial_accel_behavior.gd`；
## 删旧池后，弹的协程体不再由本项目启动，本文件只把参数翻译成内核端口。

var accel_rate: float = 150.0  ## 加速度（px/s²），可用 param("accel_rate", v) 注入
## 复用替换弹实例（M2：工厂每次返回同一实例，避免内核弹型表膨胀）
var _down_bullet_data: BulletData


## 内核端口：加速 + 顶边换向下弹。替换弹用**工厂**（每次新对象）。
func kernel_port() -> Dictionary:
	return {
		"move": &"radial_accel",
		"params": {
			&"accel_rate": accel_rate,
			&"spawn_factory": Callable(self, "_kernel_make_down"),
			&"sfx": "kira",
			&"sfx_db": -6.0,
		},
	}


## 替换弹工厂：每次调用返回一颗**新** BulletData（不复用共享模板，避免 duplicate 丢贴图）。
func _kernel_make_down() -> BulletData:
	if _down_bullet_data == null:
		_down_bullet_data = BulletData.new()
		_down_bullet_data.tex("米弹").color(Color.FUCHSIA).blend(true).enemy()
	return _down_bullet_data

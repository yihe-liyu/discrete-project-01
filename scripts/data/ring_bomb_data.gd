## 环状 bomb 数据：绕自机外扩 → 保持 → 追敌 → 接触引爆。
## 宿主实体 = KernelBomb。数值全在 .tres 里可调，别写回引擎代码。
extends BombData
class_name RingBombData

@export_group("运动（绕自机外扩 → 保持 → 追敌）")
@export var hitbox_radius: float = 45.0                     ## 判定半径（追敌引爆距离）
@export var orbit_speed_deg: float = 300.0                  ## 环绕角速度（度/秒）
@export var radius_growth: float = 200.0                    ## 外扩速度（px/s）
@export var max_radius: float = 200.0                       ## 外扩上限
@export var hold_time: float = 1.8                          ## 外圈保持时长
@export var homing_speed: float = 1500.0                    ## 追踪速度

@export_group("爆炸 / 清弹")
@export var explode_damage: float = 150.0                   ## 引爆伤害
@export var explode_radius: float = 140.0                   ## 引爆伤害半径
@export var explode_duration: float = 0.4                   ## 引爆清弹动画时长
@export var explode_start_radius: float = 20.0              ## 引爆清弹起始半径
@export var clear_radius: float = 90.0                      ## 飞行途中持续清弹半径（每帧）


## 环状炸：多颗按色环均匀上色（base_hue 随机起色 → 彩虹；i/count 铺满色环）。
func tint_for(index: int, base_hue: float) -> Color:
	return Color.from_hsv(fmod(base_hue + float(index) / float(maxi(count, 1)), 1.0), 1.0, 1.0)

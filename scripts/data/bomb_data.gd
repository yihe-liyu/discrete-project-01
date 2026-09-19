## 自机 bomb 数据**基类**：所有 bomb 共有的外观 / 编队 / 无敌。
## 具体炸弹类型继承它，补自己的运动与判定字段（RingBombData / MistBombData）。
## 与弹幕数据（BulletData）分开：bomb 是**宿主实体**（个位数、宿主动作），不是弹幕。
extends Resource
class_name BombData

@export_group("符卡名")
## 释放时的大字报名字（自机 Bomb 符卡名；空串 = 不播报）。
@export var name: String = ""

@export_group("震屏")
## 冲击震屏强度（0..1；击中/引爆时一次）。
@export var shake_impulse: float = 0.0
## 持续震屏强度（0..1；整个 bomb 期间）。
@export var shake_sustain: float = 0.0

@export_group("滤镜（Bomb 期间）")
## 场地颜色滤镜（a = 0 表示不启用）；从游戏框中心扩圆铺满 → 停留 → 渐隐。
@export var field_filter_color: Color = Color(0, 0, 0, 0)

@export_group("外观")
@export var texture: Texture2D                              ## 炸弹贴图（单帧）
@export var z_index: int = LayerConfig.BOMB                 ## 渲染层

@export_group("编队（一次 bomb 的生成方式）")
@export var count: int = 8                                  ## 生成几颗（Player 逐颗 spawn）
@export var interval: float = 0.1                           ## 每颗间隔（秒）
@export var invincible_time: float = 5.0                    ## 自机无敌时长


## 第 index 颗 bomb 的染色（Player 逐颗 spawn 时调用）。
## 默认 **保留贴图原色**；子类可覆写（如环状炸按色环给多颗上色）。
func tint_for(_index: int, _base_hue: float) -> Color:
	return Color.WHITE

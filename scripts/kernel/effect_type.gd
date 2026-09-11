## 特效定义（一等公民，R17）：形状格 | 时长 | 缩放。
## 发弹 / 消弹 / 纯特效行都用它；**与"子弹"分离**——特效不是弹幕，只是池里一段短命粒子。
class_name EffectType
extends Resource

@export var id: StringName = &""
## atlas 形状格 key（渲染器经 BulletShapes 解析成 UV）。
@export var key: StringName = &""
## 特效时长（秒）：= 出生相位长度 = 纯特效行寿命。
@export var duration: float = 0.3
## 起止缩放（**倍率**：1.0 = 该特效格正常大小）。
@export var scale_from: float = 2.0
@export var scale_to: float = 1.0
## 染色模式（默认 BLEND：只取亮度换色，颜色由触发方传入）。
@export var tint_mode: BulletType.TintMode = BulletType.TintMode.BLEND

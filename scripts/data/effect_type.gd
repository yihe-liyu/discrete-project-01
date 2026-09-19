## 特效定义（一等公民，R17）：贴图 | 时长 | 缩放 | 淡出 | 染色。
## 发弹（出生雾/预告）与消弹（消散）共用同一份描述符；**与"子弹"分离**——特效不是弹幕，只是一段短命行。
class_name EffectType
extends Resource

@export var id: StringName = &""
## 特效贴图（本项目弹幕/特效用独立贴图，不走图集）。
@export var texture: Texture2D
## 特效时长（秒）：= 出生相位长度 = 纯特效行寿命。
@export var duration: float = 0.3
## 起止缩放（**倍率**：1.0 = 贴图原始大小）。
@export var scale_from: float = 2.0
@export var scale_to: float = 1.0
## 起止 alpha（淡出）：进度 = 1 - 剩余/duration。
@export var alpha_from: float = 1.0
@export var alpha_to: float = 0.0
## 染色模式（默认 BLEND：只取亮度换色，颜色由触发方传入）。
@export var tint_mode: BulletType.TintMode = BulletType.TintMode.BLEND

## 弹型内容定义（外观 + 碰撞 + 朝向）—— `data/bullets/*.tres` 的唯一内容资源。
## 只放「共享、换发不换」的那点数据；阵营 / 染色 / 特效 / 伤害 / 出生雾等**变化多**的属性
## 交给 `BulletData` 构造链按需给 —— 构造链的存在就是为了「只改一点属性不必新建资源」。
## 运行时类型是 `BulletType`（由 `BulletData.to_bullet_type()` 建，内核/渲染读它）；本资源不参与运行时。
class_name BulletDef
extends Resource

@export_group("Identity")
@export var id: StringName = &""

@export_group("Visual | Collision")
## atlas 形状 key（经 BulletShapes 解析成图集格）。**外观与碰撞放一起**。
@export var texture_key: StringName = &""
## 受击判定半径（圆判定；hitbox_size 非零时忽略）。
@export var hitbox_radius: float = 4.0
## 判定中心相对弹位置的偏移（本地坐标，随弹朝向旋转）。
@export var hitbox_offset: Vector2 = Vector2.ZERO
## 非零 = 矩形判定（忽略 hitbox_radius）；零 = 圆判定。
@export var hitbox_size: Vector2 = Vector2.ZERO
## 贴图/判定随飞行方向旋转；圆弹可设 false。
@export var follow_dir: bool = true
## 朝向补偿（弧度，仅 follow_dir 时生效）。
@export var dir_offset: float = 0.0
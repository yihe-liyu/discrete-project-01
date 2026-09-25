## 弹型（**运行时内核类型**，纯数据）：形状 | 判定 | 阵营 | 可选特效。
## 运行时每颗弹是内核 SoA 里的一行，绝不实例化成节点；同型弹共享这里的参数。
## 速度 / 颜色 / 弹道不在这里 —— 由 `BulletData`（内容构造助手）逐发传入。
## **本类不落 .tres**：内容资源是 `BulletDef`（`data/bullets/*.tres`，只外观+碰撞+朝向）；
## `BulletData.to_bullet_type()` 首次发射时把类型级字段快照成本类并缓存（同实例 → 同弹型）。
## @tool：编辑器里 @tool 工具脚本（弹型查看器）要调 rotation_for 等方法，
## 没有 @tool 的话加载出来是 placeholder，会报 "Attempt to call a method on a placeholder instance"。
@tool
class_name BulletType
extends Resource

## 弹型类别（预留：曲线激光以后接入）。
enum Kind { POINT, LASER }
## 阵营：碰撞/消弹按它过滤。NONE = 纯特效/装饰行（不碰撞、不被消弹波及）。
enum Faction { ENEMY, PLAYER, NONE }
## 染色模式（贴图怎么上色）。**枚举值就是 shader 的模式位**（instance_color.a），改顺序要同步 shader。
## MULTIPLY = 乘法叠加：rgb = 贴图 × tint → tint=白 即**贴图原色**（自机弹；记忆变红 = tint 往红 lerp）。
## BLEND = 亮度混合：只取贴图亮度、丢色相，rgb = mix(tint, 白, 亮度)（敌弹换色用）。
enum TintMode { MULTIPLY, BLEND }

@export_group("Identity")
@export var id: StringName = &""
@export var kind: Kind = Kind.POINT
@export var faction: Faction = Faction.ENEMY

@export_group("Visual | Collision")
## 染色模式（默认 BLEND：我们的图集是彩图，靠亮度换色；自机弹用 MULTIPLY 保原色）。
@export var tint_mode: TintMode = TintMode.BLEND
## 受击判定半径（很小，S2），与视觉尺寸独立。擦弹半径不属弹型——由自机定义。
@export var hitbox_radius: float = 4.0
## 判定中心相对弹位置的偏移（本地坐标，**随弹朝向旋转**）。零 = 判定在弹心（默认，零开销）。
## 用途：长条弹判定只在弹头/弹尾、素材画心与判定心不重合的弹。
@export var hitbox_offset: Vector2 = Vector2.ZERO
## 矩形判定尺寸（宽×高，本地坐标，**随弹朝向旋转**）。非零 = 矩形判定（**忽略 hitbox_radius**）；
## 零 = 圆判定（用 hitbox_radius）。激光段、宽弹用矩形才能贴合素材。
@export var hitbox_size: Vector2 = Vector2.ZERO
## 贴图跟随飞行方向（默认开）。关掉 = 贴图永远轴对齐（圆点弹无所谓，有朝向的弹要开）。
@export var follow_dir: bool = true
## 贴图朝向补偿（仅在 follow_dir 时生效）：素材朝右 = 0；朝上 = +PI/2；朝下 = -PI/2；朝左 = PI。
@export var dir_offset: float = 0.0
## 出界宽限（秒）：出界后仍存活这么久再回收；0 = 出界立即回收（默认）。
## 与 `hitbox_*` 同规格：类型级字段 → 发射时逐行 `set_out_grace` 推给内核（内核**解释**它）。
## 用于「出界再回来」的弹（往返探针）；bounce / radial_accel 在界内撞墙回收，不需要它。
@export var out_grace: float = 0.0

@export_group("Hit effect（可选：命中的那一方播）")
## 击中特效场景（自机弹用）：命中时在命中点播一次（FxPool 池化节点，支持帧动画）。
## 颜色由命中方传"该弹当前的颜色"（含记忆调制），场景只决定形状/动画。
@export var hit_fx: PackedScene

@export_group("Spawn effect（可选：出生雾/预告）")
## 是否播出生特效（弹雾）：关掉 = 这型弹直接出现，不给玩家预告。
@export var is_spawn_fog: bool = true
## 出生特效；null = 用阵营默认（KernelNativeSystem.set_spawn_fx）。
@export var spawn_fx: EffectType

@export_group("Host payload（内核只存不解释）")
## 伤害：命中结算由**宿主**读它，内核本体不解释。
## M1（原项目融合）：从宿主侧表搬进来 —— 原先内核无 damage，靠 `KernelBulletHost._damage_by_index`。
@export var damage: float = 1.0
## 命中音效 key：宿主读；内核本体不解释。空 = 宿主默认规则。
@export var hit_sfx: StringName = &""


## 该弹在给定速度下的朝向（弧度）：跟随飞行方向时 = 速度角 + dir_offset；关闭跟随或零速度 = 轴对齐。
## **渲染与判定共用的唯一朝向语义**：渲染热路径内联展开同一公式，判定经本函数旋转 hitbox_offset。
## 两边一旦分叉，有朝向的弹（箭弹/激光）判定就会和画面错位。
func rotation_for(velocity: Vector2) -> float:
	return velocity.angle() + dir_offset if follow_dir and velocity != Vector2.ZERO else 0.0


## 判定中心 = 位置 + 随朝向旋转的 hitbox_offset。
## **判定与调试工具（HitboxOverlay / 查看器）共用的唯一语义**；零偏移走原路径。
func hit_center_for(position: Vector2, velocity: Vector2) -> Vector2:
	if hitbox_offset == Vector2.ZERO:
		return position
	return position + hitbox_offset.rotated(rotation_for(velocity))

## 子弹构造助手：外观 / 判定 / 阵营 / 行为。
##
## 本类是内容侧构造链，不是运行时行；[method to_bullet_type] 才产出内核 [code]BulletType[/code]。
## 类型级字段（faction / tint_mode / 判定 / damage / hit_sfx）首次构建时快照；
## 速度 / tint / params 逐发传入。
## 内容必须复用 BulletData 实例，避免内核弹型表每发增长。
extends Resource
class_name BulletData

## 阵营。
enum Faction {PLAYER, ENEMY, BOMB}
## 判定形状。
enum HitboxShape {CIRCLE, RECTANGLE}
## 染色模式。
enum TintMode {MULTIPLY, BLEND}

## 贴图：白色/浅灰底图，用 tint 染色。
var texture: Texture2D
## 染色模式。
var tint_mode: TintMode = TintMode.MULTIPLY
## 贴图染色。
var tint: Color = Color.WHITE
## 基础伤害（支持小数，伤害累积到整才扣血）。
var damage: float = 10.0
## 速度向量：长度 = 速度，方向 = 默认方向（发射时可由 direction 覆盖）。
var velocity: Vector2 = Vector2.UP
## 击中特效。
var hit_effect: PackedScene
## 阵营。
var faction: Faction = Faction.PLAYER
## 内核弹型类别：POINT = 普通弹；LASER = 魔理沙非 focus 激光段（供整批淡出/清理）。
var kind: BulletType.Kind = BulletType.Kind.POINT
## 判定形状。
var hitbox_shape: HitboxShape = HitboxShape.CIRCLE
## 判定偏移。
var hitbox_offset: Vector2 = Vector2.ZERO
## 圆形判定半径。
var hitbox_radius: float = 4.0
## 矩形判定尺寸（仅 RECTANGLE 用）。
var hitbox_size: Vector2 = Vector2(8, 8)
## 贴图/判定随飞行方向旋转（圆弹可关）。
var follow_dir: bool = true
## 朝向补偿（弧度，仅 follow_dir 时生效；素材朝右=0、朝上=+PI/2、朝下=-PI/2、朝左=PI）。
var dir_offset: float = 0.0
## 是否跟随阵营出生雾（用 no_spawn_fog() 逐型关闭）。
var is_spawn_fog: bool = true
## 出生特效；null = 用阵营默认。
var spawn_fx: EffectType
## 旧式移动协程脚本（兼容路径；优先用 lifecycle）。
var coroutine_script: Script
## 注入给旧式移动协程脚本的参数（脚本同名 var 覆盖）。
var params: Dictionary = {}
## 生命周期描述符；设定后优先于 coroutine_script。
## 用 BulletLifecycle 构建；相同结构共用一个原生 program（content_signature）。
var lifecycle: BulletLifecycle
## per-shot 锚点 spec（{id, offset, use_global}）；仅锚定型弹道（激光）需要。
var lifecycle_anchor: Variant = null
## 命中音效注册器 key；空 = normal_damage。
var hit_sfx: String = ""
## 出界宽限（秒）：出界后仍存活这段时间再回收；0 = 出界立即回收。
var out_grace: float = 0.0

## ---- 构造链方法 ----

## 从弹型定义（data/bullets/*.tres）载入外形 + 碰撞 + 朝向。
## 只覆盖外观/判定/朝向；阵营 / 染色 / 特效 / 伤害仍由构造链设置。
## 未知 key → BulletCatalog 告警并保持现状，不静默回退。
func def(d: BulletDef) -> BulletData:
	if d == null:
		return self
	texture = BulletShapes.atlas_texture(d.texture_key) if d.texture_key != &"" else null
	hitbox_radius = d.hitbox_radius
	hitbox_offset = d.hitbox_offset
	if d.hitbox_size == Vector2.ZERO:
		hitbox_shape = HitboxShape.CIRCLE
		hitbox_size = Vector2(8, 8)
	else:
		hitbox_shape = HitboxShape.RECTANGLE
		hitbox_size = d.hitbox_size
	follow_dir = d.follow_dir
	dir_offset = d.dir_offset
	return self


## 按 key 取弹型定义并载入（= def(BulletCatalog.find(key))）。
## key 必须来自 docs/DANMAKU_API.md §7.1 的弹型表。
func tex(key: String) -> BulletData:
	return def(BulletCatalog.find(key))

## 设默认速度大小（只写 velocity.y；方向由发射时的 direction 决定）。
func speed(v: float) -> BulletData:
	velocity.y = v
	return self

## 设速度向量（方向 + 大小）；发射时 direction 仍可覆盖方向。
func dir(x: float, y: float) -> BulletData:
	velocity = Vector2(x, y)
	return self

## 挂生命周期描述符；anchor 是 per-shot 锚点 spec（{id, offset, use_global}），仅激光需要。
func trajectory(lc: BulletLifecycle, anchor: Variant = null) -> BulletData:
	lifecycle = lc
	lifecycle_anchor = anchor
	return self

## 设贴图染色。
func color(c: Color) -> BulletData:
	tint = c
	return self

## 开关 BLEND 染色（false = MULTIPLY）。
func blend(b: bool) -> BulletData:
	tint_mode = TintMode.BLEND if b else TintMode.MULTIPLY
	return self

## 设为敌方阵营；不改出生雾开关。
func enemy() -> BulletData:
	faction = Faction.ENEMY
	# 不碰 is_spawn_fog：出生雾归阵营默认，逐型开关由 no_spawn_fog()/with_spawn_fog() 定，
	# 否则「先 no_spawn_fog 再 enemy」会被静默覆写。
	return self

## 打开/换出生雾：effect 为空 = 用阵营默认特效。
## 打开/换出生雾；effect 为空 = 用阵营默认特效。
func with_spawn_fog(effect: EffectType = null) -> BulletData:
	is_spawn_fog = true
	spawn_fx = effect
	return self


## 关掉出生雾：这型弹直接出现，不给预告。
## 关闭出生雾：这型弹直接出现，不给预告。
func no_spawn_fog() -> BulletData:
	is_spawn_fog = false
	return self


## 设为自机阵营；伤害重置为 10。
func player() -> BulletData:
	faction = Faction.PLAYER
	damage = 10
	return self

## 设为炸弹伪弹：BOMB 阵营、大圆判定、超长出界宽限。
func bomb() -> BulletData:
	faction = Faction.BOMB
	damage = 50
	hitbox_shape = HitboxShape.CIRCLE
	hitbox_radius = 45.0
	# 旋转/追踪阶段可能暂时出框，不能被 BulletManager 提前回收；由 BombBehavior 自己爆炸消失
	out_grace = 9999.0
	return self

## 挂旧式移动协程脚本（兼容路径；优先用 lifecycle）。
func behavior(v: Script) -> BulletData:
	coroutine_script = v
	return self


## 设出界宽限（秒）：出界后仍存活这段时间再回收；0 = 立即回收。
func grace(v: float) -> BulletData:
	self.out_grace = v
	return self


# ═══ 内核弹型（词汇合一：BulletData 是构造助手，产出 BulletType）═══

# 本实例的内核弹型缓存；首次 to_bullet_type() 时构建。
var _bullet_type: BulletType


## 本实例的内核弹型（首次调用时构建并缓存）。
## 同实例 → 同 BulletType；内容必须复用 BulletData 实例，避免弹型表膨胀。
## 类型级字段首次调用时快照；运行期改这些字段需 invalidate_bullet_type()。
func to_bullet_type() -> BulletType:
	if _bullet_type == null:
		_bullet_type = _build_bullet_type()
	return _bullet_type


## 类型级字段变更后失效缓存（复用实例 + 运行期改型时才需要）。
func invalidate_bullet_type() -> void:
	_bullet_type = null


func _build_bullet_type() -> BulletType:
	var bt := BulletType.new()
	bt.kind = kind
	bt.faction = _map_faction()
	bt.tint_mode = BulletType.TintMode.BLEND if tint_mode == TintMode.BLEND else BulletType.TintMode.MULTIPLY
	bt.hitbox_radius = hitbox_radius
	bt.hitbox_offset = hitbox_offset
	# 内核语义：非零 hitbox_size = 矩形；本类默认 size(8,8) 但 shape=CIRCLE，必须归零。
	bt.hitbox_size = hitbox_size if hitbox_shape == HitboxShape.RECTANGLE else Vector2.ZERO
	bt.follow_dir = follow_dir
	bt.dir_offset = dir_offset
	bt.out_grace = out_grace
	bt.hit_fx = hit_effect
	bt.is_spawn_fog = is_spawn_fog
	bt.spawn_fx = spawn_fx
	# 宿主专有字段进弹型（内核只存不解释）
	bt.damage = damage
	bt.hit_sfx = StringName(hit_sfx)
	return bt


func _map_faction() -> BulletType.Faction:
	match faction:
		Faction.ENEMY: return BulletType.Faction.ENEMY
		Faction.PLAYER: return BulletType.Faction.PLAYER
		_: return BulletType.Faction.NONE   # BOMB：炸弹走宿主节点

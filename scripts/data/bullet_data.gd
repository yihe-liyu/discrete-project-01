## 子弹配置：贴图、染色、判定、阵营、雾效
extends Resource
class_name BulletData

enum Faction {PLAYER, ENEMY, BOMB}
enum HitboxShape {CIRCLE, RECTANGLE}
enum TintMode {MULTIPLY, BLEND}

var texture: Texture2D                               ## 子弹贴图（白色/浅灰底图，用 tint 染色）
var tint_mode: TintMode = TintMode.MULTIPLY          ## MULTIPLY=乘法叠加, BLEND=灰度混合
var tint: Color = Color.WHITE                        ## 贴图染色
var damage: float = 10.0                              ## 基础伤害（支持小数，伤害累积到整才扣血）
var velocity: Vector2 = Vector2.UP                   ## 速度向量
var accel: Vector2 = Vector2.ZERO                   ## 加速度（世界方向，px/s²，0=匀速）
var hit_effect: PackedScene                          ## 击中特效
var faction: Faction = Faction.PLAYER                ## 阵营
var can_be_canceled: bool = false                    ## 是否可被 Bomb 消除
var hitbox_shape: HitboxShape = HitboxShape.CIRCLE   ## 判定形状
var hitbox_offset: Vector2 = Vector2.ZERO            ## 判定偏移
var hitbox_rotation: float = 0.0                     ## 判定旋转（弧度）
var hitbox_radius: float = 4.0                       ## 判定半径
var hitbox_size: Vector2 = Vector2(8, 8)             ## 矩形判定尺寸
var spawn_fog: bool = false                          ## 是否播弹雾特效
var fog_texture: Texture2D                           ## 弹雾贴图
var coroutine_script: Script                         ## 移动协程脚本（如诱导跟踪）
var params: Dictionary = {}                          ## 注入给移动协程脚本的参数（行为脚本同名 var 覆盖）
var hit_sfx: String = ""                             ## 命中音效注册器 key（空 = 默认 normal_damage）
var out_grace: float = 0.0                           ## 出界宽限（秒）：出界后仍存活这段时间再回收；0 = 出界立即回收

## ---- 构造链方法 ----
func tex(key: String) -> BulletData:
	texture = AssetRegistry.get_bullet_tex(key)
	var cfg: Dictionary = AssetRegistry.bullet_configs.get(key, {})
	var hb: Dictionary = cfg.get("hitbox", {})
	if hb.has("circle"):
		hitbox_shape = HitboxShape.CIRCLE
		hitbox_radius = hb["circle"]
	elif hb.has("rect"):
		hitbox_shape = HitboxShape.RECTANGLE
		var r: Dictionary = hb["rect"]
		hitbox_size = Vector2(r.get("w", 48), r.get("h", 24))
		hitbox_rotation = r.get("rotation", 0.0)
	var off: Dictionary = hb.get("offset", {"x": 0, "y": 0})
	hitbox_offset = Vector2(off.get("x", 0), off.get("y", 0))
	fog_texture = AssetRegistry.FOG_TEXTURE
	return self

func speed(v: float) -> BulletData:
	velocity.y = v
	return self

func dir(x: float, y: float) -> BulletData:
	velocity = Vector2(x, y)
	return self

## 匀加速：ax/ay 为世界方向加速度（px/s²），如 .accelerate(0, -4000) = 竖直向上匀加速
func accelerate(ax: float, ay: float) -> BulletData:
	accel = Vector2(ax, ay)
	return self

func color(c: Color) -> BulletData:
	tint = c
	return self

func blend(b: bool) -> BulletData:
	tint_mode = TintMode.BLEND if b else TintMode.MULTIPLY
	return self

func enemy() -> BulletData:
	faction = Faction.ENEMY
	can_be_canceled = true
	spawn_fog = true
	return self

func player() -> BulletData:
	faction = Faction.PLAYER
	can_be_canceled = false
	damage = 10
	return self

func bomb() -> BulletData:
	faction = Faction.BOMB
	can_be_canceled = false
	damage = 50
	hitbox_shape = HitboxShape.CIRCLE
	hitbox_radius = 45.0
	# 旋转/追踪阶段可能暂时出框，不能被 BulletManager 提前回收；由 BombBehavior 自己爆炸消失
	out_grace = 9999.0
	return self

func behavior(v: Script) -> BulletData:
	coroutine_script = v
	return self


## 出界宽限（秒）：出界后仍存活这段时间再回收（探测弹往返等；0 = 出界立即回收）
func grace(v: float) -> BulletData:
	self.out_grace = v
	return self


# ═══ 内核弹型（词汇合一：BulletData 是构造助手，产出 BulletType）═══

## 本实例的内核弹型（首次调用时构建并缓存）。
## 同实例 → 同 BulletType，内核弹型表不随发射膨胀；**内容必须复用 BulletData 实例**。
## 类型级字段（faction / tint_mode / 判定 / hit_effect / damage / hit_sfx）首次调用时快照；
## 运行期再改这些字段需 `invalidate_bullet_type()`。速度 / tint / params 不属弹型，随每次发射传入。
var _bullet_type: BulletType


func to_bullet_type() -> BulletType:
	if _bullet_type == null:
		_bullet_type = _build_bullet_type()
	return _bullet_type


## 类型级字段变更后失效缓存（复用实例 + 运行期改型时才需要）。
func invalidate_bullet_type() -> void:
	_bullet_type = null


func _build_bullet_type() -> BulletType:
	var bt := BulletType.new()
	bt.faction = _map_faction()
	bt.tint_mode = BulletType.TintMode.BLEND if tint_mode == TintMode.BLEND else BulletType.TintMode.MULTIPLY
	bt.hitbox_radius = hitbox_radius
	bt.hitbox_offset = hitbox_offset
	# 内核语义：非零 hitbox_size = 矩形；本类默认 size(8,8) 但 shape=CIRCLE，必须归零。
	bt.hitbox_size = hitbox_size if hitbox_shape == HitboxShape.RECTANGLE else Vector2.ZERO
	bt.follow_dir = true
	bt.hit_fx = hit_effect
	# 宿主专有字段进弹型（内核只存不解释）
	bt.damage = damage
	bt.hit_sfx = StringName(hit_sfx)
	return bt


func _map_faction() -> BulletType.Faction:
	match faction:
		Faction.ENEMY: return BulletType.Faction.ENEMY
		Faction.PLAYER: return BulletType.Faction.PLAYER
		_: return BulletType.Faction.NONE   # BOMB：炸弹走宿主节点

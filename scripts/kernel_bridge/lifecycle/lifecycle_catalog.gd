class_name LifecycleCatalog
extends RefCounted
## LifecycleCatalog —— 把内容现有的 `move + params` 映射到 L2 的 `BulletLifecycle`（L3.5-2）。
##
## **内容零改动**：内容仍写 `kernel_port() -> {move, params}`，创作者看不到这一层。
## move 名与参数键**以本文件 build() 为准**（原生执行器跑编译后的 packed program；
## test/reference/behavior/*.gd 只是冻结参照，不驱动 schema）。新增 move 见 CONTENT_GUIDE.md「弹幕行为接口」。

## 预拼描述符入口：内容 `kernel_port()` 直接给 `{lifecycle: BulletLifecycle}`（可选 `anchor`）。
## 对应 docs/LIFECYCLE_MODEL.md §7「`*_bullet.gd` → builder sugar」。
const MOVE_LIFECYCLE := &"lifecycle"


## 纯映射：move + params → lifecycle；未知 move 返回 null。
## **每个 move 的组合在此就地展开为原语**（唯一真相）；BulletLifecycle 的同名 preset 只是它的类型化薄包装。
static func build(move: StringName, params: Dictionary) -> BulletLifecycle:
	if move == MOVE_LIFECYCLE:
		return params.get(&"lifecycle", null) as BulletLifecycle
	var lc := BulletLifecycle.new()
	match move:
		&"world_accel":
			lc.accel_world(params.get(&"world_accel", Vector2.ZERO))
		&"accel":
			lc.accel_heading(float(params.get(&"accel", 0.0)))
		&"curve":
			lc.rotate(float(params.get(&"curve", 0.0)), float(params.get(&"curve_limit", 0.0)))
			lc.until_turned()
			lc.then()
		&"homing":
			var speed_min := float(params.get(&"min_speed", 500.0))
			var speed_max := float(params.get(&"max_speed", 2000.0))
			lc.steer(BulletLifecycle.T_NEAREST_ENEMY,
				float(params.get(&"homing_angle_per_sec", deg_to_rad(720.0))),
				float(params.get(&"accel_time", 2.0)),
				float(params.get(&"proximity_boost", 150.0)),
				speed_min,
				speed_max if speed_max > 0.0 else speed_min,
				float(params.get(&"homing_duration", 2.0)))
			lc.until_never()
		&"radial_accel":
			lc.accel_heading(float(params.get(&"accel_rate", 0.0)))
			lc.until_at_wall(BulletLifecycle.WALL_TOP)
			var sfx_radial := StringName(params.get(&"sfx", ""))
			if sfx_radial != &"":
				lc.sfx(sfx_radial, float(params.get(&"sfx_db", 0.0)))
			lc.emit(_spawn_of(params), BulletLifecycle.heading(PI), 0.0, true)
			lc.despawn()
		&"bounce":
			lc.accel_heading(float(params.get(&"accel", 0.0)))
			lc.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
			var sfx_bounce := StringName(params.get(&"sfx", "kira"))
			if sfx_bounce != &"":
				lc.sfx(sfx_bounce, float(params.get(&"sfx_db", -8.0)))
			lc.emit(_spawn_of(params),
				BulletLifecycle.toward(BulletLifecycle.T_BOSS, float(params.get(&"bounce_angle", 0.0))),
				float(params.get(&"spawn_speed", 0.0)), true)
			lc.despawn()
		&"avoid_player":
			lc.until_near(BulletLifecycle.T_PLAYER, float(params.get(&"player_proximity", 150.0)), float(params.get(&"jump", 0.05)))
			lc.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
			lc.then()
			lc.until_elapsed(float(params.get(&"flee_time", 2.0)))
			lc.despawn()
		&"non_mid_flee":
			var radius: float = float(params.get(&"boss_radius", 150.0))   # 半径是内容调参，由内容按难度传
			lc.until_near(BulletLifecycle.T_PLAYER, float(params.get(&"player_proximity", 150.0)), 0.0, 3)
			lc.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
			lc.then()
			lc.until_near(BulletLifecycle.T_BOSS, radius, 0.0, 3)
			lc.on_end_call(params.get(&"on_flee_burst", Callable()))
			lc.despawn()
		&"marisa_laser":
			lc.anchor_drift(int(params.get(&"anchor_id", 0)), params.get(&"anchor_offset", Vector2.ZERO),
				float(params.get(&"angle", 0.0)), float(params.get(&"drift_speed", 2000.0)),
				true, float(params.get(&"initial_drift", 0.0)), true)
			lc.until_never()
		&"laser_follow":
			lc.anchor_drift(int(params.get(&"anchor_id", 0)), params.get(&"anchor_offset", Vector2.ZERO),
				float(params.get(&"angle", 0.0)), float(params.get(&"drift_speed", 2000.0)),
				false, float(params.get(&"initial_drift", 0.0)), false)
			lc.until_never()
		_:
			return null
	return lc


## 替换弹来源：新写法 `spawn`（BulletData）优先，兼容旧 `spawn_factory`（Callable）。
static func _spawn_of(params: Dictionary) -> Variant:
	return params.get(&"spawn", params.get(&"spawn_factory", null))


## 签名：同 (move, params) 只编译一次。难度相关值（如 non_mid 半径）由内容放进 params，故无需额外入签名。
static func signature(move: StringName, params: Dictionary) -> int:
	if move == MOVE_LIFECYCLE:
		var lc: BulletLifecycle = params.get(&"lifecycle", null)
		var lc_sig: int = lc.content_signature() if lc != null else 0
		return hash(move) * 31 + lc_sig * 7 + hash(params.get(&"anchor"))
	return hash(move) * 31 + hash(params) * 7


var _cache: Dictionary = {}


## 带缓存取 lifecycle（可返回 null 并缓存，避免重复 build）。
func get_lifecycle(move: StringName, params: Dictionary) -> BulletLifecycle:
	var sig := signature(move, params)
	if _cache.has(sig):
		return _cache[sig]
	var lc := build(move, params)
	_cache[sig] = lc
	return lc


func cache_size() -> int:
	return _cache.size()

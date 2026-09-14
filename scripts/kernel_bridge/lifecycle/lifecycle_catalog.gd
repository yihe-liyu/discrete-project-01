## LifecycleCatalog —— 把内容现有的 `move + params` 映射到 L2 的 `BulletLifecycle`（L3.5-2）。
##
## **内容零改动**：内容仍写 `kernel_port() -> {move, params}`，创作者看不到这一层。
## move 名与参数键**以本文件 build() 为准**（原生执行器跑编译后的 packed program；
## test/reference/behavior/*.gd 只是冻结参照，不驱动 schema）。新增 move 见 CONTENT_GUIDE.md「弹幕行为接口」。
class_name LifecycleCatalog
extends RefCounted

const _NON_MID_RADIUS := [175.0, 150.0, 125.0, 100.0]


## 纯映射：move + params → lifecycle；未知 move 返回 null。
static func build(move: StringName, params: Dictionary) -> BulletLifecycle:
	match move:
		&"world_accel":
			return BulletLifecycle.world_accel(params.get(&"world_accel", Vector2.ZERO))
		&"accel":
			return BulletLifecycle.accel(float(params.get(&"accel", 0.0)))
		&"curve":
			return BulletLifecycle.curve(float(params.get(&"curve", 0.0)), float(params.get(&"curve_limit", 0.0)))
		&"homing":
			return BulletLifecycle.homing(
				float(params.get(&"homing_angle_per_sec", deg_to_rad(720.0))),
				float(params.get(&"accel_time", 2.0)),
				float(params.get(&"min_speed", 500.0)),
				float(params.get(&"max_speed", 2000.0)),
				float(params.get(&"homing_duration", 2.0)),
				float(params.get(&"proximity_boost", 150.0)))
		&"radial_accel":
			return BulletLifecycle.radial_accel(
				float(params.get(&"accel_rate", 0.0)),
				params.get(&"spawn_factory", Callable()),
				StringName(params.get(&"sfx", "")),
				float(params.get(&"sfx_db", 0.0)))
		&"bounce":
			return BulletLifecycle.bounce(
				float(params.get(&"accel", 0.0)),
				float(params.get(&"bounce_angle", 0.0)),
				float(params.get(&"spawn_speed", 0.0)),
				params.get(&"spawn_factory", Callable()),
				StringName(params.get(&"sfx", "kira")),
				float(params.get(&"sfx_db", -8.0)))
		&"avoid_player":
			# 该行为是类型级配置（构造参数），内容不通过 params 覆盖。
			return BulletLifecycle.avoid_player(150.0, 0.05, 2.0)
		&"non_mid_flee":
			var r: float = _NON_MID_RADIUS[clampi(SaveData.selected_difficulty, 0, _NON_MID_RADIUS.size() - 1)]
			return BulletLifecycle.non_mid_flee(
				float(params.get(&"player_proximity", 150.0)),
				r,
				params.get(&"on_flee_burst", Callable()))
		&"marisa_laser":
			return BulletLifecycle.marisa_laser(
				int(params.get(&"anchor_id", 0)),
				params.get(&"anchor_offset", Vector2.ZERO),
				float(params.get(&"angle", 0.0)),
				float(params.get(&"drift_speed", 2000.0)),
				float(params.get(&"initial_drift", 0.0)))
		&"laser_follow":
			return BulletLifecycle.laser_follow(
				int(params.get(&"anchor_id", 0)),
				params.get(&"anchor_offset", Vector2.ZERO),
				float(params.get(&"angle", 0.0)),
				float(params.get(&"drift_speed", 2000.0)),
				float(params.get(&"initial_drift", 0.0)))
	return null


## 签名：同 (move, params, 难度) 只编译一次。难度入签名是因为 non_mid 的半径随难度。
static func signature(move: StringName, params: Dictionary) -> int:
	return hash(move) * 31 + hash(params) * 7 + SaveData.selected_difficulty


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

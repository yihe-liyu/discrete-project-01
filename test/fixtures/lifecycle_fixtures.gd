extends RefCounted
## 测试/基准用的**手写原语组合**（不是生产 preset）。
## F10c 删掉了 BulletLifecycle 的 9 个 preset；这些 helper 只服务旧 parity/native 夹具，
## 组合逻辑与删掉的 preset 逐行一致，便于直接替换调用点。

static func world_accel(v: Vector2) -> BulletLifecycle:
	return BulletLifecycle.new().accel_world(v)


static func accel(a: float) -> BulletLifecycle:
	return BulletLifecycle.new().accel_heading(a)


static func curve(w: float, limit: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.rotate(w, limit)
	lc.until_turned()
	lc.then()
	return lc


static func bounce(accel_rate: float, bounce_angle: float, spawn_speed: float, spawn: Variant,
		sfx_key: StringName = &"kira", sfx_db: float = AudioManager.SFX_LEVEL_DB) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_heading(accel_rate)
	lc.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
	if sfx_key != &"":
		lc.sfx(sfx_key, sfx_db)
	lc.emit(spawn, BulletLifecycle.toward(BulletLifecycle.T_BOSS, bounce_angle), spawn_speed, BulletLifecycle.AT_PHASE_END)
	lc.despawn()
	return lc


static func radial_accel(rate: float, spawn: Variant, sfx_key: StringName = &"", sfx_db: float = AudioManager.SFX_LEVEL_DB) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_heading(rate)
	lc.until_at_wall(BulletLifecycle.WALL_TOP)
	if sfx_key != &"":
		lc.sfx(sfx_key, sfx_db)
	lc.emit(spawn, BulletLifecycle.world_heading(PI), 0.0, BulletLifecycle.AT_PHASE_END)
	lc.despawn()
	return lc


static func homing(angle_per_sec := deg_to_rad(720.0), accel_time := 2.0, min_speed := 500.0,
		max_speed := 2000.0, duration := 2.0, proximity_boost := 150.0) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.steer(BulletLifecycle.T_NEAREST_ENEMY, angle_per_sec, accel_time, proximity_boost, duration)
	lc.speed_lerp(min_speed, max_speed if max_speed > 0.0 else min_speed, accel_time)
	lc.until_never()
	return lc


static func avoid_player(proximity: float, jump: float, flee_time: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.until_near(BulletLifecycle.T_PLAYER, proximity).every(jump)
	lc.on_end_heading(BulletLifecycle.away(BulletLifecycle.T_PLAYER))
	lc.then()
	lc.until_elapsed(flee_time)
	lc.despawn()
	return lc


static func laser_follow(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.anchor_drift(anchor_id, offset, angle, drift_speed, false, initial_drift, false)
	lc.until_never()
	return lc


static func marisa_laser(anchor_id: int, offset: Vector2, angle: float, drift_speed: float, initial_drift: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.anchor_drift(anchor_id, offset, angle, drift_speed, true, initial_drift, true)
	lc.until_never()
	return lc

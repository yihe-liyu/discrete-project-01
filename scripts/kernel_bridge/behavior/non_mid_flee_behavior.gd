## NonMidFleeBehavior（Track A / S4c-3）—— 中boss非符弹丸：
## TRAVEL → 靠近自机则 FLEE（沿远离自机方向）→ 靠近 Boss 时散圈并消失。
## 移植旧 data/stages/stage01/phase/non_mid01/non_mid01_bullet.gd。
## 只 set_velocity；散圈由内容 on_flee_burst 回调入队（KernelBehaviorHost）。
## params：player_proximity | on_flee_burst(Callable(pos, boss_pos, has_boss, host) -> bool)
extends Behavior

const CHECK_EVERY := 3   # 每 3 帧查一次距离（与旧 _skip % 3 一致）
var host   # KernelBehaviorHost


func process(system: BulletSystem, bullet_id: int, ctx: BehaviorContext) -> void:
	var params: Variant = system.get_behavior_params(bullet_id)
	if not (params is Dictionary):
		return
	var st: Variant = system.get_behavior_state(bullet_id)
	if not (st is Dictionary):
		st = {&"skip": 0}
		system.set_behavior_state(bullet_id, st)
	st[&"skip"] = int(st[&"skip"]) + 1
	if int(st[&"skip"]) % CHECK_EVERY != 0:
		return
	if system.get_behavior_phase(bullet_id) == 0:
		_travel(system, bullet_id, ctx, params)
	else:
		_flee(system, bullet_id, params)


func _travel(system: BulletSystem, bullet_id: int, ctx: BehaviorContext, params: Dictionary) -> void:
	var player_pos: Vector2 = ctx.get_player_position()
	var pos: Vector2 = system.get_position(bullet_id)
	if pos.distance_to(player_pos) < params.get(&"player_proximity", 150.0):
		var flee_dir: Vector2 = (pos - player_pos).normalized()
		system.set_velocity(bullet_id, flee_dir * system.get_velocity(bullet_id).length())
		system.set_behavior_phase(bullet_id, 1)


func _flee(system: BulletSystem, bullet_id: int, params: Dictionary) -> void:
	var burst: Callable = params.get(&"on_flee_burst", Callable())
	if not burst.is_valid():
		return
	var boss = host.get_boss() if host != null else null
	var has_boss: bool = is_instance_valid(boss)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	# 内容回调返回 true = 已散圈 → 回收自己
	if burst.call(system.get_position(bullet_id), boss_pos, has_boss, host):
		system.request_despawn(bullet_id)

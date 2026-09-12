## 行为：子弹靠近自机后逃离。
## 状态机：TRAVEL → 自机进入 proximity → FLEE → 逃够 flee_time → 标记回收。
## 每弹状态用行字段：阶段 _behavior_phase | 死线 _timer（本行为只 set，系统递减）。
extends Behavior
class_name AvoidPlayerBehavior

## 类型级配置（同实例的所有子弹共用）。
var proximity := 150.0   # 触发逃离的自机距离
var jump := 0.05         # TRAVEL 阶段检查间隔
var flee_time := 2.0     # 逃离持续时长，之后自杀


func _init(p_proximity := 150.0, p_flee_time := 2.0) -> void:
	proximity = p_proximity
	flee_time = p_flee_time


## 入口：按 _behavior_phase 走 TRAVEL/FLEE。
func process(system: BulletSystem, bullet_id: int, ctx: BehaviorContext) -> void:
	if system.get_behavior_phase(bullet_id) == 0:
		# TRAVEL：每 jump 秒查一次距离（省高频检查）
		if system.get_timer(bullet_id) > 0.0:
			return
		system.set_timer(bullet_id, jump)   # 下一次检查的间隔
		var player_pos: Vector2 = ctx.get_player_position()
		var offset: Vector2 = system.get_position(bullet_id) - player_pos
		if offset.length_squared() < proximity * proximity:
			system.set_behavior_phase(bullet_id, 1)
			var away: Vector2 = offset.normalized()   # 远离自机（局部量）
			system.set_velocity(bullet_id, away * system.get_velocity(bullet_id).length())
			system.set_timer(bullet_id, flee_time)   # 逃跑持续死线
	else:
		# FLEE：死线到则标记回收（由处理器统一 despawn）
		if system.get_timer(bullet_id) <= 0.0:
			system.request_despawn(bullet_id)

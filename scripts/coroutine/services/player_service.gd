class_name PlayerService
extends RefCounted
## 玩家服务 —— 只读访问玩家状态（自机由 StageContext.entity_registry 显式注入，不摸全局）

var ctx: StageContext


func get_player() -> Player:
	if ctx == null or ctx.entity_registry == null:
		return null
	var player = ctx.entity_registry.player
	return player if is_instance_valid(player) else null


func get_position() -> Vector2:
	var player := get_player()
	return player.global_position if player else Vector2.ZERO
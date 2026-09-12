class_name PlayerService
extends RefCounted
## 玩家服务 —— 只读访问玩家状态（自机由 StageContext.refs 显式注入，不摸全局）

var ctx: StageContext


func get_player() -> Player:
	if ctx == null or ctx.refs == null:
		return null
	var p = ctx.refs.player
	return p if is_instance_valid(p) else null


func get_position() -> Vector2:
	var p := get_player()
	return p.global_position if p else Vector2.ZERO
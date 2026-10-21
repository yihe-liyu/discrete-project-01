## 玩家服务 —— 只读访问玩家状态（自机由 StageContext.entity_registry 显式注入，不摸全局）
class_name PlayerService
extends RefCounted

## 绑定给本服务的关卡上下文；null 时所有查询安全返回空值。
var ctx: StageContext


## 取当前自机；无 ctx / 注册表 / 已释放 = null。
func get_player() -> Player:
	if ctx == null or ctx.entity_registry == null:
		return null
	var player = ctx.entity_registry.player
	return player if is_instance_valid(player) else null


## 取自机位置；无自机 = Vector2.ZERO。
func get_position() -> Vector2:
	var player := get_player()
	return player.global_position if player else Vector2.ZERO

## 行为上下文：行为所需的最小世界引用，由组合根注入，不碰全局（R2）；喂假 ctx 即可单测。
## 只做"定位器"（自机 + 世界查询），查询逻辑在 WorldQuery，别往这里堆方法（胖 ctx 是旧项目的坑）。
extends RefCounted
class_name BehaviorContext

var _player: Node2D
var _world_query: WorldQuery


## 注入自机与世界查询（world 可省 = 空查询：永远没有敌人）。
func setup(player: Node2D, world: WorldQuery = null) -> void:
	_player = player
	_world_query = world


## 自机世界坐标（无自机时返回 ZERO）。
func get_player_position() -> Vector2:
	return _player.global_position if _player else Vector2.ZERO


## 世界查询（未注入 = 惰建空查询，内容脚本不必判空）。
func get_world() -> WorldQuery:
	if _world_query == null:
		_world_query = WorldQuery.new()
	return _world_query

# player_base.gd
extends Area2D
class_name PlayerBase
## 自机**类型化接口**基类 —— 凡能被 `EntityRegistry.bind_player()` 绑定的自机
## （真自机 `Player` / 工作台幽灵 `GhostPlayer` / 测试桩）都从这里取单局资源。
##
## 为什么单独抽一层：`EntityRegistry.get_player_resources()` 旧实现用
## `player.get("resources")` **字符串键**读资源（鸭子类型）—— 属性改名就静默返回 null，
## 编译期查不出来。现在走类型化属性：只认 `PlayerBase` 子类。

## 单局资源（自机是 owner；消费者经 `EntityRegistry` 取同一实例）。
## 惰性创建：任何读取都保证非 null（无需 `_ready` 判空自建），也允许入树前预注入。
var _player_resources: PlayerResources
var resources: PlayerResources:
	get:
		if _player_resources == null:
			_player_resources = PlayerResources.new()
		return _player_resources
	set(v):
		_player_resources = v

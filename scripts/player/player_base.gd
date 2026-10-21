# player_base.gd
## 自机类型化接口基类 —— 凡能被 [code]EntityRegistry.bind_player()[/code] 绑定的自机
## （真自机 [code]Player[/code] / 工作台幽灵 [code]GhostPlayer[/code] / 测试桩）都从这里取单局资源。
##
## 为什么单独抽一层：[code]EntityRegistry.get_player_resources()[/code] 旧实现用
## [code]player.get("resources")[/code] 字符串键读资源（鸭子类型）—— 属性改名就静默返回 null，
## 编译期查不出来。现在走类型化属性：只认 [code]PlayerBase[/code] 子类。
extends Area2D
class_name PlayerBase

var _player_resources: PlayerResources
## 单局资源（自机是 owner；消费者经 [code]EntityRegistry[/code] 取同一实例）。
## 惰性创建：任何读取都保证非 null（无需 [code]_ready[/code] 判空自建），也允许入树前预注入。
var resources: PlayerResources:
	get:
		if _player_resources == null:
			_player_resources = PlayerResources.new()
		return _player_resources
	set(v):
		_player_resources = v

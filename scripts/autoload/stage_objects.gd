extends Node
## 关卡内"命名对象"注册表：名字 ↔ 运行对象。
## 让流程/时间线/UI 用"名字"引用对象，而不是闭包捕获局部变量 / 全局扫描（StageManager.get_boss 那种）。
## 槽位可带类型（resolve_as 返回类型正确的对象，不用到处 as）。
## 帧级作用域：load_stage 时注册；stop_stage / 关卡结束时 clear()。

var _slots: Dictionary = {}   # String -> { node: Node, type: Script }


## 用一个名字登记运行对象（type 可选，供 resolve_as 类型检查）
func register(slot: String, node: Node, type: Script = null) -> void:
	_slots[slot] = { "node": node, "type": type }


## 按名字取对象；对象已亡/未注册返回 null
func resolve(slot: String) -> Node:
	var s = _slots.get(slot)
	if s == null:
		return null
	var n: Node = s.node
	return n if is_instance_valid(n) else null


## 按名字取对象，且校验脚本类型（不匹配返回 null）
func resolve_as(slot: String, type: Script) -> Node:
	var n := resolve(slot)
	if n and (type == null or n.get_script() == type):
		return n
	return null


## 该槽位是否有活得对象
func has(slot: String) -> bool:
	return resolve(slot) != null


func unregister(slot: String) -> void:
	_slots.erase(slot)


func clear() -> void:
	_slots.clear()

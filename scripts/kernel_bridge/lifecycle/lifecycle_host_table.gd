## 宿主模板表：只存 spawn / Callable / sfx —— 与纯 program 分开（DSL10）。
##
## local id 分配必须与 LifecycleCompiler.compile_program() 完全一致：
##   actions：EMIT / EMIT_VARIANT / CALL 共用序号
##   sfx：SFX 独立序号
## 表格本身不参与原生注册；事件 (program, local) 由宿主按本表解析。
class_name LifecycleHostTable
extends RefCounted

const COMPILER := preload("res://scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd")


## 按与 compile_program 相同的相位/action 顺序建表。
static func build(lc) -> Dictionary:
	var actions: Array = []
	var sfx: Array[StringName] = []
	var speed_specs: Array = []
	for phase in lc.phases:
		for a in phase[&"on_end"]:
			match a[&"op"]:
				COMPILER.A_EMIT:
					actions.append(a[&"spawn"])
					speed_specs.append(a.get(&"speed_spec", null))
				COMPILER.A_EMIT_VARIANT:
					actions.append(a[&"spawns"])
					speed_specs.append(a.get(&"speed_spec", null))
				COMPILER.A_CALL:
					actions.append(a[&"call"])
					speed_specs.append(null)
				COMPILER.A_SFX:
					sfx.append(a[&"key"])
	return {&"actions": actions, &"sfx": sfx, &"speed_specs": speed_specs}


## 宿主表结构签名：actions 按对象身份（Callable/BulletData 不可值比较），sfx 按名字。
static func signature(table: Dictionary) -> int:
	var h: int = hash(table.get(&"sfx", []))
	for a in table.get(&"actions", []):
		h = h * 31 + _hash_action(a)
	for s in table.get(&"speed_specs", []):
		h = h * 31 + _hash_speed_spec(s)
	return h


static func _hash_action(a: Variant) -> int:
	if a is Array:
		var sub: int = 1
		for item in a:
			sub = sub * 31 + _hash_action(item)
		return sub
	if a is Callable:
		return a.get_object_id() if a.is_valid() else 0
	if a is BulletData:
		return int(a.get_instance_id())
	if a is StringName:
		return hash(a)
	return 0


static func _hash_speed_spec(s: Variant) -> int:
	if not (s is Dictionary):
		return 0
	return hash(float(s.get(&"min", 1.0))) * 31 + hash(float(s.get(&"max", 1.0)))

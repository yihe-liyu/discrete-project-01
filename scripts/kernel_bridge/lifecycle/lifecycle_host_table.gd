class_name LifecycleHostTable
extends RefCounted
## 宿主模板表：只存 spawn / Callable / sfx —— 与纯 program 分开（DSL10）。
##
## local id 分配必须与 LifecycleCompiler.compile_program() 完全一致：
##   actions：EMIT / EMIT_VARIANT / CALL 共用序号
##   sfx：SFX 独立序号
## 表格本身不参与原生注册；事件 (program, local) 由宿主按本表解析。

const COMPILER := preload("res://scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd")


## 按与 compile_program 相同的相位/action 顺序建表。
static func build(lc) -> Dictionary:
	var actions: Array = []
	var sfx: Array[StringName] = []
	for phase in lc.phases:
		for a in phase[&"on_end"]:
			match a[&"op"]:
				COMPILER.A_EMIT, COMPILER.A_EMIT_VARIANT, COMPILER.A_CALL:
					actions.append(a.get(&"spawn", a.get(&"spawns", a.get(&"call"))))
				COMPILER.A_SFX:
					sfx.append(a[&"key"])
	return {&"actions": actions, &"sfx": sfx}


## 宿主表结构签名：actions 按对象身份（Callable/BulletData 不可值比较），sfx 按名字。
static func signature(table: Dictionary) -> int:
	var h: int = hash(table.get(&"sfx", []))
	for a in table.get(&"actions", []):
		h = h * 31 + _hash_action(a)
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

## ParamValidator —— 参数注入校验（无 class_name，使用处 preload 引用）。
extends RefCounted

## 参数注入校验（C4：把"打错键名 / 类型不匹配静默失效"变成"校验 + 响亮报错"）。
## 用法：把注入点原来那个 `for k in params: if k in script: script.set(...)`
##       替换成 `ParamValidator.apply(script, params)`。
## - 未在脚本属性列表里的键 → push_error（打错键名）。
## - 类型明显不匹配（数字/向量/颜色等互不兼容）→ push_error。
## - 宽松放行：int↔float、String↔数字（Godot 会 coerce），避免误报。
## 返回错误列表（供测试/更细处理；apply 会 push_error）。

static func validate(target: Object, params: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if target == null:
		return errs
	var types := {}
	for p in target.get_property_list():
		types[p.name] = p.type
	for k in params:
		if not types.has(k):
			errs.append("参数 '%s' 不是 %s 的属性（打错键名？）" % [str(k), target.get_class()])
			continue
		_check_type(errs, str(k), params[k], types[k], target.get_class())
	return errs


## 校验 + 只设合法键 + 响亮报错
static func apply(target: Object, params: Dictionary) -> void:
	if target == null:
		return
	for e in validate(target, params):
		push_error("ParamValidator: " + e)
	for k in params:
		if k in target:
			target.set(k, params[k])


static func _check_type(errs: Array[String], key: String, val, prop_type: int, owner: String) -> void:
	var vt := typeof(val)
	# 同型 → 放过
	if vt == prop_type:
		return
	# int↔float → 放过（Godot set 会 coerces）
	if _is_numeric(vt) and _is_numeric(prop_type):
		return
	# String → 数字：仅当字符串本身是合法数字才放过（"fast" 这类非数字串要报错）
	if vt == TYPE_STRING and _is_numeric(prop_type):
		var s: String = val
		if s.is_valid_float() or s.is_valid_int():
			return
	# 数字 → String：Godot 能转，放过
	if _is_numeric(vt) and prop_type == TYPE_STRING:
		return
	errs.append("参数 '%s' 类型不匹配：%s.%s 期望 %s，实给 %s" % [
		key, owner, key, _type_name(prop_type), _type_name(vt)])


static func _is_numeric(t: int) -> bool:
	return t == TYPE_FLOAT or t == TYPE_INT


static func _type_name(t: int) -> String:
	match t:
		TYPE_FLOAT: return "float"
		TYPE_INT: return "int"
		TYPE_STRING: return "String"
		TYPE_BOOL: return "bool"
		TYPE_OBJECT: return "Object"
		TYPE_ARRAY: return "Array"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_NIL: return "null"
		_: return "type_" + str(t)

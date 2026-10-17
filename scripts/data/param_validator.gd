## ParamValidator —— 参数注入校验（无 class_name，使用处 preload 引用）。
extends RefCounted

## 参数注入校验（把"类型不匹配静默失效"变成"校验 + 响亮报错"）。
## 用法：把注入点原来那个 `for k in params: if k in script: script.set(...)`
##       替换成 `ParamValidator.apply(script, params)`。
## - 未在脚本属性列表里的键 → 静默跳过（共享字典跨脚本合法：PhaseData.params 同灌 move+shoot，
##   未知键通常属于兄弟脚本，无法与"打错键名"可靠区分，故不警告以免刷屏——validate_unknown_keys 仍保留供按需用）。
## - `apply(..., p_strict=true)`：未知键也 push_error（只灌一个脚本时用，如 EnemyData.params）。
## - `validate_unknown_keys_union(scripts, params)`：多脚本共享 params 的并集校验（如 PhaseData.params）。
## - 类型明显不匹配（数字/向量/颜色等互不兼容）→ push_error。
## - 宽松放行：int↔float、String↔数字（Godot 会 coerce），避免误报。
## 返回错误列表（供测试/更细处理；apply 会 push_error）。

static func validate(target: Object, params: Dictionary) -> Array[String]:
	var errs: Array[String] = []
	if target == null:
		return errs
	var types := {}
	for prop in target.get_property_list():
		types[prop.name] = prop.type
	for key in params:
		if not types.has(key):
			continue  # 未知键归入 warning（validate_unknown_keys）
		_check_type(errs, str(key), params[key], types[key], target.get_class())
	return errs


## 未知键（跨脚本共享 params 时属合法情形）→ warning 级
static func validate_unknown_keys(target: Object, params: Dictionary) -> Array[String]:
	var warns: Array[String] = []
	if target == null:
		return warns
	var types := {}
	for prop in target.get_property_list():
		types[prop.name] = prop.type
	for key in params:
		if not types.has(key):
			warns.append("参数 '%s' 不是 %s 的属性（打错键名？共享字典跨脚本时请用并集校验）" % [str(key), target.get_class()])
	return warns


## 多脚本共享 params 的并集校验（PhaseData: pre_move/move/shoot 同一份字典）。
## 键必须至少属于其中一个脚本；同名键仍会同时注入多个脚本（这条不报）。
static func validate_unknown_keys_union(scripts: Array, params: Dictionary) -> Array[String]:
	var warns: Array[String] = []
	if params.is_empty():
		return warns
	var known := {}
	for script_resource in scripts:
		if not (script_resource is Script):
			continue
		for prop in (script_resource as Script).get_script_property_list():
			known[prop.get("name", "")] = true
	for key in params:
		if not known.has(key):
			warns.append("参数 '%s' 不属于本阶段 pre_move/move/shoot 任一脚本（打错键名？）" % str(key))
	return warns


## 校验 + 只设合法键 + 类型错响亮报错。
## `p_strict=true` 时未知键也 push_error（只灌一个脚本的场景，如 EnemyData.params）。
static func apply(target: Object, params: Dictionary, p_strict: bool = false) -> void:
	if target == null:
		return
	for err in validate(target, params):
		push_error("ParamValidator: " + err)
	if p_strict:
		for warning in validate_unknown_keys(target, params):
			push_error("ParamValidator（严格）: " + warning)
	for key in params:
		if key in target:
			target.set(key, params[key])





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
		var text: String = val
		if text.is_valid_float() or text.is_valid_int():
			return
	# 数字 → String：Godot 能转，放过
	if _is_numeric(vt) and prop_type == TYPE_STRING:
		return
	errs.append("参数 '%s' 类型不匹配：%s.%s 期望 %s，实给 %s" % [
		key, owner, key, _type_name(prop_type), _type_name(vt)])


static func _is_numeric(type_id: int) -> bool:
	return type_id == TYPE_FLOAT or type_id == TYPE_INT


static func _type_name(type_id: int) -> String:
	match type_id:
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
		_: return "type_" + str(type_id)

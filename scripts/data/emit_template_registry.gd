## 内容层的 EmitTemplate 注册表：名字 → 模板。
## 不是 autoload；由 Stage / 内容包持有，卸载时 clear()。
class_name EmitTemplateRegistry
extends RefCounted

var _by_id: Dictionary = {}
var _by_numeric: Dictionary = {}
var _next_id: int = 1
var _last_errors: Array[String] = []


func register(template: EmitTemplate) -> bool:
	_last_errors = []
	if template == null:
		_last_errors.append("EmitTemplate 为 null")
		return false
	var errors: Array[String] = template.validate()
	if not errors.is_empty():
		_last_errors = errors
		return false
	if _by_id.has(template.id):
		_last_errors.append("EmitTemplate id 重复：%s" % template.id)
		return false
	if template.numeric_id < 0:
		template.numeric_id = _next_id
		_next_id += 1
	_by_id[template.id] = template
	_by_numeric[template.numeric_id] = template
	return true


func get_template(id: StringName) -> EmitTemplate:
	return _by_id.get(id)


func get_by_numeric(numeric_id: int) -> EmitTemplate:
	return _by_numeric.get(numeric_id)


func has(id: StringName) -> bool:
	return _by_id.has(id)


func size() -> int:
	return _by_id.size()


func clear() -> void:
	_by_id.clear()
	_by_numeric.clear()
	_next_id = 1
	_last_errors.clear()


## 最近一次 register 的错误；成功时为空。
func last_errors() -> Array[String]:
	return _last_errors

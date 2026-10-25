## diff_pick 运行时轨迹。
##
## 只记录「实际跑到的 diff_pick 调用」：source 行 + 数组 + 当前难度 + 选中值。
## 默认关闭；调试会话 / 工具起演时打开，结束关闭。静态反射/源码扫描不污染轨迹。
class_name ParamTrace
extends RefCounted

static var _enabled: bool = false
static var _records: Dictionary = {}


static func set_enabled(value: bool) -> void:
	_enabled = value


static func is_enabled() -> bool:
	return _enabled


static func clear() -> void:
	_records.clear()


static func records() -> Dictionary:
	return _records


## 由 Difficulty.pick 调用；source 从栈里只认 res://data/ 下的内容行。
static func record(values: Array, difficulty: int, context: String) -> void:
	if not _enabled or values.is_empty():
		return
	var source := pick_source(get_stack())
	if source == "":
		return
	var index := clampi(difficulty, 0, values.size() - 1)
	var texts: Array[String] = []
	for value in values:
		texts.append(str(value))
	var old: Dictionary = _records.get(source, {})
	_records[source] = {
		"source": source,
		"values": texts,
		"difficulty": difficulty,
		"chosen": str(values[index]),
		"count": int(old.get("count", 0)) + 1,
		"context": context,
		"frame": Engine.get_physics_frames(),
	}


static func pick_source(stack: Array) -> String:
	for frame in stack:
		var source := String((frame as Dictionary).get("source", ""))
		if source.begins_with("res://data/"):
			return "%s:%d" % [source, int((frame as Dictionary).get("line", 0))]
	return ""

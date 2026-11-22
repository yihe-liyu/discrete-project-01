## 按整数物理帧推进的属性移动器 —— 玩法移动的 Tween 替代。
##
## 新录像 / 普通游玩用本类；旧录像仍用 Tween + 秒（保持旧内容相位）。
## 每次 _physics_process 只推进一帧，帧数在入队时由秒数换算，因此
## 不会因为浮点 elapsed 或 time_scale 出现一帧抖动。
class_name FrameMover
extends Node

## 全部段执行完发一次；随后节点自动释放。
signal finished()

var _segments: Array[Dictionary] = []
var _index: int = 0
var _frame: int = 0
var _from: Variant
var _default_ease: int = Tween.EASE_IN_OUT
var _default_trans: int = Tween.TRANS_QUAD


## 挂到 target 下并返回 mover；target 释放时一起释放。
static func attach(target: Node) -> FrameMover:
	var mover := FrameMover.new()
	target.add_child(mover)
	return mover


func set_ease(ease_type: int) -> FrameMover:
	_default_ease = ease_type
	return self


func set_trans(trans_type: int) -> FrameMover:
	_default_trans = trans_type
	return self


## 在 duration 秒内把 object 的 property 移到 final_value。
func tween_property(object: Object, property: NodePath, final_value: Variant, duration: float) -> FrameMover:
	if object == null or duration <= 0.0:
		if object != null:
			object.set(StringName(property), final_value)
		return self
	_segments.append({
		"kind": &"prop",
		"object": object,
		"property": property,
		"to": final_value,
		"frames": maxi(1, roundi(duration * Engine.physics_ticks_per_second)),
		"ease": _default_ease,
		"trans": _default_trans,
	})
	return self


## 停顿 duration 秒。
func tween_interval(duration: float) -> FrameMover:
	if duration > 0.0:
		_segments.append({
			"kind": &"wait",
			"frames": maxi(1, roundi(duration * Engine.physics_ticks_per_second)),
		})
	return self


## 到点执行回调。
func tween_callback(callback: Callable) -> FrameMover:
	if callback.is_valid():
		_segments.append({"kind": &"call", "callback": callback})
	return self


func _physics_process(_delta: float) -> void:
	if _index >= _segments.size():
		_finish()
		return
	var seg: Dictionary = _segments[_index]
	match StringName(seg.get("kind", &"")):
		&"call":
			var cb: Callable = seg.get("callback", Callable())
			_index += 1
			_frame = 0
			if cb.is_valid():
				cb.call()
		&"wait":
			_frame += 1
			if _frame >= int(seg.get("frames", 1)):
				_index += 1
				_frame = 0
		&"prop":
			var object: Object = seg.get("object")
			if object == null or not is_instance_valid(object):
				_index = _segments.size()
				_finish()
				return
			var property := StringName(seg.get("property"))
			if _frame == 0:
				_from = object.get(property)
			_frame += 1
			var total := int(seg.get("frames", 1))
			var t := minf(1.0, float(_frame) / float(total))
			if _frame >= total:
				object.set(property, seg.get("to"))
				_index += 1
				_frame = 0
			else:
				var target: Variant = seg.get("to")
				var interpolated: Variant = Tween.interpolate_value(
					_from, target - _from, t, 1.0,
					int(seg.get("trans", _default_trans)), int(seg.get("ease", _default_ease)))
				object.set(property, interpolated)


func _finish() -> void:
	if not is_inside_tree():
		return
	finished.emit()
	queue_free()

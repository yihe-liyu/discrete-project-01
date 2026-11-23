## 按物理 tick 推进的属性移动器 —— gameplay 移动的 Tween 替代。
##
## [b]为什么[/b][br]
## Tween 在节点之后按 delta 推进，起止点会落在渲染/物理帧边界上；
## 回放需要“第 N tick 的位置”完全可复现，所以玩法移动统一按 tick 计数。
## [br]
## [b]边界[/b][br]
## - 只给 gameplay 用；纯视觉动画继续用 Tween。[br]
## - 缓动曲线复用 [method Tween.interpolate_value]，观感一致。[br]
## - 目标释放 / 场景暂停时自动停；完成发 [signal finished] 并自释放。
class_name TickMover
extends Node

signal finished()

var _segments: Array[Dictionary] = []
var _index: int = 0
var _frame: int = 0
var _from: Variant
var _default_ease: int = Tween.EASE_IN_OUT
var _default_trans: int = Tween.TRANS_QUAD


static func attach(target: Node) -> TickMover:
	var mover := TickMover.new()
	target.add_child(mover)
	return mover


func _ready() -> void:
	# 由 SimClock 统一推进；节点自身不自动步进（物理回调中新增节点会错过本帧注册）。
	set_physics_process(false)
	SimClock.register_mover(self)


func _exit_tree() -> void:
	SimClock.unregister_mover(self)


func set_ease(ease_type: int) -> TickMover:
	_default_ease = ease_type
	return self


func set_trans(trans_type: int) -> TickMover:
	_default_trans = trans_type
	return self


## 在 duration 秒内把 object 的 property 移到 final_value（按 tick 换算）。
func tween_property(object: Object, property: NodePath, final_value: Variant, duration: float) -> TickMover:
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
func tween_interval(duration: float) -> TickMover:
	if duration > 0.0:
		_segments.append({
			"kind": &"wait",
			"frames": maxi(1, roundi(duration * Engine.physics_ticks_per_second)),
		})
	return self


## 到点执行回调。
func tween_callback(callback: Callable) -> TickMover:
	if callback.is_valid():
		_segments.append({"kind": &"call", "callback": callback})
	return self


## 仅供测试/手动推进；生产路径由 SimClock 调 tick_mover()。
func _physics_process(_delta: float) -> void:
	tick_mover()


func tick_mover() -> void:
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
				_finish()
				return
			var property := StringName(seg.get("property"))
			if _frame == 0:
				_from = object.get(property)
			_frame += 1
			var total := int(seg.get("frames", 1))
			var value: Variant = Tween.interpolate_value(_from, seg.get("to") - _from,
				float(_frame), float(total), int(seg.get("trans", Tween.TRANS_QUAD)),
				int(seg.get("ease", Tween.EASE_IN_OUT)))
			object.set(property, value)
			if _frame >= total:
				_index += 1
				_frame = 0
		_:
			_index += 1
			_frame = 0


func _finish() -> void:
	if not is_queued_for_deletion():
		finished.emit()
		queue_free()

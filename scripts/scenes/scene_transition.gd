# SceneTransition — 场景切换 + 黑场过渡
class_name SceneTransition
extends RefCounted
## 场景切换过渡：TRANSITIONING → fade_out → change_scene → fade_in → target_state

const FADE_DURATION: float = 0.4

var _parent: Node
var _transition_rect: ColorRect


func setup(parent: Node) -> void:
	_parent = parent
	_setup_transition()


func _setup_transition() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_parent.add_child(layer)

	_transition_rect = ColorRect.new()
	_transition_rect.color = Color.BLACK
	_transition_rect.modulate.a = 0.0
	_transition_rect.visible = false
	_transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_transition_rect)


## 世界由调用方（GameManager 组合根）经回调登记/操作，transition 不再读 .current 全局。
## on_pause_world/on_clear_world 作用于**切出**的世界；on_resume_world 作用于**切入**的世界。
func change_scene(path: String, current_scene_path: String, on_scene_left: Callable,
		on_pause_world: Callable = Callable(), on_clear_world: Callable = Callable(),
		on_resume_world: Callable = Callable()) -> String:
	if on_pause_world.is_valid():
		on_pause_world.call()
	_parent.get_tree().paused = true

	if current_scene_path != "":
		on_scene_left.call(current_scene_path)

	await _fade_out()

	if on_clear_world.is_valid():
		on_clear_world.call()

	var err := _parent.get_tree().change_scene_to_file(path)
	if err != OK:
		# 场景加载失败：回滚暂停状态，避免永久黑屏
		push_error("SceneTransition: 场景切换失败 %s (%s)" % [path, error_string(err)])
		_parent.get_tree().paused = false
		if on_resume_world.is_valid():
			on_resume_world.call()
		return current_scene_path if current_scene_path != "" else path
	await _parent.get_tree().process_frame

	await _fade_in()

	_parent.get_tree().paused = false
	if on_resume_world.is_valid():
		on_resume_world.call()

	return path


func _fade_out(duration: float = FADE_DURATION):
	_transition_rect.modulate.a = 0.0
	_transition_rect.visible = true
	var tween: Tween = _transition_rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_transition_rect, "modulate:a", 1.0, duration)
	await tween.finished


func _fade_in(duration: float = FADE_DURATION):
	_transition_rect.modulate.a = 1.0
	var tween: Tween = _transition_rect.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_transition_rect, "modulate:a", 0.0, duration)
	await tween.finished
	_transition_rect.visible = false

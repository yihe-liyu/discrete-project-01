# SceneTransition — 场景切换 + 黑场过渡
## 场景切换过渡：TRANSITIONING → fade_out → change_scene → fade_in → target_state
class_name SceneTransition
extends RefCounted

const FADE_DURATION: float = 0.4

var _parent: Node
var _transition_rect: ColorRect
var _loading_label: Label
## 已经预热过的背景场景路径（shader pipeline 缓存是全局的，预热一次即可）。
var _warmed_backgrounds: Dictionary = {}


## 绑定宿主并建全屏黑场 CanvasLayer（过渡用）。
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

	_loading_label = Label.new()
	_loading_label.text = "载入中…"
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 28)
	_loading_label.visible = false
	layer.add_child(_loading_label)


## 世界由调用方（GameManager 组合根）经回调登记/操作，transition 不再读 .current 全局。
## on_pause_world/on_clear_world 作用于切出的世界；on_resume_world 作用于切入的世界。
func change_scene(path: String, current_scene_path: String, on_scene_left: Callable,
		on_pause_world: Callable = Callable(), on_clear_world: Callable = Callable(),
		on_resume_world: Callable = Callable(), prewarm_scene: PackedScene = null) -> String:
	if on_pause_world.is_valid():
		on_pause_world.call()
	_parent.get_tree().paused = true

	if current_scene_path != "":
		on_scene_left.call(current_scene_path)

	await _fade_out()

	if on_clear_world.is_valid():
		on_clear_world.call()

	# 自定义背景的首次 shader/pipeline 编译很贵（Stage4 实测数秒）。
	# 在切场景前的黑场里先实例化并渲染几帧，正式进入时就不必再编译。
	await _prewarm_background(prewarm_scene)

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


## 黑场预热：实例化背景到隐藏 SubViewport，渲染几帧触发 pipeline 编译后释放。
func _prewarm_background(scene: PackedScene) -> void:
	if scene == null:
		return
	var key := scene.resource_path
	if key != "" and _warmed_backgrounds.has(key):
		return
	if key != "":
		_warmed_backgrounds[key] = true

	_loading_label.visible = true
	var vp := SubViewport.new()
	vp.size = Vector2i(640, 480)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	_parent.add_child(vp)

	var bg := scene.instantiate()
	vp.add_child(bg)
	await _parent.get_tree().process_frame
	var cam := bg.get("camera") as Camera3D
	if cam:
		cam.current = true
	# 多等几帧，覆盖主 pass / 环境雾 / 天空等 pipeline。
	for i in 4:
		await _parent.get_tree().process_frame

	vp.queue_free()
	await _parent.get_tree().process_frame
	_loading_label.visible = false

	# 预热用的实例不应该影响正式场景；清掉临时全局状态由目标场景自己重建。
	if bg and is_instance_valid(bg):
		bg.queue_free()


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

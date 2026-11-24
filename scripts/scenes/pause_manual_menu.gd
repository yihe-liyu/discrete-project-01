# PauseManualMenu.gd — 暂停菜单里的操作说明，只占游戏框，不盖右侧状态栏。
extends BasePage

const PAGE_COUNT := 6
const HELP_PATH := "res://assets/Textures/help/help%02d.png"

var _pages: Array[Texture2D] = []
var _current: int = 0
var _texture_rect: TextureRect
var _input_ready: bool = false


func _ready() -> void:
	super._ready()
	_texture_rect = $"TextureRect"
	for i in PAGE_COUNT:
		_pages.append(load(HELP_PATH % (i + 1)))
	_texture_rect.texture = _pages[0]
	_texture_rect.modulate.a = 0.0


func on_enter() -> void:
	_fade_overlay_in(0.2)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_texture_rect, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func(): _input_ready = true)


func on_leave() -> void:
	_input_ready = false
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_instance_valid(_overlay):
		tw.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	tw.tween_property(_texture_rect, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if not _input_ready:
		return
	if event.is_action_pressed("ui_up"):
		_prev()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_next()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		sfx_back()
		go_back()
		get_viewport().set_input_as_handled()


func _prev() -> void:
	_current = wrapi(_current - 1, 0, PAGE_COUNT)
	_switch_to(_pages[_current])
	sfx_nav()


func _next() -> void:
	_current = wrapi(_current + 1, 0, PAGE_COUNT)
	_switch_to(_pages[_current])
	sfx_nav()


func _switch_to(tex: Texture2D) -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_texture_rect, "modulate:a", 0.0, 0.06)
	tw.tween_callback(func(): _texture_rect.texture = tex)
	tw.tween_property(_texture_rect, "modulate:a", 1.0, 0.1)

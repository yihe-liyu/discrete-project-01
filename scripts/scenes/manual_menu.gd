# ManualMenu.gd — 操作说明（help01~06，↑↓切换）
extends BasePage

const PAGE_COUNT := 6

var _pages: Array[Texture2D] = []
var _current: int = 0

@onready var _texture_rect: TextureRect = $"TextureRect"
@onready var _title: TextureRect = $"TitleTexture"


func _ready() -> void:
	super._ready()

	for i in PAGE_COUNT:
		var num := "%02d" % (i + 1)
		_pages.append(load("res://assets/Textures/help/help" + num + ".png"))

	_texture_rect.texture = _pages[0]
	_texture_rect.modulate.a = 0.0
	_title.modulate.a = 0.0


func on_enter() -> void:
	_fade_overlay_in(0.3)
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_title, "modulate:a", 1.0, 0.3)
	tw.tween_property(_texture_rect, "modulate:a", 1.0, 0.3)


func on_leave() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.3)
	tw.tween_property(_title, "modulate:a", 0.0, 0.3)
	tw.tween_property(_texture_rect, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_up"):
		_prev()
	elif Input.is_action_just_pressed("ui_down"):
		_next()
	elif Input.is_action_just_pressed("ui_cancel"):
		sfx_back()
		go_back()


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
	tw.tween_property(_texture_rect, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func(): _texture_rect.texture = tex)
	tw.tween_property(_texture_rect, "modulate:a", 1.0, 0.12)

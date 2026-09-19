extends Node2D
class_name NumberSprite
## 用贴图显示数字 —— 横向排列 0-9 的 sprite sheet
## 每帧更新，自动创建/回收数字精灵
## 配置项由创建者 (game_ui.gd) 设置

var digit_texture: Texture2D
var char_count: int
var dot_index: int = -1
var slash_index: int = -1
var pct_index: int = -1
var minus_index: int = -1
var is_left_align: bool = false
var digit_count: int = 8
var digit_spacing: float = 24.0
@export var value: int = 0:
	set(v):
		if value == v and _text == "":
			return
		value = v
		_text = ""
		_is_dirty = true

var _digits: Array[Sprite2D] = []
var _text: String = ""
var _is_ready_done: bool = false
var _is_dirty: bool = true


func _ready() -> void:
	_is_ready_done = true
	if not digit_texture or char_count <= 0:
		return
	_setup_digits()


func _setup_digits() -> void:
	var frame_w: float = digit_texture.get_width() / float(char_count)
	var frame_h: float = digit_texture.get_height()
	for i in range(digit_count):
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = digit_texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.region_enabled = true
		sprite.region_rect = Rect2(0, 0, frame_w, frame_h)
		sprite.position.x = i * digit_spacing
		sprite.visible = false
		add_child(sprite)
		_digits.append(sprite)


func _process(_delta: float) -> void:
	if not _is_ready_done or not _is_dirty:
		return
	_is_dirty = false

	var text := _text
	if text == "":
		if is_left_align:
			text = str(value)
		else:
			text = "%0*d" % [digit_count, value]

	var offset := 0
	if not is_left_align:
		offset = digit_count - text.length()

	for i in range(digit_count):
		if offset > 0 and i < offset:
			_digits[i].visible = false
			continue
		var ti := i - offset
		if ti < 0 or ti >= text.length():
			_digits[i].visible = false
			continue

		var ch := text[ti]
		var idx := -1
		if ch >= "0" and ch <= "9":
			idx = ch.to_int()
		elif ch == "." and dot_index >= 0:
			idx = dot_index
		elif ch == "/" and slash_index >= 0:
			idx = slash_index
		elif ch == "%" and pct_index >= 0:
			idx = pct_index
		elif ch == "-" and minus_index >= 0:
			idx = minus_index

		if idx >= 0:
			var tex_w: float = float(digit_texture.get_width())
			_digits[i].region_rect = Rect2(
				idx * tex_w / float(char_count), 0,
				tex_w / float(char_count), digit_texture.get_height()
			)
			_digits[i].visible = true
		else:
			_digits[i].visible = false


func show_text(t: String) -> void:
	_text = t
	_is_dirty = true

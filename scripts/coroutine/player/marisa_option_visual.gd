extends OptionVisual

var sprite: Sprite2D
var _timer: float = 0.0

func setup(option: Node2D) -> void:
	sprite = Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = preload("res://assets/Textures/player/pl01.png")
	tex.region = Rect2(160, 144, 16, 16)
	sprite.texture = tex
	sprite.scale = Vector2(2, 2)
	option.add_child(sprite)
	set_process(true)

func _process(delta: float):
	if get_tree().paused or not is_instance_valid(sprite):
		return
	_timer += delta
	var s := 2.0 + sin(_timer * 10.0) * 0.2  # 1.8 ~ 2.2 之间脉动
	sprite.scale = Vector2(s, s)

func update_visual(_ctx: StageContext, _leader: Node2D) -> void:
	pass

extends OptionVisual

var sprite: Sprite2D

func setup(option: Node2D) -> void:
	sprite = Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = preload("res://assets/Textures/player/pl00.png")
	tex.region = Rect2(80, 144, 16, 16)
	sprite.texture = tex
	sprite.scale = Vector2(2, 2)
	option.add_child(sprite)
	set_process(true)

func _process(_delta):
	if get_tree().paused or not is_instance_valid(sprite):
		return
	sprite.rotation += deg_to_rad(3.0)

func update_visual(_ctx: StageContext, _leader: Node2D) -> void:
	pass

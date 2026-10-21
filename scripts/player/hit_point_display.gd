# hit_point_display.gd
## 自机判定点显示：focus 时淡入，阴阳玉反向自转。
extends Node2D
class_name HitPointDisplay

## 判定点自转速度（度/秒）
@export var rotate_speed: float = 180.0
## 渐隐渐显过渡时间（秒）
@export var fade_duration: float = 0.15

@onready var yin: Sprite2D = $Yin
@onready var yang: Sprite2D = $Yang

var target_alpha: float = 0.0
var current_alpha: float = 0.0

func _ready():
	modulate.a = 0.0

func _process(delta):
	yin.rotation += deg_to_rad(rotate_speed) * delta
	yang.rotation -= deg_to_rad(rotate_speed * 0.7) * delta

	current_alpha = move_toward(current_alpha, target_alpha, (1.0 / fade_duration) * delta)
	modulate.a = current_alpha

func show_hitpoint():
	target_alpha = 1.0

func hide_hitpoint():
	target_alpha = 0.0

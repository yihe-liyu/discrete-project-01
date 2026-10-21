# hit_point_display.gd
## 自机判定点显示：focus 时淡入，阴阳玉反向自转。
extends Node2D
class_name HitPointDisplay

## 判定点自转速度（度/秒）
@export var rotate_speed: float = 180.0
## 渐隐渐显过渡时间（秒）
@export var fade_duration: float = 0.15

## 阴玉贴图节点。
@onready var yin: Sprite2D = $Yin
## 阳玉贴图节点。
@onready var yang: Sprite2D = $Yang

## 目标透明度（show / hide 设置）。
var target_alpha: float = 0.0
## 当前透明度（_process 追赶 target）。
var current_alpha: float = 0.0

func _ready():
	modulate.a = 0.0

func _process(delta):
	yin.rotation += deg_to_rad(rotate_speed) * delta
	yang.rotation -= deg_to_rad(rotate_speed * 0.7) * delta

	current_alpha = move_toward(current_alpha, target_alpha, (1.0 / fade_duration) * delta)
	modulate.a = current_alpha

## 显示判定点（目标 alpha = 1，_process 淡入）。
func show_hitpoint():
	target_alpha = 1.0

## 隐藏判定点（目标 alpha = 0，_process 淡出）。
func hide_hitpoint():
	target_alpha = 0.0

extends Node2D
class_name YYJudeVisual
## 红YY玉外观：本体不动，roll 顺时针旋转，roll2 逆时针旋转

@export var roll_speed_1: float = 12.0   ## roll 转速 (弧度/秒)
@export var roll_speed_2: float = -6.0  ## roll2 转速 (弧度/秒，负数=逆时针)

@onready var _roll: Sprite2D = $Roll
@onready var _roll2: Sprite2D = $Roll2


func _process(delta: float) -> void:
	if _roll:
		_roll.rotation += roll_speed_1 * delta
	if _roll2:
		_roll2.rotation += roll_speed_2 * delta

## 死亡特效：继承 HitEffect，按 AnimatedSprite 播放一次后回收。
extends HitEffect
class_name DeathEffect

@onready var ani: AnimatedSprite2D = $AnimatedSprite2D

func _setup() -> void:
	ani.play("default")
	ani.animation_finished.connect(_finish, CONNECT_ONE_SHOT)
	velocity = Vector2.RIGHT.rotated(RNG.randf_range(0, TAU)) * 180.0
	rotation = velocity.angle()

func set_tint(color: Color) -> void:
	ani.modulate = color

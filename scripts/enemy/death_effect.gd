## 死亡特效：继承 HitEffect，按 AnimatedSprite 播放一次后回收。
extends HitEffect
class_name DeathEffect

## 场景里声明的死亡动画节点（播放 default，播完回收）。
@onready var ani: AnimatedSprite2D = $AnimatedSprite2D

func _setup() -> void:
	ani.play("default")
	ani.animation_finished.connect(_finish, CONNECT_ONE_SHOT)
	velocity = Vector2.RIGHT.rotated(RNG.randf_range(0, TAU)) * 180.0
	rotation = velocity.angle()

## 给死亡特效的 AnimatedSprite 染色。
func set_tint(color: Color) -> void:
	ani.modulate = color

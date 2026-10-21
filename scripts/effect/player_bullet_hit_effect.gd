## 通用自机子弹击中特效
## 设计：一个类 + 参数化场景 —— 新增特效 = 复制 hit_effect_*.tscn + 换贴图/动画 + 调参数，零代码！
##
## 自动识别节点结构：
##   - 有 AnimatedSprite2D → 动画版：播放第一个动画，播完回收，同时整体淡出
##   - 有 Sprite2D        → 单帧版：淡出后回收
extends HitEffect
class_name PlayerBulletHitEffect

## 飞散速度（px/s）
@export var speed: float = 300.0
## 淡出时长（秒；0 = 不淡出，动画播完即收 —— 动画自带消散效果时用 0）
@export var fade_time: float = 0.3
## 飞散方向随机抖动（弧度，0=不抖）
@export var jitter: float = 0.0
## 生成位置随机偏移半径（px，0=不偏移 —— 想要更自然/不遮挡时调大）
@export var pos_jitter: float = 0.0

var _tint: Color = Color.WHITE


func _get_speed() -> float:
	return speed


func _setup() -> void:
	# 生成位置随机偏移（相对命中点）
	if pos_jitter > 0.0:
		global_position += Vector2(
			RNG.randf_range(-pos_jitter, pos_jitter),
			RNG.randf_range(-pos_jitter, pos_jitter))
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if anim:
		# 动画版：播第一个动画，播完回收
		var names := anim.sprite_frames.get_animation_names()
		if names.size() > 0:
			anim.play(names[0])
		anim.animation_finished.connect(_finish, CONNECT_ONE_SHOT)
		# fade_time > 0 时叠加淡出；= 0 时不淡出（动画自带消散）
		if fade_time > 0.0:
			var tw := create_tween()
			tw.tween_property(anim, "modulate", Color(_tint.r, _tint.g, _tint.b, 0), fade_time)
	elif sprite:
		# 单帧版：淡出后回收（无动画，必须靠淡出消失）
		var tw := create_tween()
		tw.tween_property(sprite, "modulate:a", 0, fade_time)
		tw.tween_callback(_finish)


## 给动画 / 精灵染色（两种节点结构都支持）。
func set_tint(color: Color) -> void:
	_tint = color
	var anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
	var sprite: Sprite2D = get_node_or_null("Sprite2D")
	if anim:
		anim.modulate = color
	elif sprite:
		sprite.modulate = color


func _on_velocity_set() -> void:
	rotation = velocity.angle() + RNG.randf_range(-jitter, jitter) if jitter > 0.0 else velocity.angle()

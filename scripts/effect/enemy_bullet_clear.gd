extends HitEffect
class_name EnemyBulletClear

## 敌弹消弭特效——扩散缩小 + 透明渐变

@onready var sprite: Sprite2D = $Sprite2D

const BLEND_SHADER = preload("res://gdshader/bullet_fog_blend.gdshader")

var _tween: Tween


func _ready() -> void:
	_ensure_material()


func _get_speed() -> float:
	return 0.0


func _setup() -> void:
	# 材质、缩放、朝向、alpha 每帧重置，避免复用旧状态
	if _tween and _tween.is_valid():
		_tween.kill()

	# 防御：add_child 同栈 activate 时 _ready 未跑，@onready sprite 可能为 null
	if sprite == null:
		return

	sprite.scale = Vector2.ONE
	rotation = RNG.randf_range(0.0, TAU)

	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter("fog_tint:a", 0.75)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(sprite, "scale", Vector2(0.2, 0.2), 0.2)
	_tween.tween_method(_set_alpha.bind(mat), 1.0, 0.0, 0.2)
	_tween.chain().tween_callback(_finish)


func set_tint(color: Color) -> void:
	if sprite == null:
		return
	var mat := sprite.material as ShaderMaterial
	if not mat:
		return
	# 提亮 1.5x，让消弹特效比弹幕更亮
	var bright := Color(
		minf(color.r * 1.5, 1.0),
		minf(color.g * 1.5, 1.0),
		minf(color.b * 1.5, 1.0),
		color.a
	)
	mat.set_shader_parameter("fog_tint", bright)


## 确保 Sprite2D 挂了 blend shader（只做一次）
func _ensure_material() -> void:
	if sprite.material:
		return
	var mat := ShaderMaterial.new()
	mat.shader = BLEND_SHADER
	sprite.material = mat


## tween 回调：逐帧降低 alpha
func _set_alpha(a: float, mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("fog_tint:a", a)


func _get_life_limit() -> float:
	return 1.5

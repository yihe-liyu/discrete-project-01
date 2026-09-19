# FieldFilterLayer.gd
extends CanvasLayer
class_name FieldFilterLayer
## 场地颜色滤镜（Bomb）：从**游戏框中心**扩圆铺满 → 停留 → 渐隐。
## 范围严格限制在游戏框内（ColorRect = 场地矩形），不影响框外 HUD。

## 扩圆 / 停留 / 渐隐时长（秒）。
@export var expand_time: float = 0.45
@export var hold_time: float = 1.0
@export var fade_time: float = 0.7
## 圆边缘羽化（px）。
@export var edge_softness: float = 80.0

@onready var _filter: ColorRect = $Filter

var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	_material = _filter.material as ShaderMaterial
	_material.set_shader_parameter("rect_size", _filter.size)
	_material.set_shader_parameter("center_uv", Vector2(0.5, 0.5))
	_material.set_shader_parameter("softness", edge_softness)
	_material.set_shader_parameter("radius", 0.0)
	_material.set_shader_parameter("alpha", 0.0)
	_filter.visible = false
	GameEvents.field_filter.connect(play)


func _exit_tree() -> void:
	if GameEvents.field_filter.is_connected(play):
		GameEvents.field_filter.disconnect(play)


## 播一次：p_color.a <= 0 直接忽略（= 该 bomb 不配滤镜）。
func play(p_color: Color) -> void:
	if p_color.a <= 0.0:
		return
	_kill()
	var max_radius := _filter.size.length() * 0.5   # 场地对角线/2：铺满整个框
	_material.set_shader_parameter("filter_color", p_color)
	_material.set_shader_parameter("radius", 0.0)
	_material.set_shader_parameter("alpha", 1.0)
	_filter.visible = true
	_tween = create_tween()
	_tween.tween_method(_set_radius, 0.0, max_radius, expand_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_alpha, 1.0, 0.0, fade_time).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_on_finished)


func _set_radius(p_radius: float) -> void:
	_material.set_shader_parameter("radius", p_radius)


func _set_alpha(p_alpha: float) -> void:
	_material.set_shader_parameter("alpha", p_alpha)


func _on_finished() -> void:
	_filter.visible = false
	_material.set_shader_parameter("radius", 0.0)
	_material.set_shader_parameter("alpha", 0.0)


func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

# FieldFilterLayer.gd
extends CanvasLayer
class_name FieldFilterLayer
## 场地颜色滤镜（Bomb）：从**游戏框中心**扩圆铺满 → 停留 → 渐隐。
## 范围严格限制在游戏框内（ColorRect = 场地矩形），不影响框外 HUD。

## 扩圆 / 停留 / 渐隐时长（秒）。
@export var expand_time: float = 1.5
@export var hold_time: float = 0.5
@export var fade_time: float = 3.0
## 圆边缘羽化（px）。
@export var edge_softness: float = 160.0

@export_group("被弹炸弹窗口（框内整体渐显）")
## 窗口期间框内整体的红滤镜颜色（a = 浓度；a <= 0 = 不启用）
@export var deathbomb_color: Color = Color(1.0, 0.2, 0.2, 0.35)
## 渐显时长（秒）
@export var deathbomb_fade_in: float = 0.2
## 渐隐时长（秒）
@export var deathbomb_fade_out: float = 0.35

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
	GameEvents.deathbomb_started.connect(_on_deathbomb_started)
	GameEvents.deathbomb_ended.connect(_on_deathbomb_ended)


func _exit_tree() -> void:
	if GameEvents.field_filter.is_connected(play):
		GameEvents.field_filter.disconnect(play)
	if GameEvents.deathbomb_started.is_connected(_on_deathbomb_started):
		GameEvents.deathbomb_started.disconnect(_on_deathbomb_started)
	if GameEvents.deathbomb_ended.is_connected(_on_deathbomb_ended):
		GameEvents.deathbomb_ended.disconnect(_on_deathbomb_ended)


## 播一次：p_color.a <= 0 直接忽略（= 该 bomb 不配滤镜）。
func play(p_color: Color) -> void:
	if p_color.a <= 0.0:
		return
	_kill()
	var max_radius := _filter.size.length() * 0.75   # 场地对角线*0.75：铺满整个框
	_material.set_shader_parameter("filter_color", p_color)
	_material.set_shader_parameter("radius", 0.0)
	_material.set_shader_parameter("alpha", 1.0)
	_filter.visible = true
	_tween = create_tween()
	_tween.tween_method(_set_radius, 0.0, max_radius, expand_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_alpha, 1.0, 0.0, fade_time).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_on_finished)


## 被弹炸弹窗口开：**整框铺满**（radius 直接给满，不扩圆）+ alpha 0 → 1 渐显。
## 必须用 `ignore_time_scale` 的 tween —— 窗口期全局被定格（`time_scale = 0`），普通 tween 一步都不走。
func _on_deathbomb_started() -> void:
	if deathbomb_color.a <= 0.0:
		return
	_kill()
	_material.set_shader_parameter("filter_color", deathbomb_color)
	_material.set_shader_parameter("center_uv", Vector2(0.5, 0.5))
	_material.set_shader_parameter("radius", _filter.size.length() * 0.75)
	_material.set_shader_parameter("alpha", 0.0)
	_filter.visible = true
	_tween = _make_ignore_time_scale_tween()
	_tween.tween_method(_set_alpha, 0.0, 1.0, deathbomb_fade_in).set_trans(Tween.TRANS_QUAD)


## 窗口关（抢命成功 / 到点结算都走它）：渐隐后收起。
func _on_deathbomb_ended() -> void:
	if not _filter.visible:
		return
	_kill()
	_tween = _make_ignore_time_scale_tween()
	_tween.tween_method(_set_alpha, float(_material.get_shader_parameter("alpha")), 0.0, deathbomb_fade_out)
	_tween.tween_callback(_on_finished)


## 定格（`time_scale = 0`）与暂停里都照走的 tween：
## `ignore_time_scale` 抵掉定格，`TWEEN_PAUSE_PROCESS` 抵掉 `get_tree().paused`。
func _make_ignore_time_scale_tween() -> Tween:
	var tween := create_tween()
	tween.set_ignore_time_scale(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


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

## Miss 全屏反色圈（屏幕空间 shader）：一个 ColorRect + `miss_circle.gdshader`，最多 8 圈同时。
## 与 FxPool 分工：本层是「全屏 shader 合成」（屏幕空间）；局部精灵特效池在 FxPool（世界坐标、节点池）。
## 不再是 autoload：由组合根（GameScene）声明并注入 EffectService。
class_name MissCircleLayer
extends CanvasLayer

const MAX_CIRCLES := 8

var _circles: Array[Dictionary] = []
var _rect: ColorRect
var _mat: ShaderMaterial
var _prefixes := ["c0", "c1", "c2", "c3", "c4", "c5", "c6", "c7"]
var _view_size: Vector2


func _ready() -> void:
	layer = 0
	_rect = ColorRect.new()
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_view_size = get_viewport().get_visible_rect().size
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://gdshader/miss_circle.gdshader")
	_mat.set_shader_parameter("view_size", _view_size)
	_mat.set_shader_parameter("edge_soft", 0.005)
	for pf: String in _prefixes:
		_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
		_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
		_mat.set_shader_parameter("%s_alpha" % pf, 0.0)
	
	_rect.material = _mat
	add_child(_rect)


func add_circle(world_pos: Vector2, duration: float = 0.8, max_radius: float = 1280.0, start_radius: float = 0.0, start_delay: float = 0.0, fade_out: float = 0.0) -> void:
	if _circles.size() >= MAX_CIRCLES: return
	_circles.append({
		world_pos = world_pos,
		age = -start_delay,
		duration = duration,
		start_r = start_radius,
		max_r = max_radius,
		fade_out = fade_out,
	})


func _process(delta: float) -> void:
	for i in range(_circles.size() - 1, -1, -1):
		_circles[i].age += delta
	_update_shader()
	var removed := false
	for i in range(_circles.size() - 1, -1, -1):
		var c := _circles[i]
		var total: float = c.duration + c.fade_out
		if c.age >= total:
			_circles.remove_at(i)
			removed = true
	# 反色闪烁根治：raw_mask 偶数=复原、奇数=反转（mod 三角波）。
	# 多组圈重叠时（连续 miss / miss+记忆释放），先消失的一组会让剩余 raw 落奇数区 → 中间帧反色闪烁。
	# 这里：本帧有圈到期且剩余圈数为奇 → 同帧全清（跳变复原），与渲染帧率无关。
	if removed and _circles.size() % 2 == 1:
		_circles.clear()

func clear_all() -> void:
	_circles.clear()
	_update_shader()


func _update_shader() -> void:
	var view_size: Vector2 = _view_size
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	
	for i in MAX_CIRCLES:
		var pf: String = _prefixes[i]
		if i < _circles.size():
			var c := _circles[i]
			if c.age < 0.0:
				_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
				_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
				_mat.set_shader_parameter("%s_alpha" % pf, 0.0)
				continue
			var t := clampf(c.age / c.duration, 0.0, 1.0)
			var radius_px := lerpf(c.start_r, c.max_r, t)
			var screen_pos: Vector2 = canvas * c.world_pos
			var uv_pos := screen_pos / view_size
			# 渐隐
			var alpha: float = 1.0
			if c.fade_out > 0.0 and c.age > c.duration:
				var fade_t := clampf((c.age - c.duration) / c.fade_out, 0.0, 1.0)
				alpha = 1.0 - fade_t
			
			_mat.set_shader_parameter("%s_pos" % pf, uv_pos)
			_mat.set_shader_parameter("%s_radpx" % pf, radius_px)
			_mat.set_shader_parameter("%s_alpha" % pf, alpha)
		else:
			_mat.set_shader_parameter("%s_pos" % pf, Vector2(-1, -1))
			_mat.set_shader_parameter("%s_radpx" % pf, 0.0)
			_mat.set_shader_parameter("%s_alpha" % pf, 0.0)

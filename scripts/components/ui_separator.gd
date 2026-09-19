# scripts/components/ui_separator.gd
extends Node2D
class_name UISeparator
## 渐变分隔条 —— 两端渐透明，中间实色
##
## 用法：
##   var sep := UISeparator.new()
##   sep.color = Color(1, 0.5, 0.2)
##   sep.width = 2
##   sep.length = 280
##   add_child(sep)

## 分隔条颜色
@export var line_color: Color = Color(0.7, 0.7, 0.7, 0.8)
## 线条高度（像素）
@export var line_width: float = 1.5
## 线条总长度（像素）
@export var line_length: float = 280.0
## 两端渐变占全长的比例（0.0~0.5）
@export var fade_ratio: float = 0.2
## 生长进度（0.0=看不见, 1.0=全长），用于入场动画
@export var progress: float = 1.0: set = set_progress


func set_progress(v: float) -> void:
	progress = clampf(v, 0.0, 1.0)
	queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var draw_len := line_length * progress
	if draw_len <= 0:
		return
	var fade_len := draw_len * fade_ratio
	var mid_len := draw_len - fade_len * 2.0

	if mid_len <= 0:
		# 全渐变模式：两端渐变直接相接
		var half := line_length * 0.5
		# 左半：从左透明渐变到中间实色
		var left_grad := Gradient.new()
		left_grad.add_point(0.0, Color(line_color.r, line_color.g, line_color.b, 0.0))
		left_grad.add_point(1.0, line_color)
		var left_tex := GradientTexture1D.new()
		left_tex.gradient = left_grad
		left_tex.width = 1
		draw_line(Vector2(0, 0), Vector2(half, 0), line_color, line_width, false)
		# 不支持单端渐变纹理的 fallback：用多个线段模拟
		# 改用多线段绘制渐变
		_draw_gradient_line(0, half, false)

		# 右半：从中间实色渐变到右透明
		_draw_gradient_line(half, line_length, true)

		return

	# 左渐变段：透明 → 实色
	_draw_gradient_line(0, fade_len, false)

	# 中间实色段
	draw_line(Vector2(fade_len, 0), Vector2(fade_len + mid_len, 0), line_color, line_width, false)

	# 右渐变段：实色 → 透明
	_draw_gradient_line(fade_len + mid_len, line_length, true)


## 绘制一段渐变线段
## from_x, to_x: 起止 x 坐标
## fade_out: true=实色到透明, false=透明到实色
func _draw_gradient_line(from_x: float, to_x: float, fade_out: bool) -> void:
	var steps := maxi(int((to_x - from_x) / 2.0), 4)
	var seg_len := (to_x - from_x) / float(steps)

	for i in range(steps):
		var ratio := float(i) / float(steps - 1) if steps > 1 else 0.0
		var alpha: float = ratio if not fade_out else (1.0 - ratio)

		# 使用 ease 让渐变更自然
		alpha = _ease_quad(alpha)

		var color := Color(line_color.r, line_color.g, line_color.b, line_color.a * alpha)
		var x1 := from_x + seg_len * float(i)
		var x2 := x1 + seg_len
		draw_line(Vector2(x1, 0), Vector2(x2, 0), color, line_width, false)


## 二次缓动，让两端渐变更平滑
static func _ease_quad(ratio: float) -> float:
	if ratio < 0.5:
		return 2.0 * ratio * ratio
	else:
		return -1.0 + (4.0 - 2.0 * ratio) * ratio

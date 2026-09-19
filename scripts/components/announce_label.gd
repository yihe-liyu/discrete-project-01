## 通用大标题入场动画：放大淡入 → 缩回 → 停留 → 滑出
## 用于符卡名 / Bomb 名等需要“大字报”演出的地方。
## 使用锚点/实际尺寸定位，避免手动摆位置歪掉。
class_name AnnounceLabel
extends Label

signal finished

const DEFAULT_FONT_SIZE := 48
const FADE := 0.5
const INITIAL_SCALE := 3.0
const SHRINK := 0.6
const HOLD := 0.2
const SLIDE := 1.0
## 缩放绕中心 pivot：视觉包围盒每侧比布局框多出 size*(1-SHRINK)/2。
## 贴父容器右缘时布局框要按此内缩，否则缩放后的视觉右缘会越界。
const VISUAL_HALF := (1.0 + SHRINK) / 2.0

var _tween: Tween


## 右停落点的布局框 x：让「缩放后的视觉右缘」贴父容器右缘。
## 视觉右缘 = 布局框 x + size.x*VISUAL_HALF。
static func rest_x(parent_size_x: float, label_size_x: float) -> float:
	return parent_size_x - label_size_x * VISUAL_HALF


## 播放动画。
## parent_size 用于居中；on_finished 可选（也可连接 finished 信号）。
func play(p_text: String, parent_size: Vector2) -> void:
	_kill_tween()
	self.text = p_text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)

	# 真正把尺寸撑起来，避免 0×0 导致文字/缩放基准错乱
	var min_size := get_minimum_size()
	custom_minimum_size = min_size
	size = min_size
	pivot_offset = size / 2.0

	# 居中定位（基于父节点实际尺寸，不再依赖硬编码 center）
	position = (parent_size - size) / 2.0
	scale = Vector2(INITIAL_SCALE, INITIAL_SCALE)
	modulate.a = 0.0

	var center := position
	var stop_x := rest_x(parent_size.x, size.x)
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, FADE)
	_tween.tween_property(self, "scale", Vector2(SHRINK, SHRINK), FADE).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", center, FADE).set_trans(Tween.TRANS_QUAD)
	_tween.set_parallel(false)
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "position", Vector2(stop_x, parent_size.y - size.y * VISUAL_HALF), SLIDE).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", Vector2(stop_x, 0), SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(finished.emit)


## 停止动画并释放（用于切换/退场时清理）
func clear() -> void:
	_kill_tween()
	if is_inside_tree():
		queue_free()
	else:
		free()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

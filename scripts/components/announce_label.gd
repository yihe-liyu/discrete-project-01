## 通用大标题入场动画：放大淡入 → 缩回 → 停留 → 滑出
## 用于符卡名 / Bomb 名等需要“大字报”演出的地方。
## 结构声明在 scenes/ui/announce_label.tscn（R21）：Label 根 + Background / BonusLabel / CaptureLabel。
class_name AnnounceLabel
extends Label

signal finished

const DEFAULT_FONT_SIZE := 48
const FADE := 0.5
const INITIAL_SCALE := 3.0
const SHRINK := 0.6
const HOLD := 0.2
const SLIDE := 1.0
## 底衬在名字缩回正常后再渐显的时长（秒）。
const BG_FADE := 0.35
## 缩放绕中心 pivot：视觉包围盒每侧比布局框多出 size*(1-SHRINK)/2。
## 贴父容器右缘时布局框要按此内缩，否则缩放后的视觉右缘会越界。
const VISUAL_HALF := (1.0 + SHRINK) / 2.0
## Capture 相对名字宽度的落点比例。
const CAPTURE_X_RATIO := 0.6

## 底衬手动微调（单位：屏幕像素；+x 右移 / +y 下移）。
## 自动位 = 右缘贴父容器右缘 + 在名字上垂直居中；这里只叠加人工偏移（可在 announce_label.tscn 根节点 Inspector 调）。
@export var background_offset: Vector2 = Vector2.ZERO

var _tween: Tween

@onready var _background: TextureRect = $Background
@onready var _bonus_label: Label = $BonusLabel
@onready var _capture_label: Label = $CaptureLabel


func _ready() -> void:
	_hide_info_labels()


## 右停落点的布局框 x：让「缩放后的视觉右缘」贴父容器右缘。
## 视觉右缘 = 布局框 x + size.x*VISUAL_HALF。
static func rest_x(parent_size_x: float, label_size_x: float) -> float:
	return parent_size_x - label_size_x * VISUAL_HALF


## 播放动画。parent_size 用于居中；p_background 可选（贴图原尺寸显示，随名字同一路径）。
func play(p_text: String, parent_size: Vector2, p_background: Texture2D = null) -> void:
	_kill_tween()
	self.text = p_text
	add_theme_font_size_override("font_size", DEFAULT_FONT_SIZE)

	# 真正把尺寸撑起来，避免 0×0 导致文字/缩放基准错乱
	var min_size := get_minimum_size()
	custom_minimum_size = min_size
	size = min_size
	pivot_offset = size / 2.0
	_setup_background(p_background)
	_hide_info_labels()

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
	# 底衬：名字缩回正常后再渐显（与第一段滑出并行）
	if _background.visible:
		_tween.set_parallel(true)
		_tween.tween_property(_background, "modulate:a", 1.0, BG_FADE)
		_tween.tween_property(self, "position", Vector2(stop_x, parent_size.y - size.y * VISUAL_HALF), SLIDE).set_trans(Tween.TRANS_QUAD)
		_tween.set_parallel(false)
	else:
		_tween.tween_property(self, "position", Vector2(stop_x, parent_size.y - size.y * VISUAL_HALF), SLIDE).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", Vector2(stop_x, 0), SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_on_finished)


## 设置底部分数（Bonus）。
func set_bonus_text(p_text: String) -> void:
	_bonus_label.text = p_text


## 设置底部收取数。
func set_capture_text(p_text: String) -> void:
	_capture_label.text = p_text


func _on_finished() -> void:
	_show_info_labels()
	finished.emit()


## 底衬：贴图原尺寸显示（不缩放），随名字的 position 一起滑。
## 子 scale = 1/SHRINK 抵消父节点最终的 0.6 缩放；局部位置反推成「缩到 SHRINK 时右缘贴父容器右缘、垂直居中」。
func _setup_background(p_background: Texture2D) -> void:
	if p_background == null:
		_background.visible = false
		return
	_background.visible = true
	_background.texture = p_background
	var bg_size := p_background.get_size()
	var inv := 1.0 / SHRINK
	_background.size = bg_size
	_background.scale = Vector2(inv, inv)
	# 局部偏移会被父节点 0.6 缩放，所以把"屏幕像素"偏移先除以 SHRINK，保证 1:1 直观。
	_background.position = Vector2(size.x - bg_size.x * inv, size.y / 2.0 - bg_size.y * inv / 2.0) \
		+ background_offset / SHRINK
	_background.modulate.a = 0.0


## 底衬渐显后亮出 Bonus / Capture（位置按名字布局框算，随名字缩放）。
func _show_info_labels() -> void:
	var label_h := size.y
	_bonus_label.position = Vector2(0.0, label_h)
	_capture_label.position = Vector2(size.x * CAPTURE_X_RATIO, label_h)
	_bonus_label.visible = true
	_capture_label.visible = true


func _hide_info_labels() -> void:
	_bonus_label.visible = false
	_capture_label.visible = false
	_bonus_label.text = ""
	_capture_label.text = ""


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

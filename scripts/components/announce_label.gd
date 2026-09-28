## 通用大标题入场动画：放大淡入 → 缩回 → 停留 → 滑出。
## BOSS 样式 = BossUI 符卡名（右上收尾）；PLAYER 样式 = 自机 Bomb 符卡名（左上 → 左下 + 停顿渐隐）。
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
## 视觉盒贴左缘时布局框要往左挪的量：(1-SHRINK)/2。
const EDGE_HALF := (1.0 - SHRINK) / 2.0
## Bonus / Capture 两串之间的间距（**局部单位**；父节点 0.6 缩放 → 屏幕约 ×0.6）。
const INFO_GAP := 32.0## 自机样式：左下停住后的停留 / 渐隐时长（秒）。
const PLAYER_HOLD := 1.0
const FADE_OUT := 0.6

## 大字报样式。
enum Style { BOSS, PLAYER }

## 底衬手动微调（单位：屏幕像素；+x 右移 / +y 下移）。
## 自动位 = 右缘贴父容器右缘 + 在名字上垂直居中；这里只叠加人工偏移（可在 announce_label.tscn 根节点 Inspector 调）。
@export var background_offset: Vector2 = Vector2.ZERO

## 自机样式最终（左下）落点的人工偏移（屏幕像素；+x 右移 / +y 下移）。
## 要"偏上"就填负 y（如 Vector2(0, -120)）。Boss 样式不受影响。
@export var player_rest_offset: Vector2 = Vector2.ZERO

## Bonus / Capture 的**说明前缀**（Boss 符卡计分信息那两行）。
## 文案属表现 → 声明在 announce_label.tscn，改措辞不用动代码。
@export var bonus_prefix: String = ""
@export var capture_prefix: String = ""

var _tween: Tween
var _style: Style = Style.BOSS
## Bonus 文本的**预留宽度**（只增不减）。
## 为什么不能直接用当前文本宽度：本作字体数字**不等宽**（实测 "1"=15px、"8"=18px），
## 而 bonus 是逐帧递减的 → 每掉一位/换个数字，整块「奖励分数：」就往右抽一下。
## bonus 单调递减 ⇒ 见过的最宽即此后最宽 ⇒ 预留只增不减就把框钉住，数字在原地缩小。
var _bonus_reserve: float = 0.0

@onready var _background: TextureRect = $Background
@onready var _bonus_label: Label = $BonusLabel
@onready var _capture_label: Label = $CaptureLabel


func _ready() -> void:
	_hide_info_labels()


## 右停落点的布局框 x：让「缩放后的视觉右缘」贴父容器右缘。
## 视觉右缘 = 布局框 x + size.x*VISUAL_HALF。
static func rest_x(parent_size_x: float, label_size_x: float) -> float:
	return parent_size_x - label_size_x * VISUAL_HALF


## 左停落点的布局框 x：让「缩放后的视觉左缘」贴父容器左缘。
## 视觉左缘 = 布局框 x + size.x*EDGE_HALF。
static func rest_x_left(label_size_x: float) -> float:
	return -label_size_x * EDGE_HALF


## 自机样式最终（左下）落点：贴左缘 + 贴底边，再叠加人工偏移（屏幕像素）。
static func player_rest_pos(parent_size: Vector2, label_size: Vector2, offset: Vector2) -> Vector2:
	var bottom_left := Vector2(rest_x_left(label_size.x), parent_size.y - label_size.y * VISUAL_HALF)
	return bottom_left + offset / SHRINK


## 播放动画。parent_size 用于居中；p_background 可选（贴图原尺寸显示，随名字同一路径）。
## p_style = BOSS（先右下再右上，定住）或 PLAYER（先左上再左下，停一会儿渐隐）。
func play(p_text: String, parent_size: Vector2, p_background: Texture2D = null, p_style: Style = Style.BOSS) -> void:
	_kill_tween()
	_style = p_style
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

	# 收尾落点：BOSS = 先右下再右上；PLAYER = 先左上再左下（贴另一侧边、垂直顺序相反）。
	var edge_x := rest_x(parent_size.x, size.x) if p_style == Style.BOSS else rest_x_left(size.x)
	var first_pos := Vector2(edge_x, parent_size.y - size.y * VISUAL_HALF) if p_style == Style.BOSS else Vector2(edge_x, 0.0)
	var second_pos := Vector2(edge_x, 0.0) if p_style == Style.BOSS else player_rest_pos(parent_size, size, player_rest_offset)

	var center := position
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
		_tween.tween_property(self, "position", first_pos, SLIDE).set_trans(Tween.TRANS_QUAD)
		_tween.set_parallel(false)
	else:
		_tween.tween_property(self, "position", first_pos, SLIDE).set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "position", second_pos, SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if p_style == Style.PLAYER:
		# 自机符卡：左下停一会儿再渐隐
		_tween.tween_interval(PLAYER_HOLD)
		_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_on_finished)


## 设置底部分数（Bonus）：`说明前缀 + 数值`（前缀是表现层文案，见 `bonus_prefix`）。
func set_bonus_text(p_text: String) -> void:
	_bonus_label.text = bonus_prefix + p_text
	_bonus_reserve = maxf(_bonus_reserve, _bonus_label.get_minimum_size().x)   # 只增不减 → 递减时不重排
	_align_info_labels()


## 设置底部收取数（Capture）：`说明前缀 + n/m`。
func set_capture_text(p_text: String) -> void:
	_capture_label.text = capture_prefix + p_text
	_align_info_labels()


func _on_finished() -> void:
	# Bonus / Capture 是 Boss 符卡计分信息，只给 BOSS 样式。
	if _style == Style.BOSS:
		_show_info_labels()
	finished.emit()


## 底衬：贴图原尺寸显示（不缩放），随名字的 position 一起滑。
## 子 scale = 1/SHRINK 抵消父节点最终的 0.6 缩放；局部位置反推成「缩到 SHRINK 时贴对应侧边、垂直居中」。
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
	# BOSS 贴右缘（局部右 = size.x）；PLAYER 贴左缘（局部左 = 0）。
	var bg_x := (size.x - bg_size.x * inv) if _style == Style.BOSS else 0.0
	_background.position = Vector2(bg_x, size.y / 2.0 - bg_size.y * inv / 2.0) + background_offset / SHRINK
	_background.modulate.a = 0.0


## 底衬渐显后亮出 Bonus / Capture（位置按名字布局框算，随名字缩放）。
func _show_info_labels() -> void:
	_align_info_labels()
	_bonus_label.visible = true
	_capture_label.visible = true


## Bonus / Capture 排成**一行**：整行**右对齐到名字视觉右缘**（= 场地右缘），向左依次排开。
## 三个坑（都实测过）：
## ① 各贴一端不行 —— 带说明前缀后两串加起来比名字视觉宽度大（276 > 230）→ 直接叠在一起；
## ② 按「名字宽度比例」落点也不行 —— 比例随名字宽度漂，短名字会顶出场地右缘（越界 48px）；
## ③ 用**当前**文本宽度当 Bonus 宽度更不行 —— 数字不等宽 + bonus 递减 → 每换一个数就抽一下，
##    故 Bonus 用 `_bonus_reserve`（只增不减）。
## 用 `get_minimum_size()` 而不是 `size`：改文本后 size 是延迟更新的，这里要的是即时宽度。
func _align_info_labels() -> void:
	var label_h := size.y
	var capture_w := _capture_label.get_minimum_size().x
	_capture_label.position = Vector2(size.x - capture_w, label_h)
	var bonus_w := maxf(_bonus_reserve, _bonus_label.get_minimum_size().x)
	_bonus_label.position = Vector2(size.x - capture_w - INFO_GAP - bonus_w, label_h)


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

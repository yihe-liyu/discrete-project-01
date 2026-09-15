# BasePage — 统一菜单页面基类（替代 MenuScreen）
#
## 所有可被 MenuNav 管理的页面都应继承此类
##
## 生命周期:
##   push → on_enter()     (首次进入)
##   push another → on_deactivate()  (被覆盖)
##   pop another → on_activate()     (重新激活)
##   pop self   → on_leave()         (退场)
##
## 退场标准流程:
##   on_leave() → 播放退场动画 → finished.emit({}) 或 queue_free()

class_name BasePage
extends Control

signal finished(result: Dictionary)
signal back()
signal sfx_requested(kind: String)   # 音效意图：只喊，不碰音频；由 MenuNav 接线播放

# ═══ 内置遮罩（可选） ═══

const OVERLAY_FADE_IN: float = 0.2
const OVERLAY_FADE_OUT: float = 0.15

## 设为 true 则 on_enter 时自动淡入暗色遮罩
@export var is_auto_overlay: bool = true

var overlay_color: Color = Color(0, 0, 0, 0.5)
var _overlay: ColorRect = null


# ═══ 生命周期 ═══

func _init() -> void:
	pass

func _ready() -> void:
	_create_overlay()

func _create_overlay() -> void:
	if not is_auto_overlay:
		return
	# 检查场景中是否已有 Overlay 节点（复用）
	for child in get_children():
		if child.name == "Overlay" and child is ColorRect:
			_overlay = child
			_overlay.modulate.a = 0.0  # 初始透明
			_overlay.visible = true
			_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return
	# 创建新遮罩
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = overlay_color
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	move_child(_overlay, 0)

# ── 子类覆写 ──

## 首次进入（被 push 时调用一次）
func on_enter() -> void:
	pass

## 被其他页面覆盖
func on_deactivate() -> void:
	pass

## 覆盖的页面被移除，重新激活
func on_activate() -> void:
	pass

## 被 pop 时调用 —— 应包含退场动画，动画结束后 queue_free()
func on_leave() -> void:
	queue_free()


# ═══ 退场便捷方法 ═══

## 确认并返回结果（自动退场）
func done(result: Dictionary = {}) -> void:
	on_leave()
	finished.emit(result)

## X 返回（无结果，触发 back 信号）
func go_back() -> void:
	on_leave()
	back.emit()


# ═══ 遮罩动画 ═══

## 淡入遮罩
func _fade_overlay_in(duration: float = -1.0) -> void:
	if not _overlay:
		return
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	var tween := _overlay.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)


## 淡出遮罩
func _fade_overlay_out(duration: float = -1.0) -> Tween:
	if not _overlay:
		return null
	var tween := _overlay.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	return tween


## 内容淡入（从右侧滑入 + 透明 → 不透明）
func _fade_content_in(content: Control, duration: float = OVERLAY_FADE_IN, slide: bool = true) -> void:
	content.modulate.a = 0.0
	if slide:
		content.position.x += 30

	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(content, "modulate:a", 1.0, duration)
	if slide:
		tween.tween_property(content, "position:x", content.position.x - 30, duration)


## 内容 + 遮罩 一起淡出
func _fade_all_out(content: Control, content_duration: float = OVERLAY_FADE_OUT, overlay_duration: float = -1.0) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(content, "modulate:a", 0.0, content_duration)

	var overlay_tween := _fade_overlay_out(overlay_duration)

	var cb := func():
		finished.emit({})
		queue_free()

	if overlay_tween:
		overlay_tween.tween_callback(cb)
	else:
		tween.tween_callback(cb)


## 覆盖层退场：遮罩淡出 + 内容缩小淡出 → queue_free
## 调用前需自行关闭导航（_is_nav_enabled=false, _stop_pulse()）
func _overlay_leave(content: Control) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fade_overlay_out(0.15)
	tween.tween_property(content, "modulate", Color(1, 1, 1, 0), 0.12)
	tween.tween_property(content, "scale", Vector2(0.95, 0.95), 0.12)
	tween.tween_callback(queue_free)


# ═══ 音效快捷（只表达意图，不碰音频数据；AudioManager 是音效知识唯一 owner） ═══

func sfx_nav() -> void:
	sfx_requested.emit("nav")

func sfx_confirm() -> void:
	sfx_requested.emit("confirm")

func sfx_back() -> void:
	sfx_requested.emit("back")

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

## true = [code]_ready[/code] 时自动创建/复用 [code]Overlay[/code]，并把它的 [code]modulate.a[/code] 归 0。
## 它不会自动淡入 —— 子类入场时必须自己调 [code]_fade_overlay_in()[/code]，否则遮罩会一直停在
##    [code]modulate.a = 0[/code] ⇒ 有效 alpha = [code]color.a × 0[/code] = 黑幕看不见（stage 练习菜单 2026-10-04 实测）。
## 场景里设 [code]false[/code] = 本页面自己管遮罩（如符卡练习菜单），BasePage 完全不碰它。
## [code]_fade_overlay_in()[/code] / [code]_fade_overlay_out()[/code] 的默认时长就是 [code]OVERLAY_FADE_IN[/code] / [code]OVERLAY_FADE_OUT[/code]；
## 调用时不传也有正常动画（旧默认 [code]-1.0[/code] = 负时长，淡入瞬间完成）。
@export var is_auto_overlay: bool = true

## 新建 [code]Overlay[/code] 时使用的颜色（场景里已有 Overlay 时以场景自身的 color 为准）。
var overlay_color: Color = Color(0, 0, 0, 0.5)
var _overlay: ColorRect = null


# ═══ 生命周期 ═══

func _init() -> void:
	pass

func _ready() -> void:
	# 编辑器守卫：BasePage 有 @tool 子类，_create_overlay 会 add_child(Overlay) 污染 .tscn
	if Engine.is_editor_hint():
		return
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
func _fade_overlay_in(duration: float = OVERLAY_FADE_IN) -> void:
	if not _overlay:
		return
	_overlay.modulate.a = 0.0
	_overlay.visible = true
	var tween := _overlay.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 1.0, duration)


## 淡出遮罩
func _fade_overlay_out(duration: float = OVERLAY_FADE_OUT) -> Tween:
	if not _overlay:
		return null
	var tween := _overlay.create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	return tween


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

## 发 nav 音效意图（sfx_requested），不直接播音。
func sfx_nav() -> void:
	sfx_requested.emit("nav")

## 发 confirm 音效意图。
func sfx_confirm() -> void:
	sfx_requested.emit("confirm")

## 发 back 音效意图。
func sfx_back() -> void:
	sfx_requested.emit("back")

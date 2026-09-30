## 符卡背景里「**一层自动向上无缝滚动**的图」——可选组件，作者把它贴在**自己背景场景内的
## Sprite2D** 上（或以 `scenes/effect/spell_backdrop_plain.tscn` 为模板）。只管滚动这一件事：
## 显隐 / 淡入淡出 / 层级 / 坐标都归 `SpellBackdropLayer` 与作者场景管。
##
## 做法：窗口 = **整张图**，靠 `texture_repeat` 重复采样；每帧把窗口**下移**（= 画面向上滚），
## 对图高取模 ⇒ 循环处看不出接缝。**前提是图本身纵向可平铺**（卡摩瑞那张顶行/底行 98% 一致，
## 就是为平铺画的）。
##
## `centered` 由作者/模板决定（模板为 true → 图心落在 `(0,0)` = 场地正中，与宿主约定一致）。
class_name SpellBackdropScroll
extends Sprite2D

## 向上滚动速度（像素/秒）；**0 = 静止**（每层各调各的 → 想要视差就放两层不同速度）
@export var scroll_speed: float = 48.0


func _ready() -> void:
	if texture == null:
		return
	# 窗口 = 整张图；滚动靠改这个窗口的 y
	region_enabled = true
	region_rect = Rect2(Vector2.ZERO, texture.get_size())
	# 重复采样：窗口滚出图外时自动绕回来（无缝的关键）
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(scroll_speed != 0.0)


func _process(delta: float) -> void:
	if texture == null:
		return
	var h := texture.get_height()
	if h <= 0.0:
		return
	var r := region_rect
	r.position.y = fmod(r.position.y + scroll_speed * delta, h)
	region_rect = r

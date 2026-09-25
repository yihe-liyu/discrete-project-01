extends Sprite2D
## 符卡背景（**每 Boss 一张**）：压在 3D 背景之上、弹幕之下的一层图案。
## 卡摩瑞那张（768×896）是照 **场地尺寸** 画的（`FIELD_LEFT..RIGHT` × `FIELD_TOP..BOTTOM`），
## 所以居中放、**不缩放** 就正好铺满场地。
##
## 显示时机：**只在符卡期间**（`phase.uid != 0`）—— 非符不显示；Boss 没配图则不显示。
## 判定抽成 `should_show()` **纯函数**（无树可测），淡入淡出交给 tween。

## 淡入 / 淡出时长（秒）
const FADE_SEC := 0.4

## 向上滚动速度（像素/秒）；0 = 静止不滚
const SCROLL_SPEED := 48.0

var _current: Texture2D


## 该阶段该不该显示符卡背景：**符卡才有**（非符不显示）。
## 「用哪张图」由调用方解析（当前 Boss 的 / 练习会话载荷的）——本层只管显隐规则。
static func should_show(phase: PhaseData) -> bool:
	return phase != null and phase.uid != 0


## 阶段 + 图 → 显示 / 隐藏。同一张图重复调用不会重放淡入（连打两张符卡不闪）。
func apply(phase: PhaseData, tex: Texture2D) -> void:
	if should_show(phase) and tex != null:
		show_for(tex)
	else:
		clear()


## 淡入一张符卡背景
func show_for(tex: Texture2D) -> void:
	if tex == null:
		return
	if visible and _current == tex:
		return
	_current = tex
	texture = tex
	# 窗口 = 整张图（= 场地尺寸，不溢出场外）；滚动靠改这个窗口的 y
	region_enabled = true
	region_rect = Rect2(Vector2.ZERO, tex.get_size())
	modulate.a = 0.0
	visible = true
	set_process(SCROLL_SPEED != 0.0)
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SEC)


## 淡出并隐藏
func clear() -> void:
	if not visible:
		return
	_current = null
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(func() -> void:
		visible = false
		set_process(false))


## 向上无缝滚动：窗口 **向下** 移 = 画面向上滚；对图高取模 → 循环处看不出接缝
## （前提是图本身纵向可平铺 —— 卡摩瑞那张顶行/底行 98% 一致，是为平铺画的）
func _process(delta: float) -> void:
	if texture == null:
		return
	var h := texture.get_height()
	if h <= 0.0:
		return
	var r := region_rect
	r.position.y = fmod(r.position.y + SCROLL_SPEED * delta, h)
	region_rect = r


func _ready() -> void:
	centered = true
	# 重复采样：窗口滚出图外时自动绕回来（无缝的关键）
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	set_process(false)   # 只在显示时滚
	# 场地中心：贴图尺寸 == 场地尺寸 → 两者原点重合，四边对齐
	position = Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y)
	z_index = LayerConfig.SPELL_BG
	visible = false
	modulate.a = 0.0

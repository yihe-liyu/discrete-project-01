class_name ScorePopupLayer
extends Node2D
## 吃道具得分浮字：池化 NumberSprite，在被吃掉的位置显示本次得分，上浮 + 渐隐后回池。
## 数据源：GameEvents.item_score（Item.collect 发射）。组合根在 game_scene.tscn 声明（R21）。
## 与 FxPool 分工：FxPool 是命中/爆炸的**精灵动画**池；本层是**数字**浮字池（同字体 ascii.png）。

## 上浮像素 / 渐隐时长（秒）
const RISE: float = 24.0
const FADE_TIME: float = 0.4
## 最多位数（max_point 从 10000 起，5 位足够；超出会截断高位）
const DIGIT_COUNT: int = 5
## 自动收取（过收点线 / 靠近吸附）时的金色
const AUTO_COLLECT_COLOR: Color = Color(1.0, 0.843, 0.0)

## 字号倍率（Inspector 可调；**别缩本节点** —— 那会连 position 一起缩放）
@export var font_scale: float = 1.0

const _DIGIT_TEXTURE: Texture2D = preload("res://assets/Textures/ascii/ascii.png")

var _pool: Array[NumberSprite] = []


func _ready() -> void:
	z_index = LayerConfig.SCORE_POPUP
	GameEvents.item_score.connect(_on_item_score)


## 在 pos 显示 amount 的得分浮字（amount <= 0 静默）。is_auto_collect = 过收点线 / 靠近吸附。
func show_score(amount: int, pos: Vector2, is_auto_collect: bool = false) -> void:
	if amount <= 0:
		return
	var ns := _acquire()
	ns.value = amount
	ns.position = pos
	ns.scale = Vector2.ONE * font_scale
	ns.modulate = AUTO_COLLECT_COLOR if is_auto_collect else Color.WHITE
	ns.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(ns, "position:y", pos.y - RISE * font_scale, FADE_TIME)
	tween.tween_property(ns, "modulate:a", 0.0, FADE_TIME)
	tween.chain().tween_callback(_recycle.bind(ns))


func _on_item_score(score: int, pos: Vector2, is_auto_collect: bool) -> void:
	show_score(score, pos, is_auto_collect)


## 取一个不可见实例；没有则新建（配置必须在入树前设好，NumberSprite._ready 才建数字精灵）。
func _acquire() -> NumberSprite:
	for ns in _pool:
		if is_instance_valid(ns) and not ns.visible:
			return ns
	var ns := NumberSprite.new()
	ns.digit_texture = _DIGIT_TEXTURE
	ns.char_count = 14   # 贴图: 0-9 . / - %
	ns.dot_index = 10
	ns.slash_index = 11
	ns.minus_index = -1
	ns.pct_index = -1
	ns.is_left_align = true   # 不补前导零
	ns.digit_count = DIGIT_COUNT
	ns.visible = false
	add_child(ns)
	_pool.append(ns)
	return ns


func _recycle(ns: NumberSprite) -> void:
	if is_instance_valid(ns):
		ns.visible = false


## 清空池（换关/重开）。
func clear_pool() -> void:
	for ns in _pool:
		if is_instance_valid(ns):
			ns.queue_free()
	_pool.clear()

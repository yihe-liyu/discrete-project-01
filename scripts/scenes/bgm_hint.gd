extends CanvasLayer
## BGM 提示 —— 播放音乐时，右下角从右侧框外滑入显示曲名（BGM：xxx），停留后滑出
##
## 触发：监听 AudioManager.bgm_started（实际切换 BGM 时广播）
## 图层：CanvasLayer layer=0 —— 在游戏内容（默认 layer 1）**之下**，"框的图层在文本之上"，
##       被弹幕/敌人遮挡属预期（半嵌合画面）；仅高于背景（layer -1）
## 布局用 GameConfig 常量（stretch viewport 下禁用 get_window().size，见 `docs/archive/ARCHITECTURE_ROADMAP.md` 坑 #7）

const SLIDE_IN_TIME := 1.5      ## 滑入时长（秒）
const SHOW_TIME := 5.0          ## 停留时长（秒）
const SLIDE_OUT_TIME := 2.5     ## 滑出时长（秒）
const RIGHT_MARGIN := 24.0      ## 落点距视口右缘（px）
const ENTRANCE_OFFSET := 100.0  ## 初始在右侧框外的水平偏移（px）

@onready var _label: Label = $Root/Label

var _tween: Tween


func _ready() -> void:
	# 初始在右侧框外（不可见）
	_label.position = Vector2(GameConfig.FIELD_RIGHT + ENTRANCE_OFFSET, GameConfig.FIELD_BOTTOM - 48.0)
	if not AudioManager.bgm_started.is_connected(_on_bgm_started):
		AudioManager.bgm_started.connect(_on_bgm_started)


func _exit_tree() -> void:
	if AudioManager.bgm_started.is_connected(_on_bgm_started):
		AudioManager.bgm_started.disconnect(_on_bgm_started)


func _on_bgm_started(stream: AudioStream) -> void:
	var title := AssetRegistry.get_bgm_title(stream)
	if title.is_empty():
		return
	_label.text = "BGM：" + title
	_slide_in()


## 从右侧框外向左滑入右下角 → 停留 → 原路滑出
func _slide_in() -> void:
	_kill_tween()
	var target_x: float = GameConfig.FIELD_RIGHT - _label.get_minimum_size().x - RIGHT_MARGIN
	_tween = create_tween()
	_tween.tween_property(_label, "position:x", target_x, SLIDE_IN_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_tween.tween_interval(SHOW_TIME)
	_tween.tween_property(_label, "position:x", GameConfig.FIELD_RIGHT + ENTRANCE_OFFSET, SLIDE_OUT_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

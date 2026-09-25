extends Sprite2D
## 宣言立绘（Boss 符卡 / 自机 Bomb 共用）：从游戏框一角快慢快地扫到另一角，到位后淡出。
## - Boss 符卡：**右上 → 左下**（`sweep()`）
## - 自机 Bomb：**左下 → 右上**（`sweep_from_bottom_left()`，与 Boss 镜像）
## 层级在弹幕**之下**、3D 背景之上（`LayerConfig.SPELL_PORTRAIT`）—— 看得见但不挡读弹幕。
##
## 「快慢快」与走位脚本同法：两段 tween 接力 ——
## 前半 `EASE_OUT`（快→慢）到中点，后半 `EASE_IN`（慢→快）到左下角。

## 场地两角。⚠️ **这两行是作者在调手感的**（当前把端点放到框外 200/150 px，让立绘从画面外进出）——
## 测试只锁「从哪个常量起 + 朝哪边走」，改这里不会让门禁红。
## （R17：基准取 `GameConfig.FIELD_*`，不写死 832/32/64/928）
const CORNER_TOP_RIGHT := Vector2(GameConfig.FIELD_RIGHT+200, GameConfig.FIELD_TOP+150)
const CORNER_BOTTOM_LEFT := Vector2(GameConfig.FIELD_LEFT-200, GameConfig.FIELD_BOTTOM-150)

## 扫场总时长（秒）
const SWEEP_SEC := 2.0
## 到位后的淡出时长（秒）
const FADE_SEC := 0.25

var _busy: bool = false


## 扫一遍：右上角 → 左下角（快慢快）→ 淡出。
## 扫场期间再调用会被忽略（不会叠加两条 tween）。
## Boss 符卡立绘：右上角 → 左下角
func sweep(tex: Texture2D) -> void:
	_sweep(tex, CORNER_TOP_RIGHT, CORNER_BOTTOM_LEFT)


## 自机 Bomb 立绘：左下角 → 右上角（与 Boss 镜像）
func sweep_from_bottom_left(tex: Texture2D) -> void:
	_sweep(tex, CORNER_BOTTOM_LEFT, CORNER_TOP_RIGHT)


## 扫一遍：`corner` → `dest`（快慢快）→ 淡出。扫场中重复调用被忽略（不叠 tween）。
func _sweep(tex: Texture2D, corner: Vector2, dest: Vector2) -> void:
	if tex == null or _busy:
		return
	_busy = true
	var mid := (corner + dest) * 0.5                                         # 中点 = 场地中心
	texture = tex
	modulate.a = 1.0
	visible = true
	global_position = corner
	var half := SWEEP_SEC * 0.5
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "global_position", mid, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", dest, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	tw.tween_callback(func() -> void:
		visible = false
		_busy = false)


func _ready() -> void:
	centered = true
	z_index = LayerConfig.SPELL_PORTRAIT
	visible = false
	modulate.a = 0.0

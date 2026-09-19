## 震屏（trauma 模型）：挂在 game_scene 的 Camera2D 上。
## - 冲击：`add_trauma(x)` 叠加后按 `DECAY` 衰减（一次性，如灵梦 bomb 引爆）
## - 持续：`set_sustain(x)` 按住不衰减（整个 bomb 期间，如魔理沙），结束传 0
## 只晃 World（2D 节点）；HUD / 背景是 CanvasLayer，不受 Camera2D 影响。
class_name ScreenShake
extends Camera2D

const MAX_OFFSET := 14.0   ## amount=1 时的最大位移（像素）
const DECAY := 2.0         ## trauma 每秒衰减量

var _trauma: float = 0.0
var _sustain: float = 0.0


func _ready() -> void:
	GameEvents.screen_shake.connect(add_trauma)
	GameEvents.screen_shake_sustain.connect(set_sustain)


func _exit_tree() -> void:
	if GameEvents.screen_shake.is_connected(add_trauma):
		GameEvents.screen_shake.disconnect(add_trauma)
	if GameEvents.screen_shake_sustain.is_connected(set_sustain):
		GameEvents.screen_shake_sustain.disconnect(set_sustain)


## 冲击震屏：叠加 trauma（0..1），随帧自动衰减。
func add_trauma(p_amount: float) -> void:
	_trauma = clampf(_trauma + p_amount, 0.0, 1.0)


## 持续震屏：整个 bomb 期间传强度（0..1），结束传 0。
func set_sustain(p_amount: float) -> void:
	_sustain = clampf(p_amount, 0.0, 1.0)


## 当前总震幅（max(冲击, 持续)）——测试/调试用。
func amount() -> float:
	return maxf(_trauma, _sustain)


func _process(p_delta: float) -> void:
	_trauma = maxf(_trauma - DECAY * p_delta, 0.0)
	var mag := amount()
	if mag <= 0.0:
		offset = Vector2.ZERO
		return
	# mag²：弱震更细、强震更猛
	offset = Vector2(RNG.randf_range(-1.0, 1.0), RNG.randf_range(-1.0, 1.0)) * MAX_OFFSET * mag * mag

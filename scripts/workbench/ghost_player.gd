## 幽灵玩家 —— 工作台关卡沙盒的"假自机"
##
## 用途：给真实关卡提供自机狙目标（ctx.player 读取注入的自机；见 StageRuntime.entity_registry）
## 特性：固定路径自动移动、不可操控、不射击、无敌（预览不会 Game Over）
## 用法：实例化 player.tscn 后 set_script 为本脚本（继承 Player 保证类型兼容）
extends Player
class_name GhostPlayer

## 正弦路径参数（可调：路径宽度/纵向中心/摆动频率）
var path_amplitude: float = 330.0
## 正弦路径的纵向中心（也是 STATIC 模式的固定 y；默认 = 真自机起始高度）。
var path_center_y: float = GameConfig.PLAYER_START.y
## 正弦路径的纵向半振幅（像素）：实际 y 在中心上下各摆这么远，并夹在自机活动范围内。
var path_y_amp: float = 40.0
const DEFAULT_CENTER_Y: float = GameConfig.PLAYER_START.y

## 走位模式（AUTO=自动漂移【工作台默认】/ MOUSE=鼠标跟随【弹幕试验台】/ STATIC=静止）
enum Mode { AUTO, MOUSE, STATIC }
## 走位模式：AUTO = 自动正弦漂移（工作台默认）；MOUSE = 鼠标跟随；
## STATIC = 固定在场地中心线 / [code]path_center_y[/code]。
var mode: int = Mode.AUTO

var _elapsed: float = 0.0


## 不启动射击脚本（预览只关心敌方弹幕，玩家子弹会干扰视野）
func _init_shoot_script() -> void:
	pass


## 覆写父类：不走输入/受击/动画状态机，只沿固定路径漂 / 跟随鼠标 / 静止
func _physics_process(delta: float) -> void:
	match mode:
		Mode.MOUSE:
			var mouse_pos := get_global_mouse_position()
			position = _clamp_to_player_bounds(mouse_pos)
		Mode.STATIC:
			position = Vector2(GameConfig.FIELD_CENTER_X, path_center_y)
		_:
			_elapsed += delta
			position.x = clampf(
				GameConfig.FIELD_CENTER_X + sin(_elapsed * 0.55) * path_amplitude,
				GameConfig.PLAYER_MIN_X, GameConfig.PLAYER_MAX_X)
			position.y = clampf(
				path_center_y + sin(_elapsed * 0.9) * path_y_amp,
				GameConfig.PLAYER_MIN_Y, GameConfig.PLAYER_MAX_Y)
	# 无敌：bullet_physics 命中判定读 is_invincible，预览不死亡
	is_invincible = true


## 真自机同款中心活动范围（公开接缝，测试/文档用）。
static func player_bounds() -> Rect2:
	return Rect2(
		GameConfig.PLAYER_MIN_X, GameConfig.PLAYER_MIN_Y,
		GameConfig.PLAYER_MAX_X - GameConfig.PLAYER_MIN_X,
		GameConfig.PLAYER_MAX_Y - GameConfig.PLAYER_MIN_Y)


func _clamp_to_player_bounds(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, GameConfig.PLAYER_MIN_X, GameConfig.PLAYER_MAX_X),
		clampf(pos.y, GameConfig.PLAYER_MIN_Y, GameConfig.PLAYER_MAX_Y))


## 重跑时复位（重头开始走路径）
func reset() -> void:
	_elapsed = 0.0
	position = Vector2(GameConfig.FIELD_CENTER_X, path_center_y)
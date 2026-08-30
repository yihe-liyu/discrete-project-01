## 幽灵玩家 —— 工作台关卡沙盒的"假自机"
##
## 用途：给真实关卡提供自机狙目标（ctx.player.get_player() 需要 GameState.player）
## 特性：固定路径自动移动、不可操控、不射击、无敌（预览不会 Game Over）
## 用法：实例化 player.tscn 后 set_script 为本脚本（继承 Player 保证类型兼容）
extends Player
class_name GhostPlayer

## 正弦路径参数（可调：路径宽度/纵向中心/摆动频率）
var path_amplitude: float = 330.0
var path_center_y: float = 620.0
var path_y_amp: float = 110.0

## 走位模式（AUTO=自动漂移【工作台默认】/ MOUSE=鼠标跟随【弹幕试验台】/ STATIC=静止）
enum Mode { AUTO, MOUSE, STATIC }
var mode: int = Mode.AUTO

var _t: float = 0.0


## 不启动射击脚本（预览只关心敌方弹幕，玩家子弹会干扰视野）
func _init_shoot_script() -> void:
	pass


## 覆写父类：不走输入/受击/动画状态机，只沿固定路径漂 / 跟随鼠标 / 静止
func _physics_process(delta: float) -> void:
	match mode:
		Mode.MOUSE:
			# make_canvas_position_local：世界缩放时把画布鼠标点转回世界坐标（无缩放=同一结果）
			var m := make_canvas_position_local(get_viewport().get_mouse_position())
			position = Vector2(
				clampf(m.x, GameConfig.FIELD_LEFT + 12.0, GameConfig.FIELD_RIGHT - 12.0),
				clampf(m.y, GameConfig.FIELD_TOP + 12.0, GameConfig.FIELD_BOTTOM - 60.0))
		Mode.STATIC:
			position = Vector2(GameConfig.FIELD_CENTER_X, path_center_y)
		_:
			_t += delta
			position.x = clampf(
				GameConfig.FIELD_CENTER_X + sin(_t * 0.55) * path_amplitude,
				GameConfig.FIELD_LEFT + 12.0, GameConfig.FIELD_RIGHT - 12.0)
			position.y = clampf(
				path_center_y + sin(_t * 0.9) * path_y_amp,
				GameConfig.FIELD_TOP + 12.0, GameConfig.FIELD_BOTTOM - 60.0)
	# 无敌：bullet_physics 命中判定读 is_invincible，预览不死亡
	is_invincible = true


## 重跑时复位（重头开始走路径）
func reset() -> void:
	_t = 0.0
	position = Vector2(GameConfig.FIELD_CENTER_X, path_center_y)
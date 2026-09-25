extends CoroutineScript
## 走位到点：移动到指定站位后**自己结束**。
## 主要用途 = `PhaseData.pre_move_script`（发动符卡**之前**的走位）：
## 它跑完，符卡才会宣言（报幕 + card 音效 + 符卡背景）。
##
## 站位 / 耗时可在 `PhaseData.params` 里覆盖：`{"dest": Vector2(448, 240), "move_time": 1.2}`
##
## ⚠️ 写 pre_move 脚本的铁律：**必须能结束** —— 它不结束这张符卡就永远不会发动。
## 本脚本靠 `auto_stop = true` + 第二轮 `_tick` 返回 `false` 收尾。

const META := {
	"name": "走位到点",
	"desc": "移动到指定站位后结束（用作 PhaseData.pre_move_script 的发动前走位）。",
}

var dest: Vector2 = Vector2(448.0, 240.0)   ## 目标站位
var move_time: float = 1.0                  ## 移动耗时（秒）

var _moving: bool = false


func _init() -> void:
	# ⚠️ auto_stop 默认 false（持续运行语义）—— 不开，`_tick` 返回 false 也停不下来，
	#    于是这张符卡永远等不到宣言。
	auto_stop = true


func _tick(p_ctx: StageContext):
	if not target:
		return false          # 没有控制目标 → 结束（别把整场卡住）
	if _moving:
		return false          # 第二轮：位移已走完 → 结束 → 宣言
	_moving = true
	var tw := target.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(target, "global_position", dest, move_time)
	return p_ctx.clock.wait(move_time)   # 等这条 tween 走完再来第二轮

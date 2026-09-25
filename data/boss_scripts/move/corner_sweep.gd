extends CoroutineScript
## 对角扫场：从游戏框**右上角**扫到**左下角**，**快 → 慢 → 快**。
## 用作 `PhaseData.pre_move_script`（发动符卡**之前**的走位）：跑完才宣言。
##
## 「快慢快」= 两段 tween 接力：
##   前半 `EASE_OUT`（快→慢）走到**中点**，后半 `EASE_IN`（慢→快）走到终点。
##   中点正好是场地中心，所以看起来是「冲到中央、缓一下、再冲出去」。
##
## 参数（可在 `PhaseData.params` 覆盖）：
##   `move_time`(总秒数) / `hold_middle`(中点停留秒数) / `from_corner`(是否先瞬移到右上角)

const META := {
	"name": "对角扫场",
	"desc": "从游戏框右上角快慢快地扫到左下角（用作 PhaseData.pre_move_script 的发动前走位）。",
}

var move_time: float = 1.6      ## 总耗时（秒）
var hold_middle: float = 0.0    ## 在中点停留（秒），0 = 不停留
var from_corner: bool = true    ## true = 起跑前先瞬移到右上角

var _moving: bool = false


func _init() -> void:
	# ⚠️ auto_stop 默认 false —— 不开，_tick 返回 false 也停不下来，这张符卡就永远不宣言。
	auto_stop = true


func _tick(p_ctx: StageContext):
	if not target:
		return false
	if _moving:
		return false                      # 第二轮：扫完了 → 结束 → 宣言
	var corner := Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)          # 右上角
	var dest := Vector2(GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM)         # 左下角
	var mid := (corner + dest) * 0.5                                             # 中点 = 场地中心
	_moving = true
	if from_corner:
		target.global_position = corner   # 瞬移到右上角再起跑
	var half := maxf(move_time, 0.0) * 0.5
	var tw := target.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(target, "global_position", mid, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hold_middle > 0.0:
		tw.tween_interval(hold_middle)
	tw.tween_property(target, "global_position", dest, half).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return p_ctx.clock.wait(move_time + hold_middle)

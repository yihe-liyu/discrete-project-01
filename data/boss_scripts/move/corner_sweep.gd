extends CoroutineScript
## 对角扫场：从游戏框右上角扫到左下角，快 → 慢 → 快。
## 用作 [code]PhaseData.pre_move_script[/code]（发动符卡之前的走位）：跑完才宣言。
##
## 「快慢快」= 两段 tween 接力：
##   前半 [code]EASE_OUT[/code]（快→慢）走到中点，后半 [code]EASE_IN[/code]（慢→快）走到终点。
##   中点正好是场地中心，所以看起来是「冲到中央、缓一下、再冲出去」。
##
## 参数（可在 [code]PhaseData.params[/code] 覆盖）：
##   [code]move_time[/code](总秒数) / [code]hold_middle[/code](中点停留秒数) / [code]from_corner[/code](是否先瞬移到右上角)


## 总耗时（秒）
var move_time: float = 1.6
## 在中点停留（秒），0 = 不停留
var hold_middle: float = 0.0
## true = 起跑前先瞬移到右上角
var from_corner: bool = true

var _moving: bool = false


func _init() -> void:
	# ⚠️ auto_stop 默认 false —— 不开，_tick 返回 false 也停不下来，这张符卡就永远不宣言。
	auto_stop = true


func _tick(p_ctx: StageContext):
	if not target:
		return false
	if _moving:
		return false                      # 第二轮：扫完了 → 结束 → 宣言
	var 右上角 := Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
	var 左下角 := Vector2(GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM)
	var 中点 := (右上角 + 左下角) * 0.5   # 中点 = 场地中心
	_moving = true
	if from_corner:
		target.global_position = 右上角   # 瞬移到右上角再起跑
	var 半程 := maxf(move_time, 0.0) * 0.5
	p_ctx.boss.move_path(target, [中点, 左下角], [半程, 半程],
		[Tween.EASE_OUT, Tween.EASE_IN], hold_middle)
	return p_ctx.clock.wait(move_time + hold_middle)

extends CoroutineScript
## @role: boss_move
## （上面这行是创作台目录角色：[code]const META[/code] 只管名字/描述，角色要靠 [code]@role[/code]；
##   缺了它这个"只被 [code]pre_move_script[/code] 之外没人引用"的脚本会落到「未分类」、目录里双击不跳台。）
## 对角扫场：从游戏框右上角扫到左下角，快 → 慢 → 快。
## 用作 [code]PhaseData.pre_move_script[/code]（发动符卡之前的走位）：跑完才宣言。
##
## 「快慢快」= 两段 tween 接力：
##   前半 [code]EASE_OUT[/code]（快→慢）走到中点，后半 [code]EASE_IN[/code]（慢→快）走到终点。
##   中点正好是场地中心，所以看起来是「冲到中央、缓一下、再冲出去」。
##
## 参数（可在 [code]PhaseData.params[/code] 覆盖）：
##   [code]move_time[/code](总秒数) / [code]hold_middle[/code](中点停留秒数) / [code]from_corner[/code](是否先瞬移到右上角)

const META := {
	"name": "对角扫场",
	"desc": "从游戏框右上角快慢快地扫到左下角（用作 PhaseData.pre_move_script 的发动前走位）。",
}

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
	var corner := Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)          # 右上角
	var dest := Vector2(GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM)         # 左下角
	var mid := (corner + dest) * 0.5                                             # 中点 = 场地中心
	_moving = true
	if from_corner:
		target.global_position = corner   # 瞬移到右上角再起跑
	var half := maxf(move_time, 0.0) * 0.5
	p_ctx.boss.move_path(target, [mid, dest], [half, half],
		[Tween.EASE_OUT, Tween.EASE_IN], hold_middle)
	return p_ctx.clock.wait(move_time + hold_middle)

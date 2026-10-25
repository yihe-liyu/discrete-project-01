extends CoroutineScript
## 原地不动：本卡期间不主动改坐标 —— 显式占住 [code]PhaseData.move_script[/code] 槽。
##
## 为什么需要这个脚本：空槽 ≠ 不动。[code]move_script = null[/code] 在运行时确实不会移动 Boss，
## 但"故意不走位"和"忘了接脚本"在数据里长得一模一样。把「本卡不走位」显式声明成脚本，
## 意图比留空更清楚，也让阶段配置可读。
##
## 用法：
##   - [code]move_script[/code] = 本脚本 → 整个阶段停在原地；
##   - 站位本身交给 [code]pre_move_script[/code]（如 [code]move_to_point[/code]），它把 Boss 送到点位上再宣言。
##
## 本脚本每帧只返回 [code]true[/code]、不写任何坐标（所以别的系统推它也不会被拉回来 —— 需要"钉住"
## 请另写脚本每帧回写 [code]target.global_position[/code]）。


func _tick(_ctx: StageContext) -> Variant:
	return true   # 持续运行、什么都不做：Boss 停在 pre_move_script 交出来的站位

extends CoroutineScript
## 原地不动：本卡期间**不主动改坐标** —— 显式占住 `PhaseData.move_script` 槽。
##
## 为什么需要这个脚本：**空槽 ≠ 不动**。`move_script = null` 在运行时确实不会移动 Boss
## （Boss 自己没有默认走位：位置只由 `pre_move_script` 与 `move_script` 改），
## 但"故意不走位"和"**忘了接脚本**"在数据里长得一模一样 ——
## `test_data_validity` 要求每个阶段的 move / shoot **双槽都在**，就是为了让"漏接"响亮。
## 所以「本卡不走位」要显式声明成一个脚本，而不是留空。
##
## 用法：
##   - `move_script` = 本脚本 → 整个阶段停在原地；
##   - 站位本身交给 `pre_move_script`（如 `move_to_point`），它把 Boss 送到点位上再宣言。
##
## 本脚本每帧只返回 `true`、**不写任何坐标**（所以别的系统推它也不会被拉回来 —— 需要"钉住"
## 请另写脚本每帧回写 `target.global_position`）。

const META := {
	"name": "原地不动",
	"desc": "本卡期间不主动移动（显式占住 move_script 槽；空槽是「漏接」而不是「不动」）。",
}


func _tick(_ctx: StageContext) -> Variant:
	return true   # 持续运行、什么都不做：Boss 停在 pre_move_script 交出来的站位

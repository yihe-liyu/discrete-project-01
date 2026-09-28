## 符卡结算横幅（`Boss.clear_phase` → `GameEvents.spell_result` → BossUI 放它）：
## 场地上部渐显 → 停 → 渐隐，一闪而过。
## 干净收取 = 「Get Spell Card Bonus」+ 奖励分；失败（超时 / miss·bomb 作废）= 「Bonus Failed」
## 且**不显示分数**（那分没入账 —— 显示会撒谎）；两种都带一行**击破时间**。
## 文案 / 颜色 / 位置声明在 scenes/ui/phase_result_banner.tscn（R21：改措辞不用动代码）。
##
## **时长与阶段间隔无关**（作者要求）：横幅不看阶段边界，只按下面四个 @export 走完 ——
## 下一张开卡（`phase_start`）不会掐掉它；唯一会提前收掉它的是"又出了一张结算"或整个 BossUI 退场。
## 于是这四个数可以随便调（总时长 = 2×`line_stagger` + `fade_in` + `hold` + `fade_out`），
## **不用再去动内容里的 `sequence_phases(gap)`**。
## 代价：它会和下一张符卡的**大字报幕**同屏，所以落点选在"倒计时之下、报幕大字最大态之上"那条带子里 ——
## 横幅块高 160px（三行最小高 59+47+38 + 两处行距 8×2）、倒计时底 = 132、报幕最大态视觉顶 = 343
## ⇒ 取 `anchor_top = 0.17`（×896 = 152，离上下各约 20 / 31px）。这条关系由
## `test_phase_result_banner.test_block_fits_between_countdown_and_spell_announce` 钉着：
## 改倒计时位置 / 报幕字号 / 行高 / 本场景落点时它会替我们红一次。
class_name PhaseResultBanner
extends Control

signal finished

## 三行 → 最长的那行等两次错开
const LINE_GAPS := 2

## 每行**错开**渐显的间隔（秒；0 = 三行一起淡入）
@export var line_stagger: float = 0.1
@export var fade_in: float = 0.2
@export var hold: float = 1.4
@export var fade_out: float = 0.3
## 文案（值由代码拼在**前缀**后面；标题两种结果各一条）
@export var failed_title: String = "Bonus Failed"
@export var captured_title: String = "Get Spell Card Bonus"
@export var bonus_prefix: String = "Bonus："
@export var time_prefix: String = "击破时间："
## 用时格式（秒）
@export var time_format: String = "%.2f"
## 标题配色：失败偏红 / 干净收取金色（与阶段进度点的红/金同源）
@export var failed_color: Color = Color(1.0, 0.45, 0.45)
@export var captured_color: Color = Color(0.95, 0.839, 0.475)

var _tween: Tween

@onready var _title: Label = $Lines/Title
@onready var _bonus: Label = $Lines/Bonus
@onready var _time: Label = $Lines/Time


func _ready() -> void:
	visible = false


## 干净收取 = **击破了**（`p_captured`）且**奖励分没作废**（期间没 miss / 没用 bomb）。
## 超时（captured=false）与作废都不算 —— 真值表在 `test_phase_result_banner`。
static func is_clean_capture(p_captured: bool, p_bonus_failed: bool) -> bool:
	return p_captured and not p_bonus_failed


## 总时长（三行都亮时）：从开始渐显到完全淡出。**与阶段边界无关** —— 想更长直接调那四个 @export。
func total_duration() -> float:
	return float(LINE_GAPS) * line_stagger + fade_in + hold + fade_out


## 播放本张符卡的结算。`bonus_failed` 为真时**不显示分数行**（那分没入账）。
func show_result(captured: bool, bonus: int, elapsed: float, bonus_failed: bool) -> void:
	var clean := is_clean_capture(captured, bonus_failed)
	_title.text = captured_title if clean else failed_title
	_title.add_theme_color_override("font_color", captured_color if clean else failed_color)
	_bonus.visible = clean
	_bonus.text = (bonus_prefix + str(bonus)) if clean else ""
	_time.text = time_prefix + (time_format % elapsed)
	_play()


## 本次要动画的行：**暗掉的行不参与错开**（失败时只有两行，时间行不必为空格等一拍）
func _active_lines() -> Array[Label]:
	var lines: Array[Label] = [_title, _time]
	if _bonus.visible:
		lines.insert(1, _bonus)
	return lines


## 渐显（逐行错开）→ 停 → 渐隐。全用**绝对 delay** 排一条并行时间线：
## 比"并行 + 顺序混用"的链式写法少一层歧义（`chain()` 到底接在谁后面得看引擎实现），
## 且顺序可由测试直接断言（停住那一刻 alpha 必须还是 1，见 test_phase_result_banner）。
func _play() -> void:
	_kill_tween()
	visible = true
	var lines := _active_lines()
	var out_delay := fade_in + hold
	_tween = create_tween()
	_tween.set_parallel(true)
	for i in lines.size():
		var line := lines[i]
		var delay := float(i) * line_stagger
		line.modulate.a = 0.0
		_tween.tween_property(line, "modulate:a", 1.0, fade_in).set_delay(delay)
		_tween.tween_property(line, "modulate:a", 0.0, fade_out).set_delay(delay + out_delay)
	var end_delay := float(lines.size() - 1) * line_stagger + out_delay + fade_out
	_tween.tween_callback(_on_finished).set_delay(end_delay)


func _on_finished() -> void:
	visible = false
	finished.emit()


## 停止动画并释放（切阶段 / 退场时清理；与 `AnnounceLabel.clear()` 同法）
func clear() -> void:
	_kill_tween()
	if is_inside_tree():
		queue_free()
	else:
		free()


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null

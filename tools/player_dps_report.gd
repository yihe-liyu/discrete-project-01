extends SceneTree
## 自机伤害数值计算器（手动调参 · 平衡参考）
## 用法: godot --headless --path . -s tools/player_dps_report.gd
## 改顶部"数值输入"区后重跑即得新表（不需要动公式区）

# ═══════════════════ 数值输入 ═══════════════════
# 对照 reimu_shoot.gd / marisa_shoot.gd 的 b.damage / wait_frames / 路数 填写

# ── 灵梦 Reimu ──
const REIMU_MAIN_DMG := 6.0        # 主射击单发伤害
const REIMU_MAIN_INTERVAL := 3     # 主射击间隔（物理帧）
const REIMU_MAIN_LANES := 2        # 主射击路数

const REIMU_FOCUS_DMG := 1.4       # option·聚焦
const REIMU_FOCUS_INTERVAL := 4
const REIMU_FOCUS_LANES := 2

const REIMU_SPREAD_DMG := 3.5      # option·散开（homing）
const REIMU_SPREAD_INTERVAL := 6
const REIMU_SPREAD_LANES := 1

# ── 魔理沙 Marisa ──
const MARISA_MAIN_DMG := 6.0
const MARISA_MAIN_INTERVAL := 3
const MARISA_MAIN_LANES := 2

const MARISA_FOCUS_DMG := 4.0      # option·聚焦
const MARISA_FOCUS_INTERVAL := 5
const MARISA_FOCUS_LANES := 1

const MARISA_LASER_DMG := 1.2      # option·激光 每段伤害
const MARISA_LASER_DRIFT := 2000.0 # 激光漂移速度 px/s
const MARISA_LASER_SEG_W := 64.0   # 激光段宽 px
const MARISA_LASER_OVERLAP := 0.85 # 段间距系数（间距 = 段宽×系数）

# ── 通用 ──
const OPTIONS_BY_POWER := [1, 2, 3, 4]  # power 0/100/200/300 → 子机数
const MEMORY_BONUS := [1.15, 1.05]      # 低记忆加成区间（memory 0→1.15, 49→1.05；≥50 = ×1.0）
const TARGET_HP := {                    # 击杀时间参考目标
	"小型妖精 40hp": 40.0,
	"中型妖精 120hp": 120.0,
	"Boss 符卡 4000hp": 4000.0,
}
const SPELL_TIME_LIMIT := 40.0          # 符卡时间限制（秒）

# ═══════════════════ 公式（一般不用改）═══════════════════

const FPS := 60.0
const REPORT_PATH := "res://tools/dps_report.txt"  # 输出同时保存到这里

var _buf: Array[String] = []


func _say(s: String) -> void:
	print(s)
	_buf.append(s)


func _dps(dmg: float, lanes: int, interval: int) -> float:
	return dmg * lanes * FPS / float(interval)


func _init() -> void:
	_say("")
	_say("════════════════════════════════════════════════════")
	_say("  自机伤害数值计算器（全命中 · 60fps 基准）")
	_say("  改顶部数值输入后重跑: godot --headless --path . -s tools/player_dps_report.gd")
	_say("════════════════════════════════════════════════════")

	_print_shooter("灵梦 Reimu",
		REIMU_MAIN_DMG, REIMU_MAIN_INTERVAL, REIMU_MAIN_LANES,
		REIMU_FOCUS_DMG, REIMU_FOCUS_INTERVAL, REIMU_FOCUS_LANES,
		REIMU_SPREAD_DMG, REIMU_SPREAD_INTERVAL, REIMU_SPREAD_LANES,
		MARISA_LASER_DMG, MARISA_LASER_DRIFT, MARISA_LASER_SEG_W, MARISA_LASER_OVERLAP,
		true)
	_print_shooter("魔理沙 Marisa",
		MARISA_MAIN_DMG, MARISA_MAIN_INTERVAL, MARISA_MAIN_LANES,
		MARISA_FOCUS_DMG, MARISA_FOCUS_INTERVAL, MARISA_FOCUS_LANES,
		0.0, 1, 0,  # 无散开 option（else 分支是激光）
		MARISA_LASER_DMG, MARISA_LASER_DRIFT, MARISA_LASER_SEG_W, MARISA_LASER_OVERLAP,
		false)

	_say("")
	_say("  [记忆加成] 高记忆(≥50): ×1.00   低记忆: ×%.2f~%.2f（仅玩家弹）" % [MEMORY_BONUS[0], MEMORY_BONUS[1]])
	_say("  [命中提示] 全命中理论值；高弹速窄判定/激光段命中率 <100% 时实际 DPS 更低")
	_say("════════════════════════════════════════════════════")
	_save_report()
	quit(0)


func _save_report() -> void:
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(_buf) + "\n")
		print("\n[已保存] 报告写入: ", REPORT_PATH)
	else:
		push_error("无法写入报告文件: " + REPORT_PATH)


func _print_shooter(name: String, main_dmg: float, main_int: int, main_lanes: int,
		focus_dmg: float, focus_int: int, focus_lanes: int,
		spread_dmg: float, spread_int: int, spread_lanes: int,
		laser_dmg: float, laser_drift: float, laser_seg_w: float, laser_overlap: float,
		has_spread: bool) -> void:
	var main_dps: float = _dps(main_dmg, main_lanes, main_int)
	var focus_dps: float = _dps(focus_dmg, focus_lanes, focus_int)
	_say("")
	_say("── %s ──" % name)
	_say("  主射击     : %.0f伤 ×%d路 @%d帧 = %.1f DPS" % [main_dmg, main_lanes, main_int, main_dps])
	if has_spread:
		var spread_dps: float = _dps(spread_dmg, spread_lanes, spread_int)
		_say("  option聚焦 : %.0f伤 ×%d路 @%d帧 = %.1f DPS/子机" % [focus_dmg, focus_lanes, focus_int, focus_dps])
		_say("  option散开 : %.0f伤 ×%d路 @%d帧 = %.1f DPS/子机 (homing)" % [spread_dmg, spread_lanes, spread_int, spread_dps])
		_print_power_summary(main_dps, focus_dps, spread_dps, laser_dmg, laser_drift, laser_seg_w, laser_overlap, true)
	else:
		var seg_per_s: float = laser_drift / (laser_seg_w * laser_overlap)
		var laser_dps: float = laser_dmg * seg_per_s
		_say("  option聚焦 : %.0f伤 ×%d路 @%d帧 = %.1f DPS/子机" % [focus_dmg, focus_lanes, focus_int, focus_dps])
		_say("  option激光 : %.1f伤/段 × %.1f段/s = %.1f DPS/子机" % [laser_dmg, seg_per_s, laser_dps])
		_print_power_summary(main_dps, focus_dps, 0.0, laser_dmg, laser_drift, laser_seg_w, laser_overlap, false)


func _print_power_summary(main_dps: float, focus_dps: float, spread_dps: float,
		laser_dmg: float, laser_drift: float, laser_seg_w: float, laser_overlap: float,
		has_spread: bool) -> void:
	var seg_per_s: float = laser_drift / (laser_seg_w * laser_overlap)
	var laser_dps: float = laser_dmg * seg_per_s
	for p in OPTIONS_BY_POWER.size():
		var n: int = OPTIONS_BY_POWER[p]
		var focus_total: float = main_dps + focus_dps * n
		var total: float
		var mode: String
		if has_spread:
			total = main_dps + spread_dps * n
			mode = "散开"
		else:
			total = main_dps + laser_dps * n
			mode = "激光"
		_say("    power%d (%d子机): 聚焦 %.0f | %s %.0f DPS" % [p * 100, n, focus_total, mode, total])
		# power300 击杀时间（取强势模式，高记忆无加成）
		if n == OPTIONS_BY_POWER[OPTIONS_BY_POWER.size() - 1]:
			for label in TARGET_HP:
				var hp: float = TARGET_HP[label]
				var t_hi: float = hp / (total * 1.0)
				var t_lo: float = hp / (total * MEMORY_BONUS[0])
				_say("      击杀 %s: %.1fs（低记忆 %.1fs）" % [label, t_hi, t_lo])
			var ratio: float = SPELL_TIME_LIMIT / (4000.0 / (total * 1.0))
			_say("      40s符卡(4000hp)余裕: %.1f 倍" % ratio)

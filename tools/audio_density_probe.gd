extends Node
## 音频密度探针 —— **SE 密度护栏「先量再调」的仪表**（2026-10-10）。
##
## **为什么要有它**：作者报「音效音量管理不怎么好」，而听得出来的毛病（忽大忽小 / 糊 / 被掐断）
## 来自**并发与密度**，不是响度 —— 光靠耳朵调 `SFX_DB` 治不了。这个工具把三个真变量量出来：
##   ① 每秒起了多少路 SE；② 单帧同时起几路；③ 池满时**踢掉正在响的一路**多少次。
## 数字说话之后再定护栏（每帧声部预算 / 优先级 / 总线限幅），改完再跑一遍对比。
##
## 用法（headless 即可 —— 音频走 dummy 后端，但**池 / 节流 / 统计全是真的**）：
##   godot --headless --path . res://tools/audio_density_probe.tscn -- --seconds 30
##
## 参数（`--` 之后）：
##   `--seconds <秒>`  跑多久（默认 20）
##   `--no-shoot`      不按住射击（默认**按住** —— headless 没有人类输入，
##                     不按就量不到「自机侧」那一半声部，数字会假低）
##   `--focus`         同时按住低速（魔理沙 = 激光那条最密的音）
##
## 读法：
##   * `每秒起声部数` 与 `单帧最多` → 决定"每帧预算"该定多少；
##   * `池满被踢掉` > 0 → 已经在**掐断正在响的声音**（听感 = 忽大忽小），护栏最该治这个；
##   * `踢到受保护音` > 0 → 危险信号（16 路全被重要音占满，说明池太小或密度太高）；
##   * `密度压制` 峰值/均值 → 护栏到底动了多少（均值很小 = 只在拥挤瞬间出手，平时不碰）。
##
## ⚠️ 跑不满给的秒数是**正常**的：headless 里自机不会躲弹，通常 35~60s 就 Game Over（整棵树 paused）——
## 探针会**报告并退出**，不会挂死（`process_mode = ALWAYS` + paused 检测）。想看 Boss 战要么加"不死"开关，
## 要么把 `--seconds` 调小到道中段。

const GAME_SCENE := "res://scenes/game_scene.tscn"
const DEFAULT_SECONDS := 20.0
const MEASURE_FPS := 60

var _elapsed: float = 0.0
var _seconds: float = DEFAULT_SECONDS
var _max_active: int = 0
var _max_active_at: float = 0.0
var _per_second_trace: Array[int] = []
var _last_second_value: int = -1
var _game: Node = null
var _seated: bool = false
var _hold_shoot: bool = true
var _hold_focus: bool = false


func _ready() -> void:
	_seconds = _arg_float("--seconds", DEFAULT_SECONDS)
	_hold_shoot = not _has_flag("--no-shoot")
	_hold_focus = _has_flag("--focus")
	# 关卡会因 Game Over / 暂停把整棵树 paused —— 探针必须照常跑，否则量到一半就冻住
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = MEASURE_FPS
	AudioManager.reset_sfx_stats()
	# 关卡场景必须挂在 **root** 下并成为 `current_scene`：
	# 它自己会 `GameManager.change_scene()` 换场，若挂在探针下会**连探针一起被释放**（量到一半就没了）。
	_game = load(GAME_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(_game)
	print("=== 音频密度实测（真实关卡 %.0fs%s%s / headless dummy 后端）===" % [
		_seconds, "，按住射击" if _hold_shoot else "", "，按住低速" if _hold_focus else ""])


func _process(delta: float) -> void:
	if not _seated:
		if not _game.is_inside_tree():
			return
		get_tree().current_scene = _game   # 必须等它真进了 root 才能认领（否则引擎报 parent != root）
		_seated = true
		if _hold_shoot:
			Input.action_press(&"shoot")
		if _hold_focus:
			Input.action_press(&"focus")
		return   # 入座的那一帧不计（场景刚开始，读数是 0）
	_elapsed += delta
	var stats: Dictionary = AudioManager.sfx_stats()
	if int(stats["active_voices"]) > _max_active:
		_max_active = int(stats["active_voices"])
		_max_active_at = _elapsed
	var per_second: int = int(stats["per_second"])
	if per_second != _last_second_value:
		_last_second_value = per_second
		_per_second_trace.append(per_second)
	if _elapsed >= _seconds:
		_report(stats, "跑满 %.0fs" % _seconds)
		get_tree().quit(0)
	elif not is_instance_valid(_game) or not _game.is_inside_tree():
		_report(stats, "关卡场景提前离场（%.1fs）—— 后面没有内容可量" % _elapsed)
		get_tree().quit(0)
	elif get_tree().paused:
		# 自机在 headless 里不会躲弹 → 通常 50~60s 就 Game Over，之后整棵树 paused
		_report(stats, "游戏结束/暂停（%.1fs，通常是 Game Over）—— 后面没有内容可量" % _elapsed)
		get_tree().quit(0)


func _exit_tree() -> void:
	# 松手：Input 是全局状态，别把"按住"泄漏给同一进程里的后续用例
	if _hold_shoot:
		Input.action_release(&"shoot")
	if _hold_focus:
		Input.action_release(&"focus")


func _report(stats: Dictionary, note: String) -> void:
	var played: int = int(stats["played"])
	print("  结束原因：%s" % note)
	print("  起了 %d 路 / %.1fs ⇒ 平均 %.1f 路/秒" % [played, _elapsed, float(played) / maxf(_elapsed, 0.001)])
	print("  单帧最多同时起 %d 路" % int(stats["peak_per_frame"]))
	print("  同时在响最多 %d / %d 路（第 %.1fs）" % [_max_active, int(stats["pool_size"]), _max_active_at])
	print("  池满被踢掉 %d 次（其中踢到**受保护**音 %d 次）" % [int(stats["evicted"]), int(stats["evicted_protected"])])
	print("  密度压制：峰值 %.2f dB · 平均 %.2f dB（护栏到底动了多少）" % [
		float(stats["density_cut_peak"]), float(stats["density_cut_avg"])])
	print("  被同帧去重挡掉 %d 次 · 被最小间隔挡掉 %d 次" % [int(stats["deduped"]), int(stats["throttled"])])
	print("  每秒起声部数轨迹（连续重复值已省略）：%s" % str(_per_second_trace))


func _arg_float(key: String, fallback: float) -> float:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == key and i + 1 < args.size():
			return float(args[i + 1])
	return fallback


func _has_flag(flag: String) -> bool:
	return OS.get_cmdline_user_args().has(flag)

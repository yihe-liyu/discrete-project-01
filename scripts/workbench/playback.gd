## 播放状态机（工作台）—— 只持状态、只做决策：不碰场景树 / 不碰 Engine / 不碰音频总线。
##
## 暂停 / 速度 / 快进 / 逐帧 / 静音这些规则原先长在 [code]workbench.gd[/code]，
## 必须借 Control 台子真跑帧才能验；抽出来后全是“给状态、问结果”的纯投影，可无树断言。
##
## 分工：本类只改自己的字段并发信号；宿主（[code]workbench.gd[/code]）在 [code]changed[/code] 里把状态下发到引擎
## （[code]tree.paused[/code] / [code]Engine.time_scale[/code] / [code]max_physics_steps_per_frame[/code] /
## [code]AudioManager.set_bgm_pitch[/code] / Master 总线静音）并同步播放控制行。
##
## 信号：
##   changed      —— 状态变了 → 宿主重新下发一次运行时设置
##   logged(text) —— 操作播报 → 宿主转交事件日志
class_name Playback
extends RefCounted

signal changed
signal logged(text: String)

const COMMON := preload("res://scripts/workbench/bench_common.gd")

## 播放速度档位（慢放/快进；书签跳转另用 FAST_FORWARD_SCALE）
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]
## 书签跳转的固定快进倍率（真实关卡不支持任意 seek，只能加速跑到目标）
const FAST_FORWARD_SCALE := 12.0
## 快进时抬高的物理步上限（默认 8 撑不住 12 步/帧 → 演出 tween/物理落后）
const FAST_FORWARD_MAX_STEPS := 64
## 默认物理步上限。
const DEFAULT_MAX_STEPS := 8
## 跳转容差：目标比当前早这么多以内算"同一点"，不值得重跑
const JUMP_BACK_TOLERANCE := 0.5
## 跳转下限：这么早的目标等价于"回开头"（不启动快进）
const MIN_JUMP_TARGET := 0.05

## 是否暂停。
var paused := false
## 是否手动静音。
var muted := false
## 是否显示背景。
var show_bg := true
## 当前速度档下标（SPEEDS）。
var speed_index := 2
## 是否使用固定种子。
var fixed_seed := false
## 快进目标时刻（< 0 = 不快进）。
var ff_target := -1.0
## 逐帧推进中（防重入）。
var stepping := false


# ═══ 播放 / 暂停 ═══

## 切换播放 / 暂停。
func toggle_play() -> void:
	if paused:
		resume()
	else:
		pause()


## 暂停：先退出快进（避免 time_scale 残留），再置 paused 并发 changed。
func pause() -> void:
	# 先退出快进：否则 time_scale 残留 12x，暂停后仍在飞
	if ff_active():
		stop_fast_forward()
	if paused:
		return
	paused = true
	logged.emit("＊ 暂停")
	changed.emit()


## 继续播放；未暂停时 no-op。
func resume() -> void:
	if not paused:
		return
	paused = false
	logged.emit("▶ 继续")
	changed.emit()


# ═══ 速度 / 快进 ═══

## 选速度档（越界忽略）。快进中只记不改 —— 快进优先，收尾时才落到新档
func select_speed(idx: int) -> void:
	if idx < 0 or idx >= SPEEDS.size():
		return
	speed_index = idx
	if not ff_active():
		logged.emit("＊ 速度 ×%.2f" % SPEEDS[idx])
	changed.emit()


## 是否正在快进
func ff_active() -> bool:
	return ff_target >= 0.0


## 目标时刻在过去吗（返回 true = 宿主必须先重跑关卡才能快进到它）
func jump_reload_needed(target_time: float, cur: float) -> bool:
	stop_fast_forward()
	return target_time < cur - JUMP_BACK_TOLERANCE


## 执行跳转：先收掉进行中的快进（两个入口都安全），太早的目标等价于回开头
func jump_to(target_time: float) -> void:
	stop_fast_forward()
	if target_time <= MIN_JUMP_TARGET:
		return
	start_fast_forward(target_time)


## 开始快进到 target_time；若当前暂停会先 resume。发 changed。
func start_fast_forward(target_time: float) -> void:
	if paused:
		resume()  # 快进要走时间，暂停中先解开（resume 自己发 changed）
	ff_target = target_time
	logged.emit("▶ 快进到 %.1fs ..." % target_time)
	changed.emit()


## 结束快进（到点 / 手动 / 跳转前都走这里），播报实际目标并发 changed。
func stop_fast_forward() -> void:
	if not ff_active():
		return
	var reached := ff_target
	ff_target = -1.0
	logged.emit("▶ 到达 %.1fs" % reached)
	changed.emit()


## 每帧推进：到达目标即收尾（宿主 PROCESS_MODE_ALWAYS，暂停中也推进）。
## cur 用 INF 表示"关卡已停/取不到时刻" → 同样收尾，避免目标永远挂着。
func poll(cur: float) -> void:
	if not ff_active():
		return
	if cur >= ff_target:
		stop_fast_forward()


# ═══ 逐帧推进 ═══

## 进入逐帧：返回 false = 正在推进中（防重入）。会先退快进、再进暂停。
## 推进期间树不停（见 [code]should_pause_tree[/code]）、time_scale 归 1 —— 恰好一个物理步。
func begin_step() -> bool:
	if stepping:
		return false
	if ff_active():
		stop_fast_forward()
	if not paused:
		pause()
	stepping = true
	changed.emit()
	return true


## 结束逐帧推进，恢复常规暂停投影；发 changed。
func end_step() -> void:
	stepping = false
	changed.emit()


# ═══ 开关 ═══

## 设手动静音；发 changed。
func set_muted(on: bool) -> void:
	muted = on
	changed.emit()


## 设背景显示；发 changed。
func set_show_bg(on: bool) -> void:
	show_bg = on
	changed.emit()


## 设固定种子开关并播报；发 changed。
func set_fixed_seed(on: bool) -> void:
	fixed_seed = on
	if on:
		logged.emit("＊ 固定种子 %d：重跑弹幕序列可复现" % fixed_seed_value())
	else:
		logged.emit("＊ 随机种子：每次重跑弹幕不同")
	changed.emit()


## 本次重跑该用的固定种子（宿主据此设 RNG；开关关掉时宿主自己 randomize）。
## 取值来自 [code]BenchCommon.FIXED_SEED[/code] —— 全工作台唯一来源，别在这里抄字面量。
func fixed_seed_value() -> int:
	return COMMON.FIXED_SEED


# ═══ 运行时投影（宿主据此下发；也是测试的断言面）═══

## 引擎该用的 time_scale：逐帧 1x · 快进 12x · 否则用户档位
func desired_time_scale() -> float:
	if stepping:
		return 1.0
	if ff_active():
		return FAST_FORWARD_SCALE
	return SPEEDS[speed_index]


## 物理步上限：快进要抬高（否则丢步）
func desired_physics_steps() -> int:
	return FAST_FORWARD_MAX_STEPS if ff_active() else DEFAULT_MAX_STEPS


## BGM 音高跟随 time_scale（慢放也同步）。统一口径：
## 旧代码在"快进收尾"那一支写死 1.0，慢放档下会与 time_scale 脱钩（0.5 画面配 1.0 音高）。
func desired_bgm_pitch() -> float:
	return desired_time_scale()


## 树该暂停吗：暂停中才暂停，但逐帧推进那一瞬要放行物理
func should_pause_tree() -> bool:
	return paused and not stepping


## 音频该静音吗：手动静音 / 暂停 / 快进中都不该出声
func is_audio_muted() -> bool:
	return muted or paused or ff_active()

extends RefCounted
## 整关预览的 Playback 宿主投影（D3：从 Workbench 拆出）。
##
## 规则仍在 Playback；本服务只做：
##   状态 → tree.paused / Engine.time_scale / 音频总线 / 播放条
##   轮询快进到达 / 逐帧推进 / 跳转（过去目标先重载）
## 重载与日志用 Callable 注入，不反向依赖 Workbench 私有。

var _host: Node
var _playback: Playback
var _playback_bar: PlaybackBar
var _stage_runtime: StageRuntime
var _redraw: Callable
var _load_stage: Callable
var _log_line: Callable


func setup(host: Node, playback: Playback, playback_bar: PlaybackBar, stage_runtime: StageRuntime,
		redraw: Callable, load_stage: Callable, log_line: Callable) -> void:
	_host = host
	_playback = playback
	_playback_bar = playback_bar
	_stage_runtime = stage_runtime
	_redraw = redraw
	_load_stage = load_stage
	_log_line = log_line


## 快进到达检测（本服务宿主 PROCESS_MODE_ALWAYS，暂停中也照检）
func poll() -> void:
	var runner := _stage_runtime.current_stage_script()
	_playback.poll(runner.game_time() if runner != null else INF)


## Playback.changed 的唯一落点：投影到引擎/音频/播放条，再触发舞台重绘。
func apply_runtime() -> void:
	var scene_tree := _host.get_tree()
	if scene_tree != null:
		scene_tree.paused = _playback.should_pause_tree()
	Engine.time_scale = _playback.desired_time_scale()
	Engine.max_physics_steps_per_frame = _playback.desired_physics_steps()
	AudioManager.set_bgm_pitch(_playback.desired_bgm_pitch())
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, _playback.is_audio_muted())
	if _playback_bar != null:
		_playback_bar.set_playing(not _playback.paused)
		_playback_bar.set_speed(_playback.speed_index)
	if _redraw.is_valid():
		_redraw.call()


## 暂停状态下精确走一帧物理（physics_frame 先于节点物理，await 两次 = 一个物理步）
func frame_step() -> void:
	if not _playback.begin_step():
		return
	await _host.get_tree().physics_frame
	await _host.get_tree().physics_frame
	_playback.end_step()


## 跳转：协程关卡不能倒带 → 目标在过去时先重载，再快进。
func jump_to(target_time: float) -> void:
	var cur := current_time()
	if _playback.jump_reload_needed(target_time, cur):
		if _log_line.is_valid():
			_log_line.call("＊ 目标 %.1fs 在过去（当前 %.1fs），重跑后快进" % [target_time, cur])
		if _load_stage.is_valid():
			_load_stage.call()
	_playback.jump_to(target_time)


func current_time() -> float:
	var runner := _stage_runtime.current_stage_script()
	return runner.game_time() if runner != null else 0.0

extends GutTest
## `Playback`（播放状态机）**无树**单测：S3 把它从 `workbench.gd` 抽出来之后，
## 暂停 / 速度 / 快进 / 逐帧 / 静音这些规则不必再借一个 Control 台子 + 真跑帧才能验 ——
## 全是"给状态、问投影"：`desired_time_scale()` / `should_pause_tree()` / `is_audio_muted()`。
##
## 这里断言的正是当初写在 `workbench.gd` 里、出错也看不见的几条：
## 快进与档位的优先级、暂停顺手收快进、逐帧那一瞬要放行物理、慢放收尾后音高不脱钩。

const PLAYBACK := preload("res://scripts/workbench/playback.gd")

var pb: Playback


func before_each() -> void:
	pb = Playback.new()   # RefCounted：**不入树**也能跑，这正是抽服务的目的
	watch_signals(pb)


func test_initial_state_is_playing_at_1x() -> void:
	assert_false(pb.paused, "初始在播")
	assert_eq(pb.speed_index, 2, "初始档 = ×1.0")
	assert_eq(pb.desired_time_scale(), 1.0)
	assert_false(pb.ff_active(), "初始不快进")
	assert_false(pb.is_audio_muted(), "初始不静音")
	assert_true(pb.show_bg, "初始带背景")
	assert_eq(pb.desired_physics_steps(), PLAYBACK.DEFAULT_MAX_STEPS)


func test_toggle_play_pauses_then_resumes() -> void:
	pb.toggle_play()
	assert_true(pb.paused)
	assert_true(pb.should_pause_tree(), "暂停要真的停树")
	assert_true(pb.is_audio_muted(), "暂停顺手静音")
	pb.toggle_play()
	assert_false(pb.paused)
	assert_false(pb.should_pause_tree(), "继续要放行树")
	assert_false(pb.is_audio_muted())


## 幂等：已经在暂停再按一次，不该重复播报/重复下发（日志里刷两行"暂停"是噪声）
func test_pause_is_idempotent() -> void:
	pb.pause()
	pb.pause()
	assert_signal_emit_count(pb, "logged", 1, "已在暂停 → 不重复播报")
	assert_signal_emit_count(pb, "changed", 1, "状态没变 → 不重复下发")
	pb.resume()
	pb.resume()
	assert_signal_emit_count(pb, "logged", 2, "继续同理只播报一次")


## 暂停必须先收快进：否则 `time_scale` 残留 12x，画面"暂停"了其实还在飞
func test_pause_stops_fast_forward() -> void:
	pb.select_speed(6)
	pb.start_fast_forward(30.0)
	assert_true(pb.ff_active())
	pb.pause()
	assert_false(pb.ff_active(), "暂停顺手收掉快进")
	assert_true(pb.paused)
	assert_eq(pb.desired_time_scale(), 16.0, "收尾落到用户档位")


## 快进优先于档位；快进中选档只记不抢时间轴，收尾才落到新档
func test_speed_applies_only_when_not_fast_forwarding() -> void:
	pb.select_speed(0)
	assert_eq(pb.desired_time_scale(), 0.25)
	pb.start_fast_forward(20.0)
	assert_eq(pb.desired_time_scale(), PLAYBACK.FAST_FORWARD_SCALE, "快进压过档位")
	pb.select_speed(6)
	assert_eq(pb.desired_time_scale(), PLAYBACK.FAST_FORWARD_SCALE, "快进中选档不抢时间轴")
	assert_eq(pb.speed_index, 6, "但档位记下了")
	pb.stop_fast_forward()
	assert_eq(pb.desired_time_scale(), 16.0, "收尾才落到新档")


func test_speed_out_of_range_ignored() -> void:
	pb.select_speed(-1)
	pb.select_speed(99)
	assert_eq(pb.speed_index, 2, "越界不改档")
	assert_signal_emit_count(pb, "changed", 0, "越界连下发都不用")


func test_fast_forward_raises_physics_steps_and_pitch_and_mutes() -> void:
	pb.start_fast_forward(12.5)
	assert_eq(pb.ff_target, 12.5)
	assert_eq(pb.desired_physics_steps(), PLAYBACK.FAST_FORWARD_MAX_STEPS,
		"12 步/帧要抬上限，否则丢步（演出 tween / 物理落后）")
	assert_eq(pb.desired_bgm_pitch(), PLAYBACK.FAST_FORWARD_SCALE, "音乐跟快进变速")
	assert_true(pb.is_audio_muted(), "快进中不该出声")


func test_poll_stops_at_target() -> void:
	pb.start_fast_forward(30.0)
	pb.poll(29.9)
	assert_true(pb.ff_active(), "没到不收")
	pb.poll(30.0)
	assert_false(pb.ff_active(), "到了收")
	var params = get_signal_parameters(pb, "logged", 1)
	assert_true(String(params[0]).contains("到达"), "播报到达（实得 %s）" % params[0])


func test_poll_without_fast_forward_is_silent() -> void:
	pb.poll(1000.0)
	assert_signal_emit_count(pb, "changed", 0)
	assert_signal_emit_count(pb, "logged", 0)


## 取不到游戏内时刻（关卡已停 / 无 runner）也要收尾 —— 否则快进目标永远挂着、time_scale 卡 12x
func test_poll_with_infinite_time_finishes() -> void:
	pb.start_fast_forward(30.0)
	pb.poll(INF)
	assert_false(pb.ff_active(), "无 runner（INF）应视为到达")


## 慢放收尾后音高仍跟画面：旧代码在"快进收尾"那一支写死 1.0 → 0.5 画面配 1.0 音高
func test_slow_motion_pitch_survives_fast_forward_stop() -> void:
	pb.select_speed(1)   # ×0.5
	pb.start_fast_forward(10.0)
	pb.stop_fast_forward()
	assert_eq(pb.desired_time_scale(), 0.5)
	assert_eq(pb.desired_bgm_pitch(), 0.5, "音高与 time_scale 同源")


func test_jump_reload_needed_only_for_past_targets() -> void:
	assert_true(pb.jump_reload_needed(5.0, 10.0), "目标在过去 → 宿主必须重跑")
	assert_false(pb.jump_reload_needed(9.5, 10.0), "容差内算同一点，不值得重跑")
	assert_false(pb.jump_reload_needed(20.0, 10.0), "未来目标更不用重跑")


func test_jump_to_ignores_near_zero() -> void:
	pb.start_fast_forward(20.0)
	pb.jump_to(0.01)
	assert_false(pb.ff_active(), "回开头不启动快进")
	assert_eq(pb.ff_target, -1.0)
	pb.jump_to(1.0)
	assert_true(pb.ff_active())
	assert_eq(pb.ff_target, 1.0)


# ═══ 逐帧推进 ═══

## 逐帧那一瞬必须**放行物理**且固定 1x：否则"一个物理步"名不副实
func test_frame_step_releases_tree_for_one_physics_frame() -> void:
	pb.pause()
	assert_true(pb.begin_step(), "首次进入逐帧")
	assert_true(pb.stepping)
	assert_false(pb.should_pause_tree(), "逐帧那一瞬要放行物理")
	assert_eq(pb.desired_time_scale(), 1.0, "逐帧固定 1x")
	pb.end_step()
	assert_false(pb.stepping)
	assert_true(pb.should_pause_tree(), "走完回到暂停")
	assert_eq(pb.desired_time_scale(), PLAYBACK.SPEEDS[2], "回到用户档位")


func test_frame_step_rejects_reentry() -> void:
	assert_true(pb.begin_step())
	assert_false(pb.begin_step(), "推进中再按 F 忽略（防重入）")
	pb.end_step()


func test_frame_step_from_playing_pauses() -> void:
	pb.begin_step()
	assert_true(pb.paused, "逐帧前先暂停（否则一帧后还在飞）")
	pb.end_step()


func test_frame_step_cancels_fast_forward() -> void:
	pb.start_fast_forward(30.0)
	pb.begin_step()
	assert_false(pb.ff_active(), "逐帧要先退出快进")
	pb.end_step()


# ═══ 开关 ═══

func test_audio_muted_by_any_of_mute_pause_fast_forward() -> void:
	assert_false(pb.is_audio_muted())
	pb.set_muted(true)
	assert_true(pb.is_audio_muted(), "手动静音")
	pb.set_muted(false)
	pb.pause()
	assert_true(pb.is_audio_muted(), "暂停静音")
	pb.resume()
	assert_false(pb.is_audio_muted())
	pb.start_fast_forward(5.0)
	assert_true(pb.is_audio_muted(), "快进静音")


func test_fixed_seed_logs_and_marks() -> void:
	pb.set_fixed_seed(true)
	assert_true(pb.fixed_seed)
	var params = get_signal_parameters(pb, "logged", 0)
	assert_true(String(params[0]).contains(str(pb.fixed_seed_value())), "播报固定种子值（实得 %s）" % params[0])
	pb.set_fixed_seed(false)
	assert_false(pb.fixed_seed)
	assert_signal_emit_count(pb, "changed", 2, "开关两次 → 下发两次")


func test_show_bg_toggles_and_notifies() -> void:
	pb.set_show_bg(false)
	assert_false(pb.show_bg)
	assert_signal_emit_count(pb, "changed", 1, "背景开关要通知宿主（装配变了，得重跑）")

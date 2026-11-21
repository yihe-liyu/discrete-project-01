## ReplaySession —— 一局录制的跨场景持有者。
##
## 录制从正常路线开局开始，跨 stage reload 持续采样；只在 run 结束
## （通关 Return / Game Over）落盘。同一类也持有回放文件、当前帧与输入掩码，
## GameScene 每物理帧推进一帧；PlayerInput 在回放时读这里的掩码。
class_name ReplaySession
extends RefCounted

const DIR := "user://replays"

## 默认录轻量逐帧状态（不含逐颗弹/道具快照）；--replay-trace 才加完整快照。
static var trace_enabled: bool = true
static var full_trace: bool = false

static var _recorder: ReplayRecorder
static var _active: bool = false

static var _playing: bool = false
static var _frames: PackedByteArray = PackedByteArray()
static var _frame_index: int = 0
static var _mask: int = 0
static var _events: Array[Dictionary] = []
static var _event_index: int = 0
static var _path: String = ""
static var _preserve_on_exit: bool = false
static var _start_stage_id: int = 1
static var _start_stage_no: int = 1
static var _start_route_id: StringName = &""
static var _samples: Array[Dictionary] = []
static var _score_events: Array[Dictionary] = []
static var _trace_diverged: bool = false
static var _last_tick_physics_frame: int = -1
static var _spawn_cursor: int = 0
static var _rng_cursor: int = 0


static func is_recording() -> bool:
	return _active


## 开一局：清空并开始采样。已在录制中（切面 reload）则保持原录制。
static func start_run() -> bool:
	if _active or _playing:
		return false
	full_trace = OS.get_cmdline_user_args().has("--replay-trace")
	trace_enabled = true
	_start_stage_id = SaveData.current_stage_id
	_start_stage_no = SaveData.current_route_index + 1
	_start_route_id = SaveData.current_route_id
	RNG.rng_trace_hook = capture_rng_call
	_recorder = ReplayRecorder.new()
	_recorder.start()
	_active = true
	return true


## GameScene 每物理帧调用一次。
static func capture_frame() -> void:
	if _active and _recorder != null:
		_recorder.capture()


## 离散动作（bomb / memory_release）由 Player 的输入事件调用。
static func capture_event(action: StringName) -> void:
	if _active and _recorder != null:
		_recorder.capture_event(action)


## 记录一次得分来源（录制时由敌人 / 道具 / 擦弹 / 符卡奖励调用）。
## gameplay RNG 调用：录制时按帧落盘；回放时逐条比对入口与帧。
static func capture_rng_call(method: StringName, before: int, after: int) -> void:
	if _active and _recorder != null:
		_recorder.rng_calls.append({
			"frame": _recorder.duration_frames - 1,
			"m": String(method),
			"before": str(before),
			"after": str(after),
		})
	elif _playing and _recorder != null and not _recorder.rng_calls.is_empty():
		var rf := _frame_index - 1
		while _rng_cursor < _recorder.rng_calls.size() \
				and int(_recorder.rng_calls[_rng_cursor].get("frame", 0)) < rf:
			_rng_cursor += 1
		if _rng_cursor >= _recorder.rng_calls.size():
			push_warning("Replay RNG 多余调用 frame=%d %s before=%d" % [rf, String(method), before])
			return
		var e: Dictionary = _recorder.rng_calls[_rng_cursor]
		if int(e.get("frame", -1)) == rf and str(e.get("m", "")) == String(method):
			_rng_cursor += 1
			if str(e.get("before", "")) != str(before):
				push_warning("Replay RNG 前态分歧 frame=%d %s before=%d exp_before=%s" % [
					rf, String(method), before, str(e.get("before", "")),
				])
			if str(e.get("after", "")) != str(after):
				push_warning("Replay RNG 状态分歧 frame=%d %s before=%d cur_after=%d exp_after=%s" % [
					rf, String(method), before, after, str(e.get("after", "")),
				])
		else:
			push_warning("Replay RNG 调用分歧 frame=%d cur=%s exp=%s@%d before=%d" % [
				rf, String(method), str(e.get("m", "")), int(e.get("frame", -1)), before,
			])


## 弹幕生成：录制时落盘；回放时对比录制生成序列，报第一颗多余/缺失。
static func capture_spawn(uid: int, type_index: int, pos: Vector2, faction: int,
		behavior: StringName = &"") -> void:
	if _active and _recorder != null:
		_recorder.spawn_events.append({
			"frame": _recorder.duration_frames,
			"uid": uid,
			"type": type_index,
			"p": [pos.x, pos.y],
			"f": faction,
			"b": String(behavior),
		})
	elif _playing:
		if _recorder == null or _recorder.spawn_events.is_empty():
			return
		var f := _frame_index
		while _spawn_cursor < _recorder.spawn_events.size() \
				and int(_recorder.spawn_events[_spawn_cursor].get("frame", 0)) < f:
			var missing: Dictionary = _recorder.spawn_events[_spawn_cursor]
			push_warning("Replay 缺少生成 frame=%d type=%d" % [
				int(missing.get("frame", 0)), int(missing.get("type", -1)),
			])
			_spawn_cursor += 1
		if _spawn_cursor < _recorder.spawn_events.size():
			var e: Dictionary = _recorder.spawn_events[_spawn_cursor]
			if int(e.get("frame", -1)) == f and int(e.get("type", -1)) == type_index:
				_spawn_cursor += 1
				return
		push_warning("Replay 多余生成 frame=%d uid=%d type=%d pos=%s behavior=%s" % [
			f, uid, type_index, pos, behavior,
		])


## 敌弹命中自机：录制时落盘；回放时打印本次受击来源，便于查“多出来的受击”。
static func capture_hit(uid: int, type_index: int, pos: Vector2) -> void:
	if _active and _recorder != null:
		_recorder.hit_events.append({
			"frame": _recorder.duration_frames,
			"uid": uid,
			"type": type_index,
			"p": [pos.x, pos.y],
		})
	elif _playing:
		push_warning("Replay 受击 frame=%d uid=%d type=%d pos=%s" % [
			_frame_index, uid, type_index, pos,
		])


static func capture_score(amount: int, source: StringName) -> void:
	if _active and _recorder != null:
		_recorder.capture_score(amount, source)


## 记录一帧状态采样（位置 / RNG / 分数 / 残机 / 雷）。
static func capture_sample(pos: Vector2, res: PlayerResources, bullets: int = 0, bhash: int = 0,
		items: int = 0, ihash: int = 0, bsnap: Array = [], graze: int = 0, isnap: Array = [],
		krng: int = 0) -> void:
	if not _active or _recorder == null:
		return
	var rng := RNG.snapshot_state()
	_recorder.capture_sample({
		"p": [pos.x, pos.y],
		"seed": str(rng.get("seed", 0)),
		"state": str(rng.get("state", 0)),
		"score": res.current_score if res != null else 0,
		"lives": res.lives if res != null else 0,
		"bombs": res.bomb_count if res != null else 0,
		"bullets": bullets,
		"bhash": bhash,
		"items": items,
		"ihash": ihash,
		"bsnap": bsnap,
		"graze": graze,
		"isnap": isnap,
		"krng": krng,
	})


## 回放帧开始：恢复内核 bullet RNG 状态（宿主 RNG 已由 sync_rng_for_frame 恢复）。
static func sync_kernel_rng(manager: BulletManager) -> void:
	if not _playing or _samples.is_empty() or manager == null:
		return
	var idx := _frame_index - 1
	if idx < 0 or idx >= _samples.size():
		return
	var sample: Dictionary = _samples[idx]
	if sample.has("krng"):
		manager.set_kernel_rng_state(int(str(sample.get("krng", "0"))))


## 回放帧开始：把 gameplay RNG 恢复到录制时的状态。
## 表现 RNG 已分离；这里保证掉落 / 擦弹等 gameplay 随机逐帧一致。
static func sync_rng_for_frame() -> void:
	if not _playing or _samples.is_empty():
		return
	var idx := _frame_index - 1
	if idx < 0 or idx >= _samples.size():
		return
	var sample: Dictionary = _samples[idx]
	if not sample.has("seed") or not sample.has("state"):
		return
	RNG.restore_state({
		"seed": int(str(sample.get("seed", "0"))),
		"state": int(str(sample.get("state", "0"))),
	})


## 回放时对比当前帧采样；只报第一个分歧，避免刷屏。
static func check_sample(pos: Vector2, res: PlayerResources, bullets: int = 0, bhash: int = 0,
		items: int = 0, ihash: int = 0, bsnap: Array = [], graze: int = 0, isnap: Array = [],
		krng: int = 0) -> void:
	if not _playing or _trace_diverged or _samples.is_empty():
		return
	var idx := _frame_index - 1
	if idx < 0 or idx >= _samples.size():
		return
	var expected: Dictionary = _samples[idx]
	var p: Array = expected.get("p", [])
	if p.size() != 2:
		return
	var ep := Vector2(float(p[0]), float(p[1]))
	var rng := RNG.snapshot_state()
	var mismatch := []
	if pos.distance_to(ep) > 0.01:
		mismatch.append("pos %s != %s" % [pos, ep])
	if str(rng.get("seed", 0)) != str(expected.get("seed", "")):
		mismatch.append("rng_seed")
	if str(rng.get("state", 0)) != str(expected.get("state", "")):
		mismatch.append("rng_state cur=%s exp=%s rng_calls=%d" % [
			str(rng.get("state", 0)), str(expected.get("state", "")), _rng_cursor,
		])
	if expected.has("graze") and graze != int(expected.get("graze", 0)):
		mismatch.append("graze")
	if expected.has("krng") and krng != int(str(expected.get("krng", "0"))):
		mismatch.append("krng")
	if (res.current_score if res != null else 0) != int(expected.get("score", 0)):
		mismatch.append("score[%s]" % _score_events_near(idx))
	if (res.lives if res != null else 0) != int(expected.get("lives", 0)):
		mismatch.append("lives")
	if (res.bomb_count if res != null else 0) != int(expected.get("bombs", 0)):
		mismatch.append("bombs")
	if expected.has("bullets") and bullets != int(expected.get("bullets", 0)):
		mismatch.append("bullets")
	var expected_bhash := int(expected.get("bhash", 0))
	if expected.has("bsnap") and not (expected.get("bsnap", []) as Array).is_empty():
		# 完整 trace 才用逐颗快照重算；compact trace 的 bsnap 是空数组。
		expected_bhash = _snapshot_hash(expected.get("bsnap", []))
	if expected.has("bhash") and bhash != expected_bhash:
		mismatch.append("bhash[%s]" % _first_bullet_diff(bsnap, expected.get("bsnap", [])))
	if expected.has("items") and items != int(expected.get("items", 0)):
		mismatch.append("items")
	var expected_ihash := int(expected.get("ihash", 0))
	if expected.has("isnap") and not (expected.get("isnap", []) as Array).is_empty():
		expected_ihash = _snapshot_hash(expected.get("isnap", []))
	if expected.has("ihash") and ihash != expected_ihash:
		mismatch.append("ihash[%s]" % _first_item_diff(isnap, expected.get("isnap", [])))
	if not mismatch.is_empty():
		_trace_diverged = true
		push_warning("Replay 分歧 frame=%d: %s" % [idx, ", ".join(mismatch)])


static func _score_events_near(frame: int) -> String:
	var parts: Array[String] = []
	for e in _score_events:
		var f := int(e.get("frame", -9999))
		if absi(f - frame) <= 2:
			parts.append("%s+%d@%d" % [str(e.get("source", "?")), int(e.get("amount", 0)), f])
	return ",".join(parts) if not parts.is_empty() else "no-event"


static func _snapshot_hash(raw: Array) -> int:
	# 注意：这是道具快照重算（[type,x,y]）；子弹哈希在 BulletManager 里。
	if raw.size() > 0 and (raw[0] as Array).size() == 3:
		var ih: int = 0
		for e in raw:
			ih = (ih * 31 + int(e[0])) & 0x7fffffff
			ih = (ih * 31 + hash(Vector2(float(e[1]), float(e[2])))) & 0x7fffffff
		return ih
	var snap := _clean_snapshot(raw)
	var h: int = snap.size()
	for e in snap:
		h = (h * 31 + int(e[0])) & 0x7fffffff
		h = (h * 31 + hash(Vector2(float(e[1]), float(e[2])))) & 0x7fffffff
		h = (h * 31 + int(e[3])) & 0x7fffffff
		h = (h * 31 + int(e[4])) & 0x7fffffff
	return h


static func _clean_snapshot(raw: Array) -> Array:
	var snap: Array = []
	for e in raw:
		if e is Array and e.size() >= 4 and int(e[0]) > 0 and int(e[3]) >= 0:
			snap.append(e)
	snap.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return snap


static func _first_item_diff(current: Array, expected_raw: Array) -> String:
	if expected_raw.is_empty():
		return "no-snapshot"
	var expected := expected_raw.duplicate(true)
	expected.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]): return int(a[0]) < int(b[0])
		if not is_equal_approx(float(a[1]), float(b[1])): return float(a[1]) < float(b[1])
		return float(a[2]) < float(b[2]))
	var cur := current.duplicate(true)
	cur.sort_custom(func(a: Array, b: Array) -> bool:
		if int(a[0]) != int(b[0]): return int(a[0]) < int(b[0])
		if not is_equal_approx(float(a[1]), float(b[1])): return float(a[1]) < float(b[1])
		return float(a[2]) < float(b[2]))
	var n := mini(cur.size(), expected.size())
	for i in n:
		if cur[i] != expected[i]:
			return "i=%d cur=%s exp=%s" % [i, cur[i], expected[i]]
	if cur.size() != expected.size():
		return "len %d vs %d" % [cur.size(), expected.size()]
	return "order/hash"


static func _first_bullet_diff(current: Array, expected_raw: Array) -> String:
	var expected := _clean_snapshot(expected_raw)
	current = _clean_snapshot(current)
	var n := mini(current.size(), expected.size())
	for i in n:
		var a: Array = current[i]
		var b: Array = expected[i]
		if a.size() != b.size():
			return "i=%d shape" % i
		var bad := false
		for j in a.size():
			if j == 1 or j == 2:
				if absf(float(a[j]) - float(b[j])) > 0.001:
					bad = true
			elif int(a[j]) != int(b[j]):
				bad = true
		if bad:
			return "i=%d cur=%s exp=%s" % [i, a, b]
	if current.size() != expected.size():
		return "len %d vs %d" % [current.size(), expected.size()]
	return "order/hash"


## 结束并落盘；meta 为空时仍写一份只有输入/种子的录制。
## 返回路径；未录制 / 写盘失败 = 空串。
static func finish_run(meta: Dictionary = {}) -> String:
	if not _active or _recorder == null:
		return ""
	_recorder.stop()
	_recorder.metadata = meta.duplicate(true)
	# 回放必须从录制起点开始，不能默认 Stage1；旧字段缺失时由调用方兜底。
	_recorder.metadata["start_stage_id"] = _start_stage_id
	_recorder.metadata["start_stage_no"] = _start_stage_no
	_recorder.metadata["start_route_id"] = String(_start_route_id)
	_recorder.metadata["sample_phase"] = "next_physics"
	_active = false
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/%s_%d.json" % [DIR, stamp, Time.get_ticks_msec()]
	if not _recorder.save(path):
		return ""
	RNG.rng_trace_hook = Callable()
	_recorder = null
	return path


## 从文件进入回放：装载 seed / 难度 / 角色 / 路线，再交给 GameScene 启动。
static func start_playback(path: String) -> bool:
	var rec := ReplayRecorder.new()
	if not rec.load_file(path):
		push_warning("ReplaySession: 无法加载回放 " + path)
		return false
	var meta := rec.metadata
	var diff := int(meta.get("difficulty", 1))
	if not Difficulty.is_valid(diff):
		diff = 1
	SaveData.reset_session()
	SaveData.selected_difficulty = diff
	SaveData.selected_character = int(meta.get("character", 0))
	PracticeSession.finish()
	SaveData.is_stage_practice = false
	SaveData.is_restarting = false
	if not SaveData.begin_route_for_difficulty(diff):
		return false
	# 录像可能从 Stage2 开始（例如从路线中途进入）；播到录制起点，而不是强行 Stage1。
	var start_stage := int(meta.get("start_stage_id", 1))
	var route := SaveData.current_route()
	if route != null:
		for i in route.stages.size():
			if route.stages[i] != null and route.stages[i].stage_id == start_stage:
				SaveData.current_route_index = i
				SaveData.current_stage_id = start_stage
				break
	RNG.set_seed(rec.rng_seed)
	_path = path
	_recorder = rec
	_frames = rec.frames
	_frame_index = 0
	_mask = 0
	_last_tick_physics_frame = -1
	_spawn_cursor = 0
	_rng_cursor = 0
	_events = rec.events.duplicate(true)
	_event_index = 0
	_samples.clear()
	if str(meta.get("sample_phase", "")) == "next_physics":
		_samples = rec.samples.duplicate(true)
	_score_events = rec.score_events.duplicate(true)
	_trace_diverged = false
	_playing = true
	# 必须在 _playing / cursor 就绪后再挂 hook，否则首批调用会被丢弃。
	RNG.rng_trace_hook = capture_rng_call
	return true


## 从头重播当前录像；保留场景跨 reload 的标志。
static func restart_playback() -> bool:
	if _path == "":
		return false
	if not start_playback(_path):
		return false
	_preserve_on_exit = true
	return true


## 路线切面也要跨 GameScene reload 保留 playback。
static func mark_preserve_on_scene_change() -> void:
	_preserve_on_exit = true


## 当前帧所属的 deathbomb 窗口的真实 end 帧；只接受 24 帧附近的配对。
static func deathbomb_end_for_current() -> Dictionary:
	if not _playing:
		return {"frame": -1, "cancelled": false}
	var start := -1
	for e in _events:
		var action := StringName(str(e.get("action", "")))
		var f := int(e.get("frame", 0))
		if action == &"deathbomb_start":
			start = f
		elif (action == &"deathbomb_end_cancel" or action == &"deathbomb_end_miss") and start >= 0:
			var near := _frame_index >= start - 2 and _frame_index <= f + 2
			var sane := f - _frame_index <= 26
			if near and sane:
				return {"frame": f, "cancelled": action == &"deathbomb_end_cancel"}
			start = -1
	return {"frame": -1, "cancelled": false}


static func current_frame() -> int:
	return _frame_index


## 开新窗口前，清掉早于当前帧的旧 deathbomb end，防止旧事件关新窗口。
static func discard_stale_deathbomb_ends(before_frame: int) -> void:
	var i := _event_index
	while i < _events.size():
		var action := StringName(str(_events[i].get("action", "")))
		if (action == &"deathbomb_end_cancel" or action == &"deathbomb_end_miss") \
				and int(_events[i].get("frame", 0)) < before_frame:
			_events.remove_at(i)
		else:
			i += 1


## 每个物理帧最多推进一次；physics 与 process 双驱动时防重复。
static func begin_playback_tick() -> bool:
	var pf := Engine.get_physics_frames()
	if pf == _last_tick_physics_frame:
		return false
	_last_tick_physics_frame = pf
	return true


## GameScene 退出时消费：true = 这次场景 reload 是回放重开，别停 playback。
static func consume_preserve_on_exit() -> bool:
	var keep := _preserve_on_exit
	_preserve_on_exit = false
	return keep


## 回放结束时对比最终资源；trace 只覆盖逐帧，末段结算差异在这里暴露。
static func check_final(res: PlayerResources) -> void:
	if not _playing or _recorder == null:
		return
	var meta := _recorder.metadata
	var expected_score := int(meta.get("score", 0))
	var actual_score := res.current_score if res != null else -1
	if actual_score != expected_score:
		var tail: Array[String] = []
		for i in range(maxi(0, _score_events.size() - 5), _score_events.size()):
			var e: Dictionary = _score_events[i]
			tail.append("%s+%d@%d" % [
				str(e.get("source", "?")), int(e.get("amount", 0)), int(e.get("frame", 0)),
			])
		push_warning("Replay final 分歧 score=%d expected=%d lives=%d/%d bombs=%d/%d last_score_events=%s" % [
			actual_score, expected_score,
			res.lives if res != null else -1, int(meta.get("lives", -1)),
			res.bomb_count if res != null else -1, int(meta.get("bombs", -1)),
			",".join(tail),
		])


## 回放推进一帧；返回 false = 文件已放完。
static func advance_frame() -> bool:
	if not _playing:
		return false
	if _frame_index >= _frames.size():
		_playing = false
		return false
	_mask = int(_frames[_frame_index])
	_frame_index += 1
	return true


static func is_playing() -> bool:
	return _playing



## 取出当前帧已到点的离散动作；定格中也可以 call（Player._process）。
## 严格按录制帧号消费：提前消费会让炸弹/RNG 比录制早一帧。
static func poll_events(defer_miss_timeout: bool = false, after_sample: int = -1) -> Array[StringName]:
	var out: Array[StringName] = []
	while _event_index < _events.size():
		var e: Dictionary = _events[_event_index]
		var action := StringName(str(e.get("action", "")))
		if int(e.get("frame", 0)) > _frame_index:
			break
		if after_sample >= 0 and bool(e.get("after_sample", true)) != (after_sample == 1):
			break
		if defer_miss_timeout and (action == &"deathbomb_end_miss" or action == &"memory_release"):
			break
		out.append(action)
		_event_index += 1
	return out


## 取队首指定事件；用于把 deathbomb_end_miss 推迟到物理帧之后（对齐真实 timer）。
static func take_event(action: StringName, after_sample: int = -1) -> bool:
	if _event_index >= _events.size():
		return false
	var e: Dictionary = _events[_event_index]
	if int(e.get("frame", 0)) > _frame_index:
		return false
	if after_sample >= 0 and bool(e.get("after_sample", true)) != (after_sample == 1):
		return false
	if StringName(str(e.get("action", ""))) != action:
		return false
	_event_index += 1
	return true


static func action_pressed(action: StringName) -> bool:
	var idx := ReplayRecorder.ACTIONS.find(action)
	return idx >= 0 and (_mask & (1 << idx)) != 0


static func axis(negative: StringName, positive: StringName) -> float:
	var neg := 1.0 if action_pressed(negative) else 0.0
	var pos := 1.0 if action_pressed(positive) else 0.0
	return pos - neg


static func stop_playback() -> void:
	_playing = false
	RNG.rng_trace_hook = Callable()
	_last_tick_physics_frame = -1
	_frames = PackedByteArray()
	_frame_index = 0
	_mask = 0
	_last_tick_physics_frame = -1
	_spawn_cursor = 0
	_rng_cursor = 0
	_events.clear()
	_event_index = 0
	_path = ""
	_preserve_on_exit = false
	_samples.clear()
	_score_events.clear()
	_trace_diverged = false
	_recorder = null


## 删除一份已存回放；只允许删 user://replays 下的文件。
static func delete_replay(path: String) -> bool:
	if not path.begins_with(DIR + "/"):
		push_warning("ReplaySession.delete_replay: 拒绝删除目录外文件 " + path)
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	return DirAccess.remove_absolute(absolute_path) == OK


## 放弃当前录制（新开一局 / 拆场景且不保存）。
static func cancel_run() -> void:
	if _recorder != null:
		_recorder.stop()
	_recorder = null
	_active = false


## 列出已存回放（新→旧）。坏文件跳过。
static func list_replays() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var file_path := "%s/%s" % [DIR, file]
		var f := FileAccess.open(file_path, FileAccess.READ)
		if f == null:
			continue
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is not Dictionary:
			continue
		var rec := ReplayRecorder.new()
		if not rec.load_dict(parsed):
			continue
		out.append({
			"path": file_path,
			"name": file.get_basename(),
			"duration": rec.duration_frames,
			"metadata": rec.metadata,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.path) > str(b.path))
	return out

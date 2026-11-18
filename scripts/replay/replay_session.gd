## ReplaySession —— 一局录制的跨场景持有者。
##
## 录制从正常路线开局开始，跨 stage reload 持续采样；只在 run 结束
## （通关 Return / Game Over）落盘。同一类也持有回放文件、当前帧与输入掩码，
## GameScene 每物理帧推进一帧；PlayerInput 在回放时读这里的掩码。
class_name ReplaySession
extends RefCounted

const DIR := "user://replays"

static var _recorder: ReplayRecorder
static var _active: bool = false

static var _playing: bool = false
static var _playback_paused: bool = false
static var _frames: PackedByteArray = PackedByteArray()
static var _frame_index: int = 0
static var _mask: int = 0
static var _events: Array[Dictionary] = []
static var _event_index: int = 0
static var _samples: Array[Dictionary] = []
static var _score_events: Array[Dictionary] = []
static var _trace_diverged: bool = false


static func is_recording() -> bool:
	return _active


## 开一局：清空并开始采样。已在录制中（切面 reload）则保持原录制。
static func start_run() -> bool:
	if _active or _playing:
		return false
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
static func capture_score(amount: int, source: StringName) -> void:
	if _active and _recorder != null:
		_recorder.capture_score(amount, source)


## 记录一帧状态采样（位置 / RNG / 分数 / 残机 / 雷）。
static func capture_sample(pos: Vector2, res: PlayerResources, bullets: int = 0, bhash: int = 0,
		items: int = 0, ihash: int = 0, bsnap: Array = [], graze: int = 0) -> void:
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
	})


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
		items: int = 0, ihash: int = 0, bsnap: Array = [], graze: int = 0) -> void:
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
		mismatch.append("rng_state")
	if expected.has("graze") and graze != int(expected.get("graze", 0)):
		mismatch.append("graze")
	if (res.current_score if res != null else 0) != int(expected.get("score", 0)):
		mismatch.append("score[%s]" % _score_events_near(idx))
	if (res.lives if res != null else 0) != int(expected.get("lives", 0)):
		mismatch.append("lives")
	if (res.bomb_count if res != null else 0) != int(expected.get("bombs", 0)):
		mismatch.append("bombs")
	if expected.has("bullets") and bullets != int(expected.get("bullets", 0)):
		mismatch.append("bullets")
	var expected_bhash := int(expected.get("bhash", 0))
	if expected.has("bsnap"):
		# 旧回放的 bhash 可能包含清弹中的死行/未排序；用快照重算。
		expected_bhash = _snapshot_hash(expected.get("bsnap", []))
	if expected.has("bhash") and bhash != expected_bhash:
		mismatch.append("bhash[%s]" % _first_bullet_diff(bsnap, expected.get("bsnap", [])))
	if expected.has("items") and items != int(expected.get("items", 0)):
		mismatch.append("items")
	if expected.has("ihash") and ihash != int(expected.get("ihash", 0)):
		mismatch.append("ihash")
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
	_active = false
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/%s_%d.json" % [DIR, stamp, Time.get_ticks_msec()]
	if not _recorder.save(path):
		return ""
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
	RNG.set_seed(rec.rng_seed)
	_recorder = rec
	_frames = rec.frames
	_frame_index = 0
	_mask = 0
	_events = rec.events.duplicate(true)
	_event_index = 0
	_samples = rec.samples.duplicate(true)
	_score_events = rec.score_events.duplicate(true)
	_trace_diverged = false
	_playing = true
	_playback_paused = false
	return true


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


static func is_playback_paused() -> bool:
	return _playback_paused


## 对话等需要人工节奏的 UI 打开时暂停回放帧推进；关闭后恢复。
static func pause_playback() -> void:
	if _playing:
		_playback_paused = true


static func resume_playback() -> void:
	_playback_paused = false


## 取出当前帧已到点的离散动作；定格中也可以 call（Player._process）。
## 严格按录制帧号消费：提前消费会让炸弹/RNG 比录制早一帧。
static func poll_events(defer_miss_timeout: bool = false) -> Array[StringName]:
	var out: Array[StringName] = []
	while _event_index < _events.size():
		var e: Dictionary = _events[_event_index]
		var action := StringName(str(e.get("action", "")))
		if int(e.get("frame", 0)) > _frame_index:
			break
		if defer_miss_timeout and (action == &"deathbomb_end_miss" or action == &"memory_release"):
			break
		out.append(action)
		_event_index += 1
	return out


## 取队首指定事件；用于把 deathbomb_end_miss 推迟到物理帧之后（对齐真实 timer）。
static func take_event(action: StringName) -> bool:
	if _event_index >= _events.size():
		return false
	var e: Dictionary = _events[_event_index]
	if int(e.get("frame", 0)) > _frame_index:
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
	_playback_paused = false
	_frames = PackedByteArray()
	_frame_index = 0
	_mask = 0
	_events.clear()
	_event_index = 0
	_samples.clear()
	_score_events.clear()
	_trace_diverged = false
	_recorder = null


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

## Replay 的跨场景持有者：录制 / 回放 / 列表 / 删除。
##
## [b]边界[/b][br]
## - 只保存输入 + 命令 + 哈希；不保存游戏状态，不做 force 修正。[br]
## - 回放从录像的起始 stage / 难度 / 角色开始；跨 stage 由 GameScene 重载后继续。[br]
## - 旧 v1 文件不列出、不加载。
class_name ReplaySession
extends RefCounted

const DIR := "user://replays_v2"
## 模拟语义版本：玩法代码/顺序变了就升；不匹配的录像直接拒绝。
const SIM_VERSION := "sim-v10"

static var _replay: Replay
static var _recording: bool = false
static var _playing: bool = false
static var _practice_mode: String = ""
static var _path: String = ""
## 回放：下一个要消费的录像下标 / 当前 tick 已准备的下标（-1 = 已放完）。
static var _next_index: int = 0
static var _current_index: int = -1
## 回放是否已经出现哈希分歧（测试 / 诊断用）。
static var _diverged: bool = false
## start_resources 只抓 / 只应用一次（跨面 reload 不能覆盖）。
static var _start_resources_captured: bool = false
static var _start_resources_applied: bool = false
## 对话推进 / 关闭：帧间事件，归到下一个 tick。
static var _pending_dialogue_advance: bool = false
static var _pending_dialogue_close: bool = false
## 调试：录制时保存人类可读快照，回放时逐 tick 比对。
## 开发期默认开（replay 未完全稳定前）；正式收尾前改回 false。
static var debug_capture: bool = true
static var debug_snapshots: Array[String] = []


static func is_recording() -> bool:
	return _recording


static func is_playing() -> bool:
	return _playing


## 当前回放是否是练习（stage / spell）；普通路线为空串。
static func practice_playback_mode() -> String:
	return _practice_mode


static func is_practice_playback() -> bool:
	return _playing and _practice_mode != ""


static func has_diverged() -> bool:
	return _diverged


## 调试：比较当前 tick 的现场快照与录制快照；首个差异打印后自动关掉，避免刷屏。
static func debug_compare(idx: int, live: String) -> void:
	if not debug_capture or idx < 0 or idx >= debug_snapshots.size():
		return
	var expected := debug_snapshots[idx]
	if expected == live:
		return
	debug_capture = false
	var exp_lines := expected.split("\n")
	var cur_lines := live.split("\n")
	push_warning("Replay 状态分歧 idx=%d" % idx)
	for i in maxi(exp_lines.size(), cur_lines.size()):
		var a := exp_lines[i] if i < exp_lines.size() else "<missing>"
		var b := cur_lines[i] if i < cur_lines.size() else "<missing>"
		if a != b:
			push_warning("  exp: " + a)
			push_warning("  cur: " + b)
			break


static func current_path() -> String:
	return _path


static func replay_tick_count() -> int:
	if _replay != null:
		return _replay.tick_count()
	return 0


## 当前相对 tick（录制 = 已录条数；回放 = 正在校验的录像下标）。
static func current_tick() -> int:
	if _playing:
		return _current_index
	if _recording and _replay != null:
		return _replay.tick_count()
	return 0


## 开一局录制；meta 至少带 difficulty / character / route_id / start_stage_id / start_stage_no。
static func start_recording(meta: Dictionary) -> bool:
	if _recording or _playing:
		return false
	_replay = Replay.new()
	var snap := RNG.snapshot_state()
	_replay.begin(Engine.physics_ticks_per_second, int(snap.get("seed", 0)), SIM_VERSION)
	_replay.content_hash = ContentFingerprint.compute()
	_replay.rng_state = int(snap.get("state", 0))
	_replay.metadata = meta.duplicate(true)
	_practice_mode = ""
	if not _replay.metadata.has("start_stage_id"):
		_replay.metadata["start_stage_id"] = SaveData.current_stage_id
	if not _replay.metadata.has("start_stage_no"):
		_replay.metadata["start_stage_no"] = SaveData.current_route_index + 1
	_replay.start_resources = {}
	_start_resources_captured = false
	_start_resources_applied = false
	_pending_dialogue_advance = false
	_pending_dialogue_close = false
	debug_snapshots.clear()
	_recording = true
	_path = ""
	return true


## 录制起点自机资源（在自机 setup / 跨面继承完成之后调用）。
static func capture_start_resources(res: PlayerResources) -> void:
	if not _recording or _replay == null or res == null or _start_resources_captured:
		return
	_start_resources_captured = true
	var snap := {}
	for key in SaveData.RUN_STATE_KEYS:
		snap[String(key)] = res.get(key)
	_replay.start_resources = snap


## 回放起点自机资源（在自机 setup 之后、关卡 tick 之前调用）。
static func apply_start_resources(res: PlayerResources) -> void:
	if not _playing or _replay == null or res == null or _replay.start_resources.is_empty() \
			or _start_resources_applied:
		return
	_start_resources_applied = true
	for key in SaveData.RUN_STATE_KEYS:
		var k := String(key)
		if not _replay.start_resources.has(k):
			continue
		var v = _replay.start_resources[k]
		if key == &"memory_value":
			res.set(key, float(v))
		else:
			res.set(key, int(v))


## 每 tick 录一条（GameScene 的 SimClock observer 调用）。
static func record_tick(mask: int, command_flags: int, state_hash: int,
		fields: Dictionary = {}) -> void:
	if _recording and _replay != null:
		var flags := command_flags
		if _pending_dialogue_advance:
			flags |= Replay.COMMAND_DIALOGUE_ADVANCE
		if _pending_dialogue_close:
			flags |= Replay.COMMAND_DIALOGUE_CLOSE
		_pending_dialogue_advance = false
		_pending_dialogue_close = false
		_replay.capture_tick(mask, flags, state_hash, fields)


## 录制：本帧玩家推进了一句对话；归到下一个 tick。
static func record_dialogue_advance() -> void:
	if _recording:
		_pending_dialogue_advance = true


## 录制：本帧玩家关闭了对话。
static func record_dialogue_close() -> void:
	if _recording:
		_pending_dialogue_close = true


## 结束录制并落盘；返回路径（失败 / 没在录 = 空串）。
## target_path 为空 = 旧行为（时间戳文件名）；保存页传入槽位路径。
## display_name 非空 = 写入 metadata.name。
static func finish_recording(meta: Dictionary = {}, target_path: String = "", display_name: String = "") -> String:
	if not _recording or _replay == null:
		return ""
	_replay.metadata.merge(meta.duplicate(true), true)
	if display_name.strip_edges() != "":
		_replay.metadata["name"] = display_name.strip_edges()
	_replay.metadata["recorded_at"] = Time.get_datetime_string_from_system()
	_replay.sim_version = SIM_VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var path := target_path
	if path == "":
		var stamp := Time.get_datetime_string_from_system().replace(":", "-")
		path = "%s/%s_%d.json" % [DIR, stamp, Time.get_ticks_msec()]
	var ok := _replay.save(path)
	_recording = false
	_replay = null
	return path if ok else ""


## 放弃当前录制（不落盘）。
static func cancel_recording() -> void:
	_recording = false
	_replay = null


## 从文件进入回放：装载难度 / 角色 / 路线 / 起始 stage / seed。
static func start_playback(path: String) -> bool:
	var rec := Replay.new()
	if not rec.load_file(path):
		push_warning("ReplaySession: 无法加载回放 " + path)
		return false
	if rec.sim_version != "" and rec.sim_version != SIM_VERSION:
		push_warning("ReplaySession: 录像兼容版本 %s 与当前 %s 不匹配" % [
			rec.sim_version, SIM_VERSION,
		])
		return false
	if rec.content_hash != "" and rec.content_hash != ContentFingerprint.compute():
		push_warning("ReplaySession: 内容指纹不匹配（录像 %s）" % rec.content_hash)
		return false
	var meta := rec.metadata
	var diff := int(meta.get("difficulty", 1))
	if not Difficulty.is_valid(diff):
		diff = 1
	SaveData.reset_session()
	SaveData.selected_difficulty = diff
	SaveData.selected_character = int(meta.get("character", 0))
	SaveData.is_restarting = false
	SaveData.is_route_transition = false
	_practice_mode = str(meta.get("practice_mode", ""))
	var practice_stage := int(meta.get("practice_stage_id", 0))
	if _practice_mode == "spell":
		var phase_index := int(meta.get("practice_phase_index", 0))
		var phase := BossCatalog.phase_at(practice_stage, phase_index, diff)
		var boss := BossCatalog.boss_of_phase(practice_stage, phase_index)
		if phase == null or boss == null:
			push_warning("ReplaySession: 符卡练习录像缺少阶段配置")
			_practice_mode = ""
			return false
		var boss_label := boss.boss_name if boss.boss_name != "" else phase.name
		PracticeSession.start(phase, boss.visual, boss_label, practice_stage, phase_index,
			boss.spell_background, BossCatalog.practice_bgm_key(boss, practice_stage))
	elif _practice_mode == "stage":
		SaveData.is_stage_practice = true
		SaveData.current_stage_id = practice_stage if practice_stage > 0 else int(meta.get("start_stage_id", 1))
		SaveData.current_route_index = 0
	else:
		if not SaveData.begin_route_for_difficulty(diff):
			return false
		var start_stage := int(meta.get("start_stage_id", 1))
		var route := SaveData.current_route()
		if route != null:
			for i in route.stages.size():
				if route.stages[i] != null and route.stages[i].stage_id == start_stage:
					SaveData.current_route_index = i
					SaveData.current_stage_id = start_stage
					break
	RNG.set_seed(rec.rng_seed)
	if rec.rng_state != 0:
		RNG.restore_state({"seed": rec.rng_seed, "state": rec.rng_state})
	_replay = rec
	_playing = true
	_path = path
	_next_index = 0
	_current_index = -1
	_diverged = false
	_start_resources_applied = false
	_pending_dialogue_advance = false
	_pending_dialogue_close = false
	return true


## 回放：在 SimClock latch 前注入本 tick 的 mask / 命令。
static func prepare_tick(_tick: int) -> void:
	if not _playing or _replay == null:
		return
	if _next_index >= _replay.tick_count():
		_current_index = -1
		PlayerInput.set_override_mask(0)
		return
	_current_index = _next_index
	_next_index += 1
	PlayerInput.set_override_mask(_replay.mask_at(_current_index))
	var flags := _replay.command_at(_current_index)
	if flags & Replay.COMMAND_BOMB:
		PlayerInput.queue_command(&"bomb")
	if flags & Replay.COMMAND_MEMORY:
		PlayerInput.queue_command(&"memory_release")
	if flags & Replay.COMMAND_DIALOGUE_ADVANCE:
		if DialogueBox.active != null:
			DialogueBox.active.apply_replay_advance()
	if flags & Replay.COMMAND_DIALOGUE_CLOSE:
		if DialogueBox.active != null:
			DialogueBox.active.apply_replay_close()


## 回放：在 SimClock observer 里比对本 tick 的哈希。
## 返回 false = 已放完 或 出现分歧。
static func observe_tick(tick: int, state_hash: int) -> bool:
	if not _playing or _replay == null:
		return true
	if _current_index < 0 or _current_index >= _replay.tick_count():
		return false
	if not _replay.hashes.is_empty() and _replay.hash_at(_current_index) != state_hash:
		_diverged = true
		push_warning("Replay 分歧 tick=%d idx=%d cur=%d exp=%d" % [
			tick, _current_index, state_hash, _replay.hash_at(_current_index),
		])
		return false
	return true


## 分歧时报告首个不同的分项字段（需要录像有 field_hashes；旧文件会提示无数据）。
static func report_fields(idx: int, live: Dictionary) -> void:
	if _replay == null or idx < 0 or idx >= _replay.field_hashes.size():
		return
	var expected: Dictionary = _replay.field_hashes[idx]
	if expected.is_empty():
		push_warning("Replay 分歧 idx=%d：这份录像没有分项哈希（旧格式），无法定位字段" % idx)
		return
	for key in live:
		if not expected.has(key):
			continue
		if int(expected[key]) != int(live[key]):
			push_warning("Replay 分歧字段 idx=%d field=%s exp=%d cur=%d" % [
				idx, key, int(expected[key]), int(live[key]),
			])
			return
	push_warning("Replay 分歧 idx=%d：分项哈希全部相同（总 hash 碰撞或未覆盖状态）" % idx)


## 停止回放并清理注入。
static func stop_playback() -> void:
	_playing = false
	_practice_mode = ""
	_replay = null
	_path = ""
	_next_index = 0
	_current_index = -1
	PlayerInput.clear_override()
	PlayerInput.clear_latch()


## 给单条回放改名（只改 metadata.name，不动模拟数据 / 内容指纹）。
static func rename_replay(path: String, display_name: String) -> bool:
	var rec := Replay.new()
	if not rec.load_file(path):
		return false
	rec.metadata["name"] = display_name.strip_edges()
	return rec.save(path)


## 已存回放列表（新 → 旧）；坏文件跳过。
static func list_replays() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	var current_content := ContentFingerprint.compute()
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var file_path := "%s/%s" % [DIR, file]
		var rec := Replay.new()
		if not rec.load_file(file_path):
			continue
		if rec.sim_version != "" and rec.sim_version != SIM_VERSION:
			continue  # 不兼容版本不显示，避免玩家点了才失败
		if rec.content_hash != "" and rec.content_hash != current_content:
			continue  # 内容变了，旧录像不显示
		out.append({
			"path": file_path,
			"name": file.get_basename(),
			"duration": rec.tick_count(),
			"metadata": rec.metadata,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) > str(b["name"]))
	return out


## 保存页专用：固定 25 槽位。已有 slot 的保持原位；没有 slot 的旧文件按当前顺序
## 首次分配一个空槽并写回 metadata.slot，之后不再随删除/排序移位。
static func slot_entries() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	slots.resize(25)
	var entries := list_replays()
	var unassigned: Array[Dictionary] = []
	for entry in entries:
		var meta: Dictionary = entry.get("metadata", {})
		var slot := int(meta.get("slot", 0))
		if slot >= 1 and slot <= 25 and slots[slot - 1].is_empty():
			slots[slot - 1] = entry
		else:
			unassigned.append(entry)
	var next_free := 0
	for entry in unassigned:
		while next_free < 25 and not slots[next_free].is_empty():
			next_free += 1
		if next_free >= 25:
			break
		var slot := next_free + 1
		var rec := Replay.new()
		if rec.load_file(str(entry.get("path", ""))):
			rec.metadata["slot"] = slot
			rec.save(str(entry.get("path", "")))
			entry["metadata"] = rec.metadata
		slots[next_free] = entry
		next_free += 1
	return slots


## 删除一份 v2 回放；只允许删 DIR 下文件。
static func delete_replay(path: String) -> bool:
	if not path.begins_with(DIR + "/"):
		push_warning("ReplaySession.delete_replay: 拒绝删除目录外文件 " + path)
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

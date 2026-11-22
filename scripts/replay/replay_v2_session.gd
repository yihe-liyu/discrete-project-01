## ReplayV2 的跨场景持有者：录制 / 回放 / 列表 / 删除。
##
## [b]边界[/b][br]
## - 只保存输入 + 命令 + 哈希；不保存游戏状态，不做 force 修正。[br]
## - 回放从录像的起始 stage / 难度 / 角色开始；跨 stage 由 GameScene 重载后继续。[br]
## - 旧 v1 文件不列出、不加载。
class_name ReplayV2Session
extends RefCounted

const DIR := "user://replays_v2"
## 模拟语义版本：玩法代码/顺序变了就升；不匹配的录像直接拒绝。
const SIM_VERSION := "sim-v2"

static var _rec: ReplayV2
static var _play: ReplayV2
static var _recording: bool = false
static var _playing: bool = false
static var _path: String = ""
## 回放：下一个要消费的录像下标 / 当前 tick 已准备的下标（-1 = 已放完）。
static var _next_index: int = 0
static var _current_index: int = -1
## 回放是否已经出现哈希分歧（测试 / 诊断用）。
static var _diverged: bool = false


static func is_recording() -> bool:
	return _recording


static func is_playing() -> bool:
	return _playing


static func has_diverged() -> bool:
	return _diverged


static func current_path() -> String:
	return _path


static func replay_tick_count() -> int:
	if _play != null:
		return _play.tick_count()
	if _rec != null:
		return _rec.tick_count()
	return 0


## 当前相对 tick（录制 = 已录条数；回放 = 正在校验的录像下标）。
static func current_tick() -> int:
	if _playing:
		return _current_index
	if _recording and _rec != null:
		return _rec.tick_count()
	return 0


## 开一局录制；meta 至少带 difficulty / character / route_id / start_stage_id / start_stage_no。
static func start_recording(meta: Dictionary) -> bool:
	if _recording or _playing:
		return false
	_rec = ReplayV2.new()
	var snap := RNG.snapshot_state()
	_rec.begin(Engine.physics_ticks_per_second, int(snap.get("seed", 0)), SIM_VERSION)
	_rec.rng_state = int(snap.get("state", 0))
	_rec.metadata = meta.duplicate(true)
	_recording = true
	_path = ""
	return true


## 每 tick 录一条（GameScene 的 SimClock observer 调用）。
static func record_tick(mask: int, command_flags: int, state_hash: int) -> void:
	if _recording and _rec != null:
		_rec.capture_tick(mask, command_flags, state_hash)


## 结束录制并落盘；返回路径（失败 / 没在录 = 空串）。
static func finish_recording(meta: Dictionary = {}) -> String:
	if not _recording or _rec == null:
		return ""
	_rec.metadata.merge(meta.duplicate(true), true)
	_rec.metadata["recorded_at"] = Time.get_datetime_string_from_system()
	_rec.sim_version = "sim-v2"
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/%s_%d.json" % [DIR, stamp, Time.get_ticks_msec()]
	var ok := _rec.save(path)
	_recording = false
	_rec = null
	return path if ok else ""


## 放弃当前录制（不落盘）。
static func cancel_recording() -> void:
	_recording = false
	_rec = null


## 从文件进入回放：装载难度 / 角色 / 路线 / 起始 stage / seed。
static func start_playback(path: String) -> bool:
	var rec := ReplayV2.new()
	if not rec.load_file(path):
		push_warning("ReplayV2Session: 无法加载回放 " + path)
		return false
	if rec.sim_version != "" and rec.sim_version != SIM_VERSION:
		push_warning("ReplayV2Session: 录像 sim_version=%s 与当前 %s 不匹配" % [
			rec.sim_version, SIM_VERSION,
		])
		return false
	var meta := rec.metadata
	var diff := int(meta.get("difficulty", 1))
	if not Difficulty.is_valid(diff):
		diff = 1
	SaveData.reset_session()
	SaveData.selected_difficulty = diff
	SaveData.selected_character = int(meta.get("character", 0))
	SaveData.is_stage_practice = false
	SaveData.is_restarting = false
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
	_play = rec
	_playing = true
	_path = path
	_next_index = 0
	_current_index = -1
	_diverged = false
	return true


## 回放：在 SimClock latch 前注入本 tick 的 mask / 命令。
static func prepare_tick(_tick: int) -> void:
	if not _playing or _play == null:
		return
	if _next_index >= _play.tick_count():
		_current_index = -1
		PlayerInput.set_override_mask(0)
		return
	_current_index = _next_index
	_next_index += 1
	PlayerInput.set_override_mask(_play.mask_at(_current_index))
	var flags := _play.command_at(_current_index)
	if flags & ReplayV2.COMMAND_BOMB:
		PlayerInput.queue_command(&"bomb")
	if flags & ReplayV2.COMMAND_MEMORY:
		PlayerInput.queue_command(&"memory_release")


## 回放：在 SimClock observer 里比对本 tick 的哈希。
## 返回 false = 已放完 或 出现分歧。
static func observe_tick(tick: int, state_hash: int) -> bool:
	if not _playing or _play == null:
		return true
	if _current_index < 0 or _current_index >= _play.tick_count():
		return false
	if not _play.hashes.is_empty() and _play.hash_at(_current_index) != state_hash:
		_diverged = true
		push_warning("ReplayV2 分歧 tick=%d idx=%d cur=%d exp=%d" % [
			tick, _current_index, state_hash, _play.hash_at(_current_index),
		])
		return false
	return true


## 停止回放并清理注入。
static func stop_playback() -> void:
	_playing = false
	_play = null
	_path = ""
	_next_index = 0
	_current_index = -1
	PlayerInput.clear_override()
	PlayerInput.clear_latch()


## 已存回放列表（新 → 旧）；坏文件跳过。
static func list_replays() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var file_path := "%s/%s" % [DIR, file]
		var rec := ReplayV2.new()
		if not rec.load_file(file_path):
			continue
		out.append({
			"path": file_path,
			"name": file.get_basename(),
			"duration": rec.tick_count(),
			"metadata": rec.metadata,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]) > str(b["name"]))
	return out


## 删除一份 v2 回放；只允许删 DIR 下文件。
static func delete_replay(path: String) -> bool:
	if not path.begins_with(DIR + "/"):
		push_warning("ReplayV2Session.delete_replay: 拒绝删除目录外文件 " + path)
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK

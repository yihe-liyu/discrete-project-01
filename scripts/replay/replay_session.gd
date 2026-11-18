## ReplaySession —— 一局录制的跨场景持有者。
##
## 录制从正常路线开局开始，跨 stage reload 持续采样；只在 run 结束
## （通关 Return / Game Over）落盘。回放播放不在本类：这里先解决“录得下来”。
class_name ReplaySession
extends RefCounted

const DIR := "user://replays"

static var _recorder: ReplayRecorder
static var _active: bool = false


static func is_recording() -> bool:
	return _active


## 开一局：清空并开始采样。已在录制中（切面 reload）则保持原录制。
static func start_run() -> bool:
	if _active:
		return false
	_recorder = ReplayRecorder.new()
	_recorder.start()
	_active = true
	return true


## GameScene 每物理帧调用一次。
static func capture_frame() -> void:
	if _active and _recorder != null:
		_recorder.capture()


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

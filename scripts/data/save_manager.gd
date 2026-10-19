class_name SaveManager
extends RefCounted
## 高分 / 设置存档管理（从 SaveData 拆出，职责单一）。
##
## 写盘策略：**临时文件 → 轮换备份 → 提交**。
##   - 直接写正式档时，写到一半崩溃会同时毁掉设置和高分；
##   - 先用 `save_data.cfg.tmp` 写完，再把旧档轮换成 `.bak`，最后 rename 成正式档；
##   - 主档损坏时自动回退到 `.bak`，并把坏档隔离成 `.corrupt`（不会再被下一次保存覆盖）。
##
## 格式：`meta/version` 当前为 [constant FORMAT_VERSION]；读档时对设置/高分做类型与范围校验，
## 坏值回退到默认值（不再让手改/旧版本档把运行时搞崩）。

const SAVE_PATH: String = "user://save_data.cfg"
const META_SECTION := "meta"
const SETTINGS_SECTION := "settings"
const HIGH_SCORES_SECTION := "high_scores"
const FORMAT_VERSION := 1

## 设置默认值也是**校验白名单**：未知 key 原样保留，已知 key 按这里的类型收敛。
const SETTING_DEFAULTS := {
	"volume_master": 1.0,
	"volume_bgm": 1.0,
	"volume_sfx": 0.7,
	"fullscreen": false,
	"max_fps": 0,
}
const MAX_FPS_CHOICES: Array[int] = [0, 60, 120, 144]

## 存档路径（默认 user://save_data.cfg；测试可覆盖为独立路径）。
var save_path: String = SAVE_PATH
var high_scores: Dictionary = {}
var settings: Dictionary = {}
var _config: ConfigFile = ConfigFile.new()
var _last_save_error: Error = OK


func load() -> void:
	# 重载必须从干净状态开始：否则上一次的旧 key / 旧高分会在新档上"叠"回来。
	high_scores.clear()
	settings.clear()
	_config = ConfigFile.new()

	var main_err := _try_load(save_path)
	# ConfigFile.load 对"非配置文件"也可能返回 OK（只是没有任何段）——按坏档处理，
	# 否则会拿空档覆盖掉可用的 .bak（实测：写入 "not a config file" 后 load() == OK）。
	if main_err == OK and not _has_known_sections():
		main_err = ERR_FILE_CORRUPT
	if main_err == OK:
		_read_sections()
		_sanitize()
		return

	_config = ConfigFile.new()
	var backup_err := _try_load(_backup_path())
	if backup_err == OK:
		push_warning("SaveManager: 主存档不可用（%s），已从备份恢复" % error_string(main_err))
		_quarantine_broken_main()
		_read_sections()
		_sanitize()
		return

	if main_err != ERR_FILE_NOT_FOUND or backup_err != ERR_FILE_NOT_FOUND:
		push_warning("SaveManager: 主存档与备份均不可用（%s / %s），按空档启动"
			% [error_string(main_err), error_string(backup_err)])


## 保存全部设置（以及当前高分）到正式档。返回是否成功。
func save_settings() -> bool:
	return _save()


func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)


func set_setting(key: String, value: Variant) -> bool:
	settings[key] = value
	return _save()


func save_high_score(stage_id: int, score: int) -> bool:
	var prev: int = get_high_score(stage_id)
	if score <= prev:
		return true
	high_scores[stage_id] = score
	return _save()


func get_high_score(stage_id: int) -> int:
	return high_scores.get(stage_id, 0)


## 最近一次写盘错误（OK = 成功）。诊断用；正常流程看 [method save_settings] 的返回值即可。
func get_last_save_error() -> Error:
	return _last_save_error


## 清空玩家数据：高分归零（**设置保留**）。
func clear_player_data() -> bool:
	high_scores.clear()
	# 全新档没有任何东西可清：别为了"清空"凭空创建一份存档。
	if not FileAccess.file_exists(save_path) and settings.is_empty():
		return true
	return _save()


# ═══ 读写 ═══

func _try_load(path: String) -> Error:
	var config := ConfigFile.new()
	var err := config.load(path)
	if err == OK:
		_config = config
	return err


func _has_known_sections() -> bool:
	return _config.has_section(META_SECTION) \
		or _config.has_section(SETTINGS_SECTION) \
		or _config.has_section(HIGH_SCORES_SECTION)


func _read_sections() -> void:
	if _config.has_section(HIGH_SCORES_SECTION):
		for key in _config.get_section_keys(HIGH_SCORES_SECTION):
			high_scores[key] = _config.get_value(HIGH_SCORES_SECTION, key)
	if _config.has_section(SETTINGS_SECTION):
		for key in _config.get_section_keys(SETTINGS_SECTION):
			settings[key] = _config.get_value(SETTINGS_SECTION, key)


## 已知设置按类型/范围收敛；高分只保留「非负整数 id + 非负整数分」。
func _sanitize() -> void:
	for key in settings.keys():
		var value: Variant = settings[key]
		match String(key):
			"volume_master", "volume_bgm", "volume_sfx":
				var default_value: float = float(SETTING_DEFAULTS[key])
				settings[key] = clampf(float(value), 0.0, 1.0) \
					if value is float or value is int else default_value
			"fullscreen":
				settings[key] = bool(value) if value is bool or value is int else false
			"max_fps":
				var fps: int = int(value) if value is int or value is float else 0
				settings[key] = fps if MAX_FPS_CHOICES.has(fps) else 0

	var clean_scores := {}
	for key in high_scores.keys():
		var key_text := String(key)
		var value: Variant = high_scores[key]
		if not key_text.is_valid_int() or not (value is int or value is float):
			continue
		var stage_id := int(key_text)
		var score := int(value)
		if stage_id >= 0 and score >= 0:
			clean_scores[stage_id] = score
	high_scores.clear()
	for stage_id in clean_scores:
		high_scores[stage_id] = clean_scores[stage_id]

	var raw_version: Variant = _config.get_value(META_SECTION, "version", 0)
	var version: int = int(raw_version) if raw_version is int or raw_version is float else 0
	if version > FORMAT_VERSION:
		push_warning("SaveManager: 存档版本 %d 高于当前 %d（按当前版本只读兼容，保存会降级）"
			% [version, FORMAT_VERSION])
	# v0（无 meta 段）→ v1：结构未变，保存时补写版本号即可。
	_config.set_value(META_SECTION, "version", FORMAT_VERSION)


func _sync_config() -> void:
	_config.set_value(META_SECTION, "version", FORMAT_VERSION)
	if _config.has_section(SETTINGS_SECTION):
		_config.erase_section(SETTINGS_SECTION)
	for key in settings:
		_config.set_value(SETTINGS_SECTION, String(key), settings[key])
	if _config.has_section(HIGH_SCORES_SECTION):
		_config.erase_section(HIGH_SCORES_SECTION)
	for stage_id in high_scores:
		var value: Variant = high_scores[stage_id]
		if value is int or value is float:
			_config.set_value(HIGH_SCORES_SECTION, str(stage_id), int(value))


## 原子提交：tmp 写成功后才轮换旧档；任何一步失败都保留原正式档。
func _save() -> bool:
	_last_save_error = OK
	_sync_config()

	var temp_path := _temp_path()
	var err := _config.save(temp_path)
	if err != OK:
		_last_save_error = err
		push_warning("SaveManager: 写临时存档失败（%s）：%s" % [error_string(err), temp_path])
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
		return false

	var abs_temp := ProjectSettings.globalize_path(temp_path)
	var abs_main := ProjectSettings.globalize_path(save_path)
	var abs_backup := ProjectSettings.globalize_path(_backup_path())

	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(_backup_path()):
			var remove_err := DirAccess.remove_absolute(abs_backup)
			if remove_err != OK:
				_last_save_error = remove_err
				push_warning("SaveManager: 清理旧备份失败（%s），保留原档不覆盖" % error_string(remove_err))
				DirAccess.remove_absolute(abs_temp)
				return false
		var backup_err := DirAccess.rename_absolute(abs_main, abs_backup)
		if backup_err != OK:
			_last_save_error = backup_err
			push_warning("SaveManager: 轮换备份失败（%s），保留原档不覆盖" % error_string(backup_err))
			DirAccess.remove_absolute(abs_temp)
			return false

	var commit_err := DirAccess.rename_absolute(abs_temp, abs_main)
	if commit_err != OK:
		_last_save_error = commit_err
		push_warning("SaveManager: 提交存档失败（%s）" % error_string(commit_err))
		return false
	return true


## 主档已损坏且备份已接管：把坏档挪走，避免下一次保存把它当成"旧档"轮换、覆盖掉好备份。
func _quarantine_broken_main() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var corrupt_path := save_path + ".corrupt"
	if FileAccess.file_exists(corrupt_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	var err := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(save_path),
		ProjectSettings.globalize_path(corrupt_path))
	if err != OK:
		push_warning("SaveManager: 隔离损坏主档失败（%s）" % error_string(err))


func _backup_path() -> String:
	return save_path + ".bak"


func _temp_path() -> String:
	return save_path + ".tmp"

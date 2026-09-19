class_name SaveManager
extends RefCounted
## 高分存档管理（从 SaveData 拆出，职责单一）

const SAVE_PATH: String = "user://save_data.cfg"
const SETTINGS_SECTION := "settings"

var high_scores: Dictionary = {}
var settings: Dictionary = {}
var _config: ConfigFile


func load() -> void:
	_config = ConfigFile.new()
	if _config.load(SAVE_PATH) != OK:
		return
	if _config.has_section("high_scores"):
		for key in _config.get_section_keys("high_scores"):
			high_scores[int(key)] = _config.get_value("high_scores", key)
	if _config.has_section(SETTINGS_SECTION):
		for key in _config.get_section_keys(SETTINGS_SECTION):
			settings[key] = _config.get_value(SETTINGS_SECTION, key)


## 保存全部设置到 [settings] 段
func save_settings() -> void:
	for key in settings:
		_config.set_value(SETTINGS_SECTION, key, settings[key])
	_config.save(SAVE_PATH)


func get_setting(key: String, default: Variant = null) -> Variant:
	return settings.get(key, default)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()


func save_high_score(stage_id: int, score: int):
	var prev: int = get_high_score(stage_id)
	if score <= prev:
		return
	high_scores[stage_id] = score
	_config.set_value("high_scores", str(stage_id), score)
	_config.save(SAVE_PATH)


func get_high_score(stage_id: int) -> int:
	return high_scores.get(stage_id, 0)


## 清空玩家数据：高分归零（**设置保留**）。
func clear_player_data() -> void:
	high_scores.clear()
	if _config:
		_config.erase_section("high_scores")
		_config.save(SAVE_PATH)

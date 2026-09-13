## 存档 + 菜单/练习状态（从旧的全局状态瘦身而来，纯 `static`，不再是 autoload）。
## 只保留「持久化 / 跨场景选择 / 练习配置 / 符卡簿 / 高分」；
## 单局资源归 `Player.resources`（经 `EntityRegistry`），运行时实体归 `EntityRegistry`，
## 启动装配（主题 / 存档 / 设置 / 关卡注册表）经 `boot()` 由 `GameManager` 调一次。
class_name SaveData
extends RefCounted

const REGISTRY_PATH := "res://data/registry/stage_registry.tres"

# ═══ 全局选择（持久化，不随关卡重置）═══

## 0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra
static var selected_difficulty: int = 1
## 0=Reimu 1=Marisa
static var selected_character: int = 0
## 当前打到第几面
static var current_stage_id: int = 1

# ═══ 关卡数据 ═══

static var stage_registry: StageRegistry

# ═══ 符卡簿 / 存档 ═══

static var spell_book: SpellRecordBook
static var spell_book_mgr := SpellBookManager.new()
static var save_mgr := SaveManager.new()

# ═══ 练习模式 ═══

static var is_practice_mode: bool = false
## 关卡练习模式（完整一面，不打下一关）
static var is_stage_practice: bool = false
static var practice_phase: PhaseData
static var practice_boss_scene: PackedScene
static var practice_name: String
static var practice_stage_id: int = 1
static var practice_phase_index: int = 0
static var practice_background: PackedScene
static var restarting: bool = false


# ═══ 启动装配 ═══

## 主题 / 存档 / 设置 / 关卡注册表——由壳入口（GameManager）调一次
static func boot() -> void:
	apply_ui_theme()
	spell_book_mgr.load()
	spell_book = spell_book_mgr.spell_book
	save_mgr.load()
	apply_settings()
	if ResourceLoader.exists(REGISTRY_PATH):
		stage_registry = ResourceLoader.load(REGISTRY_PATH)


## 把 themes/ui_theme.tres 的样式拷进 ThemeDB 默认主题（全局 Control 生效）
static func apply_ui_theme() -> void:
	var ui: Theme = load("res://themes/ui_theme.tres")
	if not ui:
		return
	var def: Theme = ThemeDB.get_default_theme()
	for t in ui.get_type_list():
		for n in ui.get_constant_list(t):
			def.set_constant(n, t, ui.get_constant(n, t))
		for n in ui.get_color_list(t):
			def.set_color(n, t, ui.get_color(n, t))
		for n in ui.get_stylebox_list(t):
			def.set_stylebox(n, t, ui.get_stylebox(n, t))
		for n in ui.get_font_list(t):
			def.set_font(n, t, ui.get_font(n, t))
		for n in ui.get_font_size_list(t):
			def.set_font_size(n, t, ui.get_font_size(n, t))
		for n in ui.get_icon_list(t):
			def.set_icon(n, t, ui.get_icon(n, t))


## 应用存档设置（音量 / 全屏 / 帧率）
static func apply_settings() -> void:
	var s: Dictionary = save_mgr.settings
	if s.has("volume_bgm"):
		AudioManager.bgm_volume = float(s["volume_bgm"])
	if s.has("volume_sfx"):
		AudioManager.sfx_volume = float(s["volume_sfx"])
	if s.has("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if s["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if s.has("max_fps"):
		var mf: int = int(s["max_fps"])
		# 0 = 自动：跟显示器刷新率；读不到则无上限(0)
		if mf == 0:
			var rate := DisplayServer.screen_get_refresh_rate(0)
			Engine.max_fps = int(rate) if rate > 0.0 else 0
		else:
			Engine.max_fps = mf


static func load_save_data() -> void:
	save_mgr.load()
	apply_settings()


## 高分表（委托 SaveManager）
static var high_scores: Dictionary:
	get: return save_mgr.high_scores


static func save_high_score(stage_id: int, score: int) -> void:
	save_mgr.save_high_score(stage_id, score)


static func get_high_score(stage_id: int) -> int:
	return save_mgr.get_high_score(stage_id)


# ═══ 关卡生命周期 ═══

## 重置一局：清练习标志 + 自机资源（资源真源在 Player；注册表由组合根显式传入，去全局）
static func reset_all(entity_registry: EntityRegistry) -> void:
	_clear_practice()
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if entity_registry != null and res == null:
		push_warning("SaveData.reset_all: 注册表存在但取不到自机资源（Player 未绑定？）——重置空跑")
	if res != null:
		res.reset_all()


static func reset_practice(entity_registry: EntityRegistry) -> void:
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if entity_registry != null and res == null:
		push_warning("SaveData.reset_practice: 注册表存在但取不到自机资源（Player 未绑定？）——重置空跑")
	if res != null:
		res.reset_practice()


# ═══ 练习模式 ═══

static func start_practice(phase: PhaseData, boss_scene: PackedScene, p_name: String, stage_id: int, phase_index: int = 0) -> void:
	reset_session()
	is_practice_mode = true
	practice_phase = phase
	practice_boss_scene = boss_scene
	practice_name = p_name
	practice_stage_id = stage_id
	practice_phase_index = phase_index
	practice_background = find_stage_background(stage_id)


static func end_practice() -> void:
	if restarting:
		return
	_clear_practice()


## 清空练习载荷（阶段 / Boss 场景 / 名字 / 关卡 / 背景）——练习结束后不得留残余状态，
## 否则下一局普通流程会看到残留 `practice_phase`（game_scene 告警「已设置但 is_practice_mode=false」）。
static func _clear_practice() -> void:
	is_practice_mode = false
	practice_phase = null
	practice_boss_scene = null
	practice_name = ""
	practice_stage_id = 1
	practice_phase_index = 0
	practice_background = null


## 开一局前统一清空 per-run 会话状态（**唯一复位入口**）：练习载荷 + 关卡进度 + 重开 / 关卡练习标志。
## 新游戏（`main_menu._start_game_flow`）与进练习（`start_practice`）都必须经过它。
static func reset_session() -> void:
	_clear_practice()
	current_stage_id = 1
	restarting = false
	is_stage_practice = false


static func find_stage_background(stage_id: int) -> PackedScene:
	var stage_data := find_stage_data(stage_id)
	return stage_data.background_scene if stage_data else null


# ═══ 关卡数据查找 ═══

static func find_stage_data(stage_id: int) -> StageData:
	if stage_registry:
		return stage_registry.find(stage_id)
	return scan_stage_dir(stage_id)


static func scan_stage_dir(stage_id: int) -> StageData:
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var stage_data: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if stage_data and stage_data.stage_id == stage_id:
				return stage_data
		file_name = dir.get_next()
	return null


## 获取所有 StageData（供练习菜单等界面遍历用）
static func get_all_stages() -> Array[StageData]:
	if stage_registry and not stage_registry.stages.is_empty():
		return stage_registry.stages
	var result: Array[StageData] = []
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var stage_data: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if stage_data:
				result.append(stage_data)
		file_name = dir.get_next()
	return result


# ═══ 符卡记录（委托 SpellBookManager）═══

static func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book_mgr.unlock_spell(pid)


static func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book_mgr.record_spell(pid, captured, score, elapsed)


static func record_capture(pid: PhaseIdentity, score: int, elapsed: float) -> void:
	spell_book_mgr.record_capture(pid, score, elapsed)


static func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book_mgr.record_practice(pid, captured)


static func record_practice_capture(pid: PhaseIdentity) -> void:
	spell_book_mgr.record_practice_capture(pid)

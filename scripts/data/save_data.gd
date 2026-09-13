## 存档 + 全局选择 + 会话编排（纯 `static`，不再是 autoload）。
## 职责：持久化（符卡簿 / 存档 / 高分）、跨场景选择（难度 / 角色 / 关卡进度）、会话复位。
## 已拆出：关卡目录 → `StageCatalog`；练习载荷 → `PracticeSession`；主题 → `UiTheme`。
## 启动装配经 `boot()` 由 `GameManager` 调一次。
class_name SaveData
extends RefCounted

# ═══ 全局选择（持久化，不随关卡重置）═══

## 0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra
static var selected_difficulty: int = 1
## 0=Reimu 1=Marisa
static var selected_character: int = 0
## 当前打到第几面
static var current_stage_id: int = 1

# ═══ 符卡簿 / 存档 ═══

static var spell_book: SpellRecordBook
static var spell_book_mgr := SpellBookManager.new()
static var save_mgr := SaveManager.new()

# ═══ 会话标志 ═══

## 关卡练习模式（完整一面，不打下一关）
static var is_stage_practice: bool = false
## 重开中（暂停 / GameOver 选重开时置位；重开时不结束练习）
static var restarting: bool = false


# ═══ 启动装配 ═══

## 主题 / 存档 / 设置 / 关卡注册表——由壳入口（GameManager）调一次
static func boot() -> void:
	UiTheme.apply()
	spell_book_mgr.load()
	spell_book = spell_book_mgr.spell_book
	save_mgr.load()
	apply_settings()
	StageCatalog.load_registry()


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


# ═══ 会话生命周期 ═══

## 重置一局：清练习载荷 + 自机资源（资源真源在 Player；注册表由组合根显式传入，去全局）
static func reset_all(entity_registry: EntityRegistry) -> void:
	PracticeSession.clear()
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


## 开一局前统一清空 per-run 会话状态（**唯一复位入口**）：练习载荷 + 关卡进度 + 重开 / 关卡练习标志。
## 新游戏（`main_menu._start_game_flow`）与进练习（`PracticeSession.start`）都必须经过它。
static func reset_session() -> void:
	PracticeSession.clear()
	current_stage_id = 1
	restarting = false
	is_stage_practice = false


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

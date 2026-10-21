## 存档 + 全局选择 + 会话编排（纯 static，不是 autoload）。
## 职责：持久化（符卡簿 / 存档 / 高分）、跨场景选择（难度 / 角色 / 关卡进度）、会话复位。
##
## [b]模型[/b][br]
## 启动时 [method boot] 由 GameManager 调一次；之后各场景直接读静态字段 / 调静态方法。
## 写盘与符卡记录都委托出去：高分 / 设置 → SaveManager，符卡簿 → SpellBookManager。
## [br]
## [b]边界[/b][br]
## - 只做“持久化 + 选择 + 会话复位”；关卡目录在 StageCatalog，练习载荷在 PracticeSession，主题在 UiTheme。[br]
## - 会话复位分两层：[method reset_session] 清 per-run 标志与进度；[method reset_all] / [method reset_practice]
##   清自机资源，两者由调用方按顺序组合。[br]
## - [method reset_all] / [method reset_practice] 的注册表由组合根显式传入，不回退全局。
class_name SaveData
extends RefCounted

# ═══ 全局选择（持久化，不随关卡重置）═══

## 难度：0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra。
static var selected_difficulty: int = 1
## 自机：0=Reimu 1=Marisa。
static var selected_character: int = 0
## 当前打到的关卡主键（StageData.stage_id；3B 面 = 4、EX 面 = 9，不等于面序号）。
static var current_stage_id: int = 1

# ═══ 符卡簿 / 存档 ═══

## 运行期符卡簿（boot / load 后可用）。
static var spell_book: SpellRecordBook
## 符卡簿管理器（加载 / 保存 / 解锁 / 记录）。
static var spell_book_mgr := SpellBookManager.new()
## 高分 / 设置存档管理器。
static var save_mgr := SaveManager.new()

# ═══ 会话标志 ═══

## 关卡练习模式（完整一面，不打下一关）。
static var is_stage_practice: bool = false
## 重开中（暂停 / GameOver 选重开时置位；重开不结束练习）。
static var is_restarting: bool = false


# ═══ 启动装配 ═══

## 启动装配（GameManager 调一次）：主题 → 符卡簿 → 存档 → 设置 → 关卡注册表。
static func boot() -> void:
	UiTheme.apply()
	spell_book_mgr.load()
	spell_book = spell_book_mgr.spell_book
	save_mgr.load()
	apply_settings()
	StageCatalog.load_registry()


## 把存档设置应用到音频 / 全屏 / 帧率；缺 key 跳过。
## max_fps = 0 表示跟显示器刷新率（读不到则无上限 0）。
static func apply_settings() -> void:
	var settings: Dictionary = save_mgr.settings
	if settings.has("volume_master"):
		AudioManager.master_volume = float(settings["volume_master"])
	if settings.has("volume_bgm"):
		AudioManager.bgm_volume = float(settings["volume_bgm"])
	if settings.has("volume_sfx"):
		AudioManager.sfx_volume = float(settings["volume_sfx"])
	if settings.has("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED)
	if settings.has("max_fps"):
		var mf: int = int(settings["max_fps"])
		# 0 = 自动：跟显示器刷新率；读不到则无上限(0)
		if mf == 0:
			var rate := DisplayServer.screen_get_refresh_rate(0)
			Engine.max_fps = int(rate) if rate > 0.0 else 0
		else:
			Engine.max_fps = mf


## 重载存档并重新应用设置（设置菜单改完后用）。
static func load_save_data() -> void:
	save_mgr.load()
	apply_settings()


## 高分表（stage_id → score；委托 SaveManager）。
static var high_scores: Dictionary:
	get: return save_mgr.high_scores


## 写入高分（只升不降；委托 SaveManager）。
static func save_high_score(stage_id: int, score: int) -> void:
	save_mgr.save_high_score(stage_id, score)


## 取该面最高分；无记录 = 0。
static func get_high_score(stage_id: int) -> int:
	return save_mgr.get_high_score(stage_id)


## 清空玩家数据（设置菜单「清空数据」）：符卡记录 + 高分归零、关卡进度回第 1 面；设置保留。
static func clear_player_data() -> void:
	spell_book_mgr.clear_player_data()
	spell_book = spell_book_mgr.spell_book
	save_mgr.clear_player_data()
	current_stage_id = 1


# ═══ 会话生命周期 ═══

## 重置一局：清练习载荷 + 自机资源（PlayerResources.reset_all）。
## 注册表由组合根显式传入；注册表存在但取不到资源时警告并空跑。
static func reset_all(entity_registry: EntityRegistry) -> void:
	PracticeSession.clear()
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if entity_registry != null and res == null:
		push_warning("SaveData.reset_all: 注册表存在但取不到自机资源（Player 未绑定？）——重置空跑")
	if res != null:
		res.reset_all()


## 关卡练习的起始火力约定：第 1 面按正常 1.00 起步，其余面直接满火力（4.00）。
## 原因：后面几面本来就是“在已有火力下”打的；练习若从 1.00 攒起就练不到该面的弹幕。
## 只对关卡练习（is_stage_practice）生效；正常流程不动，符卡练习本来就是满火力。
const PRACTICE_FULL_POWER_FROM_STAGE: int = 2


## 关卡练习本面是否从满火力开始（纯判定，便于菜单 / 测试直接用）。
## 比的是面序号（StageCatalog.stage_no_of）而不是 stage_id：3B 面 id=4、EX 面 id=9，
## “是不是第一面”要按面序号判。
static func practice_starts_at_full_power() -> bool:
	return is_stage_practice and StageCatalog.stage_no_of(current_stage_id) >= PRACTICE_FULL_POWER_FROM_STAGE


## 应用上面的约定：关卡练习第 2 面起把火力拉满。
## 必须在 reset_all() 之后调用（它会先把火力归 0）；非关卡练习 / 第 1 面空跑。
static func apply_stage_practice_power(entity_registry: EntityRegistry) -> void:
	if not practice_starts_at_full_power():
		return
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if res == null:
		push_warning("SaveData.apply_stage_practice_power: 取不到自机资源 —— 关卡练习的满火力未生效")
		return
	res.set_max_power()


## 符卡练习的资源重置（PlayerResources.reset_practice：满火力 / 0 命 / 0 雷）。
## 注册表存在但取不到资源时警告并空跑。
static func reset_practice(entity_registry: EntityRegistry) -> void:
	var res: PlayerResources = entity_registry.get_player_resources() if entity_registry else null
	if entity_registry != null and res == null:
		push_warning("SaveData.reset_practice: 注册表存在但取不到自机资源（Player 未绑定？）——重置空跑")
	if res != null:
		res.reset_practice()


## 开一局前统一清空 per-run 会话状态（唯一复位入口）：练习载荷 + 关卡进度 + 重开 / 关卡练习标志。
## 新游戏与进练习都必须经过它；它不动自机资源（资源另走 reset_all / reset_practice）。
static func reset_session() -> void:
	PracticeSession.clear()
	current_stage_id = 1
	is_restarting = false
	is_stage_practice = false


# ═══ 符卡记录（委托 SpellBookManager）═══

## 见到即记：注册一张符卡（不记 attempt）并落盘。
static func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book_mgr.unlock_spell(pid)


## 普通模式记一次符卡尝试（captured / score / elapsed）并落盘。
static func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book_mgr.record_spell(pid, captured, score, elapsed)


## 补记一次收取（进入阶段时已记过 attempt，这里只补成绩）并落盘。
static func record_capture(pid: PhaseIdentity, score: int, elapsed: float) -> void:
	spell_book_mgr.record_capture(pid, score, elapsed)


## 记一次练习尝试并落盘。
static func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book_mgr.record_practice(pid, captured)


## 练习收取补记（attempt 已在开始练习时记过，防重复）并落盘。
static func record_practice_capture(pid: PhaseIdentity) -> void:
	spell_book_mgr.record_practice_capture(pid)


## 调试：一键补全所有符卡练习的空白记录（不覆盖已有成绩）；返回新建条数。
static func debug_unlock_all_spells() -> int:
	return spell_book_mgr.debug_unlock_all_spells()

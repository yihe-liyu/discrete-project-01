# GameState.gd
extends Node
## 全局游戏数据唯一真源

const BossScript = preload("res://scripts/enemy/boss.gd")
const REGISTRY_PATH := "res://data/registry/stage_registry.tres"

# ══════════════════════════════════════════════
# 全局选择（持久化，不随着关卡重置）
# ══════════════════════════════════════════════

## 0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra
var selected_difficulty: int = 1
## 0=Reimu 1=Marisa
var selected_character: int = 0
## 当前打到第几面
var current_stage_id: int = 1

# ══════════════════════════════════════════════
# 运行时引用
# ══════════════════════════════════════════════

var player: Player = null
var active_enemies: Array = []
var stage_registry: StageRegistry

# ══════════════════════════════════════════════
# 符卡簿
# ══════════════════════════════════════════════

var spell_book: SpellRecordBook


## 子模块：符卡簿 / 存档（拆分职责，对外 API 不变）
var spell_book_mgr := SpellBookManager.new()
var save_mgr := SaveManager.new()


func _ready():
	# 全局 UI 主题：手动拷进默认主题（本引擎 fork 无 Theme.merge / ThemeDB.set_project_theme，
	# project.godot 的 gui/theme/custom 也解析异常——用 Theme item API 逐项拷贝最稳）
	_apply_ui_theme()


## 把 themes/ui_theme.tres 的样式拷进 ThemeDB 默认主题（全局 Control 生效）
func _apply_ui_theme() -> void:
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
	spell_book_mgr.load()
	spell_book = spell_book_mgr.spell_book
	save_mgr.load()
	_apply_settings()
	if ResourceLoader.exists(REGISTRY_PATH):
		stage_registry = ResourceLoader.load(REGISTRY_PATH)
	if not GameEvents.enemy_killed.is_connected(_on_enemy_killed):
		GameEvents.enemy_killed.connect(_on_enemy_killed)
	GameManager.game_state_changed.connect(_on_state_changed)
	set_process(false)


# ══════════════════════════════════════════════
# 练习模式
# ══════════════════════════════════════════════

var is_practice_mode: bool = false
## 关卡练习模式（完整一面，不打下一关）
var is_stage_practice: bool = false
var practice_phase: PhaseData        ## 练习阶段配置（来自符卡记录）
var practice_boss_scene: PackedScene ## 练习 Boss 视觉（来自符卡记录）
var practice_name: String            ## 显示名
var practice_stage_id: int = 1
var practice_phase_index: int = 0  ## 练习阶段的记录键 phase_index（正篇阶段序）
var practice_background: PackedScene
var restarting: bool = false  ## 练习模式重开标志（公开：菜单/场景需要读写）


func start_practice(phase: PhaseData, boss_scene: PackedScene, p_name: String, stage_id: int, phase_index: int = 0) -> void:
	is_practice_mode = true
	practice_phase = phase
	practice_boss_scene = boss_scene
	practice_name = p_name
	practice_stage_id = stage_id
	practice_phase_index = phase_index
	practice_background = _find_stage_background(stage_id)


func end_practice() -> void:
	if restarting:
		return
	is_practice_mode = false


func _find_stage_background(stage_id: int) -> PackedScene:
	var sd := _find_stage_data(stage_id)
	return sd.background_scene if sd else null

# ══════════════════════════════════════════════
# 关卡数据查找
# ══════════════════════════════════════════════

func _find_stage_data(stage_id: int) -> StageData:
	if stage_registry:
		return stage_registry.find(stage_id)
	# 回退：扫目录（stage_registry 未加载时用）
	return _scan_stage_dir(stage_id)


func _scan_stage_dir(stage_id: int) -> StageData:
	var dir := DirAccess.open("res://data/stages/")
	if not dir:
		return null
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var sd: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if sd and sd.stage_id == stage_id:
				return sd
		file_name = dir.get_next()
	return null


## 获取所有 StageData（供练习菜单等界面遍历用）
func get_all_stages() -> Array[StageData]:
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
			var sd: StageData = ResourceLoader.load("res://data/stages/" + file_name)
			if sd:
				result.append(sd)
		file_name = dir.get_next()
	return result

# ══════════════════════════════════════════════
# 符卡记录
# ══════════════════════════════════════════════

## 注册一张符卡（委托 SpellBookManager）
func unlock_spell(pid: PhaseIdentity) -> void:
	spell_book_mgr.unlock_spell(pid)


## 记录一次符卡尝试（委托）
func record_spell(pid: PhaseIdentity, captured: bool, score: int, elapsed: float) -> void:
	spell_book_mgr.record_spell(pid, captured, score, elapsed)


## 补记一次收取（委托）
func record_capture(pid: PhaseIdentity, score: int, elapsed: float) -> void:
	spell_book_mgr.record_capture(pid, score, elapsed)


## 记录一次练习尝试（委托）
func record_practice(pid: PhaseIdentity, captured: bool) -> void:
	spell_book_mgr.record_practice(pid, captured)


## 练习收取补记（委托）：attempt 已在开始练习时记过，防重复
func record_practice_capture(pid: PhaseIdentity) -> void:
	spell_book_mgr.record_practice_capture(pid)

# ══════════════════════════════════════════════
# 得分 & High Score
# ══════════════════════════════════════════════

## 高分表（委托 SaveManager）
var high_scores: Dictionary:
	get: return save_mgr.high_scores

## 单局资源（W4b-1：GameState 转发到 PlayerResources，单一 owner；后续逐步迁移调用点）
var resources := PlayerResources.new()

var current_score: int:
	get: return resources.current_score
	set(v): resources.current_score = v


func load_save_data():
	save_mgr.load()
	_apply_settings()


## 启动应用存档设置（音量/全屏）
func _apply_settings() -> void:
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


func save_high_score(stage_id: int, score: int):
	save_mgr.save_high_score(stage_id, score)


func get_high_score(stage_id: int) -> int:
	return save_mgr.get_high_score(stage_id)


func add_score(amount: int):
	resources.add_score(amount)


func _on_enemy_killed(score: int, _position: Vector2):
	add_score(score)

# ══════════════════════════════════════════════
# 火力 (Power)
# ══════════════════════════════════════════════

var power_raw: int:
	get: return resources.power_raw
	set(v): resources.power_raw = v


func get_power_display() -> String:
	return resources.get_power_display()


func get_power_float() -> float:
	return resources.get_power_float()


func add_power(amount: int) -> void:
	resources.add_power(amount)


func on_miss_power_penalty() -> void:
	resources.on_miss_power_penalty()

# ══════════════════════════════════════════════
# Max Point / Graze / Memory
# ══════════════════════════════════════════════

var max_point: int:
	get: return resources.max_point
	set(v): resources.max_point = v

var graze_count: int:
	get: return resources.graze_count
	set(v): resources.graze_count = v

var memory_value: float:
	get: return resources.memory_value
	set(v): resources.memory_value = v

# 记忆值常量（单一来源 PlayerResources）
const MEMORY_REGEN: float = PlayerResources.MEMORY_REGEN
const MEMORY_GRAZE: float = PlayerResources.MEMORY_GRAZE
const MEMORY_HIT_BY_BULLET: float = PlayerResources.MEMORY_HIT_BY_BULLET
const MEMORY_MISS: float = PlayerResources.MEMORY_MISS


func add_max_point() -> int:
	return resources.add_max_point()


func add_memory(amount: float) -> void:
	resources.add_memory(amount)


func reduce_memory(amount: float) -> void:
	resources.reduce_memory(amount)

# ══════════════════════════════════════════════
# 残机 & Bomb
# ══════════════════════════════════════════════

var lives: int:
	get: return resources.lives
	set(v): resources.lives = v

var life_fragments: int:
	get: return resources.life_fragments
	set(v): resources.life_fragments = v

var bomb_count: int:
	get: return resources.bomb_count
	set(v): resources.bomb_count = v

var bomb_fragments: int:
	get: return resources.bomb_fragments
	set(v): resources.bomb_fragments = v


func collect_life_fragment() -> void:
	resources.collect_life_fragment()


func lose_life() -> bool:
	return resources.lose_life()


func collect_life_full() -> void:
	resources.collect_life_full()


func collect_bomb_fragment() -> void:
	resources.collect_bomb_fragment()


func collect_bomb_full() -> void:
	resources.collect_bomb_full()


func use_bomb() -> bool:
	return resources.use_bomb()

# ══════════════════════════════════════════════
# 关卡生命周期
# ══════════════════════════════════════════════

func reset_all():
	resources.reset_all()
	is_practice_mode = false


func reset_practice():
	resources.reset_practice()

# ══════════════════════════════════════════════
# Memory 自动恢复（仅在 PLAYING 时）
# ══════════════════════════════════════════════

func _on_state_changed(_old: int, new: int) -> void:
	set_process(new == GameManager.AppState.PLAYING)


func _process(delta: float) -> void:
	resources.regen(delta)

# ══════════════════════════════════════════════
# 敌人列表
# ══════════════════════════════════════════════

func get_active_enemies() -> Array:
	return active_enemies


func get_boss():
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.get_script() == BossScript:
			return enemy
	return null


func clear_enemies():
	for enemy in active_enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			enemy.queue_free()
	active_enemies.clear()

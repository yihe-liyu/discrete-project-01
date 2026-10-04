class_name GameScene
extends Node

const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

var _blur_rect: ColorRect
var _background_instance: Node  # StageBackground 或测试 Node3D
## 当前 Boss（符卡背景取它的 `BossData.spell_background`）；由 boss_spawned/defeated 维护
var _current_boss: Boss
## 本局是否**已进入结算**。中弹(延迟 2s) / 击破 / 通关是三条独立的路，
## 而结算菜单挂在 autoload 的菜单栈上（切场景后仍在）——不加闸门就会「主菜单 + Game Over」叠一起。
## 规则：谁先到谁生效，其余一律放弃。
var _ending: bool = false
## 符卡练习的 SE 额外压低（dB）。**当前 0.0 = 关闭** ——
## 真凶已修（`lc.sfx()` 的 db 默认 0.0 = 满音量，比正常大 15 dB），所以这条补偿先撤掉。
## 若还是嫌大，从这里往负调（-3 → -6 → -9）；旋钮保留着，改一个数即可。
const PRACTICE_SFX_TRIM_DB := 0.0

@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _world: Node2D = %World
## 符卡背景层（每 Boss 一张**场景**，压在 3D 背景之上、弹幕之下；见 spell_backdrop_layer.gd）
@onready var _spell_backdrop: SpellBackdropLayer = %SpellBackdrop
## 符卡宣言立绘层（右上一→左下，快慢快 → 淡出；见 spell_portrait.gd）
@onready var _spell_portrait: Sprite2D = %SpellPortrait
## 自机 Bomb 立绘层（左下 → 右上，与 Boss 镜像；同一个脚本）
@onready var _player_portrait: Sprite2D = %PlayerPortrait
@onready var _fx_pool: FxPool = %FxPool
@onready var _stage_runtime: StageRuntime = %StageRuntime
@onready var _game_ui: GameUI = $GameUI
@onready var _item_pool: ItemPool = %ItemPool
@onready var _bullet_manager: BulletManager = %BulletManager   # R21：弹幕世界（game_scene.tscn 声明）
@onready var _miss_circle_layer: MissCircleLayer = %MissCircleLayer
@onready var _screen_shake: ScreenShake = $ScreenShake


func _ready():
	GameManager.set_state(GameManager.AppState.PLAYING)

	# R21：弹幕世界在 game_scene.tscn 的 World 下声明；这里只把它交给关卡运行时
	# 组合根装配：Miss 圈 / 特效层 / 关卡运行时（均在 game_scene.tscn 声明，R21），这里只注入。
	_stage_runtime.world = _world
	_stage_runtime.miss_layer = _miss_circle_layer
	_stage_runtime.fx_pool = _fx_pool
	_stage_runtime.item_pool = _item_pool
	_stage_runtime.ui_layer = _game_ui     # Boss 位置指示器所属 HUD 层

	_bullet_manager.inject_fx_pool(_fx_pool)
	# 与工作台/组合台**同一条接线**（StageHost）：fx_parent / 运行时认领 / 共享子弹 ctx
	StageHost.wire_world(_stage_runtime, _bullet_manager, _world)
	GameManager.register_world(_bullet_manager, _stage_runtime.entity_registry)   # 切场由壳显式操作，不读 .current

	_item_pool.entity_registry = _stage_runtime.entity_registry   # 道具经注册表取自机/资源

	# 震屏：3D 背景层（CanvasLayer）跟着 World 一起晃（SubViewportContainer 已 over-scan，不露边）。
	_screen_shake.bind_layer($Background)

	GameEvents.player_death.connect(_on_player_death)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_stage_runtime.stage_cleared.connect(_on_stage_cleared)
	# 符卡背景：Boss 谱由 boss_spawned 记下，显示时机由 phase_start 决定。
	# 顺序有保证：spawn_boss() 里先 start_boss()（发 boss_spawned）再 start_phase()（发 phase_start）。
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_defeated.connect(_on_boss_defeated)
	GameEvents.phase_start.connect(_on_phase_start)
	GameEvents.phase_end.connect(_on_phase_end)
	GameEvents.player_bomb.connect(_on_player_bomb)

	if PracticeSession.is_practice_mode:
		SaveData.is_restarting = false
		_setup_player()          # 先绑定自机（reset_* 经注册表取同一 PlayerResources）
		SaveData.reset_practice(_stage_runtime.entity_registry)
		_start_practice_game()
	else:
		if PracticeSession.phase != null:
			push_warning("GameScene: practice_phase 已设置但 is_practice_mode=false —— 练习标志被提前清除，误走普通关卡")
		SaveData.is_restarting = false
		_setup_player()          # 先绑定自机（reset_* 经注册表取同一 PlayerResources）
		SaveData.reset_all(_stage_runtime.entity_registry)
		_start_normal_game()


func _start_normal_game() -> void:
	var data: StageData = _resolve_stage_data()
	if not data:
		push_error("GameScene: 找不到关卡 stage_id=%d difficulty=%d" % [SaveData.current_stage_id, SaveData.selected_difficulty])
		return
	_load_background(data.background_scene)
	_stage_runtime.load_stage(data)


func _start_practice_game() -> void:
	# 符卡练习：作者反馈 SE（尤其弹幕 kira）在练习里明显偏大。
	# 这里是**场景级**压低 —— 正常流程的混音一个数都不动。
	AudioManager.sfx_trim_db = PRACTICE_SFX_TRIM_DB
	_load_background(PracticeSession.background)
	# 练习模式没有关卡脚本 → 没人起 BGM（只剩 SE，没有衬托会显得特别响）。
	# 曲目由菜单按「选中的卡属于哪只 Boss」解析后随载荷带来（道中 Boss 出道中曲、关底出 Boss 曲）；
	# 载荷没带（旧路径 / 合成场景）→ 回落该面的 `StageData.bgm_key`。
	var bgm_key: String = PracticeSession.bgm_key
	if bgm_key.is_empty():
		bgm_key = StageCatalog.bgm_key_of(PracticeSession.stage_id)
	if bgm_key != "":
		var bgm: AudioStream = AssetRegistry.get_bgm(bgm_key)
		if bgm:
			AudioManager.play_bgm(bgm)

	var phase: PhaseData = PracticeSession.phase
	if not phase:
		push_error("GameScene: practice_phase 未设置")
		return

	# 现查**真 BossData**（记录的 stage/phase_index → 花名册）：
	# 这样 `spell_background` / `portrait` 等字段不会丢，不必再让 PracticeSession 各带一份。
	var boss_data: BossData = BossCatalog.boss_of_phase(PracticeSession.stage_id, PracticeSession.phase_index)
	var boss: Boss = _stage_runtime.start_spell_card(
		phase, PracticeSession.boss_scene, PracticeSession.boss_name,
		Vector2(GameConfig.FIELD_CENTER_X, 240), boss_data
	)
	if not boss:
		push_warning("GameScene: start_spell_card 返回 null —— 练习 Boss 未生成")
		return
	var player := %Player
	if player:
		player.bind_ctx(boss.ctx)
	boss.phase_cleared.connect(func(_c: bool, _b: int): boss.die())
	GameEvents.boss_defeated.connect(_on_practice_cleared)


func _resolve_stage_data() -> StageData:
	if StageCatalog.registry:
		return StageCatalog.registry.find(SaveData.current_stage_id)
	push_error("GameScene: stage_registry 未设置")
	return null


func _load_background(scene: PackedScene) -> void:
	if not scene: return
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	_background_instance = scene.instantiate()
	if _background_instance is StageBackground:
		_stage_runtime.current_background = _background_instance
	_sub_viewport.add_child(_background_instance)


func _exit_tree():
	# 断开 autoload 信号连接（防悬空连接：接收者 free 后连接仍在发出者）
	if GameEvents.player_death.is_connected(_on_player_death):
		GameEvents.player_death.disconnect(_on_player_death)
	if GameManager.game_state_changed.is_connected(_on_game_state_changed):
		GameManager.game_state_changed.disconnect(_on_game_state_changed)
	if _stage_runtime.stage_cleared.is_connected(_on_stage_cleared):
		_stage_runtime.stage_cleared.disconnect(_on_stage_cleared)
	if GameEvents.boss_defeated.is_connected(_on_practice_cleared):
		GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	if GameEvents.boss_spawned.is_connected(_on_boss_spawned):
		GameEvents.boss_spawned.disconnect(_on_boss_spawned)
	if GameEvents.boss_defeated.is_connected(_on_boss_defeated):
		GameEvents.boss_defeated.disconnect(_on_boss_defeated)
	if GameEvents.phase_start.is_connected(_on_phase_start):
		GameEvents.phase_start.disconnect(_on_phase_start)
	if GameEvents.phase_end.is_connected(_on_phase_end):
		GameEvents.phase_end.disconnect(_on_phase_end)
	if GameEvents.player_bomb.is_connected(_on_player_bomb):
		GameEvents.player_bomb.disconnect(_on_player_bomb)

	_stage_runtime.miss_layer = null  # 解除注入（节点随本场景释放）
	_bullet_manager.clear_all()       # 内含 fx_pool.clear_pool()
	_bullet_manager.inject_fx_pool(null)  # 解除特效层注入（防持悬空引用）
	_bullet_manager.fx_parent = null
	_stage_runtime.fx_pool = null
	_stage_runtime.ui_layer = null
	_stage_runtime.player = null      # 解除自机注入（节点随本场景释放）
	if PracticeSession.is_practice_mode:
		PracticeSession.finish()
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	_stage_runtime.stop_stage()
	_stage_runtime.current_background = null
	AudioManager.sfx_trim_db = 0.0   # 离场还原（别漏到下一局）
	GameManager.unregister_world(_bullet_manager)   # 世界随场景注销


func _setup_player() -> void:
	var data_map := [
		preload("res://data/player_data/reimu_data.tres"),
		preload("res://data/player_data/marisa_data.tres"),
	]
	var player: Player = %Player
	# 组合根显式注入自机：StageRuntime._inject_player_ctx 只认这个引用（不再按名字找 World/Player）。
	# 放在分支**之前**：异常路径（角色下标越界）也要能注入关卡 ctx，行为与旧名字查找一致。
	_stage_runtime.player = player
	if player and SaveData.selected_character < data_map.size():
		player.setup_character(data_map[SaveData.selected_character])
		# 自机 → 本次关卡世界的实体注册表；注册表 → 内核弹幕后端（同一条 StageHost 接线）
		StageHost.wire_player(_stage_runtime, player)
	else:
		# 异常路径（角色下标越界 / 场景里没有 Player）：没有自机可绑，
		# 但注册表仍要交给内核后端（保持原行为；接线也只走 StageHost）
		StageHost.wire_registry(_stage_runtime)
	# HUD 单局资源
	_game_ui.resources = _stage_runtime.entity_registry.get_player_resources()


## ── 符卡背景（每 Boss 一张，只在符卡期间显示）──

## 记下当前 Boss —— 背景图取自它的 `BossData.spell_background`。
## 参数用 `Node` + `as Boss`（与 boss_ui 同法）：信号声明写的是 `Enemy`，但 `Boss` 与 `Enemy`
## 是**兄弟**（都 extends Area2D），实际发的就是 `Boss` —— 那句声明是错的，见 BEST_PRACTICES_LOG。
func _on_boss_spawned(boss: Node) -> void:
	_current_boss = boss as Boss


func _on_boss_defeated(_boss: Node) -> void:
	_current_boss = null
	_spell_backdrop.clear()


## 判据在 `spell_backdrop.should_show()`：符卡显示、非符/没图淡出
func _on_phase_start(phase: PhaseData) -> void:
	_spell_backdrop.apply(phase, _resolve_spell_background())
	_spell_portrait.sweep(_resolve_spell_portrait(phase))


## 阶段结束（符卡打完 / 超时 / 被击破）→ 符卡背景**渐隐**。
## 只靠 phase_start 更新的话，背景会一直挂到下一阶段开始 —— 符卡结束后本该收掉。
func _on_phase_end(_captured: bool, _bonus: int) -> void:
	_spell_backdrop.clear()


## 自机用 Bomb：立绘**左下 → 右上**扫场（与 Boss 的符卡立绘镜像）
func _on_player_bomb(_spell_name: String) -> void:
	_player_portrait.sweep_from_bottom_left(_resolve_player_portrait())


## 自机立绘：取当前机体 `PlayerData.portrait`（`%Player` 已按角色装配）
func _resolve_player_portrait() -> Texture2D:
	var player: Player = %Player
	if player != null and player.player_data != null:
		return player.player_data.portrait
	return null


## 符卡立绘：**只在符卡期间**扫场；取当前 Boss 的 `BossData.portrait`。
## 练习模式回落用 `BossCatalog` 现查（`start_spell_card` 自建 BossData 会丢字段）。
func _resolve_spell_portrait(phase: PhaseData) -> Texture2D:
	if phase == null or phase.uid == 0:
		return null
	# ⚠️ 必须连 portrait != null 一起判：练习模式的自建 BossData 没有这个字段，
	#    若这里拿到 null 就 return，就永远落不到下面的练习回落（符卡背景同样写法）
	if is_instance_valid(_current_boss) and _current_boss.boss_data != null \
			and _current_boss.boss_data.portrait != null:
		return _current_boss.boss_data.portrait
	if PracticeSession.is_practice_mode:
		var bd: BossData = BossCatalog.boss_of_phase(PracticeSession.stage_id, PracticeSession.phase_index)
		if bd != null:
			return bd.portrait
	return null


## 符卡背景场景：优先**当前 Boss** 的 `BossData.spell_background`；
## 练习模式回落到会话载荷 —— `start_spell_card()` 自建 BossData（只带 phase/visual/name），
## 会把 `spell_background` 丢掉，故 `PracticeSession` 单独携带一张。
func _resolve_spell_background() -> PackedScene:
	if is_instance_valid(_current_boss) and _current_boss.boss_data != null \
			and _current_boss.boss_data.spell_background != null:
		return _current_boss.boss_data.spell_background
	if PracticeSession.is_practice_mode:
		return PracticeSession.spell_background
	return null


func _on_player_death():
	if _ending:
		return
	await get_tree().create_timer(GameConfig.DEATH_MENU_DELAY).timeout
	# 这段窗口里可能已被击破/通关结算过（那时主菜单已经出来了）→ 不能再叠一个 Game Over
	if _ending or not is_inside_tree():
		return
	_ending = true
	var menu: Control = GAME_OVER_MENU.instantiate()
	menu.title_text = "Game Over"
	GameManager.push_overlay_menu(menu)


func _on_game_state_changed(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		_add_blur()
	elif _old == GameManager.AppState.PAUSED:
		_remove_blur()
	# 暂停时停掉背景视口的渲染：**视口更新与 process_mode 无关**（暂停菜单只是盖在场景之上），
	# 不停的话 3D 背景照旧每帧跑整条管线（llvmpipe 实测：暂停时**省 ≈8.7 ms/帧**），而玩家只看得到模糊层。
	# 副作用（作者 2026-10-02 拍板接受）：雾 shader 用 TIME，本来暂停时还在飘 —— 现在整张背景**冻住**。
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED \
		if new == GameManager.AppState.PAUSED else SubViewport.UPDATE_ALWAYS


func _on_stage_cleared():
	if _ending:
		return
	_ending = true
	if SaveData.is_stage_practice:
		SaveData.is_stage_practice = false
		GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
	elif not PracticeSession.is_practice_mode:
		var next_id: int = SaveData.current_stage_id + 1
		if StageCatalog.find(next_id) != null:
			SaveData.current_stage_id = next_id
			GameManager.reload_current_scene()
		else:
			# 没有下一关 = 通关：回标题并复位会话（否则 +1 会随 current_stage_id 泄漏到下一局）
			SaveData.reset_session()
			GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _on_practice_cleared(_boss: Node) -> void:
	if _ending:
		return
	_ending = true
	if _boss is Boss:
		var runner: CoroutineRunner = (_boss as Boss).ctx.runner
		if runner and is_instance_valid(runner):
			runner.stop()
			runner.queue_free()
	GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	PracticeSession.finish()
	# 返回**符卡练习菜单**（而不是主菜单）：到菜单后自动压回练习页，
	# 层级/选中项由该页从 PracticeSession.return_menu_state 还原
	PracticeSession.restore_menu_on_enter = true
	GameManager.pending_page_path = "res://scenes/ui/spell_practice_menu.tscn"
	GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _add_blur() -> void:
	if _blur_rect: return
	var container := %SubViewportContainer
	var vs := get_viewport().get_visible_rect().size
	_blur_rect = ColorRect.new()
	_blur_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/pause_blur.gdshader")
	mat.set_shader_parameter("rect_min", Vector2(container.position) / vs)
	mat.set_shader_parameter("rect_max", Vector2(container.position + container.size) / vs)
	_blur_rect.material = mat
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 15
	blur_layer.name = "BlurLayer"
	blur_layer.add_child(_blur_rect)
	add_child(blur_layer)


func _remove_blur() -> void:
	if not _blur_rect: return
	var layer := _blur_rect.get_parent()
	_blur_rect.queue_free()
	_blur_rect = null
	if layer and layer.name == "BlurLayer":
		layer.queue_free()

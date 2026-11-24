## 游戏主场景：装配关卡 / Boss / UI / 背景，并管理结算与练习模式。
class_name GameScene
extends Node

const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")
const STAGE_RESULT_MENU = preload("res://scenes/ui/stage_result_menu.tscn")

var _blur_rect: ColorRect
var _blur_tween: Tween
var _background_instance: Node  # StageBackground 或测试 Node3D
## 当前 Boss（符卡背景取它的 [code]BossData.spell_background[/code]）；由 boss_spawned/defeated 维护
var _current_boss: Boss
## 本局是否已进入结算。中弹(延迟 2s) / 击破 / 通关是三条独立的路，
## 而结算菜单挂在 autoload 的菜单栈上（切场景后仍在）——不加闸门就会「主菜单 + Game Over」叠一起。
## 规则：谁先到谁生效，其余一律放弃。
var _ending: bool = false
## 路线切面 reload 时保留录制 / 回放会话；新场景实例默认 false。
var _continuing_replay: bool = false
## 符卡练习的 SE 额外压低（dB）。当前 0.0 = 关闭 ——
## 真凶已修（[code]lc.sfx()[/code] 的 db 默认 0.0 = 满音量，比正常大 15 dB），所以这条补偿先撤掉。
## 若还是嫌大，从这里往负调（-3 → -6 → -9）；旋钮保留着，改一个数即可。
const PRACTICE_SFX_TRIM_DB := 0.0

@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _world: Node2D = %World
## 符卡背景层（每 Boss 一张场景，压在 3D 背景之上、弹幕之下；见 spell_backdrop_layer.gd）
@onready var _spell_backdrop: SpellBackdropLayer = %SpellBackdrop
## 符卡宣言立绘层（右上一→左下，快慢快 → 淡出；见 spell_portrait.gd）
@onready var _spell_portrait: Sprite2D = %SpellPortrait
## 自机 Bomb 立绘层（左下 → 右上，与 Boss 镜像；同一个脚本）
@onready var _player_portrait: Sprite2D = %PlayerPortrait
@onready var _fx_pool: FxPool = %FxPool
@onready var _stage_runtime: StageRuntime = %StageRuntime
@onready var _game_ui: GameUI = $GameUI
@onready var _item_pool: ItemPool = %ItemPool
@onready var _telegraph_path: Node2D = %TelegraphPath
@onready var _bullet_manager: BulletManager = %BulletManager   # R21：弹幕世界（game_scene.tscn 声明）
@onready var _miss_circle_layer: MissCircleLayer = %MissCircleLayer
@onready var _screen_shake: ScreenShake = $ScreenShake


func _ready():
	# 上一局若留下冻结（异常退出 / 测试），新一局必须从干净状态开始。
	SimClock.reset()
	GameManager.set_state(GameManager.AppState.PLAYING)

	# R21：弹幕世界在 game_scene.tscn 的 World 下声明；这里只把它交给关卡运行时
	# 组合根装配：Miss 圈 / 特效层 / 关卡运行时（均在 game_scene.tscn 声明，R21），这里只注入。
	_stage_runtime.world = _world
	_stage_runtime.miss_layer = _miss_circle_layer
	_stage_runtime.fx_pool = _fx_pool
	_stage_runtime.item_pool = _item_pool
	_stage_runtime.telegraph = _telegraph_path
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
	GameEvents.pause_exit_started.connect(_on_pause_exit_started)

	if PracticeSession.is_practice_mode:
		SaveData.is_restarting = false
		_setup_player()          # 先绑定自机（reset_* 经注册表取同一 PlayerResources）
		SaveData.reset_practice(_stage_runtime.entity_registry)
		_start_practice_game()
	else:
		if PracticeSession.phase != null:
			push_warning("GameScene: practice_phase 已设置但 is_practice_mode=false —— 练习标志被提前清除，误走普通关卡")
		SaveData.is_restarting = false
		var carry_run := SaveData.is_route_transition
		SaveData.is_route_transition = false
		if not ReplaySession.is_playing() and not ReplaySession.is_recording():
			# 先定路线 / 起始 stage，再抓 RNG 起点；播放端在场景之前恢复同一 state。
			if not SaveData.is_stage_practice:
				SaveData.ensure_route_for_difficulty(SaveData.selected_difficulty)
			ReplaySession.start_recording(_replay_meta("recording", true))
		_setup_player()          # 先绑定自机（资源恢复 / reset_* 经注册表取同一 PlayerResources）
		if carry_run:
			if not SaveData.apply_run_state(_stage_runtime.entity_registry.get_player_resources()):
				SaveData.reset_all(_stage_runtime.entity_registry)
		else:
			SaveData.reset_all(_stage_runtime.entity_registry)
			SaveData.apply_stage_practice_power(_stage_runtime.entity_registry)
		var res: PlayerResources = _stage_runtime.entity_registry.get_player_resources()
		if ReplaySession.is_playing():
			ReplaySession.apply_start_resources(res)
		elif ReplaySession.is_recording():
			ReplaySession.capture_start_resources(res)
		_start_normal_game()


func _start_normal_game() -> void:
	# Route = 本局成员/顺序；stage_id 是路线当前位置的派生结果。
	# 关卡练习不经过路线：它由菜单直接指定 current_stage_id，不能被 route 重置回第 1 面。
	if not SaveData.is_stage_practice:
		if not SaveData.ensure_route_for_difficulty(SaveData.selected_difficulty):
			return
	var data: StageData = _resolve_stage_data()
	if not data:
		push_error("GameScene: 找不到关卡 stage_id=%d difficulty=%d" % [SaveData.current_stage_id, SaveData.selected_difficulty])
		return
	_load_background(data.background_scene)
	_stage_runtime.load_stage(data)
	# 录制 / 回放的 tick 钩子必须在关卡装好之后挂：observer 要读得到 entity registry。
	if ReplaySession.is_playing():
		SimClock.set_tick_hooks(_on_replay_prepare, _on_replay_observe)
	elif not SaveData.is_stage_practice and not PracticeSession.is_practice_mode:
		SimClock.set_tick_hooks(_on_record_prepare, _on_record_observe)


func _start_practice_game() -> void:
	# 符卡练习：作者反馈 SE（尤其弹幕 kira）在练习里明显偏大。
	# 这里是**场景级**压低 —— 正常流程的混音一个数都不动。
	AudioManager.sfx_trim_db = PRACTICE_SFX_TRIM_DB
	_load_background(PracticeSession.background)
	# 符卡练习不走 load_stage()，但背景的入场协程仍要启动（Stage03B 的黑场恢复等）。
	_stage_runtime.start_background_scripts()
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


## 调试用的人类可读状态快照（只在 ReplaySession.debug_capture 时生成）。
func sim_debug_state(tick: int = -1) -> String:
	var relative := tick if tick >= 0 else SimClock.tick
	var laser: LaserEngine = _bullet_manager.laser_engine()
	var laser_list: Array = laser.get_active() if laser != null else []
	return SimHash.describe(_stage_runtime.entity_registry, _bullet_manager.kernel_system(),
		relative, _item_pool, laser_list)


## 当前 tick 的分项状态哈希（诊断用；不改变玩法）。
func sim_fields(tick: int = -1) -> Dictionary:
	var relative := tick if tick >= 0 else SimClock.tick
	var laser: LaserEngine = _bullet_manager.laser_engine()
	var laser_list: Array = laser.get_active() if laser != null else []
	return SimHash.fields(_stage_runtime.entity_registry, _bullet_manager.kernel_system(), relative,
		_item_pool, laser_list)


## 当前 tick 的规范状态指纹（诊断 / 回放校验用；不改变玩法）。
## [param tick] 传相对 tick；回放/录制必须用同一个相对序号，不能混入全局 SimClock.tick。
func sim_hash(tick: int = -1) -> int:
	var relative := tick if tick >= 0 else SimClock.tick
	var laser: LaserEngine = _bullet_manager.laser_engine()
	var laser_list: Array = laser.get_active() if laser != null else []
	return SimHash.of(_stage_runtime.entity_registry, _bullet_manager.kernel_system(), relative,
		_item_pool, laser_list)


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
	# 离开游戏场景：清掉输入锁存 / 注入 / 钩子 / 兜底解冻，菜单不会被上一局状态卡住。
	SimClock.clear_tick_hooks()
	if not _continuing_replay:
		if ReplaySession.is_recording():
			ReplaySession.cancel_recording()
		if ReplaySession.is_playing():
			ReplaySession.stop_playback()
	PlayerInput.clear_latch()
	PlayerInput.clear_override()
	SimClock.reset()
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
	if GameEvents.pause_exit_started.is_connected(_on_pause_exit_started):
		GameEvents.pause_exit_started.disconnect(_on_pause_exit_started)

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

## 记下当前 Boss —— 背景图取自它的 [code]BossData.spell_background[/code]。
## 参数用 [code]Node[/code] + [code]as Boss[/code]（与 boss_ui 同法）：信号声明写的是 [code]Enemy[/code]，但 [code]Boss[/code] 与 [code]Enemy[/code]
## 是兄弟（都 extends Area2D），实际发的就是 [code]Boss[/code] —— 那句声明是错的，见 BEST_PRACTICES_LOG。
func _on_boss_spawned(boss: Node) -> void:
	_current_boss = boss as Boss


func _on_boss_defeated(_boss: Node) -> void:
	_current_boss = null
	_spell_backdrop.clear()


## 判据在 [code]spell_backdrop.should_show()[/code]：符卡显示、非符/没图淡出
func _on_phase_start(phase: PhaseData) -> void:
	_spell_backdrop.apply(phase, _resolve_spell_background())
	_spell_portrait.sweep(_resolve_spell_portrait(phase))


## 阶段结束（符卡打完 / 超时 / 被击破）→ 符卡背景渐隐。
## 只靠 phase_start 更新的话，背景会一直挂到下一阶段开始 —— 符卡结束后本该收掉。
func _on_phase_end(_captured: bool, _bonus: int) -> void:
	_spell_backdrop.clear()


## 自机用 Bomb：立绘左下 → 右上扫场（与 Boss 的符卡立绘镜像）
func _on_pause_exit_started() -> void:
	# 退场动画一开始就淡出模糊；tree 仍 paused，等动画结束才真正 resume。
	_remove_blur()


func _on_player_bomb(_spell_name: String) -> void:
	_player_portrait.sweep_from_bottom_left(_resolve_player_portrait())


## 自机立绘：取当前机体 [code]PlayerData.portrait[/code]（[code]%Player[/code] 已按角色装配）
func _resolve_player_portrait() -> Texture2D:
	var player: Player = %Player
	if player != null and player.player_data != null:
		return player.player_data.portrait
	return null


## 符卡立绘：只在符卡期间扫场；取当前 Boss 的 [code]BossData.portrait[/code]。
## 练习模式回落用 [code]BossCatalog[/code] 现查（[code]start_spell_card[/code] 自建 BossData 会丢字段）。
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


## 符卡背景场景：优先当前 Boss 的 [code]BossData.spell_background[/code]；
## 练习模式回落到会话载荷 —— [code]start_spell_card()[/code] 自建 BossData（只带 phase/visual/name），
## 会把 [code]spell_background[/code] 丢掉，故 [code]PracticeSession[/code] 单独携带一张。
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
	if ReplaySession.is_playing():
		_ending = true
		_finish_playback()
		return
	# 用物理 tick 等，不用真实时间 Timer（否则 Game Over 落盘 tick 会随帧率漂）
	var delay_ticks := maxi(1, roundi(GameConfig.DEATH_MENU_DELAY * SimClock.TICK_RATE))
	for _i in delay_ticks:
		if _ending or not is_inside_tree():
			return
		await get_tree().physics_frame
	# 这段窗口里可能已被击破/通关结算过（那时主菜单已经出来了）→ 不能再叠一个 Game Over
	if _ending or not is_inside_tree():
		return
	# Game Over 也是一次 run 的结束：整条 run 的累计分同样要参与高分。
	if not SaveData.is_stage_practice and not PracticeSession.is_practice_mode:
		var res: PlayerResources = _stage_runtime.entity_registry.get_player_resources()
		if res != null:
			SaveData.save_high_score(0, res.current_score)
	if ReplaySession.is_recording():
		ReplaySession.finish_recording(_replay_meta("game_over"))
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
	# 副作用（作者 2026-10-02 拍板接受）：雾现在用 ScreenFogFX 的本地 time（随 delta 推进），
	# 暂停时 ScreenFogFX._process 也停 ⇒ 整张背景**冻住**，恢复不跳。
	# 暂停时只再更新一帧，保住“冻结画面”；持续更新会白烧背景管线。
	_sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE \
		if new == GameManager.AppState.PAUSED else SubViewport.UPDATE_ALWAYS


func _on_stage_cleared():
	if _ending:
		return
	_ending = true
	if ReplaySession.is_playing():
		_advance_playback_stage()
		return
	if SaveData.is_stage_practice:
		SaveData.is_stage_practice = false
		GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)
	elif not PracticeSession.is_practice_mode:
		_show_stage_result()


## 先展示结算，不提前推进路线；Continue 时才 capture + advance。
func _show_stage_result() -> void:
	var route := SaveData.current_route()
	var has_next := route != null \
		and SaveData.current_route_index + 1 < route.stages.size()
	var res: PlayerResources = _stage_runtime.entity_registry.get_player_resources()
	var stage := _stage_runtime.current_stage
	var data := {
		"has_next": has_next,
		"stage_no": SaveData.current_route_index + 1,
		"stage_name": stage.display_name if stage != null else "",
		"score": res.current_score if res != null else 0,
		"high_score": SaveData.get_high_score(0),
		"graze": res.graze_count if res != null else 0,
		"power": res.get_power_display() if res != null else "1.00",
		"lives": res.lives if res != null else 0,
		"bombs": res.bomb_count if res != null else 0,
	}
	var menu: StageResultMenu = STAGE_RESULT_MENU.instantiate() as StageResultMenu
	menu.configure(data)
	menu.finished.connect(_on_stage_result_action.bind(menu), CONNECT_ONE_SHOT)
	GameManager.push_overlay_menu(menu)


func _on_stage_result_action(result: Dictionary, menu: BasePage) -> void:
	GameManager.pop_overlay_menu(menu)
	if result.get("action") == "continue":
		# 路线切面继承上一面的自机资源；高分由 StageRuntime 按整条 run 累计写入 key 0。
		SaveData.capture_run_state(_stage_runtime.entity_registry.get_player_resources())
		var next_stage := SaveData.advance_route()
		if next_stage != null:
			_continuing_replay = true
			SaveData.is_route_transition = true
			GameManager.reload_current_scene()
			return
	if ReplaySession.is_recording():
		ReplaySession.finish_recording(_replay_meta("cleared"))
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


func _on_record_prepare(_tick: int) -> void:
	if not ReplaySession.is_recording():
		return
	if DialogueBox.active != null:
		DialogueBox.active.flush_pending_dialogue()


func _on_record_observe(_tick: int) -> void:
	if not ReplaySession.is_recording():
		return
	if ReplaySession.debug_capture:
		ReplaySession.debug_snapshots.append(sim_debug_state(ReplaySession.current_tick()))
	var idx := ReplaySession.current_tick()
	ReplaySession.record_tick(PlayerInput.input_mask(), PlayerInput.command_flags(),
		sim_hash(idx), sim_fields(idx))


func _on_replay_prepare(tick: int) -> void:
	ReplaySession.prepare_tick(tick)


func _on_replay_observe(tick: int) -> void:
	if _ending:
		return
	if ReplaySession.debug_capture:
		ReplaySession.debug_compare(ReplaySession.current_tick(),
			sim_debug_state(ReplaySession.current_tick()))
	var idx := ReplaySession.current_tick()
	if not ReplaySession.observe_tick(tick, sim_hash(idx)):
		if not _ending:
			ReplaySession.report_fields(idx, sim_fields(idx))
		_ending = true
		_finish_playback()


## [param include_start] 只在开录时 true：结束时的 stage 是“终点”，不能覆盖起点。
func _replay_meta(result: String, include_start: bool = false) -> Dictionary:
	var res: PlayerResources = _stage_runtime.entity_registry.get_player_resources()
	var meta := {
		"result": result,
		"difficulty": SaveData.selected_difficulty,
		"character": SaveData.selected_character,
		"route_id": String(SaveData.current_route_id),
		"stage_id": SaveData.current_stage_id,
		"stage_no": SaveData.current_route_index + 1,
		"score": res.current_score if res != null else 0,
		"lives": res.lives if res != null else 0,
		"bombs": res.bomb_count if res != null else 0,
	}
	if include_start:
		meta["start_stage_id"] = SaveData.current_stage_id
		meta["start_stage_no"] = SaveData.current_route_index + 1
	return meta


func _advance_playback_stage() -> void:
	var res: PlayerResources = _stage_runtime.entity_registry.get_player_resources()
	SaveData.capture_run_state(res)
	var next_stage := SaveData.advance_route()
	if next_stage != null:
		_continuing_replay = true
		SaveData.is_route_transition = true
		GameManager.reload_current_scene()
		return
	_finish_playback()


func _finish_playback() -> void:
	ReplaySession.stop_playback()
	SimClock.clear_tick_hooks()
	SaveData.reset_session()
	GameManager.pending_page_path = "res://scenes/ui/replay_menu.tscn"
	GameManager.change_scene("res://scenes/ui/main_menu.tscn", GameManager.AppState.MENU)


func _add_blur() -> void:
	if _blur_rect: return
	var container := %SubViewportContainer
	var vs := get_viewport().get_visible_rect().size
	_blur_rect = ColorRect.new()
	# 只盖游戏框；右侧状态栏 / 框外区域完全不压暗，也不做模糊。
	_blur_rect.position = container.position
	_blur_rect.size = container.size
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_rect.modulate.a = 0.0
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/pause_blur.gdshader")
	mat.set_shader_parameter("darken", 0.08)
	mat.set_shader_parameter("rect_min", Vector2(container.position) / vs)
	mat.set_shader_parameter("rect_max", Vector2(container.position + container.size) / vs)
	_blur_rect.material = mat
	var blur_layer := CanvasLayer.new()
	blur_layer.layer = 15
	blur_layer.name = "BlurLayer"
	blur_layer.add_child(_blur_rect)
	add_child(blur_layer)
	_blur_tween = create_tween()
	_blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_blur_tween.tween_property(_blur_rect, "modulate:a", 1.0, 0.45)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _remove_blur() -> void:
	if not _blur_rect: return
	if _blur_tween and _blur_tween.is_valid():
		_blur_tween.kill()
	var rect := _blur_rect
	var layer := rect.get_parent()
	_blur_rect = null
	_blur_tween = create_tween()
	_blur_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_blur_tween.tween_property(rect, "modulate:a", 0.0, 0.35)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_blur_tween.tween_callback(func():
		if is_instance_valid(rect):
			rect.queue_free()
		if is_instance_valid(layer) and layer.name == "BlurLayer":
			layer.queue_free()
	)

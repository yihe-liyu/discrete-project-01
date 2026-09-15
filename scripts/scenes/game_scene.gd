class_name GameScene
extends Node

const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

var _blur_rect: ColorRect
var _background_instance: Node  # StageBackground 或测试 Node3D

@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _world: Node2D = %World
@onready var _fx_pool: FxPool = %FxPool
@onready var _stage_runtime: StageRuntime = %StageRuntime
@onready var _game_ui: GameUI = $GameUI
@onready var _item_pool: ItemPool = %ItemPool
@onready var _bullet_manager: BulletManager = %BulletManager   # R21：弹幕世界（game_scene.tscn 声明）
@onready var _miss_circle_layer: MissCircleLayer = %MissCircleLayer


func _ready():
	GameManager.set_state(GameManager.AppState.PLAYING)

	# R21：弹幕世界在 game_scene.tscn 的 World 下声明；这里只把它交给关卡运行时
	# 组合根装配：Miss 圈 / 特效层 / 关卡运行时（均在 game_scene.tscn 声明，R21），这里只注入。
	_stage_runtime.bullet_manager = _bullet_manager
	_stage_runtime.world = _world
	_stage_runtime.miss_layer = _miss_circle_layer
	_stage_runtime.fx_pool = _fx_pool
	_stage_runtime.ui_layer = _game_ui     # Boss 位置指示器所属 HUD 层

	_bullet_manager.inject_fx_pool(_fx_pool)
	_bullet_manager.fx_parent = _world            # 炸弹爆炸贴图挂 World（不再全树找）
	_bullet_manager.inject_stage_runtime(_stage_runtime)   # 共享子弹 ctx 显式绑 stage（去全局回退）
	GameManager.register_world(_bullet_manager, _stage_runtime.entity_registry)   # 切场由壳显式操作，不读 .current

	_item_pool.entity_registry = _stage_runtime.entity_registry   # 道具经注册表取自机/资源

	GameEvents.player_death.connect(_on_player_death)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_stage_runtime.stage_cleared.connect(_on_stage_cleared)

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
	_load_background(PracticeSession.background)

	var phase: PhaseData = PracticeSession.phase
	if not phase:
		push_error("GameScene: practice_phase 未设置")
		return

	var boss: Boss = _stage_runtime.start_spell_card(
		phase, PracticeSession.boss_scene, PracticeSession.boss_name,
		Vector2(GameConfig.FIELD_CENTER_X, 240)
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

	_stage_runtime.miss_layer = null  # 解除注入（节点随本场景释放）
	_bullet_manager.clear_all()       # 内含 fx_pool.clear_pool()
	_bullet_manager.inject_fx_pool(null)  # 解除特效层注入（防持悬空引用）
	_bullet_manager.fx_parent = null
	_stage_runtime.fx_pool = null
	_stage_runtime.ui_layer = null
	if PracticeSession.is_practice_mode:
		PracticeSession.finish()
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	_stage_runtime.stop_stage()
	_stage_runtime.current_background = null
	GameManager.unregister_world(_bullet_manager)   # 世界随场景注销


func _setup_player() -> void:
	var data_map := [
		preload("res://data/player_data/reimu_data.tres"),
		preload("res://data/player_data/marisa_data.tres"),
	]
	var player: Player = %Player
	if player and SaveData.selected_character < data_map.size():
		player.setup_character(data_map[SaveData.selected_character])
		# 自机 → 本次关卡世界的实体注册表（BulletManager 亦经注入读取）
		_stage_runtime.entity_registry.bind_player(player)
	# 自机已就绪：把本关卡的实体注册表注入内核弹幕后端
	_bullet_manager.inject_entity_registry(_stage_runtime.entity_registry)
	# HUD 单局资源
	_game_ui.resources = _stage_runtime.entity_registry.get_player_resources()


func _on_player_death():
	await get_tree().create_timer(2.0).timeout
	var menu: Control = GAME_OVER_MENU.instantiate()
	menu.title_text = "Game Over"
	GameManager.push_overlay_menu(menu)


func _on_game_state_changed(_old: int, new: int) -> void:
	if new == GameManager.AppState.PAUSED:
		_add_blur()
	elif _old == GameManager.AppState.PAUSED:
		_remove_blur()


func _on_stage_cleared():
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
	if _boss is Boss:
		var runner: CoroutineRunner = (_boss as Boss).ctx.runner
		if runner and is_instance_valid(runner):
			runner.stop()
			runner.queue_free()
	GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	PracticeSession.finish()
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

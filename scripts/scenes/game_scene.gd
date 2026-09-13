extends Node
class_name GameScene

const GAME_OVER_MENU = preload("res://scenes/ui/game_over_menu.tscn")

@onready var _sub_viewport: SubViewport = %SubViewport
@onready var _world: Node2D = %World
@onready var _fx_pool: FxPool = %FxPool
@onready var _stage_runtime: StageRuntime = %StageRuntime
@onready var _miss_layer: MissCircleLayer = %MissCircleLayer
@onready var _game_ui: GameUI = $UI
@onready var _item_pool = %ItemPool
@onready var _bullets: BulletManager = %BulletManager   # W4c/R21：弹幕世界（game_scene.tscn 声明）

var _blur_rect: ColorRect
var _background_instance: Node  # StageBackground 或测试 Node3D


func _ready():
	GameManager.set_state(GameManager.AppState.PLAYING)

	# W4c/R21：弹幕世界在 game_scene.tscn 的 World 下声明；这里只把它交给关卡运行时
	# 组合根装配：Miss 圈 / 特效层 / 关卡运行时（均在 game_scene.tscn 声明，R21），这里只注入。
	_stage_runtime.bullets = _bullets
	_stage_runtime.world = _world
	_stage_runtime.miss_layer = _miss_layer
	_stage_runtime.fx_pool = _fx_pool
	_stage_runtime.ui_layer = _game_ui     # Boss 位置指示器所属 HUD 层（K4）
	
	_bullets.inject_fx_pool(_fx_pool)
	_bullets.fx_parent = _world            # 炸弹爆炸贴图挂 World（K4：不再全树找）
	
	_item_pool.refs = _stage_runtime.refs   # 道具经注册表取自机/资源（W4b-2b）

	GameEvents.player_death.connect(_on_player_death)
	GameManager.game_state_changed.connect(_on_game_state_changed)
	_stage_runtime.stage_cleared.connect(_on_stage_cleared)

	if SaveData.is_practice_mode:
		SaveData.restarting = false
		SaveData.reset_practice()
		_setup_player()
		_start_practice_game()
	else:
		if SaveData.practice_phase != null:
			push_warning("GameScene: practice_phase 已设置但 is_practice_mode=false —— 练习标志被提前清除，误走普通关卡")
		SaveData.restarting = false
		SaveData.reset_all()
		_setup_player()
		_start_normal_game()


func _start_normal_game() -> void:
	var data := _resolve_stage_data()
	if not data:
		push_error("GameScene: 找不到关卡 stage_id=%d difficulty=%d" % [SaveData.current_stage_id, SaveData.selected_difficulty])
		return
	_load_background(data.background_scene)
	_stage_runtime.load_stage(data)


func _start_practice_game() -> void:
	_load_background(SaveData.practice_background)

	var phase: PhaseData = SaveData.practice_phase
	if not phase:
		push_error("GameScene: practice_phase 未设置")
		return

	var boss := _stage_runtime.start_spell_card(
		phase, SaveData.practice_boss_scene, SaveData.practice_name,
		Vector2(GameConfig.FIELD_CENTER_X, 240)
	)
	if not boss:
		return
	var player := %Player
	if player:
		player.ctx = boss.ctx
	boss.phase_cleared.connect(func(_c: bool, _b: int): boss.die())
	GameEvents.boss_defeated.connect(_on_practice_cleared)


func _resolve_stage_data() -> StageData:
	if SaveData.stage_registry:
		return SaveData.stage_registry.find(SaveData.current_stage_id)
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
	_bullets.clear_all()       # 内含 fx_pool.clear_pool()
	_bullets.inject_fx_pool(null)  # 解除特效层注入（防持悬空引用）
	_bullets.fx_parent = null
	_stage_runtime.fx_pool = null
	_stage_runtime.ui_layer = null
	if SaveData.is_practice_mode:
		SaveData.end_practice()
	if _background_instance and is_instance_valid(_background_instance):
		_background_instance.queue_free()
		_background_instance = null
	_stage_runtime.stop_stage()
	_stage_runtime.current_background = null


func _setup_player() -> void:
	var data_map := [
		preload("res://data/player_data/reimu_data.tres"),
		preload("res://data/player_data/marisa_data.tres"),
	]
	var player: Player = %Player
	if player and SaveData.selected_character < data_map.size():
		player.setup_character(data_map[SaveData.selected_character])
		# 自机 → 本次关卡世界的实体注册表（BulletManager 亦经注入读取）
		_stage_runtime.refs.bind_player(player)
	# 自机已就绪：把本关卡的实体注册表注入内核弹幕后端
	_bullets.inject_world_refs(_stage_runtime.refs)
	# HUD 单局资源（W4b-2b）
	_game_ui.resources = _stage_runtime.refs.get_player_resources()


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
	elif not SaveData.is_practice_mode:
		SaveData.current_stage_id += 1
		GameManager.reload_current_scene()


func _on_practice_cleared(_boss: Node) -> void:
	if _boss is Boss:
		var runner: CoroutineRunner = (_boss as Boss).ctx.runner
		if runner and is_instance_valid(runner):
			runner.stop()
			runner.queue_free()
	GameEvents.boss_defeated.disconnect(_on_practice_cleared)
	SaveData.end_practice()
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

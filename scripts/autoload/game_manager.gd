# GameManager.gd (Autoload) — 游戏状态机 + 模块门面
extends Node

enum AppState {MENU, PLAYING, PAUSED, TRANSITIONING}

## 暂停菜单场景路径（**唯一来源**：覆盖层入口只引用这个常量，不再散落字面量）
const PAUSE_MENU_SCENE := "res://scenes/ui/pause_menu.tscn"

signal game_state_changed(old_state: int, new_state: int)
signal scene_entered(scene_path: String)
signal scene_left(scene_path: String)

# ═══ 模块 ───

var _scene_transition: SceneTransition
var _menu_nav: MenuNav

# ═══ 状态 ═══
## 换场景后要自动压入的菜单页（如"从练习返回 → 回到符卡练习页"）。由目标场景消费后清空。
var pending_page_path: String = ""
var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_state: AppState = AppState.MENU


func _ready():
	process_mode = PROCESS_MODE_ALWAYS

	SaveData.boot()  # 原 SaveData._ready（主题/存档/设置/注册表）

	_scene_transition = SceneTransition.new()
	_scene_transition.setup(self)

	_menu_nav = MenuNav.new()
	_menu_nav.setup(self)
	# 覆盖层进出的状态切换走显式信号；`CONNECT_DEFERRED` 保持旧 `set_state.call_deferred(...)` 的时序
	# （本帧末才切状态，避免在 push/pop 的半途触发 game_state_changed 的监听者）。
	_menu_nav.pause_requested.connect(_on_pause_requested, CONNECT_DEFERRED)
	_menu_nav.resume_requested.connect(_on_resume_requested, CONNECT_DEFERRED)


func _on_pause_requested() -> void:
	set_state(AppState.PAUSED)


func _on_resume_requested() -> void:
	set_state(AppState.PLAYING)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != AppState.PLAYING:
		return
	if _menu_nav.is_overlay_open():
		return
	if event.is_action_pressed("ui_pause"):
		_menu_nav.push_overlay(PAUSE_MENU_SCENE)
		get_viewport().set_input_as_handled()


# ═══ 状态 ═══

## 受控状态入口（内部模块/场景都走这里；会发信号并做去重）
func set_state(new_state: AppState) -> void:
	var old: int = current_state
	if old == new_state:
		return
	current_state = new_state
	game_state_changed.emit(old, new_state)

func is_paused() -> bool:
	return current_state == AppState.PAUSED


# ═══ 场景切换 ═══

func change_scene(path: String, target_state: AppState = AppState.PLAYING):
	if current_state == AppState.TRANSITIONING:
		return

	set_state(AppState.TRANSITIONING)

	_menu_nav.clear_pages()
	_menu_nav.clear_overlays()

	var new_path: String = await _scene_transition.change_scene(
		path, current_scene_path, scene_left.emit,
		_pause_world, _clear_world, _resume_world)
	previous_scene_path = current_scene_path
	current_scene_path = new_path

	set_state(target_state)
	scene_entered.emit(current_scene_path)


# ═══ 当前世界登记（取代跨场景读 BulletManager.current）═══

## 当前存在世界的显式登记（GameScene 组合根 `_ready` 调）；切场时由壳统一暂停/清场/恢复。
var world_bullets: BulletManager
var entity_registry: EntityRegistry


func register_world(bullets: BulletManager, p_entity_registry: EntityRegistry) -> void:
	world_bullets = bullets
	entity_registry = p_entity_registry


func unregister_world(bullets: BulletManager) -> void:
	if world_bullets == bullets:
		world_bullets = null
		entity_registry = null


func _pause_world() -> void:
	if is_instance_valid(world_bullets):
		world_bullets.pause_processing()


func _clear_world() -> void:
	if is_instance_valid(world_bullets):
		world_bullets.clear_all()
	if entity_registry != null:
		entity_registry.clear()


func _resume_world() -> void:
	if is_instance_valid(world_bullets):
		world_bullets.resume_processing()


func reload_current_scene():
	if current_scene_path != "":
		change_scene(current_scene_path)


# ═══ 子页面（MainMenu 内 push/pop） ═══

## 注入子页面容器（MainMenu 的 %PageHost）；R2：MenuNav 不再自行场景搜索
func set_page_host(host: Control) -> void:
	_menu_nav.set_page_host(host)


## 推入子页面（难度选择、角色选择等），返回页面节点
func push_page(path: String) -> Node:
	return _menu_nav.push(path)

## 弹出当前子页面
func pop_page() -> void:
	_menu_nav.pop()

## 清空所有子页面
func clear_pages() -> void:
	_menu_nav.clear_pages()


# ═══ 覆盖层（暂停 / Game Over / 通关） ═══

## 推入覆盖层（暂停游戏）— 接受已实例化的节点（兼容旧 API）
func push_overlay_menu(menu) -> void:
	_menu_nav.add_overlay_instance(menu)

func pop_overlay_menu(menu) -> void:
	_menu_nav.pop_specific_overlay(menu)


# ═══ 暂停 / 恢复 ═══

func pause_game():
	if current_state != AppState.PLAYING:
		return
	_menu_nav.push_overlay(PAUSE_MENU_SCENE)

func resume_game():
	if current_state != AppState.PAUSED:
		return
	_menu_nav.pop_overlay()

func toggle_pause():
	if current_state == AppState.PAUSED:
		resume_game()
	elif current_state == AppState.PLAYING:
		pause_game()

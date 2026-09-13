# GameManager.gd (Autoload) — 游戏状态机 + 模块门面
extends Node

enum AppState {MENU, PLAYING, PAUSED, TRANSITIONING}

signal game_state_changed(old_state: int, new_state: int)
signal scene_entered(scene_path: String)
signal scene_left(scene_path: String)

# ═══ 模块 ───
const TransClass = preload("res://scripts/scenes/scene_transition.gd")
const NavClass = preload("res://scripts/scenes/menu_nav.gd")

var _transition: SceneTransition
var _nav: MenuNav

# ═══ 状态 ═══
var current_scene_path: String = ""
var previous_scene_path: String = ""
var current_state: AppState = AppState.MENU


func _ready():
	process_mode = PROCESS_MODE_ALWAYS

	SaveData.boot()  # W4b-4：原 SaveData._ready（主题/存档/设置/注册表）

	_transition = TransClass.new()
	_transition.setup(self)

	_nav = NavClass.new()
	_nav.setup(self)


func _unhandled_input(event: InputEvent) -> void:
	if current_state != AppState.PLAYING:
		return
	if _nav.is_overlay_open():
		return
	if event.is_action_pressed("ui_pause"):
		_nav.push_overlay("res://scenes/ui/pause_menu.tscn")
		get_viewport().set_input_as_handled()


# ═══ 状态 ═══

## 受控状态入口（供内部模块/场景使用，会发信号并做去重）
func set_state(new_state: AppState) -> void:
	_set_state(new_state)


func _set_state(new_state: AppState):
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

	_set_state(AppState.TRANSITIONING)

	_nav.clear_pages()
	_nav.clear_overlays()

	var new_path: String = await _transition.change_scene(path, current_scene_path, scene_left.emit, scene_entered.emit)
	previous_scene_path = current_scene_path
	current_scene_path = new_path

	_set_state(target_state)
	scene_entered.emit(current_scene_path)


func reload_current_scene():
	if current_scene_path != "":
		change_scene(current_scene_path)


# ═══ 子页面（MainMenu 内 push/pop） ═══

## 注入子页面容器（MainMenu 的 %PageHost）；R2：MenuNav 不再自行场景搜索
func set_page_host(host: Control) -> void:
	_nav.set_page_host(host)


## 推入子页面（难度选择、角色选择等），返回页面节点
func push_page(path: String) -> Node:
	return _nav.push(path)

## 弹出当前子页面
func pop_page() -> void:
	_nav.pop()

## 清空所有子页面
func clear_pages() -> void:
	_nav.clear_pages()


# ═══ 覆盖层（暂停 / Game Over / 通关） ═══

## 推入覆盖层（暂停游戏）— 接受已实例化的节点（兼容旧 API）
func push_overlay_menu(menu) -> void:
	_nav.add_overlay_instance(menu)

func pop_overlay_menu(menu) -> void:
	_nav.pop_specific_overlay(menu)


# ═══ 暂停 / 恢复 ═══

func pause_game():
	if current_state != AppState.PLAYING:
		return
	_nav.push_overlay("res://scenes/ui/pause_menu.tscn")

func resume_game():
	if current_state != AppState.PAUSED:
		return
	_nav.pop_overlay()

func toggle_pause():
	if current_state == AppState.PAUSED:
		resume_game()
	elif current_state == AppState.PLAYING:
		pause_game()

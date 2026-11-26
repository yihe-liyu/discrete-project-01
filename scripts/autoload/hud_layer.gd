## 持久 HUD 宿主：从独立 game_hud.tscn 实例化一次，之后切面复用。
extends Node

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

var _game_ui: GameUI


func _ready() -> void:
	GameManager.scene_entered.connect(_on_scene_entered)
	GameManager.scene_left.connect(_on_scene_left)


## 取持久 HUD；没有就创建。GameScene 每次 ready 都调用它。
func get_game_ui() -> GameUI:
	if not is_instance_valid(_game_ui):
		_game_ui = HUD_SCENE.instantiate() as GameUI
		if _game_ui == null:
			return null
		add_child(_game_ui)
	_game_ui.set_hud_visible(true)
	return _game_ui


## 离开游戏场景时先藏 HUD：黑场过渡期间不残留框，主菜单也不会看到游戏 HUD。
func _on_scene_left(path: String) -> void:
	if is_instance_valid(_game_ui) and path.ends_with("game_scene.tscn"):
		_game_ui.set_hud_visible(false)


func _on_scene_entered(path: String) -> void:
	if is_instance_valid(_game_ui):
		_game_ui.set_hud_visible(path.ends_with("game_scene.tscn"))

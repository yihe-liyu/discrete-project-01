## 持久 HUD 宿主：从独立 game_hud.tscn 实例化一次，之后切面复用。
extends Node

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

var _game_ui: GameUI


func _ready() -> void:
	GameManager.scene_entered.connect(_on_scene_entered)


## 取持久 HUD；没有就创建。GameScene 每次 ready 都调用它。
func get_game_ui() -> GameUI:
	if not is_instance_valid(_game_ui):
		_game_ui = HUD_SCENE.instantiate() as GameUI
		if _game_ui == null:
			return null
		add_child(_game_ui)
	_game_ui.visible = true
	return _game_ui


func _on_scene_entered(path: String) -> void:
	if is_instance_valid(_game_ui):
		_game_ui.visible = path.ends_with("game_scene.tscn")

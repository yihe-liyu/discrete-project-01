## 持久 HUD 宿主：第一次进游戏时把 GameScene 里的 GameUI 收养到 autoload，
## 之后切面重建 GameScene 时复用同一份 HUD，只更新 resources / frame。
extends Node

var _game_ui: GameUI


func _ready() -> void:
	GameManager.scene_entered.connect(_on_scene_entered)


## GameScene 每次 ready 调用：第一次收养 local_game_ui，之后丢弃场景里的新 HUD。
func acquire(local_game_ui: GameUI) -> GameUI:
	if is_instance_valid(_game_ui):
		if is_instance_valid(local_game_ui):
			local_game_ui.queue_free()
		_game_ui.visible = true
		return _game_ui
	if not is_instance_valid(local_game_ui):
		return null
	_game_ui = local_game_ui
	if _game_ui.get_parent() != self:
		_game_ui.reparent(self)
	_game_ui.visible = true
	return _game_ui


## 当前持久 HUD（测试 / 调试用）。
func get_game_ui() -> GameUI:
	return _game_ui


func _on_scene_entered(path: String) -> void:
	if is_instance_valid(_game_ui):
		_game_ui.visible = path.ends_with("game_scene.tscn")

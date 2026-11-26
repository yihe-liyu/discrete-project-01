## 持久 HUD 宿主：从独立 game_hud.tscn 实例化一次，之后切面复用。
extends Node

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")

const HUD_FADE_TIME := 0.4
var _game_ui: GameUI
var _hud_fade_tween: Tween


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
	if _hud_fade_tween and _hud_fade_tween.is_valid():
		_hud_fade_tween.kill()
		_hud_fade_tween = null
	_game_ui.set_hud_visible(true)
	_game_ui.set_hud_alpha(1.0)
	return _game_ui


## 离开游戏场景时让 HUD 跟着黑场一起淡出；新场景入场时再恢复。
func _on_scene_left(path: String) -> void:
	if not is_instance_valid(_game_ui) or not path.ends_with("game_scene.tscn"):
		return
	if _hud_fade_tween and _hud_fade_tween.is_valid():
		_hud_fade_tween.kill()
	_game_ui.set_hud_alpha(1.0)
	_hud_fade_tween = create_tween()
	_hud_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hud_fade_tween.tween_method(_game_ui.set_hud_alpha, 1.0, 0.0, HUD_FADE_TIME)


func _on_scene_entered(path: String) -> void:
	if not is_instance_valid(_game_ui):
		return
	if _hud_fade_tween and _hud_fade_tween.is_valid():
		_hud_fade_tween.kill()
		_hud_fade_tween = null
	_game_ui.set_hud_alpha(1.0)
	_game_ui.set_hud_visible(path.ends_with("game_scene.tscn"))

# PlayerSpellUI.gd
extends CanvasLayer
## 自机 Bomb 符卡名大字报：中间起 → 左上 → 左下停一会儿 → 渐隐。
## 订阅 GameEvents.player_bomb；底衬用玩家青色贴图。

const ANNOUNCE_SCENE := preload("res://scenes/ui/announce_label.tscn")
## 自机符卡底衬（青）。敌方（Boss）用 enemy_spell_name_background。
const PLAYER_SPELL_NAME_BG := preload("res://assets/Textures/ascii/player_spell_name_background.png")

@onready var _control: Control = $Control

var _announce_label: AnnounceLabel


func _ready() -> void:
	GameEvents.player_bomb.connect(_on_player_bomb)


func _exit_tree() -> void:
	if GameEvents.player_bomb.is_connected(_on_player_bomb):
		GameEvents.player_bomb.disconnect(_on_player_bomb)


func _on_player_bomb(spell_name: String) -> void:
	if spell_name.is_empty():
		return
	_clear()
	_announce_label = ANNOUNCE_SCENE.instantiate() as AnnounceLabel
	_control.add_child(_announce_label)
	_announce_label.finished.connect(_clear, CONNECT_ONE_SHOT)
	_announce_label.play(spell_name, _control.size, PLAYER_SPELL_NAME_BG, AnnounceLabel.Style.PLAYER)


func _clear() -> void:
	if _announce_label and is_instance_valid(_announce_label):
		_announce_label.clear()
		_announce_label = null

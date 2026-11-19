## 回放采样器：priority -50，夹在 Marisa 射击(-100) 与玩家移动(0) 之间。
extends Node

var game: Node


func _ready() -> void:
	process_physics_priority = -50


func _physics_process(_delta: float) -> void:
	if game != null and is_instance_valid(game):
		game.flush_replay_sample()

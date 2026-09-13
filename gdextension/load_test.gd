extends Node
## GDExtension 加载冒烟：确认原生类已注册（CI / 本地均可跑）。

func _ready() -> void:
	print("DanmakuStore exists: ", ClassDB.class_exists("DanmakuStore"))
	get_tree().quit()

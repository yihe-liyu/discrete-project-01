extends Node
## N1 验证：Godot 4.7.2 能否加载 api_version=4.7 的 GDExtension 并注册 Hello 类。

func _ready() -> void:
	print("GDExt Hello class exists: ", ClassDB.class_exists("Hello"))
	if ClassDB.class_exists("Hello"):
		var h: Object = ClassDB.instantiate("Hello")
		if h != null and h.has_method("greet"):
			print("greet(): ", h.greet())
	get_tree().quit()

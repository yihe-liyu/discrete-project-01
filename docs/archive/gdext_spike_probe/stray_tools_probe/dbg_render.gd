extends Node
func _ready() -> void:
	var backend := KernelBulletBackend.new()
	add_child(backend)
	var renderer := BulletMultiMesh.new()
	add_child(renderer)
	renderer.set_backend(backend)
	for i in 3:
		var d := BulletData.new().enemy().blend(true).tex("小玉")
		d.velocity = Vector2.UP * 100.0
		backend.shoot(d, Vector2(10 + i * 20, 50), Vector2.RIGHT)
	print("bridge_exist=", ClassDB.class_exists("DanmakuRenderBridge"), " native=", (renderer._render_bridge() != null))
	renderer._sync()
	print("groups=", renderer._groups.size())
	for g in renderer._groups.values():
		print("visible=", g.mm.visible_instance_count, " inst_count=", g.mm.instance_count)
	get_tree().quit()

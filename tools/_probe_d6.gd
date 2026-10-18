extends Node
func _ready() -> void:
	var cs = load("res://scenes/workbench/creation_station.tscn").instantiate()
	add_child(cs)
	await get_tree().process_frame
	await get_tree().process_frame
	cs.open_slot(1)
	for i in 3:
		await get_tree().process_frame
	get_window().size = Vector2i(1280, 960)
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://.godot/probe/d6_1280c.png")
	print("window=", get_window().size, "scale=", get_window().content_scale_size, "viewport=", get_viewport().get_visible_rect().size, "catalog=", cs.catalog_open(), "content=", cs.get_node("Root/ContentHost/Content").get_rect())
	get_tree().quit()

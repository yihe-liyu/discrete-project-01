# ReplayMenu.gd — 回放菜单（占位）
extends BasePage


func on_enter() -> void:
	# 黑底渐显 + 标题渐显
	var ov: ColorRect = $"Overlay"
	ov.modulate.a = 0.0
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ov, "modulate:a", 1.0, 0.5)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)


func on_leave() -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property($"Overlay", "modulate:a", 0.0, 0.5)
	tw.tween_property($"TitleTexture", "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		go_back()

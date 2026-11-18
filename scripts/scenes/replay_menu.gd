# ReplayMenu.gd — 回放列表（录制已接线；播放下一步）
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
	_show_replays()


## 录制列表；没有文件时给一句明确提示，而不是空白占位。
func _show_replays() -> void:
	var old := get_node_or_null("ReplayList")
	if old:
		old.queue_free()
	var entries := ReplaySession.list_replays()
	var lines: Array[String] = []
	for e in entries:
		var meta: Dictionary = e.get("metadata", {})
		var diff := int(meta.get("difficulty", 1))
		var diff_name := Difficulty.display_name(diff) if Difficulty.is_valid(diff) else "?"
		var char_name := "灵梦" if int(meta.get("character", 0)) == 0 else "魔理沙"
		lines.append("Stage %s · %s · %s · %d 分 · %d 帧" % [
			str(meta.get("stage_no", "?")), diff_name, char_name,
			int(meta.get("score", 0)), int(e.get("duration", 0)),
		])
	if lines.is_empty():
		lines.append("暂无回放。\n完整打完一局（通关或 Game Over）后会自动生成。")
	var label := Label.new()
	label.name = "ReplayList"
	label.position = Vector2(240, 220)
	label.size = Vector2(800, 600)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 20)
	label.text = "\n".join(lines)
	add_child(label)


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

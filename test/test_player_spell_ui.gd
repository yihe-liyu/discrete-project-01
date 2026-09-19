extends GutTest
## PlayerSpellUI：订阅 GameEvents.player_bomb，非空名字才播大字报（PLAYER 样式）。

const UI_SCENE := preload("res://scenes/ui/player_spell_ui.tscn")


func _make_ui() -> CanvasLayer:
	var ui := UI_SCENE.instantiate() as CanvasLayer
	add_child_autofree(ui)
	return ui


func _announce(ui: CanvasLayer) -> AnnounceLabel:
	for child in ui.get_node("Control").get_children():
		if child is AnnounceLabel:
			return child
	return null


func test_spawns_announce_on_player_bomb() -> void:
	var ui := _make_ui()
	GameEvents.player_bomb.emit("梦想封印")
	var label := _announce(ui)
	assert_not_null(label, "bomb 触发符卡名大字报")
	assert_eq(label.text, "梦想封印", "大字报文本 = 符卡名")


func test_empty_name_ignored() -> void:
	var ui := _make_ui()
	GameEvents.player_bomb.emit("")
	assert_null(_announce(ui), "空名字不播报")

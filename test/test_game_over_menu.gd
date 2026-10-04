extends GutTest
## GameOverMenu：本引擎**不解析节点类型 @export**（`.tscn` 里 `title_label = NodePath(...)` 会被丢弃）。
## 于是 Game Over 标题曾永远不更新（`if title_label:` 恒假）。
## 守卫：① 入树一帧后 `title_label` 必须已由代码按路径/类型解析出来；
##       ② 设置标题的接口必须真把文字写进那个 `Label`。

const GAME_OVER_SCENE := preload("res://scenes/ui/game_over_menu.tscn")


## 建一个入树并等一帧的实例（复现「引擎丢弃节点类型 export」的现场）
func _spawn_menu():
	var menu = GAME_OVER_SCENE.instantiate()
	add_child(menu)
	await get_tree().process_frame
	return menu


func test_title_label_resolves_on_ready() -> void:
	var menu = await _spawn_menu()
	assert_not_null(menu.title_label, "入树一帧后 title_label 必须已解析（引擎不解析节点类型 @export）")
	menu.queue_free()
	await get_tree().process_frame


func test_set_title_writes_into_resolved_label() -> void:
	var menu = await _spawn_menu()
	assert_not_null(menu.title_label, "前置：title_label 必须先解析出来")
	if menu.title_label == null:
		menu.queue_free()
		return
	menu.set_title("EXTRA CLEAR")
	assert_eq(menu.title_label.text, "EXTRA CLEAR", "set_title 必须把文字写进 Panel/TitleLabel")
	menu.queue_free()
	await get_tree().process_frame

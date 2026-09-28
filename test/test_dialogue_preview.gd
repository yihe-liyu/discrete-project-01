extends GutTest
## 对话预览的**交互契约**：默认**不自动播** —— 进场景、换脚本、换段落都不该自己播起来。
##
## 回归（作者报过）：改完 `auto_play` 默认值后，**换段落那条路**还在自动播放。
## 真正开播只有三条路：`auto_play` 勾上 · 命令行 `--script=`/`--func=` · 按「▶ 播放」/ R。

const PREVIEW_SCENE := preload("res://scenes/ui/dialogue_preview.tscn")


func _preview() -> Control:
	var preview: Control = PREVIEW_SCENE.instantiate()
	add_child_autofree(preview)
	return preview


## 进场景：不该有演出，但要**预选**好第一段（省得每次都手动挑）
func test_entering_scene_does_not_play():
	var preview := _preview()
	assert_null(preview._box, "进场景不该有演出（auto_play 默认关）")
	assert_false(preview._func_name.is_empty(), "但应预选一个构建函数")
	assert_eq(preview._func_name, preview._func_picker.get_item_text(0),
		"预选的应是段列表里的第一个（不锁具体名字：剧本改名/加段都不该弄红这条）")
	assert_gt(preview._func_picker.item_count, 1, "该脚本应有多段可选")


## 换段落：只改选中项 + 停掉当前演出，**不自动开新的**（要播按 ▶ / R）
func test_switching_func_only_selects():
	var preview := _preview()
	preview._play_current()
	assert_not_null(preview._box, "「▶ 播放」之后应有演出")

	var second: String = preview._func_picker.get_item_text(1)
	preview._on_func_picked(1)

	assert_eq(preview._func_name, second, "换段应改选中项（取列表里的第二项）")
	assert_null(preview._box, "换段后不该继续/自动演出")


## 换脚本同理（当前只有一段脚本，选它自己也要停）
func test_switching_script_only_selects():
	var preview := _preview()
	preview._play_current()
	assert_not_null(preview._box)

	preview._on_script_picked(0)

	assert_null(preview._box, "换脚本后同样不该自动播")
	assert_true(preview._path.ends_with("stage01_dialogue.gd"), "应选中该脚本")

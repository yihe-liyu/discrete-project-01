extends GutTest
## 逐页 F6 冒烟：每个可独立运行的页面场景都要能实例化、入树、跑一帧，且不 push_error / engine error。
## 只验“场景自身能不能起来”（F6 口径），不验菜单交互与内容 —— 交互仍由各页自己的测试覆盖。

const PAGE_SCENES := [
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/ui/character_screen.tscn",
	"res://scenes/ui/difficulty_screen.tscn",
	"res://scenes/ui/stage_practice_menu.tscn",
	"res://scenes/ui/spell_practice_menu.tscn",
	"res://scenes/ui/option_menu.tscn",
	"res://scenes/ui/manual_menu.tscn",
	"res://scenes/ui/music_room_menu.tscn",
	"res://scenes/ui/player_data_menu.tscn",
	"res://scenes/ui/pause_menu.tscn",
	"res://scenes/ui/game_over_menu.tscn",
	"res://scenes/ui/replay_menu.tscn",
]


func test_page_scenes_load_standalone() -> void:
	for path in PAGE_SCENES:
		assert_true(ResourceLoader.exists(path), "页面场景不存在：" + path)
		var scene: PackedScene = load(path)
		assert_not_null(scene, "页面场景加载失败：" + path)
		if scene == null:
			continue
		var page: Node = scene.instantiate()
		add_child_autofree(page)
		await get_tree().process_frame
		assert_true(is_instance_valid(page) and page.is_inside_tree(), "页面实例未入树：" + path)
		assert_eq(get_errors().size(), 0, "页面 F6 时不应有 error：" + path)
		page.free()
		await get_tree().process_frame
	AudioManager.stop_bgm()

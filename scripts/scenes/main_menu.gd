extends NavPage
# MainMenu.gd — 标题画面 + 子页面导航中枢
#
# 特殊处理：MainMenu 是场景根节点，不走 MenuNav push 流程。
# 它继承 NavPage 以复用选项导航，但自己管理入口时机。

@onready var _logo: TextureRect = $"Logo"
@onready var _particles: GPUParticles2D = $"GPUParticles2D"
@onready var _page_host: Control = %PageHost   # 子页面容器（注入给 MenuNav）


var _logo_tween: Tween


func _ready() -> void:
	# 导航初始化（不走 NavPage.on_enter，因为 MainMenu 是场景根）
	_setup_nav()
	_nav_enabled = false  # 等 Logo 播完再启用

	# 锁定项
	_container.get_node("Extra Start").set_meta("locked", true)

	if SaveData.spell_book.records.is_empty():
		_container.get_node("Spell Practice").set_meta("locked", true)

	refresh_colors()

	# 选项先隐藏，等 Logo 播完再入场
	for item: Control in _nav_items:
		item.modulate.a = 0.0

	GameManager.current_scene_path = "res://scenes/ui/main_menu.tscn"
	GameManager.set_page_host(_page_host)   # R2：把子页面容器注入 MenuNav
	AudioManager.play_bgm(AssetRegistry.get_bgm("menu"), 1.0)

	# Logo 入场动画
	_logo.material.set_shader_parameter("progress", 0.0)
	_logo.material.set_shader_parameter("alpha_mult", 1.0)

	_logo_tween = create_tween()
	_logo_tween.tween_property(_logo.material, "shader_parameter/progress", 1.0, 3.0)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_logo_tween.tween_callback(_play_entrance)  # 选项在 Logo 播完后入场


func _exit_tree() -> void:
	GameManager.set_page_host(null)  # 解除注入（防 MenuNav 持悬空 host）


func _on_item_selected(index: int) -> void:
	match index:
		0: _start_game_flow()
		2: _open_page("res://scenes/ui/stage_practice_menu.tscn")
		3: _open_spell_practice()
		4: _open_page("res://scenes/ui/replay_menu.tscn")
		5: _open_page("res://scenes/ui/player_data_menu.tscn")
		6: _open_page("res://scenes/ui/music_room_menu.tscn")
		7: _open_page("res://scenes/ui/option_menu.tscn")
		8: _open_page("res://scenes/ui/manual_menu.tscn")
		9: get_tree().quit()


func _open_page(path: String) -> void:
	_deactivate_title()
	var page := GameManager.push_page(path)
	page.tree_exited.connect(func(): _activate_title.call_deferred(), CONNECT_ONE_SHOT)


func _on_cancel() -> void:
	var last_idx := _nav_items.size() - 1
	if _nav_index < last_idx:
		sfx_nav()
		_select(last_idx)
	else:
		get_tree().quit()


# ═══ 开始游戏流程（难度 → 角色） ═══

func _start_game_flow() -> void:
	SaveData.reset_session()   # 新游戏：唯一复位入口（练习载荷 / 关卡进度 / 重开标记）
	_deactivate_title()
	_push_difficulty()


func _push_difficulty() -> void:
	var page := GameManager.push_page("res://scenes/ui/difficulty_screen.tscn")
	page.finished.connect(_on_difficulty_result.bind(page), CONNECT_ONE_SHOT)


func _on_difficulty_result(result: Dictionary, _page: Node) -> void:
	GameManager.pop_page()
	if result.has("difficulty"):
		SaveData.selected_difficulty = result.difficulty
		_push_character()
	else:
		_activate_title()


func _push_character() -> void:
	var page := GameManager.push_page("res://scenes/ui/character_screen.tscn")
	page.finished.connect(_on_character_result.bind(page), CONNECT_ONE_SHOT)


func _on_character_result(result: Dictionary, _page: Node) -> void:
	GameManager.pop_page()
	if result.has("character"):
		SaveData.selected_character = result.character
		AudioManager.stop_bgm()
		GameManager.change_scene("res://scenes/game_scene.tscn")
	else:
		_push_difficulty()


# ═══ 符卡练习 ═══

func _open_spell_practice() -> void:
	_deactivate_title()
	var page := GameManager.push_page("res://scenes/ui/spell_practice_menu.tscn")
	page.tree_exited.connect(func(): _activate_title.call_deferred(), CONNECT_ONE_SHOT)


# ═══ 标题停用/恢复 ═══

func _deactivate_title() -> void:
	_nav_enabled = false
	_stop_pulse()
	refresh_colors()

	# 与 MenuNav 黑场同步渐隐（0.12s）
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_container, "modulate:a", 0.0, 0.12)
	tween.tween_property(_logo.material, "shader_parameter/alpha_mult", 0.0, 0.12)
	tween.tween_property(_particles, "modulate:a", 0.5, 0.12)
	tween.tween_callback(_container.hide).set_delay(0.12)
	tween.tween_callback(_logo.hide).set_delay(0.12)


func _activate_title() -> void:
	if not is_instance_valid(self) or not is_instance_valid(_container):
		return
	_container.show()
	_logo.show()
	_container.modulate.a = 0.0
	_logo.material.set_shader_parameter("alpha_mult", 0.0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(_container, "modulate:a", 1.0, 0.25)
	tw.tween_property(_logo.material, "shader_parameter/alpha_mult", 1.0, 0.25)
	tw.tween_property(_particles, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		refresh_colors()
		_nav_enabled = true
		if _nav_index >= 0 and _nav_index < _nav_items.size():
			_start_pulse(_nav_items[_nav_index])
	).set_delay(0.25)


# ═══ 调试（F1 全开符卡） ═══

func _skip_logo() -> void:
	if not _logo_tween or not _logo_tween.is_valid():
		return
	_logo_tween.kill()
	_logo_tween = null
	_logo.material.set_shader_parameter("progress", 1.0)
	_play_entrance()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		_skip_logo()
		skip_entrance()
		return
	if event.is_action_pressed("debug_toggle"):
		# TODO: debug_fill_spells 已移除 — 从 stage_registry 自动填充
		_container.get_node("Spell Practice").remove_meta("locked")
		refresh_colors()

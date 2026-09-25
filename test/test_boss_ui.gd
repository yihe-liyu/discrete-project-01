extends GutTest
## BossUI 场景声明式建树（R21）：倒计时 Label 与阶段点模板都在 .tscn 里，代码不再 .new()。

const BOSS_UI_SCENE := preload("res://scenes/ui/boss_ui.tscn")


func test_scene_declares_timer_and_dot_template() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	assert_not_null(ui.get_node_or_null("Control/TimerLabel"), "倒计时 Label 声明在场景里")
	assert_not_null(ui.get_node_or_null("Control/DotTemplate"), "阶段点模板声明在场景里")


func test_dot_template_hidden_and_sized() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var dot := ui.get_node_or_null("Control/DotTemplate") as ColorRect
	assert_not_null(dot, "模板在场景里")
	assert_false(dot.visible, "模板默认隐藏（不参与 HBox 布局）")
	assert_eq(dot.custom_minimum_size, Vector2(16.0, 16.0), "模板尺寸声明在场景里")


## 符卡宣言时放 `card` 音效（该资源曾在 AssetRegistry 注册却无人播放）
func test_spell_card_plays_card_sfx() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var card: AudioStream = AssetRegistry.sounds["card"]
	_clear_sfx_pool()
	ui._on_phase_start(_phase(5))
	# 断言池里被交进了 card 流（headless 下 playing 标志不可靠，故看 stream 身份）
	assert_true(_pool_has(card), "符卡宣言应播 card 音效")


## 非符不放宣言音
func test_nonspell_does_not_play_card_sfx() -> void:
	var ui := BOSS_UI_SCENE.instantiate()
	add_child_autofree(ui)
	var card: AudioStream = AssetRegistry.sounds["card"]
	_clear_sfx_pool()
	ui._on_phase_start(_phase(0))
	assert_false(_pool_has(card), "非符不该播 card 音效")


func _phase(uid: int) -> PhaseData:
	var phase := PhaseData.new()
	phase.name = "夹具符卡"
	phase.uid = uid
	phase.hp = 1000
	phase.time_limit = 30.0
	return phase


## 清空 SFX 池与同帧去重表，避免上一条用例的残留影响
func _clear_sfx_pool() -> void:
	for player in AudioManager._sfx_players:
		player.stop()
		player.stream = null
	AudioManager._played_this_frame.clear()


func _pool_has(stream: AudioStream) -> bool:
	for player in AudioManager._sfx_players:
		if player.stream == stream:
			return true
	return false

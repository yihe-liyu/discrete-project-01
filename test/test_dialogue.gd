extends GutTest
## 对话系统播放层测试：DialogueBox 步骤驱动（台词内联 DSL）
## 覆盖：DialogueBox 播放冒烟 / 行间 event 触发 / 角色表情

func _make_profile(char_name: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	p.char_name = char_name
	return p


## 内容校验：**遍历 profile 目录**，不写死文件名 —— 改名/增删不该红，数据违规才红
## （契约见 docs/TEST_INDEX.md「内容绑定契约」）。
func test_profiles_valid():
	var dir := DirAccess.open("res://data/dialogue/profile")
	assert_not_null(dir, "profile 目录应存在")
	if dir == null:
		return
	var checked := 0
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		var path := "res://data/dialogue/profile/".path_join(f)
		var p: CharacterProfile = load(path)
		assert_not_null(p, "%s 应可加载" % path)
		if p:
			assert_ne(p.char_name, "", "%s 应有 char_name" % path)
		checked += 1
	assert_gt(checked, 0, "至少应有一个角色 profile")


func test_play_steps_shows_first_line():
	# 步骤版冒烟：enter + line → 立绘出现、气泡可见
	var d := DialogueSteps.new()
	d.enter(_make_profile("测试"), Vector2(200, 200))
	d.line("测试台词")
	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps)
	await wait_seconds(0.6)  # 淡入 0.3s + runner 启动 + 显示
	assert_true(box.visible, "play 后应可见")
	assert_true(box._portrait_map.has("测试"), "第一句的立绘应出现")
	# 关闭 → finished → 等 queue_free 生效
	box._close()
	await box.finished
	await get_tree().process_frame
	assert_false(is_instance_valid(box), "关闭后应释放")


func test_event_fires_between_lines():
	# event 是行与行之间的步骤，时机精确
	var r := _make_profile("测试")
	var d := DialogueSteps.new()
	d.say(r, "A")
	d.event("probe_event")
	d.say(r, "B")
	var is_fired: Array[String] = []
	var cb := func(event_name: String): is_fired.append(event_name)
	GameEvents.dialogue_event.connect(cb)
	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps)
	await wait_seconds(0.6)
	assert_eq(is_fired, [], "第一句显示时还不该触发事件")
	box._advance()  # 说完 A → 进入 event 步骤
	assert_eq(is_fired, ["probe_event"], "行与行之间触发事件")
	box._close()
	await box.finished
	await get_tree().process_frame
	GameEvents.dialogue_event.disconnect(cb)


func test_emotion_applied_to_portrait():
	# line 的 emotion opts → actor.emotion → 立绘换表情（回归：曾丢表情）
	var r := _make_profile("测试")
	var d := DialogueSteps.new()
	d.enter(r, Vector2(200, 200))
	d.line("耍帅台词", {"emotion": "耍帅"})
	var box: CanvasLayer = load("res://scenes/ui/dialogue_box.tscn").instantiate()
	add_child(box)
	box.play_steps(d.steps)
	await wait_seconds(0.6)
	assert_true(box._portrait_map.has("测试"), "立绘出现")
	var info: Dictionary = box._portrait_map["测试"]
	assert_eq(info.profile.char_name, "测试", "profile 就位")
	box._close()
	await box.finished
	await get_tree().process_frame

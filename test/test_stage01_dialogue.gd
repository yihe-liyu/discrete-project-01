extends GutTest
## 第一面战前对话构建函数测试：验证抽出的 _build_stage01_intro() 内容（台词/说话者/表情/事件顺序）
## 纯逻辑（.new() 无树），不改游戏运行时；顺带校验 stage01.gd 能正常解析。

const STAGE01_INTRO = preload("res://data/dialogue/stage01/intro.gd")


func _intro() -> DialogueSteps:
	return STAGE01_INTRO.build()


## 抽取所有 LINE 步骤的非空台词文本（同屏多气泡按序并入）
func _line_texts(d: DialogueSteps) -> Array[String]:
	var out: Array[String] = []
	for step in d.steps:
		if step.type == DialogueStep.Type.LINE:
			for b in step.line_data.bubbles:
				if not b.text.is_empty():
					out.append(b.text)
	return out


## 抽取所有 LINE 步骤的说话者（char_name），用于校验"谁说什么"的顺序
func _line_speakers(d: DialogueSteps) -> Array[String]:
	var out: Array[String] = []
	for step in d.steps:
		if step.type == DialogueStep.Type.LINE:
			for b in step.line_data.bubbles:
				if not b.text.is_empty() and b.speaker:
					out.append(b.speaker.char_name)
	return out


## 抽取行间事件 key 顺序
func _events(d: DialogueSteps) -> Array[String]:
	var out: Array[String] = []
	for step in d.steps:
		if step.type == DialogueStep.Type.EVENT:
			out.append(step.event_key)
	return out


func test_intro_builds_valid_steps():
	var d := _intro()
	assert_not_null(d, "应返回 DialogueSteps")
	assert_gt(d.steps.size(), 0, "至少一个步骤")


func test_intro_line_texts_matches_script():
	var d := _intro()
	assert_eq(_line_texts(d), [
		"啊，什么线索都没有，怎么解决异变啊…",
		"除非…\n刚才的小妖怪～",
		"哦呀，弱小的人类怎么会在永夜出门？",
		"快回家去吧。",
		"虽然卡摩瑞我只是蝙蝠，但是再不走的话…",
		"已经是人形了却不好好长眼睛啊。",
		"把日食当夜晚吗？",
		"我是巫女，我若是回家了，谁来解决异变呐，小小的蝙蝠哟？",
		"啊，竟然遇到巫女了吗？",
		"唉，肯定没有线索啦。",
		"所以让开吧？",
		"不，不行。\n如果真见到了传说中的巫女，怎么能不打一场！",
		"而且\n在黑暗中，我可更胜一筹！",
	], "台词顺序应与剧本（docs/DIALOGUE.md Stage1）一致")


func test_intro_speakers_match_script():
	var d := _intro()
	assert_eq(_line_speakers(d), [
		"灵梦", "灵梦", "卡摩瑞", "卡摩瑞", "卡摩瑞",
		"灵梦", "灵梦", "灵梦", "卡摩瑞", "灵梦", "灵梦", "卡摩瑞", "卡摩瑞",
	], "说话者顺序应与剧本一致")


func test_intro_events_in_order():
	var d := _intro()
	assert_eq(_events(d), ["boss_enter", "display_name", "bgm_switch", "boss_fight"], "行间事件顺序应精确（含揭露真名 display_name）")


func test_intro_line_emotion_applied():
	# 关键情绪应记在台词步骤上（行内演出属性不丢）
	var d := _intro()
	var found := {}
	for step in d.steps:
		if step.type == DialogueStep.Type.LINE:
			for b in step.line_data.bubbles:
				if not b.emotion.is_empty():
					found[b.text] = b.emotion
	assert_eq(found.get("除非…\n刚才的小妖怪～"), "笑", "第二句表情应为笑")
	assert_eq(found.get("虽然卡摩瑞我只是蝙蝠，但是再不走的话…"), "耍帅", "蝙蝠自述表情应为耍帅")
	assert_eq(found.get("啊，竟然遇到巫女了吗？"), "震惊", "认出巫女表情应为震惊")

extends GutTest
## 第一面对话构建函数测试（**战前 + 战后**两段）：验证台词/说话者/表情/事件顺序。
## 纯逻辑（.new() 无树），不改游戏运行时；顺带校验 stage01.gd 能正常解析。
##
## ⚠️ **内容测试**：验的就是「stage01 这段剧本写了什么」—— **故意绑内容**，改台词/改名/挪文件时**该红**。
## 机制层（DSL / 播放器）在 test_dialogue_steps 里用自建夹具测（契约见 docs/TEST_INDEX.md）。

const STAGE01_DIALOGUE = preload("res://data/dialogue/stage/stage01_dialogue.gd")


func _intro() -> DialogueSteps:
	return STAGE01_DIALOGUE.灵梦战斗前()


func _outro() -> DialogueSteps:
	return STAGE01_DIALOGUE.灵梦战斗后()


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


## 关键情绪要真的生效。**断言读"舞台状态"而不是气泡字段**：
## 表情有两种等价写法 —— `d.screen([[KA, "耍帅", "…"]])`（气泡 emotion）
## 与 `reimu.portrait("笑").line("…")`（独立演出步）；两者最终都落到 ActorState 这份真相上，
## 所以按状态断言才对写法免疫（作者把 intro 改成句柄写法后就该这样测）。
func test_intro_line_emotion_applied():
	var report := DialogueDryRun.play(_intro().steps)
	var texts: Array = report["texts"]
	var emotions: Array = report["emotions"]
	assert_eq(emotions[texts.find("除非…\n刚才的小妖怪～")], "笑", "第二句表情应为笑")
	assert_eq(emotions[texts.find("虽然卡摩瑞我只是蝙蝠，但是再不走的话…")], "耍帅", "蝙蝠自述表情应为耍帅")
	assert_eq(emotions[texts.find("啊，竟然遇到巫女了吗？")], "震惊", "认出巫女表情应为震惊")


# ═══════════ 战后对话（关底全破 → 关卡结束前） ═══════════

## 骨架契约：**最后一步必须是 `stage_end` 事件** —— 关卡靠它收尾（对话不冻结时间轴，
## 不能用 `wait(秒)` 接）。这条错了的后果是"打完 Boss 关卡不结束"，所以单独锁。
func test_outro_ends_with_stage_end_event():
	var d := _outro()
	assert_not_null(d, "应返回 DialogueSteps")
	var events := _events(d)
	assert_eq(events.back(), "stage_end", "最后一步必须是 stage_end（否则关卡不会结束）")


## DSL 硬要求：每屏至少一句非空台词（占位骨架也得有）—— 防止"作者还没填台词"时整段播不出来
func test_outro_has_lines():
	var d := _outro()
	assert_gt(_line_texts(d).size(), 0, "至少一句非空台词")
	assert_gt(_line_speakers(d).size(), 0, "每句都要有说话者")


# ═══════════ 干跑（整段"跑起来"是什么样） ═══════════

## **整段必须能跑完** —— 跑不完 = 玩家在游戏里**卡在对话里**（比台词写错严重得多），
## 所以两段都用 `DialogueDryRun` 干跑一遍。顺带锁事件顺序（关卡靠它推进）。
func test_intro_runs_to_completion_with_events_in_order():
	var report := DialogueDryRun.play(STAGE01_DIALOGUE.灵梦战斗前().steps)
	assert_true(report["finished"], "战前对话应能跑完（否则会卡住玩家）")
	assert_eq(report["events"], ["boss_enter", "display_name", "bgm_switch", "boss_fight"],
		"行间事件顺序应精确（关卡靠它进 Boss / 切歌 / 开战）")


## 战后同理：跑得完 + 最后一步是 stage_end（关卡靠它收尾）
func test_outro_runs_to_completion_and_ends_stage():
	var report := DialogueDryRun.play(STAGE01_DIALOGUE.灵梦战斗后().steps)
	assert_true(report["finished"], "战后对话应能跑完")
	assert_eq(report["events"], ["stage_end"], "战后应只发 stage_end（收尾）")
	assert_gt(report["lines"], 0, "至少演出一句")

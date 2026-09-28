class_name DialogueDryRun
extends RefCounted
## 对话**干跑**：无头把一段 steps 跑完，收集可观测量（台词 / 说话者 / 事件 / 有没有跑完）。
##
## 用途：
## ① `DialoguePreview --dry`：不开窗就把整段文本按顺序打印出来（改完台词的最快检查）；
## ② 测试：断言"整段能跑完 / 台词顺序 / 事件顺序" —— 不需要场景树（`DialogueRunner` 是纯逻辑）。
##
## 与真实播放的差别：这里**自动翻页**（不等玩家按 Z）→ 验的是**剧本本身**，
## 不是节奏手感（手感去 `DialoguePreview` 的窗口模式看）。

const TICK := 0.05          ## 假 delta（秒）
const MAX_TICKS := 4000     ## 安全上限：剧本卡住（永远等不到输入）也不会把调用方挂死


static func play(p_steps: Array) -> Dictionary:
	var texts: Array[String] = []
	var speakers: Array[String] = []
	var emotions: Array[String] = []
	var events: Array[String] = []
	var lines := [0]
	var runner := DialogueRunner.new()
	# 注意：`line_shown` 时状态**已经** apply_line 过 → 读到的表情就是这一句的表情。
	# 这样断言"某人这句是什么表情"与**写法无关**（d.screen 的气泡 emotion 或 portrait() 步都行）。
	runner.line_shown.connect(func(line: DialogueLine, _speakers: Array, state: StageState) -> void:
		lines[0] += 1
		for bubble in line.bubbles:
			if bubble.text.is_empty():
				continue
			var char_name: String = bubble.speaker.char_name if bubble.speaker else ""
			texts.append(bubble.text)
			speakers.append(char_name)
			var actor := state.actor(char_name) if state != null and char_name != "" else null
			emotions.append(actor.emotion if actor != null else "")
	)
	runner.event_fired.connect(func(key: String) -> void: events.append(key))
	runner.start(p_steps)
	var ticks := 0
	while not runner.is_finished() and ticks < MAX_TICKS:
		runner.tick(TICK)
		if runner.current_line() != null:
			runner.advance()
		ticks += 1
	return {
		texts = texts, speakers = speakers, emotions = emotions, events = events,
		lines = lines[0], finished = runner.is_finished(),
	}


## 排版成可读文本（预览的 `--dry` 与命令行检查直接用）
static func format(p_report: Dictionary) -> String:
	var texts: Array = p_report["texts"]
	var speakers: Array = p_report["speakers"]
	var events: Array = p_report["events"]
	var out: Array[String] = []
	out.append("台词 %d 句 / 事件 %d 个 / 跑完：%s" % [
		texts.size(), events.size(), "是" if p_report["finished"] else "**否（剧本卡住了！）**"])
	for i in texts.size():
		out.append("  %2d. %s：%s" % [i + 1, speakers[i], texts[i]])
	if not events.is_empty():
		out.append("  事件顺序：" + ", ".join(events))
	return "\n".join(out)

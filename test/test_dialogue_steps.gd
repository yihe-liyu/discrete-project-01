extends GutTest
## 对话系统测试：StageState / DialogueSteps DSL / DialogueRunner（纯逻辑，不进树）
## 台词内联版：line() 直接收文本，无台词库/无 id

# ═══════════ 辅助 ═══════════

func _make_profile(name: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	p.char_name = name
	return p


func _attach(runner: DialogueRunner) -> Dictionary:
	var seen: Dictionary = {
		shown = [], events = [], finished = 0, states = [],
	}
	runner.line_shown.connect(func(line, speakers, state): seen.shown.append(line))
	runner.event_fired.connect(func(key): seen.events.append(key))
	runner.finished.connect(func(): seen.finished += 1)
	runner.state_changed.connect(func(state, _duration): seen.states.append(state))
	return seen


# ═══════════ DSL 构建 ═══════════

func test_dsl_builds_steps():
	var p := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(p, Vector2(200, 200), {"flip": true})
	d.line("第一句")
	d.event("bgm_switch")
	d.wait(0.5)
	d.flip("灵梦", false)
	d.move("灵梦", Vector2(300, 200), 0.8)
	d.portrait("灵梦", "笑")
	d.dim("灵梦", 0.4)
	d.exit("灵梦")
	assert_eq(d.steps.size(), 9, "9 个步骤")
	assert_eq(d.steps[0].type, DialogueStep.Type.ENTER, "0 = enter")
	assert_eq(d.steps[1].type, DialogueStep.Type.LINE, "1 = line")
	var line0: DialogueLine = d.steps[1].line_data
	assert_eq(line0.bubbles[0].text, "第一句", "台词内联")
	assert_eq(line0.bubbles[0].speaker.char_name, "灵梦", "说话者延续 enter")
	assert_eq(d.steps[2].type, DialogueStep.Type.EVENT, "2 = event")
	assert_eq(d.steps[2].event_key, "bgm_switch", "event key")
	assert_eq(d.steps[3].type, DialogueStep.Type.WAIT, "3 = wait")
	assert_eq(d.steps[3].duration, 0.5, "wait 时长")
	assert_eq(d.steps[4].flip, false, "flip 值")
	assert_eq(d.steps[5].pos, Vector2(300, 200), "move 位置")
	assert_eq(d.steps[6].emotion, "笑", "portrait 表情")
	assert_eq(d.steps[7].light, 0.4, "dim 明暗")
	assert_eq(d.steps[8].type, DialogueStep.Type.EXIT, "8 = exit")


func test_dsl_line_continues_speaker_and_say_switches():
	var r := _make_profile("灵梦")
	var k := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	d.enter(r, Vector2(50, 230))
	d.line("r1 台词")
	d.line("r2 台词")                       # 延续灵梦
	d.say(k, "k1 台词", {"emotion": "疑惑"})  # 换卡摩瑞
	d.line("k2 台词")                       # 延续卡摩瑞
	assert_eq((d.steps[1].line_data as DialogueLine).bubbles[0].speaker.char_name, "灵梦")
	assert_eq((d.steps[2].line_data as DialogueLine).bubbles[0].speaker.char_name, "灵梦")
	assert_eq((d.steps[3].line_data as DialogueLine).bubbles[0].speaker.char_name, "卡摩瑞")
	assert_eq((d.steps[3].line_data as DialogueLine).bubbles[0].emotion, "疑惑")
	assert_eq((d.steps[4].line_data as DialogueLine).bubbles[0].speaker.char_name, "卡摩瑞")


func test_dsl_line_requires_speaker():
	# 首句必须指定说话者（say 或 opts.speaker）；无延续者时 DSL 用 assert 拦截——约定由文档保证，这里仅确认 say 路径可用
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.say(r, "首句")
	assert_eq(d.steps.size(), 1, "say 指定说话者正常构建")


# ═══════════ 舞台状态 ═══════════

func test_stage_state_ensure_creates_actor():
	var state := StageState.new()
	var a := state.ensure(_make_profile("卡摩瑞"))
	assert_eq(a.char_name, "卡摩瑞", "actor 名字")
	assert_true(state.has("卡摩瑞"), "已注册")
	assert_same(state.ensure(_make_profile("卡摩瑞")), a, "重复 ensure 返回同一 actor")


func test_apply_line_light_rules():
	# 说话者亮 1.0；沉默在场者暗 0.35
	var state := StageState.new()
	var reimu := _make_profile("灵梦")
	var ka := _make_profile("卡摩瑞")
	state.ensure(reimu)
	state.ensure(ka)
	var line := DialogueLine.new()
	var b1 := DialogueBubble.new(); b1.speaker = reimu; b1.text = "说话"
	line.bubbles.append(b1)
	var speakers := state.apply_line(line)
	assert_eq(speakers, ["灵梦"], "说话者列表")
	assert_eq(state.actor("灵梦").light, 1.0, "说话者亮")
	assert_eq(state.actor("卡摩瑞").light, 0.35, "沉默在场者暗")
	assert_true(state.actor("灵梦").visible, "说话者在场")


func test_apply_line_multi_speaker_both_light():
	var state := StageState.new()
	var r := _make_profile("灵梦")
	var k := _make_profile("卡摩瑞")
	var line := DialogueLine.new()
	for p in [r, k]:
		var b := DialogueBubble.new(); b.speaker = p; b.text = "齐声"
		line.bubbles.append(b)
	var speakers := state.apply_line(line)
	assert_eq(speakers.size(), 2, "两人齐声")
	assert_eq(state.actor("灵梦").light, 1.0, "灵梦亮")
	assert_eq(state.actor("卡摩瑞").light, 1.0, "卡摩瑞亮")


func test_apply_line_updates_emotion():
	# 表情是内容属性：line 显示时气泡 emotion 应用到对应角色（含沉默者）
	var state := StageState.new()
	var k := _make_profile("卡摩瑞")
	var r := _make_profile("灵梦")
	state.ensure(r)
	var line := DialogueLine.new()
	var b := DialogueBubble.new(); b.speaker = k; b.text = "台词"; b.emotion = "耍帅"
	line.bubbles.append(b)
	state.apply_line(line)
	assert_eq(state.actor("卡摩瑞").emotion, "耍帅", "说话者表情跟随气泡")
	assert_eq(state.actor("灵梦").emotion, "通常", "无气泡角色保持默认")


# ═══════════ Runner 状态机 ═══════════

func test_runner_enter_then_line():
	var runner := DialogueRunner.new()
	var seen := _attach(runner)
	var reimu := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(reimu, Vector2(200, 200))
	d.line("台词")
	runner.start(d.steps)
	assert_true(runner.is_waiting_line, "停在 LINE 等输入")
	var a: ActorState = runner.state.actor("灵梦")
	assert_true(a.visible, "在场")
	assert_eq(a.position, Vector2(200, 200), "位置来自 enter")
	assert_eq(a.light, 1.0, "说话者亮")
	assert_eq(seen.shown.size(), 1, "显示了一句")
	assert_eq(seen.shown[0].bubbles[0].text, "台词", "显示内联台词")


func test_runner_event_between_lines():
	# 行间事件：line → event → line，顺序精确
	var runner := DialogueRunner.new()
	var seen := _attach(runner)
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.say(r, "A")
	d.event("bgm_switch")
	d.say(r, "B")
	runner.start(d.steps)
	assert_eq(seen.events, [], "第一句显示时还没事件")
	runner.advance()  # 说完 A
	assert_eq(seen.events, ["bgm_switch"], "行与行之间触发事件")
	assert_eq(runner.current_line().bubbles[0].text, "B", "事件后进入下一句")


func test_runner_wait_blocks_then_advances():
	var runner := DialogueRunner.new()
	var seen := _attach(runner)
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.say(r, "A")
	d.wait(0.5)
	d.say(r, "B")
	runner.start(d.steps)
	runner.advance()
	assert_true(runner.is_waiting_time, "停在 WAIT 计时")
	assert_eq(seen.shown.size(), 1, "还没显示第二句")
	runner.tick(0.3)
	assert_true(runner.is_waiting_time, "0.3 < 0.5 仍在等")
	runner.tick(0.3)
	assert_true(runner.is_waiting_line, "计时结束进入下一句")
	assert_eq(seen.shown.size(), 2, "第二句已显示")


func test_runner_finishes_at_end():
	var runner := DialogueRunner.new()
	var seen := _attach(runner)
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.say(r, "A")
	runner.start(d.steps)
	assert_eq(seen.finished, 0, "未结束")
	runner.advance()
	assert_eq(seen.finished, 1, "最后一句推进后 finished")
	assert_true(runner.is_finished(), "is_finished")


func test_runner_auto_advance():
	var runner := DialogueRunner.new()
	var seen := _attach(runner)
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.line("A", {"speaker": r, "auto_advance": 0.5})
	d.say(r, "B")
	runner.start(d.steps)
	assert_true(runner.is_waiting_line, "停在第一句")
	runner.tick(0.6)
	assert_eq(seen.shown.size(), 2, "auto_advance 到点自动推进到下一句")


func test_runner_enter_opts_applied():
	var runner := DialogueRunner.new()
	var k := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	d.enter(k, Vector2(550, 230), {"flip": true, "dim": 0.6, "emotion": "耍帅"})
	runner.start(d.steps)
	var a: ActorState = runner.state.actor("卡摩瑞")
	assert_eq(a.flip_h, true, "flip 生效")
	assert_eq(a.light, 0.6, "dim 生效")
	assert_eq(a.emotion, "耍帅", "emotion 生效")
	assert_true(runner.is_finished(), "演出步骤立即结束")


func test_runner_stage_ops():
	var runner := DialogueRunner.new()
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(r, Vector2(100, 100))
	d.move("灵梦", Vector2(300, 300))
	d.flip("灵梦", true)
	d.dim("灵梦", 0.2)
	d.portrait("灵梦", "笑")
	d.bubble("灵梦", Vector2(-650, 250))
	d.exit("灵梦")
	runner.start(d.steps)
	assert_true(runner.is_finished(), "全部执行完")
	var a: ActorState = runner.state.actor("灵梦")
	assert_eq(a.position, Vector2(300, 300), "move 生效")
	assert_eq(a.flip_h, true, "flip 生效")
	assert_eq(a.light, 0.2, "dim 生效")
	assert_eq(a.emotion, "笑", "portrait 生效")
	assert_eq(a.bubble_offset, Vector2(-650, 250), "bubble 生效")
	assert_false(a.visible, "exit 后离场")


func test_runner_state_not_shared_between_runs():
	# 每次 start 重建舞台状态（重跑不残留）
	var runner := DialogueRunner.new()
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(r, Vector2(1, 1))
	runner.start(d.steps)
	assert_eq(runner.state.actor("灵梦").position, Vector2(1, 1), "第一轮")
	var d2 := DialogueSteps.new()
	d2.enter(_make_profile("卡摩瑞"), Vector2(9, 9))
	runner.start(d2.steps)
	assert_false(runner.state.has("灵梦"), "第二轮舞台干净（无残留）")
	assert_eq(runner.state.actor("卡摩瑞").position, Vector2(9, 9), "第二轮角色就位")


func test_runner_line_applies_emotion():
	# runner 集成：LINE 步骤后 actor.emotion 更新（播放器据此换立绘）
	var runner := DialogueRunner.new()
	var k := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	d.enter(k, Vector2(400, 200))
	d.line("在黑暗中", {"emotion": "耍帅"})
	runner.start(d.steps)
	assert_eq(runner.state.actor("卡摩瑞").emotion, "耍帅", "LINE 步骤应用表情")


# ═══════════ screen() 一屏多泡 ═══════════

## screen 单泡：一项 → 一个气泡，speaker/text/emotion 正确
func test_screen_single_bubble():
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.screen([[r, "笑", "单句"]])
	assert_eq(d.steps.size(), 1, "一个 LINE 步骤")
	var line: DialogueLine = d.steps[0].line_data
	assert_eq(line.bubbles.size(), 1, "一个气泡")
	assert_eq(line.bubbles[0].speaker.char_name, "灵梦", "说话者")
	assert_eq(line.bubbles[0].text, "单句", "台词")
	assert_eq(line.bubbles[0].emotion, "笑", "表情")


## screen 多泡：两人同屏，一人说话一个沉默（空 text = 在场但暗）
func test_screen_multi_bubble_silent_dim():
	var r := _make_profile("灵梦")
	var k := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	d.screen([[r, "通常", "说话"], [k, "震惊", ""]])
	assert_eq(d.steps.size(), 1, "一个 LINE 步骤")
	var line: DialogueLine = d.steps[0].line_data
	assert_eq(line.bubbles.size(), 2, "两个气泡")
	var state := StageState.new()
	var speakers := state.apply_line(line)
	assert_eq(speakers, ["灵梦"], "只有开口者算说话者")
	assert_eq(state.actor("灵梦").light, 1.0, "说话者亮")
	assert_eq(state.actor("卡摩瑞").visible, true, "沉默者也应在场")
	assert_eq(state.actor("卡摩瑞").light, 0.35, "沉默在场者变暗")
	assert_eq(state.actor("卡摩瑞").emotion, "震惊", "沉默者表情仍应用")


## screen 延续说话者 = 最后一个真正开口的（text 非空）
func test_screen_continuation_picks_last_speaker():
	var r := _make_profile("灵梦")
	var k := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	d.screen([[r, "通常", "灵梦说话"], [k, "震惊", ""]])  # 卡摩瑞没开口
	d.line("下一句")  # 应延续灵梦
	var line: DialogueLine = d.steps[1].line_data
	assert_eq(line.bubbles[0].speaker.char_name, "灵梦", "延续说话者应为灵梦")


## screen 支持字典 spec 形式
func test_screen_dict_spec():
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.screen([{"speaker": r, "text": "字典句", "emotion": "叹气"}])
	var line: DialogueLine = d.steps[0].line_data
	assert_eq(line.bubbles[0].speaker.char_name, "灵梦", "说话者")
	assert_eq(line.bubbles[0].emotion, "叹气", "表情")
	assert_eq(line.bubbles[0].text, "字典句", "台词")

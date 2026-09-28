extends GutTest
## 对话系统测试：StageState / DialogueSteps DSL / DialogueRunner（纯逻辑，不进树）
## 台词内联版：line() 直接收文本，无台词库/无 id

# ═══════════ 辅助 ═══════════

func _make_profile(char_name: String) -> CharacterProfile:
	var p := CharacterProfile.new()
	p.char_name = char_name
	return p


func _attach(runner: DialogueRunner) -> Dictionary:
	var seen: Dictionary = {
		shown = [], events = [], finished = 0, states = [],
	}
	runner.line_shown.connect(func(line, _speakers, _state): seen.shown.append(line))
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
	d.flip(p, false)
	d.move(p, Vector2(300, 200), 0.8)
	d.portrait(p, "笑")
	d.dim(p, 0.4)
	d.exit(p)
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
	assert_eq(d.steps[4].is_flip, false, "flip 值")
	assert_eq(d.steps[5].pos, Vector2(300, 200), "move 位置")
	assert_eq(d.steps[6].emotion, "笑", "portrait 表情")
	assert_eq(d.steps[7].light, 0.4, "dim 明暗")
	assert_eq(d.steps[8].type, DialogueStep.Type.EXIT, "8 = exit")


# ═══════════ 情绪：不声明就不动 ═══════════

## `portrait("笑")` 之后的 `line()` **不该**把表情冲回"通常"（"声明即改变，不声明不动"）。
## 回归：`_build_line` 曾默认 `emotion = "通常"` → 句柄写法 `reimu.portrait("笑").line(…)` 静默丢表情。
func test_line_keeps_emotion_unless_declared():
	var p := _make_profile("灵梦")
	var d := DialogueSteps.new()
	var h := d.enter(p, Vector2.ZERO)
	h.portrait("笑").line("笑着说")
	h.line("继续（仍未声明 → 还是笑）")
	h.line("复位", {"emotion": "通常"})

	var first_line: DialogueLine = null
	for step in d.steps:
		if step.type == DialogueStep.Type.LINE:
			first_line = step.line_data
			break
	assert_not_null(first_line, "应有 LINE 步")
	assert_eq(first_line.bubbles[0].emotion, "", "气泡 emotion 默认空（不声明不动）")
	var report := DialogueDryRun.play(d.steps)
	assert_eq(report["emotions"], ["笑", "笑", "通常"], "不声明则保持；显式声明才改")


# ═══════════ 句柄写法（ActorHandle） ═══════════

## 句柄动词与低层（收 profile 的）动词**产物完全一致** —— 句柄只是薄委托，不是第二套构建逻辑
func test_actor_handle_matches_low_level_verbs():
	var p := _make_profile("灵梦")
	var a := DialogueSteps.new()
	var ha := a.enter(p, Vector2(10, 20))
	ha.line("甲")
	ha.portrait("笑").move(Vector2(30, 40), 0.5).flip().dim(0.4).bubble(Vector2(1, 2))
	ha.exit()

	var b := DialogueSteps.new()
	b.enter(p, Vector2(10, 20))
	b.say(p, "甲")
	b.portrait(p, "笑")
	b.move(p, Vector2(30, 40), 0.5)
	b.flip(p, true)
	b.dim(p, 0.4)
	b.bubble(p, Vector2(1, 2))
	b.exit(p)

	assert_eq(a.steps.size(), b.steps.size(), "步骤数一致")
	for i in a.steps.size():
		assert_eq(a.steps[i].type, b.steps[i].type, "第 %d 步类型一致" % i)
		assert_eq(a.steps[i].char_name, b.steps[i].char_name, "第 %d 步 actor key 一致" % i)


## 动词一律返回 self（可链式），且全部落到同一个 actor key —— "谁"是接收者，传不错人
func test_actor_handle_chainable_on_same_actor():
	var p := _make_profile("卡摩瑞")
	var d := DialogueSteps.new()
	var h := d.enter(p, Vector2.ZERO)
	assert_same(h.portrait("笑"), h, "动词返回 self")
	assert_same(h.move(Vector2(5, 6)), h, "链式仍返回同一句柄")
	assert_same(h.line("台词"), h, "说话也能链")
	for step in d.steps:
		# 两种载荷形态：LINE 的说话者在 line_data.bubbles 里；演出动词才用 char_name
		if step.type == DialogueStep.Type.ENTER:
			continue
		elif step.type == DialogueStep.Type.LINE:
			assert_eq((step.line_data as DialogueLine).bubbles[0].speaker.char_name, "卡摩瑞",
				"句柄说的那句，说话者应是该句柄的角色")
		else:
			assert_eq(step.char_name, "卡摩瑞", "演出动词落到同一 actor key")


## 退场语义：句柄记得 `is_exited()`；DSL 清掉在场标记（允许"退场后再登场"）；
## 退场后再调度动词**只告警、不拦步骤**（剧本仍能跑完，问题早暴露）
func test_actor_handle_exit_semantics():
	var p := _make_profile("灵梦")
	var d := DialogueSteps.new()
	var h := d.enter(p, Vector2.ZERO)
	assert_true(d.has_entered(p), "登场后 has_entered 为真")
	h.exit()
	assert_true(h.is_exited(), "句柄记得已退场")
	assert_false(d.has_entered(p), "退场后清在场标记（允许再登场）")
	h.portrait("笑")
	assert_eq(d.steps.back().type, DialogueStep.Type.PORTRAIT, "退场后调度仍加入步骤（不拦）")


## 同一角色连续两次 enter（漏了 exit）→ 告警但两步都落（不静默吞掉剧本）
func test_enter_twice_without_exit_keeps_both_steps():
	var p := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(p, Vector2.ZERO)
	d.enter(p, Vector2(50, 50))
	assert_eq(d.steps.size(), 2, "两次 enter 都落步骤")
	assert_true(d.has_entered(p), "仍在场上")


## enter(null) 不崩：跳过该步骤，句柄仍可持有（动词各自告警）
func test_enter_null_profile_is_safe():
	var d := DialogueSteps.new()
	var h := d.enter(null, Vector2.ZERO)
	assert_eq(d.steps.size(), 0, "null profile → 不落步骤")
	assert_not_null(h, "仍返回句柄（可继续链式）")
	assert_false(h.is_exited(), "未退场")


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
	assert_true(state.actor("灵梦").is_visible, "说话者在场")


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
	assert_true(a.is_visible, "在场")
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
	assert_eq(a.is_flip_h, true, "flip 生效")
	assert_eq(a.light, 0.6, "dim 生效")
	assert_eq(a.emotion, "耍帅", "emotion 生效")
	assert_true(runner.is_finished(), "演出步骤立即结束")


## 演出版动词收 **CharacterProfile**（与 enter/say 一致），但落进步骤的是 actor key（`char_name`）——
## 锁住这条转换：播放器是按**名字**查 actor 的，谁也别"顺手"把步骤里的 key 改成 profile。
func test_stage_ops_take_profile_and_store_actor_key():
	var p := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(p, Vector2.ZERO)
	d.move(p, Vector2(10, 20))
	d.exit(p)
	assert_eq(d.steps[1].char_name, "灵梦", "步骤里落的是 actor key（名字）")
	assert_eq(d.steps[2].char_name, "灵梦", "exit 同样落 actor key")
	assert_eq(d.steps[2].type, DialogueStep.Type.EXIT, "类型仍是 EXIT")


## profile 为 null → 告警但不崩（步骤照样加、key 空 → 播放时自然找不到 actor，不会误伤别人）
func test_stage_ops_tolerate_null_profile():
	var d := DialogueSteps.new()
	d.exit(null)
	assert_eq(d.steps.size(), 1, "步骤仍加入")
	assert_eq(d.steps[0].char_name, "", "key 为空")


func test_runner_stage_ops():
	var runner := DialogueRunner.new()
	var r := _make_profile("灵梦")
	var d := DialogueSteps.new()
	d.enter(r, Vector2(100, 100))
	d.move(r, Vector2(300, 300))
	d.flip(r, true)
	d.dim(r, 0.2)
	d.portrait(r, "笑")
	d.bubble(r, Vector2(-650, 250))
	d.exit(r)
	runner.start(d.steps)
	assert_true(runner.is_finished(), "全部执行完")
	var a: ActorState = runner.state.actor("灵梦")
	assert_eq(a.position, Vector2(300, 300), "move 生效")
	assert_eq(a.is_flip_h, true, "flip 生效")
	assert_eq(a.light, 0.2, "dim 生效")
	assert_eq(a.emotion, "笑", "portrait 生效")
	assert_eq(a.bubble_offset, Vector2(-650, 250), "bubble 生效")
	assert_false(a.is_visible, "exit 后离场")


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
	assert_eq(state.actor("卡摩瑞").is_visible, true, "沉默者也应在场")
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

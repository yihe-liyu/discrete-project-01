extends GutTest
## BossHandle（场景动词句柄）纯逻辑测试：无树，校验"缺槽/容错/不崩"语义。
## 注册表不再走 StageObjects autoload —— 由 StageContext.objects 持有并注入句柄。

func test_missing_slot_resolves_null():
	var h := BossHandle.new("boss_missing", null, "？？？")
	assert_null(h.resolve(), "未注册槽位应解析为 null")
	assert_false(h.exists(), "未注册槽位 exists 应为 false")

func test_verbs_tolerate_missing_boss():
	var h := BossHandle.new("boss_missing", null, "？？？")
	h.reveal("卡摩瑞")
	h.set_name("某名")
	h.hide_name()
	h.show_name()
	h.show_phase_dots()
	h.hide_phase_dots()
	h.phase(0)
	h.phase(0, true)
	h.retreat(Vector2.ZERO)
	h.defeat()
	h.enter(Vector2.ZERO, Vector2.ZERO)
	assert_true(true, "缺 Boss 时动词不应崩溃")

func test_resolve_after_register():
	# 纯逻辑：注册表挂在 StageContext.objects（无场景依赖），句柄持同一注册表
	var ctx := StageContext.new(null)
	var b := Boss.new()
	b.name = "TestBoss"
	ctx.objects.register("boss_test", b, Boss)
	var h := BossHandle.new("boss_test", null, "？？？", ctx.objects)
	assert_true(h.exists(), "注册后 exists 应为 true")
	assert_same(h.resolve(), b, "resolve 应返回注册对象")
	h.reveal("测试名")
	assert_eq(b.hud.get_name(), "测试名", "reveal 应改写显示名")
	assert_true(b.hud.is_name_shown(), "reveal 应亮出名字节点")
	h.set_name("只改名")
	assert_eq(b.hud.get_name(), "只改名", "set_name 只改显示名")
	assert_true(b.hud.is_name_shown(), "set_name 不动显隐（仍亮着）")
	h.hide_name()
	assert_false(b.hud.is_name_shown(), "hide_name 应收起名字节点")
	h.show_phase_dots()
	assert_true(b.hud.is_phase_dots_shown(), "show_phase_dots 应亮出进度点")
	h.hide_phase_dots()
	assert_false(b.hud.is_phase_dots_shown(), "hide_phase_dots 应收起进度点")
	ctx.objects.unregister("boss_test")
	assert_false(h.exists(), "注销后 exists 应为 false")
	b.free()


## 难度专属阶段：phase(index) 必须按当前难度取（回归：曾只取 phases_normal → Easy/Hard/Lunatic 串成 Normal 的卡）
func test_phase_uses_current_difficulty():
	var fin: BossData = BossCatalog.boss(1, 1)
	if fin == null:
		pending("stage 1 无第二个 Boss")
		return
	var prev_diff := SaveData.selected_difficulty
	var prev_stage := SaveData.current_stage_id
	SaveData.current_stage_id = 0   # _stage_id=0 → 身份解析 null，不污染符卡簿

	var ctx := StageContext.new(null)
	var b := Boss.new()
	add_child_autofree(b)
	b.setup(fin, null)
	ctx.objects.register("boss_diff", b, Boss)
	var h := BossHandle.new("boss_diff", fin, "？？？", ctx.objects)

	for diff in [0, 1, 2, 3]:
		var arr := fin.phases_for_difficulty(diff)
		if arr.is_empty():
			continue
		SaveData.selected_difficulty = diff
		h.phase(1)
		assert_eq(b.current_phase(), arr[1], "难度 %d 第 1 槽应进 %s" % [diff, arr[1].name])

	ctx.objects.unregister("boss_diff")
	SaveData.selected_difficulty = prev_diff
	SaveData.current_stage_id = prev_stage


# ═══════════ 收尾动词（finish_stage） ═══════════

## 记录 `finish_stage()` 调用的运行时替身（只关心"有没有转达"，不真跑关卡）
class RuntimeSpy:
	extends StageRuntime
	var finish_calls: int = 0
	func finish_stage() -> void:
		finish_calls += 1


## 记录 `spawn_boss` 调用的运行时替身（验 `boss()` 的槽位幂等）
class SpawnSpy:
	extends StageRuntime
	var spawns: int = 0
	func spawn_boss(_data: BossData, _position: Vector2, _p_ctx: StageContext = null) -> Boss:
		spawns += 1
		return null


## 活着的关卡上下文（runner 在跑）—— 事件派发要求关卡存活（`StageDirector._route`）
func _live_ctx(p_stage: StageRuntime = null) -> StageContext:
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	runner.run(func() -> bool: return true)
	var ctx := StageContext.new(runner)
	ctx.stage = p_stage
	return ctx


## `StageDirector.finish_stage()` 必须转达到 `ctx.stage.finish_stage()`（内容只碰导演，不摸运行时）
func test_finish_stage_delegates_to_runtime():
	var rt := RuntimeSpy.new()
	var ctx := StageContext.new(null)
	ctx.stage = rt
	var d := StageDirector.new(ctx)
	d.finish_stage()
	assert_eq(rt.finish_calls, 1, "导演应把收尾转达给 StageRuntime.finish_stage()")
	rt.free()


## 没装配 stage（纯逻辑/测试上下文）→ 只告警，不崩
func test_finish_stage_tolerates_missing_stage():
	var ctx := StageContext.new(null)
	var d := StageDirector.new(ctx)
	d.finish_stage()
	assert_true(true, "ctx.stage 为空时不应崩溃")


## `dialogue` 收 **DialogueSteps 本身**（不是 `.steps` 数组）：null 安全跳过；
## 无 runner（纯逻辑 ctx）时静默不播，不崩。
## （类型本身由编译期保证：传 Array 会直接编译失败 —— 这正是改成强类型参数的目的）
func test_dialogue_takes_steps_object_and_tolerates_null():
	var d := StageDirector.new(StageContext.new(null))
	d.dialogue(null)
	d.dialogue(DialogueSteps.new())
	assert_true(true, "dialogue 不应因 null / 无 runner 而崩")


## **事件驱动收尾**（stage01 战后对话就是这么接的）：对话行间事件 `stage_end` → 收尾。
## 为什么必须走事件而不是时间轴 `wait(秒)`：不依赖"对话会 pause 宿主 runner"这个播放器内部行为
## （改掉就静默在对话中途收尾），且 wait 偏移是从序列游标算的绝对值。
func test_stage_end_event_routes_to_finish_stage():
	var rt := RuntimeSpy.new()
	var d := StageDirector.new(_live_ctx(rt))
	d.on("stage_end", func(): d.finish_stage())

	GameEvents.dialogue_event.emit("stage_end")

	assert_eq(rt.finish_calls, 1, "行间事件应把收尾转达到 StageRuntime.finish_stage()")
	d.dispose()   # 断 autoload 连接（场景 _exit_tree 的同一约定）
	rt.free()


## 关卡已拆 / 未装配（无 runner）→ 事件**不派发**。
## 这条是"handler 里不必再写 `if ctx.active()`"的依据。
func test_dialogue_events_ignored_when_stage_not_live():
	var called := [0]
	var d := StageDirector.new(StageContext.new(null))   # 无 runner → active() == false
	d.on("stage_end", func(): called[0] += 1)

	GameEvents.dialogue_event.emit("stage_end")

	assert_eq(called[0], 0, "关卡不存活时不该派发事件")
	d.dispose()


## `boss()` **同名槽位幂等**：槽位已有 Boss → 不再 spawn（内容不必自己写 exists() 防重入）
func test_boss_does_not_respawn_existing_slot():
	var spy := SpawnSpy.new()
	var ctx := _live_ctx(spy)
	var existing := Boss.new()
	add_child_autofree(existing)
	ctx.objects.register("boss_final", existing, Boss)
	var d := StageDirector.new(ctx)

	var h := d.boss("boss_final", BossData.new(), Vector2(1000, 500), Vector2(100, 250))

	assert_eq(spy.spawns, 0, "槽位已有 Boss → 不该再 spawn")
	assert_same(h.resolve(), existing, "应返回指向同一只 Boss 的句柄")
	d.dispose()
	ctx.objects.unregister("boss_final")
	spy.free()


## 反向：槽位是空的 → 正常走 spawn（幂等不等于不生成）
func test_boss_spawns_when_slot_empty():
	var spy := SpawnSpy.new()
	var d := StageDirector.new(_live_ctx(spy))
	d.boss("boss_empty_slot", BossData.new(), Vector2(1000, 500), Vector2(100, 250))
	assert_eq(spy.spawns, 1, "空槽位应 spawn 一次")
	d.dispose()
	spy.free()


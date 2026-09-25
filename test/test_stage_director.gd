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


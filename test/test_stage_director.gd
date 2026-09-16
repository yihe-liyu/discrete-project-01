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
	assert_eq(b.get_boss_name(), "测试名", "reveal 应改写显示名")
	assert_true(b.is_name_shown(), "reveal 应亮出名字节点")
	h.hide_name()
	assert_false(b.is_name_shown(), "hide_name 应收起名字节点")
	h.show_phase_dots()
	assert_true(b.is_phase_dots_shown(), "show_phase_dots 应亮出进度点")
	h.hide_phase_dots()
	assert_false(b.is_phase_dots_shown(), "hide_phase_dots 应收起进度点")
	ctx.objects.unregister("boss_test")
	assert_false(h.exists(), "注销后 exists 应为 false")
	b.free()

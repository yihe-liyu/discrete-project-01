extends GutTest
## BossHandle（场景动词句柄）纯逻辑测试：无树，校验"缺槽/容错/不崩"语义。
## StageDirector 的 boss()/dialogue() 依赖真实场景/资源，留给集成测试；这里只测句柄。

func test_missing_slot_resolves_null():
	var h := BossHandle.new("boss_missing", null, "？？？")
	assert_null(h.resolve(), "未注册槽位应解析为 null")
	assert_false(h.exists(), "未注册槽位 exists 应为 false")

func test_verbs_tolerate_missing_boss():
	var h := BossHandle.new("boss_missing", null, "？？？")
	h.reveal("卡摩瑞")
	h.hide_name()
	h.phase(0)
	h.phase(0, true)
	h.retreat(Vector2.ZERO)
	h.enter(Vector2.ZERO, Vector2.ZERO)
	assert_true(true, "缺 Boss 时动词不应崩溃")

func test_resolve_after_register():
	# 在真实场景上注册一个假 Boss 槽位，验证 resolve/exists/reveal 走 StageObjects
	var b := Boss.new()
	b.name = "TestBoss"
	StageObjects.register("boss_test", b, Boss)
	var h := BossHandle.new("boss_test", null, "？？？")
	assert_true(h.exists(), "注册后 exists 应为 true")
	assert_same(h.resolve(), b, "resolve 应返回注册对象")
	h.reveal("测试名")
	assert_eq(b.get_boss_name(), "测试名", "reveal 应改写显示名")
	StageObjects.unregister("boss_test")
	b.free()

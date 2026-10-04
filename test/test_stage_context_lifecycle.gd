extends GutTest
## StageContext 生命周期：验证服务弱引用 ctx 后不形成 RefCounted 环
## 关卡退出后 ctx 应能被正常回收（阶段 2 服务层核心防泄漏回归）

func _make_runner() -> CoroutineRunner:
	var runner := CoroutineRunner.new()
	add_child_autofree(runner)
	return runner


func test_stage_context_with_dialogue_service_is_freed():
	var runner := _make_runner()
	var ctx := StageContext.new(runner)
	var svc: DialogueService = ctx.dialogue
	assert_not_null(svc, "dialogue 服务应创建成功")
	assert_eq(svc.ctx, ctx, "服务应能访问回 ctx")
	var ctx_ref: WeakRef = weakref(ctx)
	var svc_ref: WeakRef = weakref(svc)
	ctx = null
	svc = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(ctx_ref.get_ref(), "StageContext 应被释放（无 RefCounted 环）")
	assert_null(svc_ref.get_ref(), "DialogueService 应随 ctx 释放")


func test_stage_context_with_item_service_is_freed():
	var runner := _make_runner()
	var ctx := StageContext.new(runner)
	var svc: ItemService = ctx.items
	assert_not_null(svc, "item 服务应创建成功")
	var ctx_ref: WeakRef = weakref(ctx)
	var svc_ref: WeakRef = weakref(svc)
	ctx = null
	svc = null
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(ctx_ref.get_ref(), "StageContext 应被释放（无 RefCounted 环）")
	assert_null(svc_ref.get_ref(), "ItemService 应随 ctx 释放")


## ═══ B3 守卫：DecorManager 由背景**声明式持有**，不按名字找、不动态建节点 ═══

func _decor_child_count(parent: Node) -> int:
	var n := 0
	for child in parent.get_children():
		if child is DecorManager:
			n += 1
	return n


func test_ctx_decor_reads_declared_manager_not_name_lookup():
	var bg := StageBackground.new()
	autofree(bg)
	var mgr := DecorManager.new()
	mgr.name = "Deco"      # 故意不叫 DecorManager：旧实现按名字找不到就会另建一个
	bg.add_child(mgr)

	var rt := StageRuntime.new()
	autofree(rt)
	rt.current_background = bg
	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := StageContext.new(runner)
	ctx.stage = rt

	assert_eq(ctx.get_decor(), mgr, "应返回背景声明的 DecorManager（按类型解析，不按名字）")
	assert_eq(ctx.decor, mgr, "便捷属性与 get_decor() 同源")
	assert_eq(_decor_child_count(bg), 1, "不得运行时 add_child 另建（旧实现会多出一个 DecorManager）")


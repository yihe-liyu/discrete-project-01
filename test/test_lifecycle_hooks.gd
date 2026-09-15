extends GutTest
## b2b：LifecycleHooks 名字注册表 + on_end_call 用名字。

const LIFECYCLE_HOOKS_SCRIPT = preload("res://scripts/kernel_bridge/lifecycle/lifecycle_hooks.gd")


func after_each() -> void:
	LIFECYCLE_HOOKS_SCRIPT.clear()


func test_register_and_resolve() -> void:
	var calls := [0]
	LIFECYCLE_HOOKS_SCRIPT.register(&"probe", func(): calls[0] += 1)
	var fn: Callable = LIFECYCLE_HOOKS_SCRIPT.resolve(&"probe")
	assert_true(fn.is_valid(), "注册的名字应能解析")
	fn.call()
	assert_eq(calls[0], 1, "应调用一次")


func test_unknown_name_is_invalid() -> void:
	assert_false(LIFECYCLE_HOOKS_SCRIPT.resolve(&"nope").is_valid(), "未注册的名字应返回无效 Callable")


func test_named_hook_in_signature() -> void:
	var a := BulletLifecycle.non_mid_flee(150.0, 100.0, &"h")
	var b := BulletLifecycle.non_mid_flee(150.0, 100.0, &"h")
	var c := BulletLifecycle.non_mid_flee(150.0, 100.0, &"other")
	assert_eq(a.content_signature(), b.content_signature(), "同名 hook 应同签名（→ 共用 program）")
	assert_ne(a.content_signature(), c.content_signature(), "不同名 hook 应异签名")

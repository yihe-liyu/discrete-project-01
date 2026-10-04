extends GutTest
## MenuNav 子页面容器注入契约（R2：不再 current_scene 字符串搜 PageHost）

## 每条用例后复位全局：暂停树 / GameManager 状态（断言中途失败也不许漏到别的用例）
func after_each() -> void:
	get_tree().paused = false
	GameManager.current_state = GameManager.AppState.MENU

func test_injected_host_receives_pushed_page():
	var nav := MenuNav.new()
	nav.setup(self)
	assert_false(nav.has_page_host(), "初始未注入 host")

	var host := Control.new()
	add_child_autofree(host)
	nav.set_page_host(host)
	assert_true(nav.has_page_host(), "注入后应有 host")

	var page: BasePage = nav.push("res://scenes/ui/manual_menu.tscn")
	assert_not_null(page, "注入 host 后应成功 push")
	if page:
		assert_eq(page.get_parent(), host, "页面应挂在注入的 PageHost 下")
	nav.clear_pages()
	await wait_frames(1)


## ═══ B4 守卫：覆盖层状态切换走**显式信号**，不再 `_parent.set_state.call_deferred(...)` ═══

## `self`（GutTest）**没有** `set_state` 方法 —— 旧实现只能靠帧末的动态调用报错；
## 新实现发出显式信号，任何宿主都能按自己的时序接。
func test_overlay_requests_state_via_explicit_signals():
	var nav := MenuNav.new()
	nav.setup(self)
	watch_signals(nav)

	nav.push_overlay("res://scenes/ui/pause_menu.tscn")
	assert_signal_emitted(nav, "pause_requested", "进覆盖层应发 pause_requested（不再动态方法名切状态）")

	nav.pop_overlay()
	get_tree().paused = false      # 万一上面的断言提前返回，别把整棵树的暂停留给后面的用例
	assert_signal_emitted(nav, "resume_requested", "退覆盖层应发 resume_requested")


## 源码守卫：MenuNav 里不许再出现动态方法名的状态切换（机械判据，注释已按此措辞）
func test_menu_nav_source_has_no_dynamic_set_state_call():
	var f := FileAccess.open("res://scripts/scenes/menu_nav.gd", FileAccess.READ)
	assert_not_null(f, "应能读到 menu_nav.gd 源码")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	assert_false(src.contains("set_state.call_deferred"), "不许动态方法名切状态")
	assert_false(src.contains("call_deferred(\"set_state\")"), "不许字符串方法名切状态")
	assert_true(src.contains("pause_requested.emit()"), "应改发显式信号")
	assert_true(src.contains("resume_requested.emit()"), "应改发显式信号")


## 端到端：GameManager 真的接上了信号，且仍保持旧 `call_deferred` 的「帧末才切状态」时序。
func test_game_manager_applies_requested_state_deferred():
	var old := GameManager.current_state
	GameManager.current_state = GameManager.AppState.PLAYING

	GameManager.pause_game()
	get_tree().paused = false      # 别把暂停留给后续用例；状态切换仍等帧末
	assert_eq(GameManager.current_state, GameManager.AppState.PLAYING,
		"CONNECT_DEFERRED：本帧内不应立刻切状态（保持旧 call_deferred 时序）")
	await wait_frames(1)
	assert_eq(GameManager.current_state, GameManager.AppState.PAUSED, "帧末应切到 PAUSED")

	GameManager.resume_game()
	await wait_frames(1)
	assert_eq(GameManager.current_state, GameManager.AppState.PLAYING, "帧末应切回 PLAYING")

	GameManager.current_state = old


## ═══ B5 守卫：暂停菜单路径是**唯一来源常量**，不许散落字面量 ═══

func test_pause_menu_path_is_single_source_constant():
	assert_eq(GameManager.PAUSE_MENU_SCENE, "res://scenes/ui/pause_menu.tscn", "常量值 = 暂停菜单场景")

	var f := FileAccess.open("res://scripts/autoload/game_manager.gd", FileAccess.READ)
	assert_not_null(f, "应能读到 game_manager.gd 源码")
	if f == null:
		return
	var src := f.get_as_text()
	f.close()
	assert_eq(src.count("res://scenes/ui/pause_menu.tscn"), 1,
		"路径字面量只允许出现在常量定义处（旧实现两处硬编码 = 改一处漏一处）")
	assert_eq(src.count("push_overlay(PAUSE_MENU_SCENE)"), 2, "两处覆盖层入口都应引用常量")

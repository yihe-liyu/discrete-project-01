extends GutTest
## MenuNav 子页面容器注入契约（R2：不再 current_scene 字符串搜 PageHost）

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

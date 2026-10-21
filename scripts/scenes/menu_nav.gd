## 统一菜单导航：普通页面栈 + 覆盖层栈的唯一 push / pop 入口。
##
## [b]模型[/b][br]
## 普通页面挂在 MainMenu 注入的 PageHost 下；覆盖层挂独立 CanvasLayer(64)，并暂停 SceneTree。
## 页面须继承 BasePage；MenuNav 自动调 on_enter / on_leave / on_activate / on_deactivate。
## [codeblock]
## # 游戏内通常经 GameManager 包装
## GameManager.push_page("res://scenes/ui/difficulty_screen.tscn")
## GameManager.pop_page()
## # 覆盖层
## GameManager.push_overlay_menu(pause_page)
## GameManager.pop_overlay_menu(pause_page)
## [/codeblock]
## 直接实例时：setup(parent) → set_page_host(host) → push / pop。
## [br]
## [b]边界[/b][br]
## - push 前必须 set_page_host，否则 push_error 并返回 null。[br]
## - 覆盖层把 tree.paused 置 true；只有最后一个弹出才恢复。[br]
## - page.finished 不会自动 pop，由调用方决定。[br]
## - clear_pages / clear_overlays 只清节点，不调 on_leave、也不恢复 paused。
class_name MenuNav
extends RefCounted

## 页面栈变化（current = 新栈顶，previous = 旧栈顶 / 被弹出页）。
signal page_changed(current: Node, previous: Node)
## 请求宿主切到暂停状态；GameManager 用 CONNECT_DEFERRED 连接，保持“帧末切状态”时序。
signal pause_requested()
## 请求宿主恢复；与 pause_requested 对称。
signal resume_requested()

# ═══ 过渡设置 ═══

# ═══ 内部状态 ═══

var _parent: Node                     # GameManager
var _host: Control                    # 子页面容器（MainMenu 注入 %PageHost；R2：不再场景搜索）
var _page_stack: Array[BasePage] = []  # 普通页面栈
var _overlay_stack: Array[BasePage] = []  # 覆盖层栈


# ═══ 初始化 ═══

## 绑定宿主（GameManager）：取 tree、发信号都经它。
func setup(parent: Node) -> void:
	_parent = parent


## 注入子页面容器（由拥有它的场景调用，如 MainMenu 的 %PageHost）。
func set_page_host(host: Control) -> void:
	_host = host


## 是否已注入子页面容器
func has_page_host() -> bool:
	return is_instance_valid(_host)


# ═══ 页面栈 ═══

## 加载并推入子页面：隐藏当前栈顶、挂到 PageHost、on_enter、发 page_changed。
## 未注入 PageHost → push_error 并返回 null。
func push(page_path: String) -> BasePage:
	if not has_page_host():
		push_error("MenuNav: 未注入 PageHost（应由 MainMenu 注册）——拒绝 push 子页面")
		return null

	# 隐藏当前栈顶
	if not _page_stack.is_empty():
		var prev: BasePage = _page_stack[-1]
		if is_instance_valid(prev):
			_set_active(prev, false)

	# 加载 & 添加新页面
	var page: BasePage = _load_page(page_path)
	_page_stack.append(page)
	_host.add_child(page)
	_connect_signals(page)
	page.visible = true

	page.on_enter()

	page_changed.emit(page, _page_stack[-2] if _page_stack.size() > 1 else null)
	return page


## 弹出当前页面：on_leave、恢复上一层 on_activate、发 page_changed。
func pop() -> void:
	if _page_stack.is_empty():
		return

	var page: BasePage = _page_stack.pop_back()
	_disconnect_signals(page)

	if is_instance_valid(page):
		page.on_leave()

	# 恢复上一层
	if not _page_stack.is_empty():
		var prev = _page_stack[-1]
		if is_instance_valid(prev):
			prev.visible = true
			prev.on_activate()

	page_changed.emit(_page_stack[-1] if not _page_stack.is_empty() and is_instance_valid(_page_stack[-1]) else null, page)


## 弹出到指定页面（保留该页），中间页面直接 queue_free。
func pop_to(page: BasePage) -> void:
	while _page_stack.size() > 1 and _page_stack[-1] != page:
		var dead: BasePage = _page_stack.pop_back()
		_disconnect_signals(dead)
		if is_instance_valid(dead):
			dead.queue_free()
	# 重连目标页
	if _page_stack[-1] == page:
		_connect_signals(page)


## 清空页面栈：所有子页面 queue_free；不调 on_leave、不发 page_changed。
func clear_pages() -> void:
	while not _page_stack.is_empty():
		var page = _page_stack.pop_back()
		if is_instance_valid(page):
			_disconnect_signals(page)
			page.queue_free()


## 当前子页面栈顶；空栈 = null。
func get_top_page() -> BasePage:
	return _page_stack[-1] if not _page_stack.is_empty() else null


## 清空覆盖层：释放页面与 wrapper；不恢复 tree.paused、不发 resume_requested。
func clear_overlays() -> void:
	while not _overlay_stack.is_empty():
		var page: BasePage = _overlay_stack.pop_back()
		_disconnect_signals(page)
		if is_instance_valid(page):
			page.queue_free()
		# 清理 CanvasLayer wrapper
		var wrapper := page.get_parent()
		if wrapper and wrapper is CanvasLayer:
			wrapper.queue_free()


## 是否有子页面打开。
func is_page_open() -> bool:
	return not _page_stack.is_empty()


# ═══ 覆盖层（暂停 / Game Over / 通关） ═══

## 加载并推入覆盖层：挂 CanvasLayer(64)、暂停 tree、发 pause_requested、on_enter。
func push_overlay(page_path: String) -> BasePage:
	var page: BasePage = _load_page(page_path)
	_overlay_stack.append(page)
	page.process_mode = Node.PROCESS_MODE_ALWAYS

	var wrapper: CanvasLayer = CanvasLayer.new()
	wrapper.layer = 64
	wrapper.process_mode = Node.PROCESS_MODE_ALWAYS
	wrapper.add_child(page)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)

	var tree: SceneTree = _parent.get_tree()
	tree.root.add_child(wrapper)
	_connect_signals(page)

	pause_requested.emit()
	tree.paused = true

	page.on_enter()

	return page


## 接受已实例化的覆盖层（兼容旧 API），行为同 push_overlay。
func add_overlay_instance(page: BasePage) -> void:
	_overlay_stack.append(page)
	page.process_mode = Node.PROCESS_MODE_ALWAYS

	var wrapper: CanvasLayer = CanvasLayer.new()
	wrapper.layer = 64
	wrapper.process_mode = Node.PROCESS_MODE_ALWAYS
	wrapper.add_child(page)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)

	_parent.get_tree().root.add_child(wrapper)
	_connect_signals(page)
	pause_requested.emit()
	_parent.get_tree().paused = true
	page.on_enter()


## 弹出当前覆盖层：on_leave、释放 wrapper；空栈时恢复 tree.paused 并发 resume_requested。
func pop_overlay() -> void:
	if _overlay_stack.is_empty():
		return

	var page: BasePage = _overlay_stack.pop_back()
	_disconnect_signals(page)

	if is_instance_valid(page):
		page.on_leave()

	# 清理 wrapper
	var wrapper := page.get_parent()
	if wrapper and wrapper is CanvasLayer:
		wrapper.queue_free()

	# 恢复游戏
	if _overlay_stack.is_empty():
		_parent.get_tree().paused = false
		resume_requested.emit()


## 弹出指定覆盖层；空栈时恢复 tree.paused 并发 resume_requested。
func pop_specific_overlay(page: BasePage) -> void:
	_overlay_stack.erase(page)
	_disconnect_signals(page)
	if is_instance_valid(page):
		page.on_leave()
	# 清理 wrapper
	var wrapper := page.get_parent()
	if wrapper and wrapper is CanvasLayer:
		wrapper.queue_free()
	if _overlay_stack.is_empty():
		_parent.get_tree().paused = false
		resume_requested.emit()


## 是否有覆盖层打开。
func is_overlay_open() -> bool:
	return not _overlay_stack.is_empty()


## 当前覆盖层栈顶；空栈 = null。
func get_overlay_top() -> BasePage:
	return _overlay_stack[-1] if not _overlay_stack.is_empty() else null


# ═══ 内部 ═══

func _load_page(path: String) -> BasePage:
	return load(path).instantiate() as BasePage


func _connect_signals(page: BasePage) -> void:
	if page.has_signal("finished"):
		if not page.finished.is_connected(_on_page_finished):
			page.finished.connect(_on_page_finished.bind(page))
	if page.has_signal("back"):
		if not page.back.is_connected(_on_page_back):
			page.back.connect(_on_page_back.bind(page))
	if page.has_signal("sfx_requested"):
		if not page.sfx_requested.is_connected(_on_page_sfx):
			page.sfx_requested.connect(_on_page_sfx.bind(page))


func _disconnect_signals(page: BasePage) -> void:
	if not is_instance_valid(page):
		return
	if page.has_signal("finished") and page.finished.is_connected(_on_page_finished):
		page.finished.disconnect(_on_page_finished)
	if page.has_signal("back") and page.back.is_connected(_on_page_back):
		page.back.disconnect(_on_page_back)
	if page.has_signal("sfx_requested") and page.sfx_requested.is_connected(_on_page_sfx):
		page.sfx_requested.disconnect(_on_page_sfx)


func _set_active(page: BasePage, active: bool) -> void:
	if not is_instance_valid(page):
		return
	page.visible = active
	if active:
		page.on_activate()
	else:
		page.on_deactivate()


func _on_page_finished(_result: Dictionary, _page: Node) -> void:
	# 不自动 pop — 由调用者决定
	# 覆盖层特殊处理：back 信号自动关闭
	pass


func _on_page_back(page: Node) -> void:
	if page in _page_stack:
		pop()
	elif page in _overlay_stack:
		pop_specific_overlay(page)


## 页面请求播放音效（BasePage 只发意图，这里转给 AudioManager 执行）
func _on_page_sfx(kind: String, _page: Node) -> void:
	AudioManager.play_ui_sfx(kind)

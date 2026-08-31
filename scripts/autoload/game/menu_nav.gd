# MenuNav — 统一菜单导航（替代 MenuHost + MenuStack + SubPageStack + PauseControl）
#
# ★ 所有菜单页面 push/pop 的唯一入口 ★
#
# 用法:
#   # 普通页面（MainMenu 内推子页面）
#   await MenuNav.push("res://scenes/ui/difficulty_screen.tscn")
#   MenuNav.pop()
#
#   # 覆盖层（暂停 / GameOver / 通关）
#   MenuNav.push_overlay("res://scenes/ui/pause_menu.tscn")
#   MenuNav.pop_overlay()
#
# 页面契约:
#   - 必须有 finished(result: Dictionary) 信号（可选）
#   - 推荐继承 BasePage / NavPage
#   - MenuNav 自动调 _on_enter() / _on_leave()

class_name MenuNav
extends RefCounted

signal page_changed(current: Node, previous: Node)

# ═══ 过渡设置 ═══

# ═══ 内部状态 ═══

var _parent: Node                     # GameManager
var _page_stack: Array[Node] = []     # 普通页面栈
var _overlay_stack: Array[Node] = []  # 覆盖层栈


# ═══ 初始化 ═══

func setup(parent: Node) -> void:
	_parent = parent


# ═══ 页面栈 ═══

## 推入一个子页面
func push(page_path: String) -> Node:
	# 隐藏当前栈顶
	if not _page_stack.is_empty():
		var prev: Node = _page_stack[-1]
		if is_instance_valid(prev):
			_set_active(prev, false)

	# 加载 & 添加新页面
	var page: Node = _load_page(page_path)
	_page_stack.append(page)
	var host: Control = _find_or_create_host()
	host.add_child(page)
	_connect_signals(page)
	page.visible = true

	if page.has_method("_on_enter"):
		page._on_enter()

	page_changed.emit(page, _page_stack[-2] if _page_stack.size() > 1 else null)
	return page


## 弹出当前页面（回到上一层）
func pop() -> void:
	if _page_stack.is_empty():
		return

	var page: Node = _page_stack.pop_back()
	_disconnect_signals(page)

	if is_instance_valid(page) and page.has_method("_on_leave"):
		page._on_leave()
	elif is_instance_valid(page):
		page.queue_free()

	# 恢复上一层
	if not _page_stack.is_empty():
		var prev = _page_stack[-1]
		if is_instance_valid(prev):
			prev.visible = true
			if prev.has_method("_on_activate"):
				prev._on_activate()

	page_changed.emit(_page_stack[-1] if not _page_stack.is_empty() and is_instance_valid(_page_stack[-1]) else null, page)


## 弹出到指定页面（保留该页）
func pop_to(page: Node) -> void:
	while _page_stack.size() > 1 and _page_stack[-1] != page:
		var dead: Node = _page_stack.pop_back()
		_disconnect_signals(dead)
		if is_instance_valid(dead):
			dead.queue_free()
	# 重连目标页
	if _page_stack[-1] == page:
		_connect_signals(page)


## 清空页面栈
func clear_pages() -> void:
	while not _page_stack.is_empty():
		var page = _page_stack.pop_back()
		if is_instance_valid(page):
			_disconnect_signals(page)
			page.queue_free()


func get_top_page() -> Node:
	return _page_stack[-1] if not _page_stack.is_empty() else null


func clear_overlays() -> void:
	while not _overlay_stack.is_empty():
		var page: Node = _overlay_stack.pop_back()
		_disconnect_signals(page)
		if is_instance_valid(page):
			page.queue_free()
		# 清理 CanvasLayer wrapper
		var wrapper := page.get_parent()
		if wrapper and wrapper is CanvasLayer:
			wrapper.queue_free()


func is_page_open() -> bool:
	return not _page_stack.is_empty()


# ═══ 覆盖层（暂停 / Game Over / 通关） ═══

## 推入覆盖层（暂停游戏 + 独立 CanvasLayer）
func push_overlay(page_path: String) -> Node:
	var page: Node = _load_page(page_path)
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

	_parent.set_state.call_deferred(GameManager.AppState.PAUSED)
	tree.paused = true

	if page.has_method("_on_enter"):
		page._on_enter()

	return page


## 接受已实例化的覆盖层（兼容旧 API）
func add_overlay_instance(page: Node) -> void:
	_overlay_stack.append(page)
	page.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var wrapper: CanvasLayer = CanvasLayer.new()
	wrapper.layer = 64
	wrapper.process_mode = Node.PROCESS_MODE_ALWAYS
	wrapper.add_child(page)
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	_parent.get_tree().root.add_child(wrapper)
	_connect_signals(page)
	_parent.set_state.call_deferred(GameManager.AppState.PAUSED)
	_parent.get_tree().paused = true
	if page.has_method("_on_enter"):
		page._on_enter()


## 弹出当前覆盖层
func pop_overlay() -> void:
	if _overlay_stack.is_empty():
		return

	var page: Node = _overlay_stack.pop_back()
	_disconnect_signals(page)

	if page.has_method("_on_leave"):
		page._on_leave()
	else:
		page.queue_free()

	# 清理 wrapper
	var wrapper := page.get_parent()
	if wrapper and wrapper is CanvasLayer:
		wrapper.queue_free()

	# 恢复游戏
	if _overlay_stack.is_empty():
		_parent.get_tree().paused = false
		_parent.set_state.call_deferred(GameManager.AppState.PLAYING)


## 弹出指定覆盖层
func pop_specific_overlay(page: Node) -> void:
	_overlay_stack.erase(page)
	_disconnect_signals(page)
	if is_instance_valid(page):
		if page.has_method("_on_leave"):
			page._on_leave()
		else:
			page.queue_free()
	# 清理 wrapper
	var wrapper := page.get_parent()
	if wrapper and wrapper is CanvasLayer:
		wrapper.queue_free()
	if _overlay_stack.is_empty():
		_parent.get_tree().paused = false
		_parent.set_state.call_deferred(GameManager.AppState.PLAYING)


func is_overlay_open() -> bool:
	return not _overlay_stack.is_empty()


func get_overlay_top() -> Node:
	return _overlay_stack[-1] if not _overlay_stack.is_empty() else null


# ═══ 内部 ═══

func _load_page(path: String) -> Node:
	return load(path).instantiate()


func _find_or_create_host() -> Control:
	var scene: Node = _parent.get_tree().current_scene
	if not scene:
		return _parent  # fallback

	# 优先用场景预设的 PageHost
	for child in scene.get_children():
		if child.name == "PageHost":
			return child

	# 没有就创建一个
	var host: Control = Control.new()
	host.name = "PageHost"
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(host)
	return host


func _connect_signals(page: Node) -> void:
	if page.has_signal("finished"):
		if not page.finished.is_connected(_on_page_finished):
			page.finished.connect(_on_page_finished.bind(page))
	if page.has_signal("back"):
		if not page.back.is_connected(_on_page_back):
			page.back.connect(_on_page_back.bind(page))
	if page.has_signal("sfx_requested"):
		if not page.sfx_requested.is_connected(_on_page_sfx):
			page.sfx_requested.connect(_on_page_sfx.bind(page))


func _disconnect_signals(page: Node) -> void:
	if not is_instance_valid(page):
		return
	if page.has_signal("finished") and page.finished.is_connected(_on_page_finished):
		page.finished.disconnect(_on_page_finished)
	if page.has_signal("back") and page.back.is_connected(_on_page_back):
		page.back.disconnect(_on_page_back)
	if page.has_signal("sfx_requested") and page.sfx_requested.is_connected(_on_page_sfx):
		page.sfx_requested.disconnect(_on_page_sfx)


func _set_active(page: Node, active: bool) -> void:
	if not is_instance_valid(page):
		return
	page.visible = active
	if active:
		if page.has_method("_on_activate"):
			page._on_activate()
	else:
		if page.has_method("_on_deactivate"):
			page._on_deactivate()


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

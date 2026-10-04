class_name BookmarkPanel
extends VBoxContainer
## 书签面板：列表显示（自动 + 人工合并）+ 添加/重命名/删除（弹窗）
## **纯视图**：数据在 `Bookmarks` store 里（宿主注入），编辑后发 `data_changed`，
## 由 Workbench 主控制器落盘并刷新时间轴 —— 这里不再自持第二份副本（2026-09-30，S3）
##
## 信号：
##   jump_requested(t)   —— 点击书签（左键）→ 快进跳转
##   data_changed        —— 书签被编辑 → 持久化 + 刷时间轴
##   log_requested(text) —— 操作日志（转交 EventLog）

signal jump_requested(time_sec: float)
signal data_changed
signal log_requested(text: String)

## 书签模型（Workbench 注入；列表与时间轴共用它的合并视图）
var store: Bookmarks
## 关卡运行时（Workbench 注入；读当前播放时刻）
var stage_runtime: StageRuntime

var _list: ItemList
var _menu: PopupMenu
var _dialog_host: DialogHost
var _menu_index := -1


func _init() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL  # 容器撑满页签，列表才能撑满容器
	add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	var add_btn := Button.new()
	add_btn.text = "＋ 添加书签"
	add_btn.pressed.connect(func(): open_add())
	row.add_child(add_btn)
	add_child(row)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(0, 120)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.tooltip_text = "左键 = 快进跳转 · 右键 = 重命名/删除"
	_list.item_clicked.connect(_on_list_clicked)
	add_child(_list)
	_menu = PopupMenu.new()
	_menu.id_pressed.connect(_on_menu_id)
	add_child(_menu)
	_dialog_host = DialogHost.new()
	add_child(_dialog_host)


## 重画列表（宿主打开关卡 / 编辑落盘后调用）
func refresh() -> void:
	_refresh()


func _refresh() -> void:
	_list.clear()
	if store == null:
		return
	for it in store.merged():
		var label: String = ("◆ " + it.label) if it.is_manual else it.label
		var idx := _list.add_item(label)
		_list.set_item_metadata(idx, it)


# ═══ 交互 ═══

func _on_list_clicked(index: int, _pos: Vector2, btn: int) -> void:
	if index < 0 or index >= _list.item_count:
		return
	var bm: Dictionary = _list.get_item_metadata(index)
	if btn == MOUSE_BUTTON_LEFT:
		jump_requested.emit(bm.t)  # 左键跳转
	elif btn == MOUSE_BUTTON_RIGHT:
		_menu_index = index
		_menu.clear()
		if bm.get("is_manual", false):
			_menu.add_item("＊ 重命名")
			_menu.add_item("× 删除")
		else:
			_menu.add_item("＊ 重命名（转为人工）")
			_menu.add_item("× 删除")
			_menu.set_item_disabled(1, true)  # 自动书签不可直接删
		_menu.popup(Rect2i(get_viewport().get_mouse_position(), Vector2i()))


func _on_menu_id(id: int) -> void:
	match id:
		0:
			_open_rename(_menu_index)
		1:
			_open_delete_confirm(_menu_index)


## 添加书签弹窗（t < 0 = 用当前播放时刻；时间轴右键传指定时刻）
func open_add(at_time: float = -1.0) -> void:
	if store == null:
		return
	var cur: float = at_time
	if cur < 0.0:
		var runner: CoroutineScript = stage_runtime.current_stage_script() if is_instance_valid(stage_runtime) else null
		cur = runner.game_time() if runner else 0.0
	var vb := _dialog_host.open("◆ 添加书签")
	# 时刻输入（默认当前/点击处，可自选）
	var time_row := HBoxContainer.new()
	time_row.add_child(WorkbenchUI.label("时刻"))
	var time_edit := LineEdit.new()
	time_edit.text = "%.1f" % cur
	time_row.add_child(time_edit)
	vb.add_child(time_row)
	var line := LineEdit.new()
	line.placeholder_text = "名称（如：Boss 最难点）"
	vb.add_child(line)
	_dialog_host.add_actions("确定", func():
		var t_use: float = time_edit.text.to_float()
		if not is_finite(t_use) or t_use < 0.0:
			t_use = cur
		var label := line.text.strip_edges()
		if label.is_empty():
			label = "t=%.1fs" % t_use
		_manual_add(t_use, label)
		log_requested.emit("◆ 添加书签：%s" % label)
		_emit_changed()
	)
	line.text_submitted.connect(func(_s: String): _dialog_host.confirm())  # 回车确认
	time_edit.grab_focus()
	time_edit.select_all()


func _open_rename(index: int) -> void:
	var meta: Dictionary = _list.get_item_metadata(index)
	var is_manual: bool = meta.get("is_manual", false)
	var vb := _dialog_host.open("＊ 重命名书签")
	var line := LineEdit.new()
	line.text = meta.label
	vb.add_child(line)
	_dialog_host.add_actions("确定", func():
		var new_label := line.text.strip_edges()
		if new_label.is_empty():
			return
		if is_manual:
			for bm in store.manual:
				if absf(bm.t - meta.t) < 0.01 and bm.get("label", "") == meta.label:
					bm.label = new_label
					break
		else:
			# 自动书签重命名 → 加人工书签（保留 auto；删除人工后自动项恢复）
			_manual_add(meta.t, new_label)
		log_requested.emit("＊ 重命名书签：%s" % new_label)
		_emit_changed()
	)
	line.text_submitted.connect(func(_s: String): _dialog_host.confirm())
	line.grab_focus()
	line.select_all()


func _open_delete_confirm(index: int) -> void:
	var meta: Dictionary = _list.get_item_metadata(index)
	var vb := _dialog_host.open("× 删除书签")
	var msg := Label.new()
	msg.text = "确定删除「%s」？" % meta.label
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(msg)
	_dialog_host.add_actions("确定", func(): _delete_at(index))


func _delete_at(index: int) -> void:
	var meta: Dictionary = _list.get_item_metadata(index)
	if not meta.get("is_manual", false):
		log_requested.emit("＊ 自动书签不可删（改关卡脚本才刷新）")
		return
	for i in range(store.manual.size() - 1, -1, -1):
		var bm: Dictionary = store.manual[i]
		if absf(bm.t - meta.t) < 0.01 and bm.get("label", "") == meta.label:
			store.manual.remove_at(i)
			break
	log_requested.emit("× 删除书签：%s" % meta.label)
	_emit_changed()


## 追加人工书签（唯一入口：`store.manual` 只有这里写）
func _manual_add(time_value: float, label: String) -> void:
	store.manual.append({"t": time_value, "label": label})


## 数据变化：刷新列表 + 通知主控制器（落盘 + 刷时间轴）
func _emit_changed() -> void:
	_refresh()
	data_changed.emit()

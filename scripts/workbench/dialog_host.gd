class_name DialogHost
extends CanvasLayer
## 通用弹窗宿主：遮罩 + 居中面板 + 内容 VBox + 确认/取消按钮行
##
## 用法：
##   var vb := dialog.open("标题")
##   vb.add_child(...)
##   dialog.add_actions("✓ 确定", func(): ...)
##   dialog.close()
##
## 暂停时也可操作（弹窗输入）→ 显式 ALWAYS

var _panel: PanelContainer
var _content: VBoxContainer


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


## 打开弹窗（自动关闭旧的），返回内容容器
func open(title: String) -> VBoxContainer:
	close()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -180.0
	_panel.offset_right = 180.0
	_panel.offset_top = -80.0
	_panel.offset_bottom = 80.0
	add_child(_panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 8)
	_panel.add_child(_content)
	var info := Label.new()
	info.text = title
	_content.add_child(info)
	return _content


## 追加按钮行：确认（回调）+ 取消
## 确认按钮文字固定 "确定"（confirm() 按此匹配；不用 emoji 避免字体缺失）
func add_actions(ok_text: String, ok_cb: Callable) -> void:
	if _content == null:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(row)
	var ok := Button.new()
	ok.text = ok_text
	ok.pressed.connect(func():
		ok_cb.call()
		close()
	)
	row.add_child(ok)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(close)
	row.add_child(cancel)


## 触发当前弹窗的确认按钮（回车确认）
func confirm() -> void:
	if _panel == null:
		return
	var vb: VBoxContainer = _panel.get_child(0)
	for child in vb.get_children():
		if child is HBoxContainer:
			for b in child.get_children():
				if b is Button and b.text == "确定":
					b.pressed.emit()
					return


## 是否有弹窗打开（工作台快捷键守卫：弹窗时避免误触重跑/跳转）
func is_open() -> bool:
	return _panel != null


func close() -> void:
	for c in get_children():
		c.queue_free()
	_panel = null
	_content = null

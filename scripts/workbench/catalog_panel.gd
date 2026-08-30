class_name CatalogPanel
extends VBoxContainer
## 内容目录面板（M1：浏览 + 分类展示；M2 起接组合台）
## 数据来源：ContentCatalog（自动派生索引，永不手写清单）。
## 注：headless/新文件下 class_name 全局缓存不可靠 → preload 常量。
## 注意：这里不能是 ScrollContainer——它不拉伸子节点，split_area 会塌成 0 高。

const CAT = preload("res://scripts/data/content_catalog.gd")

signal preset_requested(entry)  # 双击条目 → 组合台直达

var _tree: Tree
var _search: LineEdit
var _role_filter: OptionButton
var _stats_label: Label
var _stats_roles: Label
var _info_name: Label
var _info_role: Label
var _info_path: Label
var _info_desc: Label
var _info_refs: Label
var _catalog: Variant
var _info_panel: PanelContainer
var _split_area: Control
var _sep_divider: ColorRect
var _drag_info := false
var _drag_start_y := 0.0
var _drag_start_divider := 0.0
var _divider_y := 0.0  # 0 = 未初始化（首次应用时取默认）


func _ready() -> void:
	# 关键：面板自身必须 EXPAND_FILL，否则在 %Pages 里只拿最小高度 → split_area 塌 0
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 420)
	add_theme_constant_override("separation", 4)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	add_child(box)

	# ── 搜索 + 角色筛选 ──
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 6)
	_search = LineEdit.new()
	_search.placeholder_text = "搜索名称/路径…"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_t): _rebuild_tree())
	filter_row.add_child(_search)
	_role_filter = OptionButton.new()
	_role_filter.add_item("全部角色")
	for role in CAT.ROLE_ORDER:
		_role_filter.add_item(CAT.ROLE_LABELS[role])
	_role_filter.item_selected.connect(func(_i): _rebuild_tree())
	filter_row.add_child(_role_filter)
	add_child(filter_row)

	# ── 头行：统计 + 刷新 ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	_stats_label = Label.new()
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_roles = Label.new()
	_stats_roles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_roles.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_roles.modulate = Color(1, 1, 1, 0.6)
	_stats_roles.add_theme_font_size_override("font_size", 12)
	var refresh_btn := Button.new()
	refresh_btn.text = "刷新"
	refresh_btn.pressed.connect(refresh)
	head.add_child(_stats_label)
	head.add_child(refresh_btn)
	box.add_child(head)
	box.add_child(_stats_roles)

	# ── 分割区（手写绝对布局：分隔条位置 = 信息卡顶边，跟随鼠标）──
	_split_area = Control.new()
	_split_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split_area.resized.connect(_apply_split)
	box.add_child(_split_area)

	# ── 目录树（按角色分组）──
	_tree = Tree.new()
	_tree.columns = 1
	_tree.hide_root = true
	_tree.add_theme_constant_override("v_separation", 2)
	_tree.item_selected.connect(_on_item_selected)
	_tree.gui_input.connect(_on_tree_input)
	_split_area.add_child(_tree)
	_tree.set_anchors_preset(Control.PRESET_TOP_WIDE)

	# ── 信息卡与树之间的可拖分隔条（同右面板 divider 惯例）──
	_sep_divider = ColorRect.new()
	_sep_divider.color = Color(1, 1, 1, 0.12)
	_sep_divider.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	_sep_divider.gui_input.connect(_on_info_sep_input)
	_split_area.add_child(_sep_divider)
	_sep_divider.set_anchors_preset(Control.PRESET_TOP_WIDE)

	# ── 信息卡（选中条目详情；内部纵向滚动，内容超出不裁）──
	var info := PanelContainer.new()
	_split_area.add_child(info)
	info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_info_panel = info
	var info_scroll := ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info.add_child(info_scroll)
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 2)
	info_scroll.add_child(info_box)
	var info_title := Label.new()
	info_title.text = "详情"
	info_title.modulate = Color(1, 1, 1, 0.6)
	info_title.add_theme_font_size_override("font_size", 12)
	info_box.add_child(info_title)
	_info_name = Label.new()
	_info_role = Label.new()
	_info_path = Label.new()
	_info_desc = Label.new()
	_info_refs = Label.new()
	for l in [_info_name, _info_role, _info_path, _info_desc, _info_refs]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_box.add_child(l)

	refresh()
	_apply_split.call_deferred()


## 重新扫描 + 重建目录树
func refresh() -> void:
	_catalog = CAT.new().scan()
	_rebuild_tree()
	_update_stats()
	_clear_info()


func _update_stats() -> void:
	var s = _catalog.get_stats()
	_stats_label.text = "共 %d 条 · 警告 %d" % [s["total"], s["warnings"]]
	_stats_roles.text = _roles_summary(s["by_role"])


func _roles_summary(roles: Dictionary) -> String:
	var parts: Array[String] = []
	for role in CAT.ROLE_ORDER:
		parts.append("%s %d" % [CAT.ROLE_LABELS[role], roles.get(role, 0)])
	return " · ".join(parts)


func _rebuild_tree() -> void:
	_tree.clear()
	# 关键：空树 + hide_root 时，首个 create_item() 会成为隐藏根（第一个组头会"消失"）
	# → 先确保根存在，组头一律显式挂根下
	var root_item = _tree.get_root()
	if root_item == null:
		root_item = _tree.create_item()
	var want_role: String = ""
	if _role_filter and _role_filter.selected > 0:
		want_role = CAT.ROLE_ORDER[_role_filter.selected - 1]
	var q: String = _search.text.strip_edges().to_lower()
	for role in CAT.ROLE_ORDER:
		if want_role != "" and role != want_role:
			continue
		var items = _catalog.by_role(role)
		if q != "":
			var filtered := []
			for e in items:
				if String(e.name).to_lower().contains(q) or String(e.path).to_lower().contains(q):
					filtered.append(e)
			items = filtered
		if items.is_empty():
			continue
		var head := _tree.create_item(root_item)
		head.set_text(0, "%s（%d）" % [CAT.ROLE_LABELS[role], items.size()])
		head.set_custom_color(0, Color(1, 1, 1, 0.45))
		head.set_selectable(0, false)
		# 重名消歧：同名条目后缀 uid（符卡）或文件名（兜底）
		var name_count := {}
		for e in items:
			var key: String = e.name if e.name != "" else e.path.get_file()
			name_count[key] = (name_count.get(key, 0) as int) + 1
		for e in items:
			var it := _tree.create_item(head)
			var display: String = e.name if e.name != "" else e.path.get_file()
			if (name_count.get(display, 0) as int) > 1:
				var uid: int = e.extra.get("uid", 0)
				if uid > 0:
					display += " · uid" + str(uid)
				else:
					display += "（" + e.path.get_file().get_basename() + "）"
			it.set_text(0, display)
			var full_title: String = e.extra.get("full_title", e.name)
			it.set_tooltip_text(0, full_title + "\n" + e.path)
			it.set_metadata(0, e)


## 拖动分隔条：分隔条位置跟随鼠标（树/信息卡以它划分）
## 拖拽用全局坐标（event.global_position）：分隔条移动不影响计算 → 无反馈环、不闪不跳
func _on_info_sep_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_info = event.pressed
		if _drag_info:
			_drag_start_y = (event as InputEventMouseButton).global_position.y
			_drag_start_divider = _divider_y
	elif event is InputEventMouseMotion and _drag_info:
		var motion := event as InputEventMouseMotion
		_divider_y = _drag_start_divider + (motion.global_position.y - _drag_start_y)
		_apply_split()


## 应用分隔条位置：树 = 上部，分隔条 = 中部，信息卡 = 下部
func _apply_split() -> void:
	var h := _split_area.size.y
	if h <= 0.0:
		return
	if _divider_y <= 0.0:
		_divider_y = clampf(h - 170.0, 100.0, maxf(100.0, h - 120.0))
	else:
		_divider_y = clampf(_divider_y, 100.0, maxf(100.0, h - 120.0))
	_tree.offset_bottom = _divider_y
	_sep_divider.offset_top = _divider_y
	_sep_divider.offset_bottom = _divider_y + 6.0
	# 注意：信息卡锚点=底边（BOTTOM_WIDE），offset 相对底锚点 → 必须为负
	_info_panel.offset_top = _divider_y + 6.0 - h
	_info_panel.offset_bottom = 0.0


## 双击条目 → 发给创作台（组合台直达）
func _on_tree_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.double_click and event.pressed:
		var item := _tree.get_selected()
		if item == null:
			return
		var e = item.get_metadata(0)
		if e != null:
			preset_requested.emit(e)


func _on_item_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	var entry = item.get_metadata(0)
	if entry == null:
		return
	_info_name.text = "名称：" + entry.name
	var uid: int = entry.extra.get("uid", 0)
	_info_role.text = "角色：" + CAT.ROLE_LABELS.get(entry.role, entry.role) + (
		("　uid %d" % uid) if uid > 0 else "")
	_info_path.text = "路径：" + entry.path
	_info_path.tooltip_text = entry.path
	var desc_parts: Array[String] = []
	var full_title: String = entry.extra.get("full_title", "")
	if full_title != "" and full_title != entry.name:
		desc_parts.append(full_title)
	if entry.description != "":
		desc_parts.append(entry.description)
	var desc_text: String = "描述：\n" + "\n".join(desc_parts) if not desc_parts.is_empty() else "描述：—"
	_info_desc.text = desc_text
	_info_refs.text = "被引用：%d 处" % entry.refs_from.size()


func _clear_info() -> void:
	_info_name.text = "← 选中条目查看详情"
	for l in [_info_role, _info_path, _info_desc, _info_refs]:
		l.text = ""
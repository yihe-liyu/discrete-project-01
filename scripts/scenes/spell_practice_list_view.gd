## 符卡练习菜单的列表视图（三级列表 + 高亮 + 滚动窗口）。
##
## 只管画：数据来自 [code]SpellPracticeData[/code]，选中项/层级由菜单传入。
## 不碰 SaveData、不生成记录、不做练习启动。
class_name SpellPracticeListView
extends RefCounted

## 全收颜色（正蓝）。
const CAPTURE_FULL := Color(0.4, 0.7, 1.0)
## 难度显示名（SpellRecord）。
const DIFF_NAMES = SpellRecord.DIFF_NAMES
## 角色显示名（SpellRecord）。
const CHAR_NAMES = SpellRecord.CHAR_NAMES
## 列表字号。
const LIST_FONT_SIZE := 28

## 层级：关卡。
const SECTION_STAGE := 0
## 层级：阶段。
const SECTION_PHASE := 1
## 层级：难度。
const SECTION_DIFF := 2

var _host: Node
var _stage_box: VBoxContainer
var _phase_box: VBoxContainer
var _diff_box: VBoxContainer
var _char_name: Label
var _phase_scroll_hint: Label

## 二级（阶段）列表的可视窗口起点：超长时只渲染这一段，选中项永远在窗口内。
var _phase_offset: int = 0
var _pulse_tween: Tween


## 注入宿主与四个列表容器 / 人物名 / 滚动提示。
func setup(host: Node, stage_box: VBoxContainer, p_phase_box: VBoxContainer,
		diff_box: VBoxContainer, char_name: Label, phase_scroll_hint: Label) -> void:
	_host = host
	_stage_box = stage_box
	_phase_box = p_phase_box
	_diff_box = diff_box
	_char_name = char_name
	_phase_scroll_hint = phase_scroll_hint


## 阶段列表容器。
func phase_box() -> VBoxContainer:
	return _phase_box


## 阶段列表当前窗口起点。
func phase_offset_value() -> int:
	return _phase_offset


# ═══ 构建列表 ═══

## 重建关卡列表；无记录时显示 No records，再建阶段列表。
func build_lists(data: SpellPracticeData, char_index: int, phase_index: int) -> void:
	_clear(_stage_box)
	if data.stages.is_empty():
		var lbl := Label.new()
		lbl.text = "No records"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		_stage_box.add_child(lbl)
		_clear(_phase_box)
		sync_phase_scroll_hint(data)   # 二级清空 → 提示也要跟着清
		return

	for stage in data.stages:
		# 名字走 StageCatalog（内容侧 display_name）→ 回落 "Stage %d"。
		# 别在这里拼 "Stage %d"：B 线这类 id 与名字对不上的舞台就没法显示。
		var lbl := _make_label(StageCatalog.display_name_of(stage))
		# 级联：该 stage 所有 phase 全收 → 正蓝（部分完成不显示中间色）
		if data.stage_capture_state(stage, char_index) == 2:
			lbl.add_theme_color_override("font_color", CAPTURE_FULL)
		_stage_box.add_child(lbl)
	build_phase_list(data, char_index, phase_index)


# ═══ 列表开窗（超长不撑爆面板）═══

## 该列表的可视行数：按容器实测高度 / 一行行距算。[code]-1[/code] = 量不到（尚未布局）→ 不裁剪。
func rows_visible(vbox: VBoxContainer) -> int:
	var available: float = vbox.size.y
	var pitch: float = _row_pitch(vbox)
	if available <= 0.0 or pitch <= 0.0:
		return -1
	return maxi(1, int(floor(available / pitch)))


## 一行的实际高度 + 行距：字高由主题字体决定，用一行真 Label 量（写死像素会随字体漂）。
func _row_pitch(vbox: VBoxContainer) -> float:
	var measure_label := Label.new()
	measure_label.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
	measure_label.text = "0"
	vbox.add_child(measure_label)
	var row_h: float = measure_label.get_combined_minimum_size().y
	vbox.remove_child(measure_label)
	measure_label.free()
	return row_h + float(vbox.get_theme_constant("separation"))


## 窗口起点：保证选中项落在 [code]limit[/code] 行窗口内 —— 上下移动时窗口跟着滚，而不是把列表撑长。
## [code]limit <= 0[/code]（量不到高度）→ 起点 0 = 不裁剪（旧行为，测试直调 [code]_build_*[/code] 时走这条）。
func _window_start(current: int, selected: int, total: int, limit: int) -> int:
	if limit <= 0 or total <= limit:
		return 0
	var start := current
	if selected < start:
		start = selected
	elif selected >= start + limit:
		start = selected - limit + 1
	return clampi(start, 0, total - limit)


## 按当前窗口重建阶段列表，并同步滚动提示。
func build_phase_list(data: SpellPracticeData, char_index: int, phase_index: int) -> void:
	_clear(_phase_box)

	var limit := rows_visible(_phase_box)
	_phase_offset = _window_start(_phase_offset, phase_index, data.phases.size(), limit)
	var stop: int = data.phases.size() if limit <= 0 else mini(_phase_offset + limit, data.phases.size())
	for i in range(_phase_offset, stop):
		var info: Dictionary = data.phases[i]
		var lbl := _make_label(info["label"])
		# 级联：该 phase 花名册里所有难度槽全收 → 正蓝（锁定 "?" 槽需全部收齐）
		if data.phase_capture_all(info["rec"].stage, info["rec"].boss_index, info["rec"].phase_index,
				char_index, info.get("boss")) == 2:
			lbl.add_theme_color_override("font_color", CAPTURE_FULL)
		_phase_box.add_child(lbl)

	sync_phase_scroll_hint(data)


## 二级滚动提示：[code]▲[/code] = 上面还有、[code]▼[/code] = 下面还有，中间是当前可见区间 / 总数。
## 全部看得见（没被窗口裁掉）→ 空串，不占版面、不制造噪音。
## 箭头位用全角空格占位 —— 只有一侧有箭头时字串长度不变，不会左右抖。
func sync_phase_scroll_hint(data: SpellPracticeData) -> void:
	var total: int = data.phases.size()
	var shown: int = _phase_box.get_child_count()
	var has_above: bool = _phase_offset > 0
	var has_below: bool = _phase_offset + shown < total
	if not (has_above or has_below):
		_phase_scroll_hint.text = ""
		return
	_phase_scroll_hint.text = "%s %d–%d / %d %s" % [
		"▲" if has_above else "　", _phase_offset + 1, _phase_offset + shown, total,
		"▼" if has_below else "　"]


## 选中项在当前窗口内的行号（渲染用的 child index）。
func phase_local_index(phase_index: int) -> int:
	return clampi(phase_index - _phase_offset, 0, maxi(_phase_box.get_child_count() - 1, 0))


## 按当前阶段重建难度列表（卡名 / 难度 / 收取统计）。
func build_diff_list(data: SpellPracticeData, phase_index: int) -> void:
	_clear(_diff_box)
	if phase_index < 0 or phase_index >= data.phases.size():
		return

	for entry in data.diff_entries:
		var difficulty: int = entry.diff
		var is_locked: bool = entry.is_locked
		var record: SpellRecord = entry.get("record")
		var vbox := VBoxContainer.new()
		# 名字行始终占位（两种状态下选项高度一致）：锁定 → "?"；符卡 → 卡名；非符 → 空串。
		var nl := Label.new()
		nl.text = entry.get("card_name", "")
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 30)
		if record and record.practice_captures > 0 and not is_locked:
			nl.add_theme_color_override("font_color", CAPTURE_FULL)
		vbox.add_child(nl)

		var hrow := HBoxContainer.new()
		hrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var hl := Label.new()
		if is_locked:
			hl.text = DIFF_NAMES[difficulty]
		else:
			var uid_str := ""
			if record.uid > 0:
				uid_str = "No.%03d  " % record.uid
			hl.text = uid_str + DIFF_NAMES[difficulty]
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		hl.add_theme_font_size_override("font_size", 22)
		hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hl.size_flags_stretch_ratio = 1.0
		hrow.add_child(hl)

		var sl := Label.new()
		sl.text = "--/--" if is_locked else "%02d/%02d" % [record.practice_captures, record.practice_attempts]
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sl.add_theme_font_size_override("font_size", 22)
		sl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hrow.add_child(sl)

		vbox.add_child(hrow)
		_diff_box.add_child(vbox)


func _clear(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		vbox.remove_child(child)
		child.free()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
	return lbl


# ═══ 高亮 ═══

## 按当前层级压暗全部、点亮选中项并脉冲；阶段窗口变化时重建。
func highlight(data: SpellPracticeData, section: int, stage_index: int, phase_index: int,
		diff_index: int, char_index: int) -> void:
	stop_pulse()
	# 二级窗口跟着选中项滚（超长列表不撑爆面板）：只有窗口真的要变才重建，不白重建
	if _window_start(_phase_offset, phase_index, data.phases.size(), rows_visible(_phase_box)) != _phase_offset:
		build_phase_list(data, char_index, phase_index)
	_dim_all_vbox(_stage_box)
	_dim_all_vbox(_phase_box)
	_dim_diff(data)

	match section:
		SECTION_STAGE:
			_highlight_one_vbox(_stage_box, stage_index)
			_pulse_on_vbox(_stage_box, stage_index)
			_clear(_diff_box)
		SECTION_PHASE:
			var local := phase_local_index(phase_index)
			_highlight_one_vbox(_phase_box, local)
			_pulse_on_vbox(_phase_box, local)
			_dim_diff(data)
		SECTION_DIFF:
			_highlight_diff(data, diff_index)
			# diff 选项不闪烁（符卡名+统计+难度内容多，闪烁晃眼），只保留高亮


func _dim_all_vbox(vbox: VBoxContainer) -> void:
	for child in vbox.get_children():
		child.modulate = _dim_for(child)


## 有进度色（正蓝）的行：压暗放宽，保持蓝可辨（未选中时也能看出全收）
func _dim_for(child: Control) -> Color:
	if child is Label and child.get_theme_color("font_color") == CAPTURE_FULL:
		return Color(0.55, 0.55, 0.6)
	return Color(0.3, 0.3, 0.3)


func _highlight_one_vbox(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	for i in children.size():
		if i == idx:
			children[i].modulate = Color.WHITE
		else:
			children[i].modulate = _dim_for(children[i])


func _diff_dim_for(data: SpellPracticeData, i: int) -> Color:
	if i < data.diff_entries.size() and data.diff_entries[i].is_locked:
		return Color(0.15, 0.15, 0.15)
	return Color(0.3, 0.3, 0.3)


func _dim_diff(data: SpellPracticeData) -> void:
	# 外层统一灰 + 内层复原（pulse 作用外层——不设外层会残留 pulse 中间值导致颜色不统一）
	var children := _diff_box.get_children()
	for i in children.size():
		var vbox := children[i]
		vbox.modulate = _diff_dim_for(data, i)
		for child in vbox.get_children():
			child.modulate = Color.WHITE


func _highlight_diff(data: SpellPracticeData, idx: int) -> void:
	var items := _diff_box.get_children()
	for i in items.size():
		var vbox := items[i]
		# 外层统一：非选中灰（锁定更深）、选中白；内层全部复原
		vbox.modulate = Color.WHITE if i == idx else _diff_dim_for(data, i)
		for child in vbox.get_children():
			child.modulate = Color.WHITE


func _pulse_on_vbox(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	if idx < children.size():
		_start_pulse(children[idx])


# ═══ 脉冲 ═══

func _start_pulse(item: Control) -> void:
	stop_pulse()
	if item.modulate.a < 0.01:
		return
	_pulse_tween = _host.create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", Color.WHITE, 0.3)
	_pulse_tween.tween_property(item, "modulate", Color(0.5, 0.5, 0.5), 0.3)


## 停止高亮脉冲。
func stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


# ═══ 选中项 / 标签 ═══

## 取当前层级选中项节点；索引越界 = null。
func get_highlighted_item(section: int, stage_index: int, phase_index: int, diff_index: int) -> Control:
	match section:
		SECTION_STAGE:
			var children := _stage_box.get_children()
			return children[stage_index] if stage_index < children.size() else null
		SECTION_PHASE:
			var children := _phase_box.get_children()
			var local := phase_local_index(phase_index)
			return children[local] if local < children.size() else null
		SECTION_DIFF:
			var children := _diff_box.get_children()
			return children[diff_index] if diff_index < children.size() else null
	return null


## 同步人物名标签（← 名字 →）。
func sync_char_label(char_index: int) -> void:
	_char_name.text = "← %s →" % CHAR_NAMES[char_index]


## 人物名标签文本。
func char_name_text() -> String:
	return _char_name.text


## 阶段滚动提示文本。
func phase_scroll_hint_text() -> String:
	return _phase_scroll_hint.text


## 阶段列表子项数。
func phase_box_count() -> int:
	return _phase_box.get_child_count()


## 阶段列表文本快照。
func phase_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _phase_box.get_children():
		out.append((child as Label).text)
	return out


## 难度列表文本快照（取卡名行）。
func diff_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _diff_box.get_children():
		var box := child as VBoxContainer
		out.append((box.get_child(0) as Label).text if box.get_child_count() > 0 else "")
	return out


## 难度列表高度快照。
func diff_heights() -> Array[int]:
	var out: Array[int] = []
	for child in _diff_box.get_children():
		out.append(int((child as Control).size.y))
	return out


## 关卡列表子项数。
func stage_box_count() -> int:
	return _stage_box.get_child_count()


## 关卡列表文本快照。
func stage_labels() -> Array[String]:
	var out: Array[String] = []
	for child in _stage_box.get_children():
		out.append((child as Label).text)
	return out

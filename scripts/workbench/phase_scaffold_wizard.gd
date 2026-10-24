## 阶段脚手架向导（V2-3 第一版）：给当前 Stage 的某个 Boss 追加一张阶段。
##
## 只追加到难度数组末尾；先 plan，再 apply。UI 只有一个根 Control，
## 子控件用显式位置布局（Window 会把直接子 Control 拉满，不能直接摆）。
class_name PhaseScaffoldWizard
extends ConfirmationDialog

signal created(path: String)

const SERVICE := preload("res://scripts/workbench/phase_scaffold_service.gd")
const CONTENT_ROOT_NAME := "ContentRoot"

var _phase_scaffold_service: PhaseScaffoldService
var _stage_data: StageData
var _boss: OptionButton
var _kind: OptionButton
var _difficulties: OptionButton
var _name: LineEdit
var _uid: SpinBox
var _hp: SpinBox
var _time: SpinBox
var _timeout: CheckBox
var _slug: LineEdit
var _plan_label: Label
var _plan: Dictionary = {}


func _ready() -> void:
	title = "新建阶段"
	ok_button_text = "创建"
	get_cancel_button().text = "取消"
	wrap_controls = false
	dialog_hide_on_ok = false
	size = Vector2i(640, 560)
	_phase_scaffold_service = SERVICE.new()
	_build_ui()
	confirmed.connect(_on_confirmed)


func _build_ui() -> void:
	var root := Control.new()
	root.name = CONTENT_ROOT_NAME
	add_child(root)

	var intro := _label("给当前关卡的 Boss 追加一个阶段；只会追加到难度列表末尾。")
	intro.position = Vector2(8, 8)
	intro.size = Vector2(620, 32)
	root.add_child(intro)

	_boss = OptionButton.new()
	_boss.item_selected.connect(func(_i: int) -> void: _refresh_plan())
	root.add_child(_row("Boss", _boss, 48))

	_kind = OptionButton.new()
	_kind.add_item("符卡", 0)
	_kind.add_item("非符", 1)
	_kind.item_selected.connect(func(_i: int) -> void: _on_kind_changed())
	root.add_child(_row("类型", _kind, 88))

	_difficulties = OptionButton.new()
	_difficulties.add_item("Easy~Lunatic（共享）", 0)
	_difficulties.add_item("Easy~Extra（共享）", 1)
	for diff in Difficulty.COUNT:
		_difficulties.add_item("仅 " + Difficulty.display_name(diff), 2 + diff)
	_difficulties.item_selected.connect(func(_i: int) -> void: _refresh_plan())
	root.add_child(_row("追加到", _difficulties, 128))

	var name_row := HBoxContainer.new()
	name_row.position = Vector2(8, 168)
	name_row.size = Vector2(620, 30)
	var name_label := Label.new()
	name_label.text = "名称 / UID"
	name_label.custom_minimum_size = Vector2(96, 0)
	name_row.add_child(name_label)
	_name = LineEdit.new()
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.text_changed.connect(func(_t: String) -> void: _refresh_plan())
	name_row.add_child(_name)
	_uid = SpinBox.new()
	_uid.min_value = 1
	_uid.max_value = 999999
	_uid.step = 1
	_uid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_uid.value_changed.connect(func(_v: float) -> void: _refresh_plan())
	name_row.add_child(_uid)
	root.add_child(name_row)

	var stats_row := HBoxContainer.new()
	stats_row.position = Vector2(8, 208)
	stats_row.size = Vector2(620, 30)
	stats_row.add_child(_small_label("HP"))
	_hp = SpinBox.new()
	_hp.min_value = 1
	_hp.max_value = 999999
	_hp.value = 4000
	_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp.value_changed.connect(func(_v: float) -> void: _refresh_plan())
	stats_row.add_child(_hp)
	stats_row.add_child(_small_label("时限"))
	_time = SpinBox.new()
	_time.min_value = 1
	_time.max_value = 999
	_time.value = 30
	_time.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time.value_changed.connect(func(_v: float) -> void: _refresh_plan())
	stats_row.add_child(_time)
	_timeout = CheckBox.new()
	_timeout.text = "时符"
	_timeout.toggled.connect(func(_v: bool) -> void: _refresh_plan())
	stats_row.add_child(_timeout)
	root.add_child(stats_row)

	var slug_row := HBoxContainer.new()
	slug_row.position = Vector2(8, 248)
	slug_row.size = Vector2(620, 30)
	slug_row.add_child(_small_label("目录 slug"))
	_slug = LineEdit.new()
	_slug.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slug.placeholder_text = "例如 spell057；不能含 /"
	_slug.text_changed.connect(func(_t: String) -> void: _refresh_plan())
	slug_row.add_child(_slug)
	root.add_child(slug_row)

	var plan_scroll := ScrollContainer.new()
	plan_scroll.position = Vector2(8, 288)
	plan_scroll.size = Vector2(620, 190)
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(plan_scroll)
	_plan_label = _label("")
	_plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plan_label.custom_minimum_size = Vector2(596, 0)
	_plan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_scroll.add_child(_plan_label)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(56, 0)
	return label


func _row(p_title: String, control: Control, y: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = Vector2(8, y)
	row.size = Vector2(620, 30)
	var label := Label.new()
	label.text = p_title
	label.custom_minimum_size = Vector2(96, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func open_for(stage_data: StageData) -> void:
	_stage_data = stage_data
	_boss.clear()
	if stage_data != null:
		for boss in BossCatalog.all().get(stage_data.stage_id, []):
			var suffix: String = (" / " + boss.section_label) if boss.section_label != "" else ""
			_boss.add_item(boss.boss_name + suffix)
			_boss.set_item_metadata(_boss.item_count - 1, boss)
	_kind.select(0)
	_difficulties.select(0)
	_name.text = ""
	_hp.value = 4000
	_time.value = 30
	_timeout.button_pressed = false
	_slug.text = ""
	_uid.value = _next_uid()
	_on_kind_changed()
	_refresh_plan()
	call_deferred("_show_popup")


func _show_popup() -> void:
	popup_centered(Vector2i(640, 560))
	size = Vector2i(640, 560)


func _next_uid() -> int:
	var max_uid := 100
	for uid in BossCatalog.collect_spells().keys():
		max_uid = maxi(max_uid, int(uid))
	return max_uid + 1


func _on_kind_changed() -> void:
	var spell := _kind.selected == 0
	_name.editable = spell
	_uid.editable = spell
	_name.modulate = Color.WHITE if spell else Color(0.5, 0.5, 0.5)
	_uid.modulate = Color.WHITE if spell else Color(0.5, 0.5, 0.5)
	_refresh_plan()


func _selected_boss() -> BossData:
	if _boss.selected < 0:
		return null
	return _boss.get_item_metadata(_boss.selected) as BossData


func _selected_difficulties() -> Array[int]:
	var out: Array[int] = []
	match _difficulties.selected:
		0: out = [0, 1, 2, 3]
		1: out = [0, 1, 2, 3, 4]
		_: out = [_difficulties.selected - 2]
	return out


func _refresh_plan() -> void:
	var boss := _selected_boss()
	if boss == null:
		_plan = {"ok": false, "issues": ["当前 Stage 没有可选 Boss"]}
		_show_plan()
		return
	var spell := _kind.selected == 0
	var slug := _slug.text.strip_edges()
	if slug == "" and _name.text.strip_edges() != "":
		slug = "spell_%d" % int(_uid.value) if spell else "non_%d" % int(_time.value)
	if slug == "":
		slug = "spell_%d" % int(_uid.value) if spell else "non_%d" % int(_time.value)
	_plan = _phase_scaffold_service.plan(_stage_data, boss, {
		"kind": "spell" if spell else "nonspell",
		"difficulties": _selected_difficulties(),
		"name": _name.text.strip_edges() if spell else "",
		"uid": int(_uid.value) if spell else 0,
		"hp": int(_hp.value),
		"time_limit": float(_time.value),
		"timeout_only": _timeout.button_pressed,
		"slug": slug,
	})
	_show_plan()


func _show_plan() -> void:
	var ok: bool = _plan.get("ok", false)
	get_ok_button().disabled = not ok
	if ok:
		_plan_label.text = str(_plan.preview)
	else:
		_plan_label.text = "不能创建：\n- " + "\n- ".join(_plan.get("issues", ["未知错误"]))


func _on_confirmed() -> void:
	if not _plan.get("ok", false):
		return
	var errs := _phase_scaffold_service.apply(_plan, _selected_boss())
	if errs.is_empty():
		created.emit(_plan.phase_path)
		hide()
		return
	_plan_label.text = "创建失败：\n- " + "\n- ".join(errs)
	_show_popup()

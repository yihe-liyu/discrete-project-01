## 创作台脚手架向导（第一版）：为当前 StageData 新建一个 StageVariant。
##
## 选择驱动：难度选项只列尚未使用的难度；脚本默认沿用基准；BGM 留空 = 回落基准。
## 先 plan 再 apply；失败时对话框不关，计划区显示原因。
class_name ScaffoldWizard
extends ConfirmationDialog

signal created(path: String)

const SERVICE := preload("res://scripts/workbench/scaffold_service.gd")

var _scaffold_service: ScaffoldService
var _stage_data: StageData
var _difficulty: OptionButton
var _script: OptionButton
var _bgm: LineEdit
var _plan_label: Label
var _plan: Dictionary = {}


func _ready() -> void:
	title = "新建难度变体"
	ok_button_text = "创建"
	wrap_controls = false
	dialog_hide_on_ok = false
	# 内容用显式位置/尺寸（不用直挂 VBox）；窗口尺寸在 show 后再钉一次。
	size = Vector2i(620, 460)
	_scaffold_service = SERVICE.new()
	_build_ui()
	confirmed.connect(_on_confirmed)


func _build_ui() -> void:
	# 不用 VBox 直挂 Window：Window 不会给直挂 Control 做二次布局，
	# 首次按未折行内容算出的高度会一直保留。这里用显式位置/尺寸。
	var intro := _label("为当前关卡新建一个 StageVariant；未选择的字段沿用基准。")
	intro.position = Vector2(8, 8)
	intro.size = Vector2(604, 32)
	add_child(intro)

	_difficulty = OptionButton.new()
	_difficulty.item_selected.connect(func(_i: int) -> void: _refresh_plan())
	add_child(_row("难度", _difficulty, 48))

	_script = OptionButton.new()
	_script.item_selected.connect(func(_i: int) -> void: _refresh_plan())
	add_child(_row("脚本", _script, 88))

	_bgm = LineEdit.new()
	_bgm.placeholder_text = "留空 = 沿用 StageData.bgm_key（普通 + 练习）"
	_bgm.text_changed.connect(func(_t: String) -> void: _refresh_plan())
	add_child(_row("BGM key", _bgm, 128))

	var plan_scroll := ScrollContainer.new()
	plan_scroll.position = Vector2(8, 168)
	plan_scroll.size = Vector2(604, 210)
	plan_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(plan_scroll)
	_plan_label = _label("")
	_plan_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plan_label.custom_minimum_size = Vector2(580, 0)
	_plan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_scroll.add_child(_plan_label)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _row(p_title: String, control: Control, y: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.position = Vector2(8, y)
	row.size = Vector2(604, 30)
	var label := Label.new()
	label.text = p_title
	label.custom_minimum_size = Vector2(72, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


## 打开向导；stage_data 为空则不可创建。
func open_for(stage_data: StageData) -> void:
	_stage_data = stage_data
	_difficulty.clear()
	if stage_data != null:
		for difficulty in Difficulty.COUNT:
			if stage_data.variant_for(difficulty) == null:
				_difficulty.add_item(Difficulty.display_name(difficulty), difficulty)
	_script.clear()
	if stage_data != null and stage_data.create_script != null:
		_script.add_item(stage_data.create_script.resource_path)
		_script.set_item_metadata(0, stage_data.create_script)
	_bgm.text = ""
	_refresh_plan()
	# 首次 open_for 时控件还没完成布局；延迟到本帧结束后再 popup / 定尺寸，
	# 避免按未折行文本算出夸张高度。
	call_deferred("_show_popup")


func _show_popup() -> void:
	popup_centered(Vector2i(620, 460))
	size = Vector2i(620, 460)


func _refresh_plan() -> void:
	if _stage_data == null or _difficulty.item_count == 0:
		_plan = {"ok": false, "issues": ["没有可用的难度槽"]}
		_show_plan()
		return
	var difficulty: int = _difficulty.get_item_id(_difficulty.selected)
	var script: Script = _script.get_item_metadata(_script.selected) if _script.item_count > 0 else null
	_plan = _scaffold_service.plan_stage_variant(_stage_data, difficulty, script, _bgm.text.strip_edges())
	_show_plan()


func _show_plan() -> void:
	var ok: bool = _plan.get("ok", false)
	get_ok_button().disabled = not ok
	if ok:
		_plan_label.text = "将创建：\n%s\n\n并追加到：\n%s" % [_plan.variant_path, _plan.stage_path]
	else:
		_plan_label.text = "不能创建：\n- " + "\n- ".join(_plan.get("issues", ["未知错误"]))


func _on_confirmed() -> void:
	if not _plan.get("ok", false):
		return
	var errs := _scaffold_service.apply(_plan, _stage_data)
	if errs.is_empty():
		created.emit(_plan.variant_path)
		hide()
		return
	_plan_label.text = "创建失败：\n- " + "\n- ".join(errs)
	_show_popup()

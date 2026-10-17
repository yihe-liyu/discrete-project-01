# StagePracticeMenu.gd — 关卡练习：选**一面** + 难度，直接开这一面（通关不打下一关）。
#
# 与符卡练习的分工：
#   - 符卡练习 = 单张符卡（**没有关卡脚本** ⇒ BGM / 背景 / Boss 全由载荷带）。
#   - 本页     = **完整一面** ⇒ 走正常 `game_scene` → `StageRuntime.load_stage()`，
#                所以 BGM / 背景 / 道中 / Boss 全由**该面的关卡脚本**负责，本页一个字都不管。
#
# 关卡列表 = `StageCatalog` 的**可玩清单**（注册表；每项都有 `create_script`）。
# 自机与资源：人物沿用 `SaveData.selected_character`；资源由 `game_scene` 的
#   `SaveData.reset_all()` 发**全套**（练习与新开一局同一起点，不做续命 / 继承）。
extends BasePage

const CHAR_NAMES := SpellRecord.CHAR_NAMES
## 普通面的难度槽（与 `difficulty_screen` 的 4 档一致）
const MENU_DIFFS: Array[int] = [0, 1, 2, 3]
## EX 面只有 Extra 一档（`SpellRecord.Difficulty.EXTRA`）
const MENU_DIFFS_EXTRA: Array[int] = [SpellRecord.Difficulty.EXTRA]
## EX 面的 `stage_no` 约定（见 `StageData.stage_no`：1..6，EX = 7）
const STAGE_NO_EXTRA := 7
## 列表行字号（行高由它决定）
const LIST_FONT_SIZE := 28

enum Section { STAGE, DIFF }

@onready var _stage_box: VBoxContainer = $StageBox
@onready var _diff_box: VBoxContainer = $DiffBox
@onready var _char_name: Label = $CharPanel/CharName

## 可玩清单（`StageCatalog.playable()` 的产出；下标 = 一级列表行号）
var _stages: Array[StageData] = []
## 当前面的难度槽（`_menu_diffs_for()` 的产出；下标 = 二级列表行号）
var _diffs: Array[int] = []
var _stage_index: int = 0
var _diff_index: int = 0
var _char_index: int = 0
var _section: int = Section.STAGE
var _is_input_ready: bool = false
## 确认反馈播放中（闪烁那 0.24s）——用于丢弃重复确认
var _is_confirming: bool = false
var _pulse_tween: Tween


# ═══ 生命周期 ═══

func on_enter() -> void:
	modulate.a = 0.0
	SaveData.reset_session()             # 唯一复位入口：先清干净上一局
	SaveData.is_stage_practice = true    # 置位点（复位点 = reset_session；见基线会话契约）
	_char_index = clampi(SaveData.selected_character, 0, CHAR_NAMES.size() - 1)
	_stages = StageCatalog.playable()
	_stage_index = _index_of_stage(SaveData.current_stage_id)
	_build_stage_list()
	_select_diffs_for_current_stage()
	_sync_char_label()
	_highlight()

	# 整页淡入：`modulate` 对子节点是乘算 ⇒ 标题 / 列表一起入场，不必各自 tween。
	# ⚠️ 但**遮罩不能只靠这一层**：`BasePage._create_overlay()` 会按名字**复用**场景里的 `Overlay`
	#    并把它的 `modulate.a` 归 0（`is_auto_overlay` 默认 true）⇒ 必须用 `_fade_overlay_in()`
	#    把它拉回 1，否则有效 alpha = `0.55 × 0` = **黑幕整个看不见**
	#    （2026-10-04 作者实测「关卡练习菜单的黑幕怎么没有了」）。
	# ⚠️ 遮罩颜色归**场景**（`Overlay.color`），这里不再写死一份。
	_fade_overlay_in(0.35)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _is_input_ready = true)


## 退场只做画面；**不碰 `is_stage_practice`** —— 开局那条路走 `change_scene`，
## 而 `MenuNav.clear_pages()` 是 `queue_free()`（**不调 `on_leave`**）：
## 把标志清在这里会让"取消"和"开局"耦合到 `clear_pages` 的实现细节上。
## 取消路径自己清（见 `_input` 的 `ui_cancel` 分支）。
func on_leave() -> void:
	_is_input_ready = false
	_stop_pulse()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


# ═══ 列表来源 ═══

func _index_of_stage(stage_id: int) -> int:
	for i in _stages.size():
		if _stages[i].stage_id == stage_id:
			return i
	return 0


## EX 面（`stage_no == 7`）只有 Extra 一档；其余面 Easy~Lunatic。
## **static**：难度槽只由「面」决定，与菜单实例无关 ⇒ 可脱场景单测（喂夹具 StageData）。
static func menu_diffs_for(stage: StageData) -> Array[int]:
	if stage != null and stage.stage_no == STAGE_NO_EXTRA:
		return MENU_DIFFS_EXTRA
	return MENU_DIFFS


func _current_stage() -> StageData:
	if _stage_index < 0 or _stage_index >= _stages.size():
		return null
	return _stages[_stage_index]


## 换面后**只重算**难度槽与选中项（不建 UI）—— 二级列表只在真的进二级时建（见 `confirm_current`），
## 免得在一级上下移动时每按一次键就"建 4 个 Label 再全部 free"。
func _select_diffs_for_current_stage() -> void:
	_diffs = menu_diffs_for(_current_stage())
	_diff_index = _diffs.find(SaveData.selected_difficulty)
	if _diff_index < 0:
		_diff_index = 0


func _build_stage_list() -> void:
	_clear(_stage_box)
	for stage in _stages:
		var lbl := _make_label(StageCatalog.display_name_of(stage.stage_id))
		var best := SaveData.get_high_score(stage.stage_id)
		if best > 0:
			lbl.text += "   Hi %08d" % best
		_stage_box.add_child(lbl)


func _build_diff_list() -> void:
	_clear(_diff_box)
	for diff in _diffs:
		_diff_box.add_child(_make_label(SpellRecord.DIFF_NAMES[diff]))


func _sync_char_label() -> void:
	_char_name.text = "← %s →" % CHAR_NAMES[_char_index]


# ═══ 列表行工具 ═══

## 同步清空（`queue_free()` 是延迟的 ⇒ 紧接着重建会看到旧行、列表翻倍）
func _clear(box: VBoxContainer) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.free()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
	return lbl


func _highlight() -> void:
	_stop_pulse()
	if _section == Section.STAGE:
		_clear(_diff_box)          # 一级时二级不留旧行（避免"看着能选"的误导）
	_dim(_stage_box)
	_dim(_diff_box)
	if _section == Section.STAGE:
		_highlight_row(_stage_box, _stage_index)
		_pulse_row(_stage_box, _stage_index)
	else:
		_highlight_row(_diff_box, _diff_index)


func _dim(box: VBoxContainer) -> void:
	for child in box.get_children():
		child.modulate = Color(0.3, 0.3, 0.3)


func _highlight_row(box: VBoxContainer, idx: int) -> void:
	var children := box.get_children()
	for i in children.size():
		if i == idx:
			children[i].modulate = Color.WHITE
		else:
			children[i].modulate = Color(0.3, 0.3, 0.3)


func _pulse_row(box: VBoxContainer, idx: int) -> void:
	var children := box.get_children()
	if idx >= 0 and idx < children.size():
		_start_pulse(children[idx])


func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if item.modulate.a < 0.01:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", Color.WHITE, 0.3)
	_pulse_tween.tween_property(item, "modulate", Color(0.5, 0.5, 0.5), 0.3)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if not _is_input_ready:
		return

	if event.is_action_pressed("ui_cancel"):
		sfx_back()
		if _section == Section.DIFF:
			_section = Section.STAGE
			_highlight()
		else:
			SaveData.is_stage_practice = false   # 取消 = 不练习了，别把标志漏给下一局
			go_back()
		get_viewport().set_input_as_handled()
		return

	# ←→ 换自机（与符卡练习同口径：即时写回 `selected_character`）
	if event.is_action_pressed("ui_left"):
		sfx_nav()
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		SaveData.selected_character = _char_index
		_sync_char_label()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_right"):
		sfx_nav()
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		SaveData.selected_character = _char_index
		_sync_char_label()
		get_viewport().set_input_as_handled()
		return

	if _row_count() <= 0:
		return

	if event.is_action_pressed("ui_up"):
		sfx_nav()
		_move(-1)
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		sfx_nav()
		_move(1)
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		confirm_current()
		get_viewport().set_input_as_handled()


func _row_count() -> int:
	return _stages.size() if _section == Section.STAGE else _diffs.size()


func _move(delta: int) -> void:
	if _section == Section.STAGE:
		_stage_index = wrapi(_stage_index + delta, 0, _stages.size())
		_select_diffs_for_current_stage()   # 换了面 → 难度槽跟着换（EX 与普通面档位不同）
	else:
		_diff_index = wrapi(_diff_index + delta, 0, _diffs.size())


# ═══ 确认键（公开：状态机可脱输入单测）═══

## 一级 → **进二级**（闪一下 → 建二级列）；二级 → 开局。
## ⚠️ 进二级必须**重建**难度列：停在一级时 `_highlight()` 会把 `_diff_box` 清空
## （免得"看着能选"），所以进二级那一步不建就是**空的**（曾出此 bug：二级不显示）。
func confirm_current() -> void:
	if _is_confirming:
		return                 # 闪烁反馈期内的重复确认一律丢弃（免得连按直接跳到底）
	sfx_confirm()
	if _section == Section.STAGE:
		_is_confirming = true
		await _flash_selected(_stage_box, _stage_index)
		_is_confirming = false
		_section = Section.DIFF
		_build_diff_list()
		_highlight()
	else:
		# 末级确认 = 立刻切场景，闪了也看不见 ⇒ 不闪（与符卡练习的末级同口径）
		_launch()


## 确认反馈：选中行短促闪 2 下。**参数对齐 `SpellPracticeMenu._flash_then`**，两个练习菜单手感一致。
## 先 `_stop_pulse()`：呼吸脉冲和闪烁都在写同一个 `modulate`，不停会互相盖（符卡练习那边没停，闪得发虚）。
## `await` 到闪完为止 —— 进下一级要**等它播完**（否则 `_highlight()` 立刻重写 modulate，看着像没闪）。
func _flash_selected(box: VBoxContainer, idx: int) -> void:
	var children := box.get_children()
	if idx < 0 or idx >= children.size():
		return
	var item: Control = children[idx]
	_stop_pulse()
	item.modulate = Color.WHITE
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_loops(2)
	tw.tween_property(item, "modulate", Color(0.25, 0.25, 0.25), 0.06)
	tw.tween_property(item, "modulate", Color.WHITE, 0.06)
	await tw.finished


# ═══ 开局 ═══

## 把选中的**面 / 难度 / 自机**写进全局选择（**不切场景**：意图与副作用分开，便于测试）。
## 返回 false = 当前没有可选的面（空清单），调用方据此别切场景。
func commit_selection() -> bool:
	var stage := _current_stage()
	if stage == null:
		return false
	SaveData.current_stage_id = stage.stage_id
	SaveData.selected_difficulty = _diffs[_diff_index]
	SaveData.selected_character = _char_index
	SaveData.is_stage_practice = true
	return true


## 直接开这一面：提交选择 → 切到正常关卡场景，其余交给关卡流程。
## 通关后 `game_scene._on_stage_cleared()` 会因为 `is_stage_practice` 回标题（不推进下一面）。
func _launch() -> void:
	if not commit_selection():
		return
	_is_input_ready = false
	AudioManager.stop_bgm()
	GameManager.change_scene("res://scenes/game_scene.tscn")

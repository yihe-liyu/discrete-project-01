# SpellPracticeMenu.gd — 符卡练习（记录驱动：记录即真相，配置随解锁入记录）
extends BasePage

const PROBE := preload("res://scripts/scenes/spell_practice_menu_probe.gd")
const DATA := preload("res://scripts/scenes/spell_practice_data.gd")
const LIST_VIEW := preload("res://scripts/scenes/spell_practice_list_view.gd")

@onready var _stage_box: VBoxContainer = $StageBox
@onready var _phase_box: VBoxContainer = $PhaseBox
@onready var _diff_box: VBoxContainer = $DiffBox
@onready var _char_name: Label = $CharPanel/CharName
@onready var _phase_scroll_hint: Label = $PhaseScrollHint

enum Section { STAGE, PHASE, DIFF }
var _section: int = Section.STAGE
var _stage_index: int = 0
var _phase_index: int = 0
var _diff_index: int = 0
var _char_index: int = 0
var _is_input_ready: bool = false

const CHAR_NAMES = SpellRecord.CHAR_NAMES

## 数据模型（无树：记录 → stage/phase/diff + 收取进度）与列表视图（三级列表 + 高亮）。
var _spell_practice_data: SpellPracticeData = DATA.new()
var _spell_practice_list_view: SpellPracticeListView

# 数据模型字段的只读转发：菜单/测试仍按旧名读，写入走 Data 的方法。
var _stages: Array[int]:
	get: return _spell_practice_data.stages
var _phases: Array[Dictionary]:
	get: return _spell_practice_data.phases
var _diff_entries: Array[Dictionary]:
	get: return _spell_practice_data.diff_entries


func _ready() -> void:
	super()
	_spell_practice_list_view = LIST_VIEW.new()
	_spell_practice_list_view.setup(self, _stage_box, _phase_box, _diff_box, _char_name, _phase_scroll_hint)


# ═══ 生命周期 ═══

func on_enter() -> void:
	modulate.a = 0.0
	# 人物**起点** = 上次选的那个人物（与 `player_data_menu` 同口径）
	_char_index = clampi(SaveData.selected_character, 0, CHAR_NAMES.size() - 1)
	_sync_char_label()
	_build_data()
	_build_lists()
	_restore_return_state()   # 从练习返回时还原层级/选中项（无状态则不动；它可能再改 `_char_index`）
	_sync_char_label()        # ← 还原之后再同步一次：标签必须跟着还原后的人物
	_highlight()

	var overlay: ColorRect = $"Overlay"
	overlay.color = Color(0, 0, 0, 0.5)   # ⚠️ 本场景的 Overlay **没在 .tscn 里声明颜色**（默认白）⇒ 这行是必需的

	# ⚠️ 本场景在 .tscn 里**明确关掉了** `is_auto_overlay` ⇒ `BasePage._create_overlay()` 早退，
	#    **不会**把本遮罩的 `modulate.a` 归 0 ⇒ 这里**不需要** `_fade_overlay_in()`，遮罩由本菜单自己管。
	#    （stage 练习菜单是 `is_auto_overlay` 默认 true 的另一种情况：那里**必须**调 `_fade_overlay_in()`，
	#      否则有效 alpha = 0.55 × 0 = 黑幕看不见 —— 2026-10-04 实测。）
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _is_input_ready = true)


func on_leave() -> void:
	_is_input_ready = false
	_spell_practice_list_view.stop_pulse()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


# ═══ 数据 / 列表（实现分别在 Data / ListView）═══

func _build_data() -> void:
	_spell_practice_data.build(_char_index)
	_stage_index = 0
	_phase_index = 0
	_diff_index = 0
	_build_phase_list()


func _change_stage(idx: int) -> void:
	_stage_index = idx
	_spell_practice_data.change_stage(idx, _char_index)
	_phase_index = 0
	_build_phase_list()


func diff_name(v: int) -> String:
	return _spell_practice_data.diff_name(v)


func _build_lists() -> void:
	_spell_practice_list_view.build_lists(_spell_practice_data, _char_index, _phase_index)


func _build_phase_list() -> void:
	_spell_practice_list_view.build_phase_list(_spell_practice_data, _char_index, _phase_index)


func _build_diff_list() -> void:
	_spell_practice_data.build_diff_entries(_phase_index)
	_diff_index = _spell_practice_data.first_unlocked_index()
	_spell_practice_list_view.build_diff_list(_spell_practice_data, _phase_index)


func _rows_visible(vbox: VBoxContainer) -> int:
	return _spell_practice_list_view.rows_visible(vbox)


func _phase_local_index() -> int:
	return _spell_practice_list_view.phase_local_index(_phase_index)


func _highlight() -> void:
	if _section == Section.PHASE:
		_build_diff_list()
	_spell_practice_list_view.highlight(_spell_practice_data, _section,
		_stage_index, _phase_index, _diff_index, _char_index)


# ═══ 收取进度（实现见 Data）═══

func _phase_capture_all(stage: int, boss: int, phase_idx: int, boss_override: BossData = null) -> int:
	return _spell_practice_data.phase_capture_all(stage, boss, phase_idx, _char_index, boss_override)


func _stage_capture_state(stage: int) -> int:
	return _spell_practice_data.stage_capture_state(stage, _char_index)


# ═══ 索引 ═══

func _max_idx() -> int:
	match _section:
		Section.STAGE: return _stages.size() - 1
		Section.PHASE: return _phases.size() - 1
		Section.DIFF:
			return _diff_entries.size() - 1
	return 0


func _get_idx() -> int:
	match _section:
		Section.STAGE: return _stage_index
		Section.PHASE: return _phase_index
		Section.DIFF:  return _diff_index
	return 0


func _set_idx(index: int) -> void:
	match _section:
		Section.STAGE: _change_stage(index)
		Section.PHASE: _phase_index = index
		Section.DIFF:  _diff_index = index


## 在难度选项间移动，跳过锁定（"?"）项
func _move_diff(dir: int) -> void:
	var count := _diff_entries.size()
	if count == 0: return
	var i := _diff_index
	for _step in range(count):
		i = wrapi(i + dir, 0, count)
		if not _diff_entries[i].is_locked:
			_diff_index = i
			return


## 从练习返回：还原到上次离开时的层级与选中项（消费后清空，避免影响下次正常进入）
func _restore_return_state() -> void:
	var st: Dictionary = PracticeSession.return_menu_state
	var authorized: bool = PracticeSession.restore_menu_on_enter and not st.is_empty()
	# ⚠️ 无论这次是否真的还原，**两者都要消费** —— 否则残留状态会让下次正常进入也跳级（曾出此 bug）
	PracticeSession.restore_menu_on_enter = false
	PracticeSession.return_menu_state = {}
	if not authorized:
		return
	_char_index = int(st.get("char", _char_index))
	# ⚠️ 还原可能改了 `_char_index`（从练习返回时就是）—— 标签必须在这里同步。
	#    曾经只在 `on_enter()` 开头写一行标签，而还原发生在其后 ⇒ 返回后人物选择显示回 0 号（作者报的 bug）。
	_sync_char_label()
	# ⚠️ 必须用 `_change_stage()`（而不是只赋 `_stage_index`）—— 它会**重建 `_phases`** 再建第二级；
	#    只赋值的话第二级还留着上一个 stage 的列表（与"切 stage 不重建二级"是同一个病）。
	_change_stage(clampi(int(st.get("stage", 0)), 0, maxi(_stages.size() - 1, 0)))
	_phase_index = clampi(int(st.get("phase", 0)), 0, maxi(_phases.size() - 1, 0))
	_build_diff_list()
	_diff_index = clampi(int(st.get("diff", 0)), 0, maxi(_diff_entries.size() - 1, 0))
	_section = int(st.get("section", Section.STAGE))
	_highlight()


## 人物标签 ↔ `_char_index` 的**唯一同步点**（进场 / 切人物 / 从练习返回都走它）。
func _sync_char_label() -> void:
	_spell_practice_list_view.sync_char_label(_char_index)


func _refresh_char() -> void:
	_sync_char_label()
	_section = Section.STAGE
	_stage_index = 0
	_phase_index = 0
	_diff_index = 0
	_build_data()
	_build_lists()
	_highlight()


# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if not _is_input_ready: return

	if event.is_action_pressed("ui_cancel"):
		sfx_back()
		if _section == Section.STAGE:
			go_back()
		else:
			_section -= 1
			_highlight()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_left"):
		sfx_nav()
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		sfx_nav()
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_refresh_char()
		get_viewport().set_input_as_handled()

	var mx := _max_idx()
	if mx < 0: return

	if event.is_action_pressed("ui_up"):
		sfx_nav()
		if _section == Section.DIFF:
			_move_diff(-1)
		else:
			_set_idx(wrapi(_get_idx() - 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		sfx_nav()
		if _section == Section.DIFF:
			_move_diff(1)
		else:
			_set_idx(wrapi(_get_idx() + 1, 0, mx + 1))
		_highlight()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		sfx_confirm()
		if _section == Section.DIFF:
			_start_practice()
		else:
			_flash_then(func(): _do_accept_transition())
		get_viewport().set_input_as_handled()


func _flash_then(on_done: Callable) -> void:
	var item := _get_highlighted_item()
	if item:
		var tw := item.create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_loops(2)
		tw.tween_property(item, "modulate", Color(0.25, 0.25, 0.25), 0.06)
		tw.tween_property(item, "modulate", Color.WHITE, 0.06)

	var delay := create_tween()
	delay.tween_interval(0.24)
	delay.tween_callback(on_done)


func _do_accept_transition() -> void:
	if _section == Section.STAGE:
		_section = Section.PHASE
	elif _section == Section.PHASE:
		_section = Section.DIFF
		_diff_index = 0
		_build_diff_list()
	_highlight()


func _get_highlighted_item() -> Control:
	return _spell_practice_list_view.get_highlighted_item(_section, _stage_index, _phase_index, _diff_index)


# ═══ 开始练习 ═══

func _start_practice() -> void:
	if _phase_index >= _phases.size():
		push_warning("SpellPractice: 未选中阶段（_phases=%d）——练习未开始" % _phases.size())
		return
	if _diff_index < 0 or _diff_index >= _diff_entries.size():
		push_warning("SpellPractice: 该阶段没有任何可用难度（未解锁或未配置阶段）——练习未开始")
		return
	var entry: Dictionary = _diff_entries[_diff_index]
	if entry.is_locked:
		push_warning("SpellPractice: 难度 %d 未解锁——练习未开始" % int(entry.get("diff", -1)))
		return  # 锁定难度不可开始
	var diff: int = entry.diff
	var info: Dictionary = _phases[_phase_index]
	var rec: SpellRecord = info["rec"]

	# 接线：卡定义优先从花名册按 (stage, boss, phase_index, difficulty) 取——难度正确，
	# 且不依赖解锁时的快照（快照只记首次遇到的那个难度，跨难度练习会错）。
	# C 方案：阶段用规范顺序取（phase_at），Boss 按"拥有该阶段"取（boss_of_phase）。
	# 记录主键 = 规范 phase_index；boss_index 不参与，拆分 Boss 后仍解析到正确 Boss/阶段。
	var phase: PhaseData = BossCatalog.phase_at(rec.stage, rec.phase_index, diff)
	var boss: BossData = BossCatalog.boss_of_phase(rec.stage, rec.phase_index)
	if not rec or phase == null or boss == null:
		push_warning("SpellPractice: 记录缺少阶段配置 stage=%d phase_index=%d（重新解锁一次）" % [rec.stage, rec.phase_index])
		return

	SaveData.selected_difficulty = diff
	SaveData.selected_character = _char_index

	var card_name: String = phase.name if phase.name != "" else "-"
	print("练习: %s 难度: %s" % [card_name, diff_name(diff)])
	var boss_scene: PackedScene = boss.visual
	var boss_label: String = boss.boss_name if boss.boss_name != "" else card_name
	# 记下"从练习返回时要回到哪一层"（第三级 = DIFF，连同三个选中项）
	PracticeSession.return_menu_state = {
		"section": Section.DIFF, "stage": _stage_index,
		"phase": _phase_index, "diff": _diff_index, "char": _char_index,
	}
	# 符卡背景随载荷带一张（练习模式自建 BossData 会丢 spell_background）；
	# BGM 也随载荷带 key：按**选中的这张卡属于哪只 Boss**解析（道中曲 / Boss 曲由 Boss 各自定）
	PracticeSession.start(phase, boss_scene, boss_label, rec.stage, rec.phase_index, boss.spell_background,
		BossCatalog.practice_bgm_key(boss, rec.stage))
	AudioManager.stop_bgm()
	on_leave()
	GameManager.change_scene("res://scenes/game_scene.tscn")


## 测试/调试探针（实现见 spell_practice_menu_probe.gd）。
func probe():
	return PROBE.new(self)

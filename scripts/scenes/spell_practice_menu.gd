# SpellPracticeMenu.gd — 符卡练习（记录驱动：记录即真相，配置随解锁入记录）
extends BasePage

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

const DIFF_NAMES = SpellRecord.DIFF_NAMES
const DIFF_VALUES = SpellRecord.DIFF_VALUES
const CHAR_NAMES = SpellRecord.CHAR_NAMES

# 练习收取进度色（与符卡记录页同色）：全收正蓝（无中间态，未全收保持灰）
const CAPTURE_FULL := Color(0.4, 0.7, 1.0)

## 菜单难度槽的**标准集合**（普通面 Easy~Lunatic）。
## 与 `phases_for_difficulty` 解耦：某难度没配阶段 → 槽仍在，但锁定 `?`、不可选。
## EX 面只有 Extra 档 → 该面改列 `MENU_DIFFS_EXTRA`（序号与普通面分开，见 `_menu_diffs_for`）。
const MENU_DIFFS: Array[int] = [0, 1, 2, 3]
const MENU_DIFFS_EXTRA: Array[int] = [SpellRecord.Difficulty.EXTRA]

## 列表行字号（`_make_label`）；行高由它决定，见 `_row_pitch`。
const LIST_FONT_SIZE := 28


## 该面的练习难度槽集合：普通面 = Easy~Lunatic（固定 4 槽，未配置的锁 `?`）；
## **只配了 Extra 的面（EX）** = 仅 Extra 一槽。
## 按 stage 分支而非单个 Boss：同一面里各阶段的三级槽集合保持一致，UI 高度/语义才稳定。
func _menu_diffs_for(stage: int) -> Array[int]:
	var bosses: Array = BossCatalog.all().get(stage, [])
	for b: BossData in bosses:
		for difficulty in MENU_DIFFS:
			if not b.phases_for_difficulty(difficulty).is_empty():
				return MENU_DIFFS
	for b: BossData in bosses:
		if not b.phases_for_difficulty(SpellRecord.Difficulty.EXTRA).is_empty():
			return MENU_DIFFS_EXTRA
	return MENU_DIFFS


func diff_name(v: int) -> String:
	var idx := DIFF_VALUES.find(v)
	return DIFF_NAMES[idx] if idx >= 0 else "?"


var _stages: Array[int] = []
# 每个 phase: {rec: SpellRecord(带配置), diffs: {diff: SpellRecord}}
var _phases: Array[Dictionary] = []
## 二级（阶段）列表的**可视窗口起点**：超长时只渲染这一段，选中项永远在窗口内（见 `_build_phase_list`）。
var _phase_offset: int = 0
# 当前 phase 的难度项：{diff: int, is_locked: bool}（锁定 = 花名册有该难度但未挑战过）
var _diff_entries: Array[Dictionary] = []
var _pulse_tween: Tween



# ═══ 生命周期 ═══

func on_enter() -> void:
	modulate.a = 0.0
	_char_name.text = "← %s →" % CHAR_NAMES[_char_index]
	_build_data()
	_build_lists()
	_restore_return_state()   # 从练习返回时还原层级/选中项（无状态则不动）
	_highlight()

	var overlay: ColorRect = $"Overlay"
	overlay.color = Color(0, 0, 0, 0.5)

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func(): _is_input_ready = true)


func on_leave() -> void:
	_is_input_ready = false
	_stop_pulse()

	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)


# ═══ 从符卡记录生成 ═══
# 只显示已有记录的卡片，记录数据由实际游玩时填入

func _build_data() -> void:
	_stages.clear()
	_phases.clear()

	var book: SpellRecordBook = SaveData.spell_book
	if book.records.is_empty():
		return
	var seen_stages: Dictionary = {}
	var phase_keys: Array[Dictionary] = []

	for rec in book.records:
		if rec.character != _char_index:
			continue
		if not phase_keys.any(func(p): return p.stage == rec.stage and p.boss_index == rec.boss_index and p.phase_index == rec.phase_index):
			phase_keys.append({stage = rec.stage, boss_index = rec.boss_index, phase_index = rec.phase_index})
		seen_stages[rec.stage] = true

	for stage in seen_stages.keys():
		_stages.append(stage)
	_stages.sort()

	if _stages.is_empty():
		return

	_stage_index = 0
	_change_stage(0)


func _change_stage(idx: int) -> void:
	_stage_index = idx
	_phases.clear()

	if _stages.is_empty():
		return

	var st_num: int = _stages[idx]
	var book: SpellRecordBook = SaveData.spell_book
	var seen_keys: Array[Dictionary] = []

	for rec in book.records:
		if rec.stage != st_num or rec.character != _char_index:
			continue
		if not seen_keys.any(func(k): return k.boss_index == rec.boss_index and k.phase_index == rec.phase_index):
			seen_keys.append({boss_index = rec.boss_index, phase_index = rec.phase_index})

	seen_keys.sort_custom(func(a, b):
		return a.boss_index < b.boss_index or (a.boss_index == b.boss_index and a.phase_index < b.phase_index))

	for key in seen_keys:
		var phase_idx: int = key.phase_index
		# 记录即真相：用该 Boss 该 phase 的任一记录判断符卡/非符 + 提供战斗配置
		var sample: SpellRecord = null
		for rec in book.records:
			if rec.stage == st_num and rec.boss_index == key.boss_index \
					and rec.phase_index == phase_idx and rec.character == _char_index:
				sample = rec
				break
		if not sample:
			continue
		var is_spell: bool = sample.uid != 0

		# label：二级只显示"非符N / 符卡N"（不带 Boss 前缀；不同 Boss 用三级的名字区分）
		# 同一关可能有多只 Boss（道中 / 关底）→ 用 BossData.section_label 当前缀，
		# 否则两级列表里全是"非符1/符卡1"，分不清是谁的。
		var bosses: Array = BossCatalog.all().get(sample.stage, [])
		var boss: BossData = bosses[key.boss_index] if key.boss_index >= 0 and key.boss_index < bosses.size() else null
		var prefix: String = ("%s·" % boss.section_label) if boss != null and boss.section_label != "" else ""
		# 序号**按 Boss 各自计**（道中·非符1 / 关底·非符1）——只影响显示：
		# `phase_number` 仍是**全关规范序**（记录/身份口径不动 ✗），这里减去"该 Boss 之前同类有几张"即得。
		var base_non := 0
		var base_spell := 0
		for bi in range(maxi(key.boss_index, 0)):
			for prev in BossCatalog.boss_slot_phases(bosses[bi] as BossData):
				if prev != null and prev.uid != 0:
					base_spell += 1
				else:
					base_non += 1
		var local_no: int = sample.phase_number - (base_spell if is_spell else base_non)
		var label := "%s%s%d" % [prefix, "符卡" if is_spell else "非符", local_no]

		var info := {rec = sample, boss_index = key.boss_index, phase_index = phase_idx, diffs = {}, label = label}

		# 取出这个 phase 在这角色 + 该 Boss 下所有难度的记录（防不同 Boss 同 phase_index 混入）
		for rec in book.records:
			if rec.stage == st_num and rec.boss_index == key.boss_index \
					and rec.phase_index == phase_idx and rec.character == _char_index:
				info["diffs"][rec.difficulty] = rec

		_phases.append(info)

	_phase_index = 0
	# ⚠️ `_phases` 是二级列表的唯一数据源 —— 必须在这里同步重建二级 UI。
	# 曾经只有 `_build_lists()` 会建它，于是「第一级切 stage」只换了数据、二级仍显示上一个 stage 的行，
	# 且与三级（按新 `_phases` 建）自相矛盾（2026-09-23 修，回归见 test_stage_nav_rebuilds_phase_list）。
	_build_phase_list()


# ═══ 构建列表 ═══

func _build_lists() -> void:
	_clear(_stage_box)
	if _stages.is_empty():
		var lbl := Label.new()
		lbl.text = "No records"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		_stage_box.add_child(lbl)
		_clear(_phase_box)
		_sync_phase_scroll_hint()   # 二级清空 → 提示也要跟着清
		return

	for stage in _stages:
		# 名字走 StageCatalog（内容侧 display_name）→ 回落 "Stage %d"。
		# 别在这里拼 "Stage %d"：B 线这类 id 与名字对不上的舞台就没法显示。
		var lbl := _make_label(StageCatalog.display_name_of(stage))
		# 级联：该 stage 所有 phase 全收 → 正蓝（部分完成不显示中间色）
		if _stage_capture_state(stage) == 2:
			lbl.add_theme_color_override("font_color", CAPTURE_FULL)
		_stage_box.add_child(lbl)
	_build_phase_list()


# ═══ 列表开窗（超长不撑爆面板）═══

## 该列表的**可视行数**：按容器实测高度 / 一行行距算。`-1` = 量不到（尚未布局）→ 不裁剪。
func _rows_visible(vbox: VBoxContainer) -> int:
	var available: float = vbox.size.y
	var pitch: float = _row_pitch(vbox)
	if available <= 0.0 or pitch <= 0.0:
		return -1
	return maxi(1, int(floor(available / pitch)))


## 一行的实际高度 + 行距：字高由主题字体决定，用一行真 Label 量（写死像素会随字体漂）。
func _row_pitch(vbox: VBoxContainer) -> float:
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", LIST_FONT_SIZE)
	probe.text = "0"
	vbox.add_child(probe)
	var row_h: float = probe.get_combined_minimum_size().y
	vbox.remove_child(probe)
	probe.free()
	return row_h + float(vbox.get_theme_constant("separation"))


## 窗口起点：保证选中项落在 `limit` 行窗口内 —— 上下移动时窗口跟着滚，而不是把列表撑长。
## `limit <= 0`（量不到高度）→ 起点 0 = 不裁剪（旧行为，测试直调 `_build_*` 时走这条）。
func _window_start(current: int, selected: int, total: int, limit: int) -> int:
	if limit <= 0 or total <= limit:
		return 0
	var start := current
	if selected < start:
		start = selected
	elif selected >= start + limit:
		start = selected - limit + 1
	return clampi(start, 0, total - limit)


func _build_phase_list() -> void:
	_clear(_phase_box)

	var limit := _rows_visible(_phase_box)
	_phase_offset = _window_start(_phase_offset, _phase_index, _phases.size(), limit)
	var stop: int = _phases.size() if limit <= 0 else mini(_phase_offset + limit, _phases.size())
	for i in range(_phase_offset, stop):
		var info: Dictionary = _phases[i]
		var lbl := _make_label(info["label"])
		# 级联：该 phase 花名册里所有难度槽全收 → 正蓝（锁定 "?" 槽需全部收齐）
		if _phase_capture_all(info["rec"].stage, info["rec"].boss_index, info["rec"].phase_index, info.get("boss")) == 2:
			lbl.add_theme_color_override("font_color", CAPTURE_FULL)
		_phase_box.add_child(lbl)

	_sync_phase_scroll_hint()


## 二级滚动提示：`▲` = 上面还有、`▼` = 下面还有，中间是当前可见区间 / 总数。
## 全部看得见（没被窗口裁掉）→ 空串，不占版面、不制造噪音。
## 箭头位用全角空格占位 —— 只有一侧有箭头时字串长度不变，不会左右抖。
func _sync_phase_scroll_hint() -> void:
	var total: int = _phases.size()
	var shown: int = _phase_box.get_child_count()
	var has_above: bool = _phase_offset > 0
	var has_below: bool = _phase_offset + shown < total
	if not (has_above or has_below):
		_phase_scroll_hint.text = ""
		return
	_phase_scroll_hint.text = "%s %d–%d / %d %s" % [
		"▲" if has_above else "　", _phase_offset + 1, _phase_offset + shown, total,
		"▼" if has_below else "　"]


## 选中项**在当前窗口内的行号**（渲染用的 child index）。
func _phase_local_index() -> int:
	return clampi(_phase_index - _phase_offset, 0, maxi(_phase_box.get_child_count() - 1, 0))


func _build_diff_list() -> void:
	_clear(_diff_box)
	_diff_entries.clear()
	_diff_index = -1   # 无可用难度时保持 -1（不可开始）
	if _phase_index >= _phases.size():
		return

	var info: Dictionary = _phases[_phase_index]
	var rec: SpellRecord = info["rec"]
	var boss: BossData = _boss_for(info)
	var diffs := _menu_diffs_for(rec.stage)

	var configured := _configured_diffs(boss, diffs)
	# 难度槽 = 该面的标准集合（普通面 4 档 / EX 面 Extra）；「有记录 **且** 该难度有阶段」才可选，否则锁定 ?。
	for difficulty in diffs:
		var is_locked: bool = not info["diffs"].has(difficulty) or not configured.has(difficulty)
		_diff_entries.append({diff = difficulty, is_locked = is_locked})

		var record: SpellRecord = info["diffs"].get(difficulty, null)
		var vbox := VBoxContainer.new()
		# 名字行**始终占位**（两种状态下选项高度一致）：锁定 → "?"；符卡 → 卡名；非符 → 空串。
		# 非符不是符卡、没有「卡名」可言（二级已写「非符N」，重复 4 遍是噪音），**但不能省掉这一行** ——
		# 省了选项就从 81 变 33，三级在「非符 / 符卡」两种状态下高度会跳。
		var nl := Label.new()
		if is_locked:
			nl.text = "?"
		elif rec.uid != 0:
			var card := BossCatalog.phase_at(rec.stage, rec.phase_index, difficulty)
			nl.text = card.name if (card and card.name != "") else "-"
		else:
			nl.text = ""   # 占位空行：空 Label(font 30) 最小高仍是 44，与有名字时同高
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 30)
		if record and record.practice_captures > 0 and not is_locked:
			nl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
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

	# 初始索引：跳到第一个未锁定的难度
	for i in _diff_entries.size():
		if not _diff_entries[i].is_locked:
			_diff_index = i
			return


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


# ═══ 练习收取进度（0=无 1=部分 2=全收）═══

## phase 状态：该 phase 在花名册里所有难度槽的练习收取
## 全部收 → 2；部分 → 1；无 → 0。锁定 "?" 槽计 0 收取（该难度也收齐才整条蓝）
func _phase_capture_all(stage: int, boss: int, phase_idx: int, boss_override: BossData = null) -> int:
	var boss_data: BossData = boss_override if boss_override != null else BossCatalog.boss_of_phase(stage, phase_idx)
	var candidate: Array = _configured_diffs(boss_data, _menu_diffs_for(stage))
	if candidate.is_empty():
		return 0  # 花名册未收录，无法判定
	var captured := 0
	for difficulty in candidate:
		var record: SpellRecord = SaveData.spell_book.get_record(stage, phase_idx, boss, _char_index, difficulty)
		if record and record.practice_captures > 0:
			captured += 1
	if captured == candidate.size():
		return 2
	if captured > 0:
		return 1
	return 0


## stage 状态：所有 phase 全收 → 2；有任意收取 → 1；无 → 0
func _stage_capture_state(stage: int) -> int:
	var book := SaveData.spell_book
	var keys: Array = []
	var any_captured := false
	for rec in book.records:
		if rec.stage != stage or rec.character != _char_index:
			continue
		if rec.practice_captures > 0:
			any_captured = true
		if not keys.any(func(k): return k.boss == rec.boss_index and k.phase == rec.phase_index):
			keys.append({boss = rec.boss_index, phase = rec.phase_index})
	if keys.is_empty():
		return 0
	var total := 0
	var done_count := 0
	for key in keys:
		total += 1
		if _phase_capture_all(stage, key.boss, key.phase) == 2:
			done_count += 1
	if done_count == total:
		return 2
	if any_captured:
		return 1
	return 0


# ═══ 高亮 ═══

func _highlight() -> void:
	_stop_pulse()
	# 二级窗口跟着选中项滚（超长列表不撑爆面板）：只有窗口真的要变才重建，不白重建
	if _window_start(_phase_offset, _phase_index, _phases.size(), _rows_visible(_phase_box)) != _phase_offset:
		_build_phase_list()
	_dim_all_vbox(_stage_box)
	_dim_all_vbox(_phase_box)
	_dim_diff()

	match _section:
		Section.STAGE:
			_highlight_one_vbox(_stage_box, _stage_index)
			_pulse_on_vbox(_stage_box, _stage_index)
			_clear(_diff_box)
		Section.PHASE:
			_highlight_one_vbox(_phase_box, _phase_local_index())
			_pulse_on_vbox(_phase_box, _phase_local_index())
			_build_diff_list()
			_dim_diff()
		Section.DIFF:
			_highlight_diff(_diff_index)
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


func _diff_dim_for(i: int) -> Color:
	if i < _diff_entries.size() and _diff_entries[i].is_locked:
		return Color(0.15, 0.15, 0.15)
	return Color(0.3, 0.3, 0.3)


func _dim_diff() -> void:
	# 外层统一灰 + 内层复原（pulse 作用外层——不设外层会残留 pulse 中间值导致颜色不统一）
	var children := _diff_box.get_children()
	for i in children.size():
		var vbox := children[i]
		vbox.modulate = _diff_dim_for(i)
		for child in vbox.get_children():
			child.modulate = Color.WHITE


func _highlight_diff(idx: int) -> void:
	var items := _diff_box.get_children()
	for i in items.size():
		var vbox := items[i]
		# 外层统一：非选中灰（锁定更深）、选中白；内层全部复原
		vbox.modulate = Color.WHITE if i == idx else _diff_dim_for(i)
		for child in vbox.get_children():
			child.modulate = Color.WHITE


func _pulse_on_vbox(vbox: VBoxContainer, idx: int) -> void:
	var children := vbox.get_children()
	if idx < children.size():
		_start_pulse(children[idx])


func _pulse_on_diff(idx: int) -> void:
	var items := _diff_box.get_children()
	if idx < items.size():
		_start_pulse(items[idx])


# ═══ 脉冲 ═══

func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if item.modulate.a < 0.01: return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", Color.WHITE, 0.3)
	_pulse_tween.tween_property(item, "modulate", Color(0.5, 0.5, 0.5), 0.3)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


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
		Section.STAGE: _stage_index = index; _change_stage(index)
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


## Boss 解析：info 注入了 boss 就用它（测试夹具），否则查花名册。
func _boss_for(info: Dictionary) -> BossData:
	var injected: Variant = info.get("boss")
	if injected is BossData:
		return injected
	return BossCatalog.boss_of_phase(info["rec"].stage, info["rec"].phase_index)


## 该 Boss **实际配置**的难度档（有阶段的那些；全收判定用；不回退）。
func _configured_diffs(boss: BossData, diffs: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for difficulty in diffs:
		if boss and not boss.phases_for_difficulty(difficulty).is_empty():
			out.append(difficulty)
	return out


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
	# ⚠️ 必须用 `_change_stage()`（而不是只赋 `_stage_index`）—— 它会**重建 `_phases`** 再建第二级；
	#    只赋值的话第二级还留着上一个 stage 的列表（与"切 stage 不重建二级"是同一个病）。
	_change_stage(clampi(int(st.get("stage", 0)), 0, maxi(_stages.size() - 1, 0)))
	_phase_index = clampi(int(st.get("phase", 0)), 0, maxi(_phases.size() - 1, 0))
	_build_diff_list()
	_diff_index = clampi(int(st.get("diff", 0)), 0, maxi(_diff_entries.size() - 1, 0))
	_section = int(st.get("section", Section.STAGE))
	_highlight()


func _refresh_char() -> void:
	_char_name.text = "← %s →" % CHAR_NAMES[_char_index]
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
	match _section:
		Section.STAGE:
			var children := _stage_box.get_children()
			return children[_stage_index] if _stage_index < children.size() else null
		Section.PHASE:
			var children := _phase_box.get_children()
			var local := _phase_local_index()
			return children[local] if local < children.size() else null
		Section.DIFF:
			var children := _diff_box.get_children()
			return children[_diff_index] if _diff_index < children.size() else null
	return null


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

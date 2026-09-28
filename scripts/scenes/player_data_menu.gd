# PlayerDataMenu.gd — 玩家数据菜单（场景内视图切换）
# 选项视图：三个竖排选项（中文主名+英文小标题，NavPage 导航：未选中暗/选中白+闪烁）
# 符卡记录视图：只显示符卡(uid!=0)，每行符卡名+普通模式收取 n/m；顶部角色(←→)×难度(↑↓)；多页 Z 翻页
@tool
extends NavPage

enum View { OPTIONS, RECORD }

const OPTIONS: Array[Dictionary] = [
	{"zh": "分数排行", "en": "Score Ranking"},
	{"zh": "符卡记录", "en": "SpellCard Record"},
	{"zh": "奖杯", "en": "Trophy"},
]

const CHAR_NAMES = SpellRecord.CHAR_NAMES
const DIFF_NAMES = SpellRecord.DIFF_NAMES
const SUB_COLOR := Color(0.72, 0.72, 0.78, 1.0)  # 英文小标题暗色
## 记录行字号（`_make_row` 三个 Label 共用；行高由它决定，见 `_row_pitch`）
const ROW_FONT_SIZE := 26
## 未遇见符卡的名字位：只显示 uid + 三个问号（与 Boss 未揭名同一套写法）
const UNKNOWN_NAME := "？？？"
## 未遇见的名字位颜色（比正常名暗一档，一眼能看出"还没见过"）
const UNKNOWN_NAME_COLOR := Color(0.42, 0.42, 0.48, 1.0)
## **至少收取过一次**的符卡名颜色（蓝）
const CAPTURED_NAME_COLOR := Color(0.4, 0.7, 1.0)

var _view: int = View.OPTIONS
var _char_index: int = 0
var _diff_index: int = 0
var _cards: Array[Dictionary] = []
var _visible: Array[Dictionary] = []  # 当前页要渲染的卡（= 当前难度的全部符卡，见 _render）
var _page: int = 0
## 每页行数 —— 按面板**实测**高度算（`_rows_per_page`），不写死常量。
## 回归（2026-09-26 作者报）：曾是 `const PER_PAGE = 6`，面板下方还空一大半就翻页。
var _per_page: int = 1


# ═══ 选项视图构建 ═══

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_options()
	_char_index = clampi(SaveData.selected_character, 0, CHAR_NAMES.size() - 1)
	_diff_index = clampi(SaveData.selected_difficulty, 0, DIFF_NAMES.size() - 1)
	_collect_cards()


func _build_options() -> void:
	var box: VBoxContainer = $"LeftPanel/ListContainer"
	box.add_theme_constant_override("separation", 30)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	for option in OPTIONS:
		box.add_child(_make_item(option["zh"], option["en"]))


func _make_item(zh: String, en: String) -> VBoxContainer:
	var item := VBoxContainer.new()
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_theme_constant_override("separation", 2)
	var main := Label.new()
	main.text = zh
	main.add_theme_font_size_override("font_size", 32)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sub := Label.new()
	sub.text = en
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", SUB_COLOR)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	item.add_child(main)
	item.add_child(sub)
	return item


# ═══ 视图切换 ═══

func _show_record_view() -> void:
	_view = View.RECORD
	_is_nav_enabled = false  # 禁 NavPage 导航，改由本页处理角色/难度/Z/X
	_stop_pulse()
	$"LeftPanel".modulate = Color(1, 1, 1, 0.4)  # 选项置灰但保留显示（像练习页面的区块感）
	$RecordView.visible = true
	_update_header()
	_render()


func _hide_record_view() -> void:
	_view = View.OPTIONS
	$RecordView.visible = false
	$"LeftPanel".modulate = Color.WHITE
	_is_nav_enabled = true
	# 冷却：同帧 _input 已处理 cancel，挡住 NavPage._process 的重复 cancel（否则直接退出页面）
	_last_accept_time = Time.get_ticks_msec() / 1000.0
	if _nav_index >= 0 and _nav_index < _nav_items.size():
		_start_pulse(_nav_items[_nav_index])


# ═══ 符卡记录数据 ═══

## 扫**花名册**列出当前难度下的**全部**符卡（uid != 0）——**不看记录**：
## 没遇见过的也要占一行（显示 uid + 问号，见 `_make_row`）。
## key 含 uid：同槽位在不同难度可挂不同卡（如 spell53/54），按 uid 去重避免重复行。
## 名字按**当前难度**取（本页本来就一次只看一个难度，难度切换会重扫）。
func _collect_cards() -> void:
	var seen := {}
	_cards.clear()
	var stage_ids: Array = BossCatalog.all().keys()
	stage_ids.sort()
	for stage_id in stage_ids:
		# 按**舞台规范槽号**遍历 —— 不是"每个 Boss 的第几槽"：多 Boss 面上两者不同
		# （道中 4 槽 + 关底 3 槽 ⇒ 关底第 0 槽是舞台第 4 槽）。`phase_at` 收的就是舞台槽号。
		var order: Array = BossCatalog.stage_phase_order(stage_id)
		for phase_index in order.size():
			var phase: PhaseData = BossCatalog.phase_at(stage_id, phase_index, _diff_index)
			if phase == null or phase.uid == 0:
				continue          # 该难度此槽空着 / 非符（无 uid）→ 不进符卡记录
			if seen.has(phase.uid):
				continue
			seen[phase.uid] = true
			var boss_index: int = BossCatalog.boss_index_of_phase(stage_id, phase_index)
			if boss_index < 0:
				continue
			_cards.append({
				"stage": stage_id, "phase_index": phase_index, "boss_index": boss_index,
				"uid": phase.uid, "name": phase.name if phase.name != "" else "-",
			})
	_cards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["stage"] != b["stage"]:
			return a["stage"] < b["stage"]
		if a["phase_index"] != b["phase_index"]:
			return a["phase_index"] < b["phase_index"]
		return a["uid"] < b["uid"])


func _record_of(card: Dictionary) -> SpellRecord:
	# 记录键不含 uid（同阶段可挂不同 uid 的难度卡）——必须校验记录 uid 与卡一致
	var record := SaveData.spell_book.get_record(card["stage"], card["phase_index"], card["boss_index"],
		_char_index, _diff_index)
	if record and record.uid == card["uid"]:
		return record
	return null


func _total_pages() -> int:
	return maxi(1, int(ceil(_visible.size() / float(maxi(_per_page, 1)))))


## 每页行数 = 面板可用高度 / 一行的实际行距。
## 用面板高度（不是 ListBox 高度）：ListBox 隐藏时是 0，而面板已经布局好 —— 首次翻开也能算对。
func _rows_per_page() -> int:
	var panel: PanelContainer = $"RecordView/RecordPanel"
	var style: StyleBox = panel.get_theme_stylebox("panel")
	var available: float = panel.size.y - style.get_minimum_size().y
	var pitch: float = _row_pitch()
	if available <= 0.0 or pitch <= 0.0:
		return 1
	return maxi(1, int(floor(available / pitch)))


## 一行的高度 + 行距：字高由主题字体决定，用一行真 Label 量（写死像素会随字体漂）。
func _row_pitch() -> float:
	var box: VBoxContainer = $"RecordView/RecordPanel/ListBox"
	var probe := Label.new()
	probe.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	probe.text = "0"
	box.add_child(probe)
	var row_h: float = probe.get_combined_minimum_size().y
	box.remove_child(probe)
	probe.free()
	return row_h + float(box.get_theme_constant("separation"))


## 难度切换：卡片列表来自**花名册**（按难度取名字/uid），所以必须重扫再渲染
func _reload_diff() -> void:
	_collect_cards()
	_update_header()
	_render()

func _update_header() -> void:
	$RecordView/Header/CharLabel.text = "← %s →" % CHAR_NAMES[_char_index]
	$RecordView/Header/DiffLabel.text = DIFF_NAMES[_diff_index]


## 一页一行地渲染**全部**符卡（没遇见过的也在，显示 uid + 问号）。
## 三档显示由 `_make_row` 决定：未遇见 = 「？？？」/ 遇见过 = 名字 / 收取过 = 名字**蓝色**。
func _render() -> void:
	var box: VBoxContainer = $"RecordView/RecordPanel/ListBox"
	for child in box.get_children():
		child.queue_free()

	_visible.assign(_cards)

	if _visible.is_empty():
		var empty := Label.new()
		empty.text = "该难度暂无符卡"
		empty.add_theme_font_size_override("font_size", 26)
		empty.modulate.a = 0.6
		box.add_child(empty)
	else:
		_per_page = _rows_per_page()
		_page = clampi(_page, 0, _total_pages() - 1)   # 面板变矮/卡变少时收敛页码，防空白页
		var start := _page * _per_page
		for i in range(start, mini(start + _per_page, _visible.size())):
			box.add_child(_make_row(_visible[i]))



## 半角字母数字转全角（０-９／Ａ-Ｚ／ａ-ｚ）；全角字符等宽 1em，全角空格补位可精确对齐
func _to_full(text: String) -> String:
	var out := ""
	for i in text.length():
		var code := text[i].unicode_at(0)
		if code >= 48 and code <= 57:
			out += char(code - 48 + 0xFF10)      # 0-9 → ０-９
		elif code >= 65 and code <= 90:
			out += char(code - 65 + 0xFF21)      # A-Z → Ａ-Ｚ
		elif code >= 97 and code <= 122:
			out += char(code - 97 + 0xFF41)      # a-z → ａ-ｚ
		elif code == 46:
			out += "．"                          # . → ．(U+FF0E)
		elif code == 47:
			out += "／"                          # / → ／(U+FF0F)
		else:
			out += text[i]
	return out


## 全角空格（U+3000）左补到 width 字符宽（不补前导零；对齐靠全角空格，不硬调 Label 宽度）
func _pad_cn(v: Variant, width: int) -> String:
	var text := str(v)
	while text.length() < width:
		text = "　" + text
	return text


## 一行 = uid + 名字 + 收取/尝试。
## 三档（作者要求）：
##   ① **没遇见过**（无记录）→ 名字显示 **？？？**（uid 照常显示，便于按 uid 找卡）
##   ② **遇见过但没收取**（有记录、captures == 0）→ 显示真名（普通色）
##   ③ **至少收取过一次**（captures > 0）→ 名字**蓝色**
func _make_row(card: Dictionary) -> HBoxContainer:
	var rec := _record_of(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	# Ｎｏ.＋全角数字（uid 三位宽：全角空格补位右对齐，不补前导零）
	var uid_l := Label.new()
	uid_l.text = _to_full("No.") + _pad_cn(_to_full(str(card["uid"])), 3)
	uid_l.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	uid_l.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	uid_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var name_l := Label.new()
	name_l.text = card["name"] if rec != null else UNKNOWN_NAME
	name_l.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if rec != null and rec.captures > 0:
		name_l.add_theme_color_override("font_color", CAPTURED_NAME_COLOR)   # 收取过：符卡名蓝色
	elif rec == null:
		name_l.add_theme_color_override("font_color", UNKNOWN_NAME_COLOR)    # 未遇见：问号压暗一档
	# 普通模式收取 ***/***（右对齐，不补前导零）
	var stat_l := Label.new()
	if rec:
		stat_l.text = "%s／%s" % [_pad_cn(_to_full(str(rec.captures)), 3), _pad_cn(_to_full(str(rec.attempts)), 3)]
		stat_l.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))  # 统一灰，不用金色
	else:
		stat_l.text = "--"
		stat_l.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	stat_l.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(uid_l)
	row.add_child(name_l)
	row.add_child(stat_l)
	return row


# ═══ 输入 ═══

func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if _view != View.RECORD:
		return  # 选项视图交给 NavPage._process 导航
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		sfx_back()
		_hide_record_view()
		return
	if event.is_action_pressed("ui_left"):
		get_viewport().set_input_as_handled()
		_char_index = wrapi(_char_index - 1, 0, CHAR_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_right"):
		get_viewport().set_input_as_handled()
		_char_index = wrapi(_char_index + 1, 0, CHAR_NAMES.size())
		_page = 0
		_update_header()
		_render()
		sfx_nav()
	elif event.is_action_pressed("ui_up"):
		get_viewport().set_input_as_handled()
		_diff_index = wrapi(_diff_index - 1, 0, DIFF_NAMES.size())
		_page = 0
		_reload_diff()
		sfx_nav()
	elif event.is_action_pressed("ui_down"):
		get_viewport().set_input_as_handled()
		_diff_index = wrapi(_diff_index + 1, 0, DIFF_NAMES.size())
		_page = 0
		_reload_diff()
		sfx_nav()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if _total_pages() > 1:
			_page = (_page + 1) % _total_pages()
			_render()
			sfx_nav()


# ═══ 生命周期 ═══

func on_enter() -> void:
	# 遮罩/标题淡入（BasePage），再走 NavPage 的选项收集 + 交错入场
	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)
	_fade_overlay_in(0.5)
	super()


func _on_item_selected(index: int) -> void:
	match index:
		1:
			_show_record_view()
		_:
			# 占位：分数排行/奖杯 后续接入
			print("[PlayerDataMenu] 选择：%s" % OPTIONS[index]["zh"])


func _on_cancel() -> void:
	go_back()

extends RefCounted
## 整关预览的右栏/顶栏 UI 装配（D3 第二批：从 Workbench 拆出）。
##
## 只负责“建控件 + 接信号 + 页签切换”；播放规则在 Playback，书签数据在 Bookmarks，
## 关卡/舞台在 StageRuntime / PreviewStageWorld。宿主回调用 Callable 注入。

const CATALOG_PANEL := preload("res://scripts/workbench/catalog_panel.gd")
const TABS := ["目录", "书签", "日志"]

var _host: Control
var _stage_data: StageData
var _playback: Playback
var _bookmarks: Bookmarks
var _stage_runtime: StageRuntime
var _stage_grid: GridContainer
var _timeline_bar
var _stage_selected: Callable
var _difficulty_changed: Callable
var _restart: Callable
var _bg_toggled: Callable
var _hitbox_toggled: Callable
var _seed_toggled: Callable
var _jump_to: Callable
var _bookmarks_changed: Callable
var _log_line: Callable

var _stages: Array[StageData] = []
var _stage_sel: OptionButton
var _diff_sel: OptionButton
var _playback_bar: PlaybackBar
var _status_bar: StatusBar
var _bookmark_panel: BookmarkPanel
var _event_log: EventLog
var _catalog
var _tab_btns: Array[Button] = []


func setup(host: Control, initial_stage: StageData, playback: Playback, bookmarks: Bookmarks,
		stage_runtime: StageRuntime, stage_grid: GridContainer, timeline_bar,
		stage_selected: Callable, difficulty_changed: Callable, restart: Callable,
		bg_toggled: Callable, hitbox_toggled: Callable, seed_toggled: Callable,
		jump_to: Callable, bookmarks_changed: Callable, log_line: Callable) -> void:
	_host = host
	_stage_data = initial_stage
	_playback = playback
	_bookmarks = bookmarks
	_stage_runtime = stage_runtime
	_stage_grid = stage_grid
	_timeline_bar = timeline_bar
	_stage_selected = stage_selected
	_difficulty_changed = difficulty_changed
	_restart = restart
	_bg_toggled = bg_toggled
	_hitbox_toggled = hitbox_toggled
	_seed_toggled = seed_toggled
	_jump_to = jump_to
	_bookmarks_changed = bookmarks_changed
	_log_line = log_line


func build() -> void:
	_build_stage_selectors()
	_build_playback_bar()
	_status_bar = StatusBar.new()
	_host.get_node("%StatusSlot").add_child(_status_bar)
	_build_bookmarks()
	_event_log = EventLog.new()
	_host.get_node("%LogSlot").add_child(_event_log)
	_build_catalog()
	_build_tabs()
	_timeline_bar.jump_to.connect(_jump_to)
	_timeline_bar.right_clicked.connect(_bookmark_panel.open_add)


func _build_stage_selectors() -> void:
	_stages = StageCatalog.playable()
	_stage_sel = OptionButton.new()
	for stage in _stages:
		_stage_sel.add_item(StageCatalog.display_name_of(stage.stage_id))
	_stage_sel.selected = _stage_index(_stage_data.stage_id)
	_stage_sel.item_selected.connect(_stage_selected)
	_stage_grid.add_child(WorkbenchUI.label("关卡"))
	_stage_grid.add_child(_stage_sel)

	_diff_sel = OptionButton.new()
	for difficulty in ["Easy", "Normal", "Hard", "Lunatic"]:
		_diff_sel.add_item(difficulty)
	_diff_sel.selected = 1  # Normal
	_diff_sel.item_selected.connect(_difficulty_changed)
	_stage_grid.add_child(WorkbenchUI.label("难度"))
	_stage_grid.add_child(_diff_sel)


func _build_playback_bar() -> void:
	_playback_bar = PlaybackBar.new()
	_playback_bar.play_toggled.connect(_playback.toggle_play)
	_playback_bar.restart_requested.connect(_restart)
	_playback_bar.mute_toggled.connect(_playback.set_muted)
	_playback_bar.bg_toggled.connect(_bg_toggled)
	_playback_bar.hitbox_toggled.connect(_hitbox_toggled)
	_playback_bar.speed_selected.connect(_playback.select_speed)
	_playback_bar.seed_toggled.connect(_seed_toggled)
	_host.get_node("%PlaybackSlot").add_child(_playback_bar)


func _build_bookmarks() -> void:
	_bookmark_panel = BookmarkPanel.new()
	_bookmark_panel.store = _bookmarks
	_bookmark_panel.stage_runtime = _stage_runtime
	_bookmark_panel.jump_requested.connect(_jump_to)
	_bookmark_panel.data_changed.connect(_bookmarks_changed)
	_bookmark_panel.log_requested.connect(_log_line)
	_host.get_node("%BookmarkSlot").add_child(_bookmark_panel)


func _build_catalog() -> void:
	_catalog = CATALOG_PANEL.new()
	_host.get_node("%Pages").add_child(_catalog)
	_catalog.visible = false


func _build_tabs() -> void:
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 22)
		tb.pressed.connect(set_tab.bind(i))
		_host.get_node("%TabBar").add_child(tb)
		_tab_btns.append(tb)
	set_tab(0)


## 页签切换：只显示对应页，按钮高亮同步
func set_tab(index: int) -> void:
	_catalog.visible = index == 0
	_host.get_node("%PageBookmarks").visible = index == 1
	_host.get_node("%PageLog").visible = index == 2
	for tab_index in _tab_btns.size():
		_tab_btns[tab_index].button_pressed = tab_index == index


## 嵌入创作台：隐藏内部“目录”页签，右侧默认落在书签页。
func set_embedded(on: bool) -> void:
	if _tab_btns.is_empty():
		return
	_tab_btns[0].visible = not on
	set_tab(0 if not on else 1)


func catalog_tab_visible() -> bool:
	return _tab_btns.size() > 0 and _tab_btns[0].visible


func stages() -> Array[StageData]:
	return _stages


func stage_selector() -> OptionButton:
	return _stage_sel


func difficulty_selector() -> OptionButton:
	return _diff_sel


func playback_bar() -> PlaybackBar:
	return _playback_bar


func status_bar() -> StatusBar:
	return _status_bar


func bookmark_panel() -> BookmarkPanel:
	return _bookmark_panel


func event_log() -> EventLog:
	return _event_log


func catalog_panel():
	return _catalog


func _stage_index(stage_id: int) -> int:
	for i in _stages.size():
		if _stages[i].stage_id == stage_id:
			return i
	return 0

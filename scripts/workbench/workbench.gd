## 内容工作台 —— 关卡预览沙盒（真实运行时预览 + 书签导航 + 调试工具）
##
## 定位：工作台 = 预览/调试沙盒。脚本与关卡数据一律在 Godot 编辑器里写（.gd/.tres）。
##   v1：LifecycleNode 纯逻辑模型复刻实体公式（一致性靠"复刻"，会漂移）
##   v2：F6 运行时直接加载真实关卡 —— StageManager + BulletManager + 真实协程
##       幽灵玩家提供自机狙目标；一致性与游戏 100% 相同（跑的就是游戏代码）
##
## 能力：
##   · 播放/暂停/重跑（真实引擎时钟）
##   · 跳转：12x 快进到目标时刻（真实关卡不支持任意 seek）
##   · 难度切换 / 静音 / 背景开关 / 固定种子（重跑弹幕序列可复现）
##   · 实时状态（时间/子弹数/敌人/Boss/FPS）+ 事件日志
##   · 逐帧推进（暂停中 F）：弹幕排布/碰撞细节逐帧检查
##   · 书签（协程关卡静态提取 + 人工打点）+ 12x 快进跳转
##   · 编排编辑（数据关卡）：波次表格 + 详情表单 + 增删复制保存 + 单波调试
##   · 出生点拖放：选中波次后 Ctrl+点击场地 = 挪出生点（带路径预览线）
##
## 定位：脚本一律在 Godot 编辑器里写（stage01.gd 等），工作台只做预览/调试；
##       改完脚本 → 重启工作台生效（F5 热重载与脚本页已移除）
##
## 快捷键：Space 播放/暂停 · R 重跑 · F 逐帧 · 1~7 速度档 · ←/→ 跳 ±1s（Ctrl ±5s）
##          B 打书签 · Ctrl+S 保存 · Home 回开头（弹窗/输入框聚焦时不拦截）
##
## 结构（2026-08 组件化重构；2026-08 收窄为纯预览沙盒）：
##   workbench.gd        —— 主控制器：装配 + 关卡生命周期 + 状态路由
##   playback_bar.gd     —— 播放控制行（信号 → 主控制器）
##   status_bar.gd       —— 实时状态显示（主控制器每帧喂数据）
##   event_log.gd        —— 事件日志（自连 GameEvents）
##   bookmark_panel.gd   —— 书签列表 + 编辑弹窗（数据自持 + data_changed 信号）
##   dialog.gd           —— 通用弹窗宿主（书签编辑用）
##   ui_common.gd        —— 控件工厂
##   布局框架在 scenes/workbench.tscn（容器/锚点/分割条/时间轴）
##
## 运行：F6（依赖 autoload），窗口自动设为 1600x1000
extends Control

const VERSION := "v3.0-cs"

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const GHOST_SCRIPT := preload("res://scripts/workbench/ghost_player.gd")
const HITBOX_OVERLAY := preload("res://scripts/workbench/hitbox_overlay.gd")
const BOOKMARK_EXTRACTOR := preload("res://scripts/workbench/bookmark_extractor.gd")
const BOOKMARK_CACHE := preload("res://scripts/workbench/bookmark_cache.gd")
const CATALOG_PANEL := preload("res://scripts/workbench/catalog_panel.gd")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
## Stage 1 = 协程版（stage01.gd Timeline 编排；数据关卡系统已移除）
const STAGE1_COROUTINE := preload("res://data/stages/stage01/stage_data/stage01.tres")

const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]
## 播放速度档位（慢放/快进；书签跳转仍用固定 12x）
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0]

# ═══ .tscn 框架节点 ═══
@onready var _right_panel: MarginContainer = %RightPanel
@onready var _divider: ColorRect = %Divider
@onready var _timeline: TimelineBar = %Timeline
@onready var _stage_grid: GridContainer = %StageGrid
@onready var _world: Node2D = $World
## 3D 背景专用子视口（768x896，与真游戏 SubViewport 同规格 → 纵横比/构图一致）
@onready var _bg_viewport: SubViewport = %BgViewport
## phase 倒计时（与真游戏 BossUI 同款：两位秒数、框顶中央）
var _phase_timer_label: Label

# ═══ 组件（代码挂载到 .tscn 槽位）═══
var _playback: PlaybackBar
var _status: StatusBar
var _log_view: EventLog
var _bookmarks: BookmarkPanel
var _catalog: VBoxContainer  # 内容目录（M1，CatalogPanel；preload 构造规避类缓存）

# 关卡状态
var _stage_data: StageData = STAGE1_COROUTINE
var _ghost: Player
var _background: Node
var _hitbox_overlay: Node2D  # 实际是 HitboxOverlay（preload，避免类缓存依赖）

# 面板拖拽
var _drag_divider := false
var _drag_start_x := 0.0
var _drag_start_off := 0.0
# 详情表单高度拖拽

var _auto_bookmarks: Array = []    # 自动收集时刻（当前缓存，编辑后重存用）
var _manual_bookmarks: Array = []  # 人工打点（可编辑，持久化）

# 播放/编辑状态
var _paused := false
var _muted := false
var _show_bg := true
var _speed_idx := 2          # 速度档位索引（SPEEDS）
var _ff_target := -1.0   # 快进目标时刻（-1 = 不快进）
var _prev_time := -1.0   # 时间轴刷新去重

## 固定种子：重跑时弹幕序列可复现（调参看效果的必备开关）
const FIXED_SEED := 20260801
## 右侧面板页签：书签（导航）/ 日志（调试）
const _TABS := ["目录", "书签", "日志"]
var _tab_btns: Array[Button] = []
var _fixed_seed_on := false
var _stepping := false        # 逐帧推进防重入
# UI 控件（关卡/难度下拉）
var _stage_sel: OptionButton
var _diff_sel: OptionButton


# ═══ 初始化 ═══

func _ready() -> void:
	# UI 在暂停/快进时也要活着
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 主题：东方风深色面板（中文字体 + 卡片 + 控件样式）
	theme = WorkbenchTheme.build()
	%Title.add_theme_color_override("font_color", WorkbenchUI.ACCENT)
	# 工作台专用窗口：纵向 1:1（1600x960 对 1280x960 视口纵向无拉伸 → 文字清晰）
	# 横向 1.25x 给右侧面板腾位置（东方框 64,32~832,928 完整可见）
	get_window().size = Vector2i(1600, 960)
	%Title.text = "内容工作台 %s" % VERSION
	_build_ui()
	_setup_phase_timer()
	_setup_world()
	_load_stage()
	_check_phase_uid_conflicts()
	# 初始面板宽度校正（延迟一帧：等窗口/布局就绪，基于实际窗口宽）
	_clamp_panel_width.call_deferred()


## phase 倒计时（仿真游戏 BossUI）：两位秒数、框顶中央，间隙/无 Boss 隐藏
func _setup_phase_timer() -> void:
	_phase_timer_label = Label.new()
	_phase_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_timer_label.add_theme_font_size_override("font_size", 32)
	_phase_timer_label.position = Vector2(
		GameConfig.FIELD_LEFT + (GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT) / 2.0 - 16.0,
		GameConfig.FIELD_TOP + 16.0)
	_phase_timer_label.visible = false
	$UI.add_child(_phase_timer_label)


## 倒计时更新（与 boss_ui._process 相同逻辑：超时归零、间隙隐藏）
func _update_phase_timer() -> void:
	if _phase_timer_label == null:
		return
	var boss: Boss = GameState.get_boss()
	if boss == null or not is_instance_valid(boss):
		_phase_timer_label.visible = false
		return
	var phase := boss.current_phase()
	if not phase or phase.time_limit <= 0 or boss.is_in_gap():
		_phase_timer_label.visible = false
		return
	_phase_timer_label.visible = true
	var rem := maxf(phase.time_limit - boss.get_elapsed(), 0.0)
	_phase_timer_label.text = "%02d" % int(ceil(rem))


func _process(_delta: float) -> void:
	# 快进到达检测（UI 是 ALWAYS，暂停中也检测）
	if _ff_target >= 0.0:
		var runner := StageManager.current_stage_script()
		if runner == null or runner.game_time() >= _ff_target:
			_stop_fast_forward()
	_update_ui()
	_update_phase_timer()


func _draw() -> void:
	# 场景底：有背景时让 3D 背景透出，只在东方框外画暗色；无背景时全屏实心
	var has_bg: bool = _show_bg and _background and is_instance_valid(_background)
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	if not has_bg:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.03, 0.03, 0.05))
	else:
		# 东方框外四块（左上/右上/左下/右下）压暗，框内留给 3D 背景
		draw_rect(Rect2(0, 0, size.x, field.position.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(0, field.end.y, size.x, size.y - field.end.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(0, field.position.y, field.position.x, field.size.y), Color(0.03, 0.03, 0.05))
		draw_rect(Rect2(field.end.x, field.position.y, size.x - field.end.x, field.size.y), Color(0.03, 0.03, 0.05))
	# 东方框边框（保留，提示边界）+ 网格/路径线（仅背景关闭时画，避免浮在 3D 上）
	draw_rect(field, Color(0.35, 0.45, 0.7, 0.5), false, 2.0)
	if not has_bg:
		for x in range(64, 833, 64):
			draw_line(Vector2(x, 32), Vector2(x, 928), Color(1, 1, 1, 0.05))
		for y in range(32, 929, 64):
			draw_line(Vector2(64, y), Vector2(832, y), Color(1, 1, 1, 0.05))
		# 幽灵玩家路径参考（纵向漂移中线）
		draw_line(Vector2(64, 620), Vector2(832, 620), Color(0.3, 0.9, 0.5, 0.15))
	# 出生点标记（数据关卡波次）

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	AudioManager.set_bgm_pitch(1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, false)


# ═══ 装配 ═══

func _build_ui() -> void:
	# ── 关卡/难度（.tscn 的 StageGrid，代码填控件）──
	_stage_sel = OptionButton.new()
	_stage_sel.add_item("Stage 1 协程版")
	_stage_sel.item_selected.connect(_on_stage_selected)
	_stage_grid.add_child(WorkbenchUI.label("关卡"))
	_stage_grid.add_child(_stage_sel)
	_diff_sel = OptionButton.new()
	for d in DIFFICULTIES:
		_diff_sel.add_item(d)
	_diff_sel.selected = 1  # Normal
	_diff_sel.item_selected.connect(_on_difficulty_changed)
	_stage_grid.add_child(WorkbenchUI.label("难度"))
	_stage_grid.add_child(_diff_sel)

	# ── 播放控制（纯视图，信号驱动）──
	_playback = PlaybackBar.new()
	_playback.play_toggled.connect(_toggle_play)
	_playback.restart_requested.connect(_restart)
	_playback.mute_toggled.connect(_on_mute_toggled)
	_playback.bg_toggled.connect(_on_bg_toggled)
	_playback.hitbox_toggled.connect(func(on: bool):
		if _hitbox_overlay:
			_hitbox_overlay.enabled = on
	)
	_playback.speed_selected.connect(_on_speed_selected)
	_playback.seed_toggled.connect(_on_seed_toggled)
	%PlaybackSlot.add_child(_playback)

	# ── 状态显示 ──
	_status = StatusBar.new()
	%StatusSlot.add_child(_status)


	# ── 书签（数据自持，编辑后 data_changed 回主控制器持久化）──
	_bookmarks = BookmarkPanel.new()
	_bookmarks.jump_requested.connect(_jump_to)
	_bookmarks.data_changed.connect(_on_bookmarks_changed)
	_bookmarks.log_requested.connect(_log_line)
	%BookmarkSlot.add_child(_bookmarks)

	# ── 日志（自连 GameEvents）──
	_log_view = EventLog.new()
	%LogSlot.add_child(_log_view)

	# ── 目录（M1：扫描+分类展示；M2 起接组合台）──
	_catalog = CATALOG_PANEL.new()
	%Pages.add_child(_catalog)
	_catalog.visible = false


	# ── 页签：编排 / 书签 / 日志 / 脚本（播放/状态固定在顶部不滚走）──
	for i in _TABS.size():
		var tb := Button.new()
		tb.text = _TABS[i]
		tb.toggle_mode = true
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, 26)
		tb.pressed.connect(_on_tab_selected.bind(i))
		%TabBar.add_child(tb)
		_tab_btns.append(tb)
	_set_tab(0)

	# ── 时间轴（.tscn 节点）──
	_timeline.jump_to.connect(_jump_to)
	_timeline.right_clicked.connect(_bookmarks.open_add)

	# ── 分割条拖拽（.tscn 节点）──
	_divider.gui_input.connect(_on_divider_input)


## 页签切换：只显示对应页，按钮高亮同步
func _set_tab(i: int) -> void:
	_catalog.visible = i == 0
	%PageBookmarks.visible = i == 1
	%PageLog.visible = i == 2
	for b in _tab_btns.size():
		_tab_btns[b].button_pressed = b == i


func _on_tab_selected(i: int) -> void:
	_set_tab(i)


## 幽灵玩家：实例化真实 player.tscn + 换 GhostPlayer 脚本（继承 Player，类型兼容）
func _setup_world() -> void:
	# World 节点在 .tscn（显式 PAUSABLE！否则继承 root 的 ALWAYS，暂停时敌人照常发弹）
	# 命中框覆盖层：独立 CanvasLayer + 高 z（> 敌弹 10 / 特效 50），画在子弹之上
	_hitbox_overlay = HITBOX_OVERLAY.new()
	_hitbox_overlay.name = "HitboxOverlay"
	_hitbox_overlay.z_index = 60
	$HitboxLayer.add_child(_hitbox_overlay)
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST_SCRIPT)
	_ghost.name = "Player"
	_ghost.player_data = REIMU_DATA
	_world.add_child(_ghost)


# ═══ 关卡加载 / 重跑 ═══

## 加载关卡（start_from >= 0 = 从该时刻续跑，数据关卡专用）
func _load_stage() -> void:
	# 统一复位运行状态（防残留：快进打断后 time_scale/静音错乱）
	_stop_fast_forward()
	_apply_audio()
	# 停止旧关卡 + 清空
	StageManager.stop_stage()
	BulletManager.clear_all()
	AudioManager.stop_bgm()  # 重跑时 BGM 从头播（play_bgm 有同流防重保护，必须先停）
	# 清 World 残留：退场中的 Boss（_exit_controlled 不 queue_free、已从
	# active_enemies 移除）stop_stage 清不到 → 立即脱离树，避免卡在画面上
	for child in _world.get_children():
		if child != _ghost:
			_world.remove_child(child)
			child.queue_free()
	if _background and is_instance_valid(_background):
		# 立即脱离树（不能只 queue_free 延迟删除）：
		# 旧背景的协程/Tween 会和新背景抢同一个 Camera3D（相机数据错乱）
		# 背景挂在 BgViewport（3D 子视口）下，从实际父节点移除
		var bg_parent := _background.get_parent()
		if bg_parent:
			bg_parent.remove_child(_background)
		_background.queue_free()
		_background = null
	GameState.restarting = false
	GameState.reset_all()
	if _diff_sel:
		GameState.selected_difficulty = _diff_sel.selected
	# 固定种子：重跑弹幕序列可复现（调参看效果必备）；关闭则随机化
	if _fixed_seed_on:
		RNG.set_seed(FIXED_SEED)
	else:
		RNG.randomize_seed()
	# 幽灵复位（重头走路径）
	if _ghost:
		_ghost.reset()
	# 背景：必须先设 current_background（load_stage 会启动背景里的协程脚本）
	# 挂 3D 专用 SubViewport（与真游戏同规格）→ 纵横比/相机/构图一致
	if _show_bg and _stage_data.background_scene:
		_background = _stage_data.background_scene.instantiate()
		if _background is StageBackground:
			StageManager.current_background = _background
		# 显式 PAUSABLE：背景演出也随暂停冻结（否则继承 root 的 ALWAYS）
		_background.process_mode = Node.PROCESS_MODE_PAUSABLE
		_bg_viewport.add_child(_background)
	# 真实加载（跑 stage01.gd 的 Timeline）
	StageManager.load_stage(_stage_data)
	# 时间轴 + 书签（协程关卡静态提取 tl.at() 时刻）
	_timeline.set_window(60.0)
	_apply_bookmarks_from_cache()
	_prev_time = -1.0
	_log_line("▶ 加载 Stage %d（难度 %s）" % [_stage_data.stage_id, DIFFICULTIES[_diff_sel.selected]])


# ═══ 书签缓存 + 静默收集 ═══

## 书签（协程关卡）：静态提取 tl.at() 时刻 + 人工打点合并
func _apply_bookmarks_from_cache() -> void:
	_auto_bookmarks = _static_extract()
	_bookmarks.set_bookmarks(_auto_bookmarks, _manual_bookmarks)
	_refresh_timeline_bookmarks()
	_log_line("📖 书签（静态提取 %d 个）" % _auto_bookmarks.size())


## 静态提取书签：扫描 tl.at() 时刻
func _static_extract() -> Array:
	var bm: Array = BOOKMARK_EXTRACTOR.extract_from_script(_stage_data.create_script)
	var auto: Array = []
	for b in bm:
		auto.append({"t": b.t})
	return auto


## 时间轴书签刷新（自动 + 人工合并；与 BookmarkPanel 同源静态合并函数）
func _refresh_timeline_bookmarks() -> void:
	_timeline.clear_bookmarks()
	for it in BookmarkPanel.merged(_auto_bookmarks, _manual_bookmarks):
		_timeline.add_bookmark(it.t, it.label, "manual" if it.get("is_manual", false) else "")

## 书签被编辑（BookmarkPanel data_changed）→ 持久化 + 刷时间轴
func _on_bookmarks_changed(auto: Array, manual: Array) -> void:
	_auto_bookmarks = auto.duplicate(true)
	_manual_bookmarks = manual.duplicate(true)
	var content_hash := BOOKMARK_CACHE.stage_content_hash(_stage_data)
	BOOKMARK_CACHE.save(_stage_data.stage_id, content_hash, _auto_bookmarks, _manual_bookmarks)
	_refresh_timeline_bookmarks()


# ═══ 播放 / 暂停 / 快进 ═══

func _restart() -> void:
	_stop_fast_forward()
	_load_stage()
	_log_line("↺ 重跑")


## 取消进行中的书签收集（切换关卡/重跑时调用，避免旧收集与新流程重叠）

func _toggle_play() -> void:
	if _paused:
		_resume()
	else:
		_pause()


func _pause() -> void:
	if _ff_target >= 0.0:
		_stop_fast_forward()
	get_tree().paused = true
	_paused = true
	_playback.set_playing(false)
	_apply_audio()
	_log_line("⏸ 暂停")


func _resume() -> void:
	get_tree().paused = false
	_paused = false
	_playback.set_playing(true)
	_apply_audio()
	_log_line("▶ 继续")


# ═══ 快捷键 / 逐帧 / 出生点拖放 ═══

## 逐帧推进：暂停状态下精确走一帧物理（弹幕排布/碰撞细节检查）
## 注：physics_frame 信号先于节点物理处理发射 → await 两次 = 恰好一个物理步
func _frame_step() -> void:
	if _stepping:
		return
	if _ff_target >= 0.0:
		_stop_fast_forward()
	if not _paused:
		_pause()
	_stepping = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	get_tree().paused = true
	_paused = true
	Engine.time_scale = SPEEDS[_speed_idx]
	_playback.set_playing(false)
	_apply_audio()
	_stepping = false


## 全局快捷键（输入框聚焦 / 弹窗打开时不拦截）
func _unhandled_input(event: InputEvent) -> void:
	# 输入框聚焦：键让给文本编辑
	var fo := get_viewport().gui_get_focus_owner()
	if fo and (fo is LineEdit or fo is TextEdit or fo is SpinBox):
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	# 物理键优先（键盘布局无关）；无物理键时退回 keycode
	var k: int = event.physical_keycode
	if k == 0:
		k = event.keycode
	match k:
		KEY_SPACE:
			_toggle_play()
			get_viewport().set_input_as_handled()
		KEY_R:
			_restart()
			get_viewport().set_input_as_handled()
		KEY_F:
			_frame_step()
			get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_RIGHT:
			var step := 5.0 if event.ctrl_pressed else 1.0
			var runner := StageManager.current_stage_script()
			var cur := runner.game_time() if runner else 0.0
			_jump_to(maxf(cur + (step if k == KEY_RIGHT else -step), 0.0))
			get_viewport().set_input_as_handled()
		KEY_B:
			_bookmarks.open_add()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var idx: int = k - KEY_1
			if idx >= 0 and idx < SPEEDS.size():
				_on_speed_selected(idx)
				_playback.set_speed(idx)
				get_viewport().set_input_as_handled()
		KEY_HOME:
			_restart()
			get_viewport().set_input_as_handled()
		KEY_G:
			if event.ctrl_pressed:
				_debug_force_clear()
			get_viewport().set_input_as_handled()


##   协程关卡：只能 12x 加速跑到目标（保持唯一路径）
func _jump_to(t: float) -> void:
	# 统一先停现有快进：重置 time_scale / BGM pitch / _ff_target
	# （否则重跑分支或 t≈0 分支会残留 12 倍速 → 数据全乱）
	_stop_fast_forward()
	var runner := StageManager.current_stage_script()
	var cur := runner.game_time() if runner else 0.0
	if t < cur - 0.5:
		# 目标在过去：无法倒带 → 重跑再快进
		_log_line("↺ 目标 %.1fs 在过去（当前 %.1fs），重跑后快进" % [t, cur])
		_load_stage()
	if t <= 0.05:
		return
	_start_fast_forward(t)


func _start_fast_forward(t: float) -> void:
	if _paused:
		_resume()
	_ff_target = t
	Engine.time_scale = 12.0
	# 默认 max_physics_steps_per_frame=8 会丢步（12 步/帧的需求）→ 演出 tween/物理落后
	Engine.max_physics_steps_per_frame = 64
	_apply_audio()
	AudioManager.set_bgm_pitch(Engine.time_scale)  # 音乐跟随快进变速
	_log_line("⏩ 快进到 %.1fs ..." % t)


func _stop_fast_forward() -> void:
	if _ff_target < 0.0:
		return
	var t := _ff_target
	_ff_target = -1.0
	Engine.time_scale = SPEEDS[_speed_idx]  # 恢复到用户设定的速度档位
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	_apply_audio()
	AudioManager.set_bgm_pitch(1.0)  # 音乐恢复正常
	_log_line("▶ 到达 %.1fs" % t)


# ═══ 选项回调 ═══

func _on_stage_selected(idx: int) -> void:
	_stage_data = STAGE1_COROUTINE
	_restart()
	_log_line("🎚 切换关卡：%s" % (_stage_sel.get_item_text(idx)))


func _on_speed_selected(idx: int) -> void:
	_speed_idx = idx
	if _ff_target < 0.0:
		# 不在书签快进中：直接应用（慢放时 BGM 同步变速）
		Engine.time_scale = SPEEDS[_speed_idx]
		AudioManager.set_bgm_pitch(Engine.time_scale)
		_log_line("⏱ 速度 ×%.2f" % SPEEDS[_speed_idx])


## 固定种子：重跑复用同一随机序列（弹幕可复现）
func _on_seed_toggled(on: bool) -> void:
	_fixed_seed_on = on
	if on:
		_log_line("🎲 固定种子 %d：重跑弹幕序列可复现" % FIXED_SEED)
	else:
		_log_line("🎲 随机种子：每次重跑弹幕不同")
	_restart()


func _on_mute_toggled(on: bool) -> void:
	_muted = on
	_apply_audio()


func _on_bg_toggled(on: bool) -> void:
	_show_bg = on
	_restart()


func _on_difficulty_changed(_i: int) -> void:
	_restart()


func _apply_audio() -> void:
	var m: bool = _muted or _paused or _ff_target >= 0.0
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, m)


# ═══ UI 刷新 / 日志 ═══

func _update_ui() -> void:
	var runner := StageManager.current_stage_script()
	var t := runner.game_time() if runner else 0.0
	_status.set_time(t, _ff_target >= 0.0)
	if absf(t - _prev_time) >= 0.05:
		_prev_time = t
		_timeline.time = t
		_timeline.queue_redraw()
	var boss = GameState.get_boss()
	_status.set_status(
		BulletManager.active_bullets.size(),
		GameState.get_active_enemies().size(),
		is_instance_valid(boss),
		int(Engine.get_frames_per_second()))


func _log_line(text: String) -> void:
	if _log_view:
		_log_view.log_line(text)


# ═══ 右侧面板拖拽 ═══

## 面板初始宽度校正：左边缘不越过游戏框右缘 + 16（仅初始/窗口变化调用）
func _clamp_panel_width() -> void:
	var win_w := GameConfig.VIEW_WIDTH
	var min_left := -(win_w - GameConfig.FIELD_RIGHT - 16.0)
	if _right_panel and _right_panel.offset_left > min_left:
		_right_panel.offset_left = min_left
		_divider.offset_left = min_left - 8.0
		_divider.offset_right = min_left


func _on_divider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_divider = event.pressed
		if event.pressed:
			_drag_start_x = (event as InputEventMouseButton).global_position.x
			_drag_start_off = _right_panel.offset_left
	elif event is InputEventMouseMotion and _drag_divider:
		var mm := event as InputEventMouseMotion
		var dx: float = mm.global_position.x - _drag_start_x
		# 宽度范围：面板 300 ~ 窗口-120（offset_left 为负值）
		var min_w := 300.0
		var max_w := GameConfig.VIEW_WIDTH - 120.0
		var new_off := clampf(_drag_start_off + dx, -max_w, -min_w)
		_right_panel.offset_left = new_off
		_divider.offset_left = new_off - 8.0
		_divider.offset_right = new_off


## Ctrl+G：强制击破当前 Boss 阶段（调试解锁 + 跳阶段）
## 配置入记录后：Boss.start_phase 时解锁自动带上战斗配置（无需注册表/CardDef）
## 工作台跑关卡到 Boss → 按 Ctrl+G 击破当前阶段 → 解锁记录 + 阶段链推进到下一张
func _debug_force_clear() -> void:
	var boss = GameState.get_boss()
	if not boss:
		_log_line("ℹ 无 Boss（先跑到 Boss 阶段再按 Ctrl+G）")
		return
	var p_name: String = boss._current_phase.name if boss._current_phase else "?"
	boss._clear_phase(true)
	_log_line("⚡ 强制击破：%s（记录已解锁，阶段链继续）" % p_name)


## 启动检查：扫描全部阶段 .tres 的 uid，冲突报日志（防手滑；配置入记录后无注册表兜底）
func _check_phase_uid_conflicts() -> void:
	var seen := {}
	var da := DirAccess.open("res://data/stages")
	if not da:
		return
	for stage_dir in da.get_directories():
		var phase_dir := "res://data/stages/%s/phase" % stage_dir
		if not DirAccess.dir_exists_absolute(phase_dir):
			continue
		var pda := DirAccess.open(phase_dir)
		if not pda:
			continue
		for f in pda.get_files():
			if not f.ends_with(".tres"):
				continue
			var phase: PhaseData = load("%s/%s" % [phase_dir, f])
			if not phase or phase.uid <= 0:
				continue
			var path := "%s/%s" % [phase_dir, f]
			if seen.has(phase.uid):
				_log_line("⚠️ uid 冲突：%d 同时用于 %s 和 %s" % [phase.uid, seen[phase.uid], path])
			else:
				seen[phase.uid] = path

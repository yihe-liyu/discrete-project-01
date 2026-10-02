## 内容工作台 —— 关卡预览沙盒（真实运行时预览 + 书签导航 + 调试工具）
##
## 定位：工作台 = 预览/调试沙盒。脚本与关卡数据一律在 Godot 编辑器里写（.gd/.tres）。
##   v1：LifecycleNode 纯逻辑模型复刻实体公式（一致性靠"复刻"，会漂移）
##   v2：F6 运行时直接加载真实关卡 —— StageRuntime + BulletManager + 真实协程
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
## 结构（组件化；纯预览沙盒）：
##   workbench.gd        —— 主控制器：装配 + 关卡生命周期 + 状态路由（**只接线**）
##   playback.gd         —— 播放状态机（暂停/速度/快进/逐帧/静音）· 无树可测
##   bookmarks.gd        —— 书签模型（静态提取/人工打点持久化/合并）· 无树可测
##   playback_bar.gd     —— 播放控制行（信号 → 主控制器）
##   status_bar.gd       —— 实时状态显示（主控制器每帧喂数据）
##   event_log.gd        —— 事件日志（自连 GameEvents）
##   bookmark_panel.gd   —— 书签列表 + 编辑弹窗（视图；数据在 Bookmarks）
##   dialog_host.gd      —— 通用弹窗宿主（书签编辑用）
##   workbench_ui.gd     —— 控件工厂
##   布局框架在 scenes/workbench.tscn（容器/锚点/分割条/时间轴）
##
## 运行：F6（依赖 autoload），窗口自动设为 1600x1000
extends Control

const VERSION := "v4.7-ui"

const GHOST_SCRIPT := preload("res://scripts/workbench/ghost_player.gd")
const HITBOX_OVERLAY := preload("res://scripts/workbench/hitbox_overlay.gd")
const CATALOG_PANEL := preload("res://scripts/workbench/catalog_panel.gd")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
## Stage 1 = 协程版（stage01.gd Timeline 编排；数据关卡系统已移除）
const STAGE1_COROUTINE := preload("res://data/stages/stage01/stage_data/stage01.tres")

const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]

# ═══ .tscn 框架节点 ═══

@onready var _timeline: TimelineBar = %Timeline
@onready var _stage_grid: GridContainer = %StageGrid
@onready var _world: Node2D = $World
@onready var _stage_runtime: StageRuntime = %StageRuntime
## 3D 背景专用子视口。**与真游戏同规格**（2026-10-02 BG7 对齐）：
##   场地本体（东方框）= 768×896 @(64,32)，唯一来源 `GameConfig`；
##   容器 = **场地每边 over-scan** `GameConfig.BACKGROUND_OVERSCAN`（16px）⇒ 800×928，
##     与 `game_scene.tscn` 的容器**同尺寸**、相机/fov 相同 ⇒ 预览与真游戏同构图；
##   ⚠️ 画框（金边/网格）在 `FrameOverlay` 里、**画在背景之上** ⇒ 别再为"别盖住金边"把背景内缩
##     （以前内缩 3px，代价是预览与真游戏差 ≈4% 横向 FOV）。
@onready var _bg_viewport: SubViewport = %BgViewport
## 画框层（金边/网格）：必须叠在 3D 背景之上，故单独成节点
@onready var _frame_overlay: FrameOverlay = $FrameOverlay
## phase 倒计时（与真游戏 BossUI 同款：两位秒数、框顶中央）
var _phase_timer_label: Label

# ═══ 组件（代码挂载到 .tscn 槽位）═══
var _playback_bar: PlaybackBar
var _status_bar: StatusBar
var _event_log: EventLog
var _bookmark_panel: BookmarkPanel
var _catalog: VBoxContainer  # 内容目录（CatalogPanel；preload 构造规避类缓存）

# ═══ 服务（无树；规则在服务里，宿主只下发/转发）═══
## 播放状态机：暂停/速度/快进/逐帧/静音
var _playback: Playback
## 书签模型：静态提取 + 人工打点持久化 + 合并
var _bookmarks: Bookmarks

# 关卡状态
var _stage_data: StageData = STAGE1_COROUTINE
var _player: Player
var _background: Node
var _hitbox_overlay: Node2D  # 实际是 HitboxOverlay（preload，避免类缓存依赖）
## 关卡的弹幕世界（组合根创建并注入）
var _bullet_manager: BulletManager

# 播放状态（全部在 Playback 里；本文件只读投影）
var _prev_time := -1.0   # 时间轴刷新去重

## 右侧面板页签：书签（导航）/ 日志（调试）
const _TABS := ["目录", "书签", "日志"]
var _tab_btns: Array[Button] = []
var _stage_shift_y := 0.0    # 嵌入创作台页面偏移；舞台视觉归一回游戏坐标用
# UI 控件（关卡/难度下拉）
var _stage_sel: OptionButton
var _diff_sel: OptionButton


# ═══ 初始化 ═══

func _ready() -> void:
	# UI 在暂停/快进时也要活着
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 服务：先建起来（UI 装配时要把信号接上去）
	_playback = Playback.new()
	_playback.changed.connect(_apply_playback_runtime)
	_playback.logged.connect(_log_line)
	_bookmarks = Bookmarks.new()
	# 主题：东方风深色面板（中文字体 + 卡片 + 控件样式）
	theme = WorkbenchTheme.build()
	# 关键：右侧 UI 挂在 CanvasLayer 下——Control 主题链在非 Control 父节点处断裂
	# （parent_control=null，祖先主题找不到）→ CanvasLayer 的每个 Control 子节点单独挂
	for ui_child in $UI.get_children():
		if ui_child is Control:
			ui_child.theme = theme
	# 坐标归一等布局依赖（_phase_timer_label 等）就绪后执行（同步：首帧即正确，
	# 避免切页首帧闪"旧位置"）——见 _ready 尾部调用
	%Title.add_theme_color_override("font_color", WorkbenchUI.ACCENT)
	# 工作台专用窗口：纵向 1:1（1600x960 对 1280x960 视口纵向无拉伸 → 文字清晰）
	# 横向 1.25x 给右侧面板腾位置（东方框 64,32~832,928 完整可见）
	# 1280x960 = 视口原生尺寸 1:1：stretch "viewport" 下窗口再放大都会被双线性
	# 拉伸，小字号在用户屏幕上看成"乱码"；场地 832 + 面板 440 = 1272 ≤ 1280，本就放得下
	get_window().size = Vector2i(1280, 960)
	%Title.text = "内容工作台 %s" % VERSION
	_build_ui()
	_setup_phase_timer()
	_sync_ui_layer_offset()  # 同步执行：首帧渲染即正确（见函数注释）
	_setup_world()
	_load_stage()
	_check_phase_uid_conflicts()


## phase 倒计时（仿真游戏 BossUI）：两位秒数、框顶中央**符卡名下方**，间隙/无 Boss 隐藏
func _setup_phase_timer() -> void:
	_phase_timer_label = Label.new()
	_phase_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_timer_label.add_theme_font_size_override("font_size", 32)
	# y 与 BossUI.TimerLabel 对齐（场景 offset_top = 64：场地坐标即 FIELD_TOP + 64）—— 别和符卡名同高
	_phase_timer_label.position = Vector2(
		GameConfig.FIELD_LEFT + (GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT) / 2.0 - 16.0,
		GameConfig.FIELD_TOP + 64.0)
	_phase_timer_label.visible = false
	$UI.add_child(_phase_timer_label)


## 倒计时更新（与 boss_ui._process 相同逻辑：超时归零、间隙隐藏）
func _update_phase_timer() -> void:
	if _phase_timer_label == null:
		return
	var boss: Boss = _stage_runtime.entity_registry.get_boss()
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
	_poll_playback()
	_update_ui()
	_update_phase_timer()


## 快进到达检测（本节点是 PROCESS_MODE_ALWAYS，暂停中也照检；取不到 runner = 关卡已停 → 收尾）
func _poll_playback() -> void:
	var runner := _stage_runtime.current_stage_script()
	_playback.poll(runner.game_time() if runner != null else INF)


func _draw() -> void:
	# 场景底：有背景时让 3D 背景透出，只在东方框外画暗色；无背景时全屏实心。
	# 金边 / 网格**不在这里** —— 它们要画在 3D 背景**之上**，见 `FrameOverlay`。
	var has_bg: bool = _playback.show_bg and _background and is_instance_valid(_background)
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP - _stage_shift_y,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT,
		GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	if not has_bg:
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.03, 0.03, 0.05))
		return
	# 东方框外四块（左上/右上/左下/右下）压暗；框内（含背景 over-scan 的那圈）留给 3D 背景
	draw_rect(Rect2(0, 0, size.x, field.position.y), Color(0.03, 0.03, 0.05))
	draw_rect(Rect2(0, field.end.y, size.x, size.y - field.end.y), Color(0.03, 0.03, 0.05))
	draw_rect(Rect2(0, field.position.y, field.position.x, field.size.y), Color(0.03, 0.03, 0.05))
	draw_rect(Rect2(field.end.x, field.position.y, size.x - field.end.x, field.size.y), Color(0.03, 0.03, 0.05))

## CanvasLayer 平移到页面全局位置（独立运行 = 0，嵌入创作台 = 页签横栏下方）
func _sync_ui_layer_offset() -> void:
	var pos := get_global_rect().position
	_stage_shift_y = pos.y
	if pos.y != 0.0:
		# 【重要】不能用 $UI.offset = pos（CanvasLayer.offset）——它会对锚定视口的
		# 控件（时间轴）二次平移：时间轴被推到窗外（962..994）→ 底部露灰边。
		# 改为【逐节点】下移：面板/分隔条顶部 +pos.y（底边 960 是窗口锚定值，不动）；
		# 时间轴锚定视口底部 928..960，天然正确。
		var rp := %RightPanel as Control
		rp.offset_top += pos.y
		# 舞台（幽灵/背景/边框/网格/命中/计时器）归一到游戏坐标（视口空间）：
		# 子弹/敌人在 autoload 根空间=游戏坐标，页面偏移会让瞄准/绘制差 page_y 像素
		$World.position.y -= pos.y
		# 3D 背景按**真游戏的 over-scan 规格**铺（场地每边外扩 `BACKGROUND_OVERSCAN`）⇒ 与
		# `game_scene.tscn` 的容器同尺寸（800×928），预览与真游戏同构图。
		# 金边由 `FrameOverlay` 画在背景**之上**，所以这里不必再为"别盖住金边"而内缩。
		var over := GameConfig.BACKGROUND_OVERSCAN
		$BgContainer.position = Vector2(
			GameConfig.FIELD_LEFT - over, GameConfig.FIELD_TOP - over - pos.y)
		$BgContainer.size = Vector2(
			GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT + over * 2.0,
			GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP + over * 2.0)
		_phase_timer_label.position.y -= pos.y
	# 画框层随页面偏移一起走（它是独立节点，不会自动跟着根 `_draw` 的坐标）
	_redraw_stage()


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

	# ── 播放控制（纯视图；信号直接接状态机，只有需要重跑的才经宿主）──
	_playback_bar = PlaybackBar.new()
	_playback_bar.play_toggled.connect(_playback.toggle_play)
	_playback_bar.restart_requested.connect(_restart)
	_playback_bar.mute_toggled.connect(_playback.set_muted)
	_playback_bar.bg_toggled.connect(_on_bg_toggled)
	_playback_bar.hitbox_toggled.connect(_on_hitbox_toggled)
	_playback_bar.speed_selected.connect(_playback.select_speed)
	_playback_bar.seed_toggled.connect(_on_seed_toggled)
	%PlaybackSlot.add_child(_playback_bar)

	# ── 状态显示 ──
	_status_bar = StatusBar.new()
	%StatusSlot.add_child(_status_bar)


	# ── 书签（视图；数据在 Bookmarks store，编辑后 data_changed 回主控制器落盘）──
	_bookmark_panel = BookmarkPanel.new()
	_bookmark_panel.store = _bookmarks
	_bookmark_panel.stage_runtime = _stage_runtime
	_bookmark_panel.jump_requested.connect(_jump_to)
	_bookmark_panel.data_changed.connect(_on_bookmarks_changed)
	_bookmark_panel.log_requested.connect(_log_line)
	%BookmarkSlot.add_child(_bookmark_panel)

	# ── 日志（自连 GameEvents）──
	_event_log = EventLog.new()
	%LogSlot.add_child(_event_log)

	# ── 目录（扫描+分类展示；起接组合台）──
	_catalog = CATALOG_PANEL.new()
	%Pages.add_child(_catalog)
	_catalog.visible = false


	# ── 页签：编排 / 书签 / 日志 / 脚本（播放/状态固定在顶部不滚走）──
	for i in _TABS.size():
		var tb := Button.new()
		tb.text = _TABS[i]
		tb.toggle_mode = true
		tb.custom_minimum_size = Vector2(0, 22)
		tb.pressed.connect(_on_tab_selected.bind(i))
		%TabBar.add_child(tb)
		_tab_btns.append(tb)
	_set_tab(0)

	# ── 时间轴（.tscn 节点）──
	_timeline.jump_to.connect(_jump_to)
	_timeline.right_clicked.connect(_bookmark_panel.open_add)



## 页签切换：只显示对应页，按钮高亮同步
func _set_tab(i: int) -> void:
	_catalog.visible = i == 0
	%PageBookmarks.visible = i == 1
	%PageLog.visible = i == 2
	for b in _tab_btns.size():
		_tab_btns[b].button_pressed = b == i


func _on_tab_selected(i: int) -> void:
	_set_tab(i)


## 舞台世界：幽灵自机（真实 player.tscn + GhostPlayer 脚本）+ 弹幕世界 + 命中框覆盖层
## 接线与真游戏/组合台**同一条实现**（`StageHost`）——预览跑的就是游戏代码那条路。
func _setup_world() -> void:
	_stage_runtime.world = _world   # 先认领舞台：fx_parent / 敌人生成目标都从运行时走
	_bullet_manager = StageHost.make_bullet_world(self)
	# 幽灵自机走固定路径（GhostPlayer 默认 AUTO），整关预览不看鼠标
	_player = StageHost.make_player(_world, GHOST_SCRIPT, "Player", REIMU_DATA)
	StageHost.wire(_stage_runtime, _bullet_manager, _player, _world)
	_setup_hitbox_overlay()


## 命中框覆盖层：独立 CanvasLayer + 高 z（> 敌弹 10 / 特效 50），画在子弹之上
## （World 节点在 .tscn 且显式 PAUSABLE！否则继承 root 的 ALWAYS，暂停时敌人照常发弹）
func _setup_hitbox_overlay() -> void:
	_hitbox_overlay = HITBOX_OVERLAY.new()
	_hitbox_overlay.name = "HitboxOverlay"
	_hitbox_overlay.z_index = LayerConfig.HITBOX_OVERLAY
	_hitbox_overlay.entity_registry = _stage_runtime.entity_registry
	_hitbox_overlay.bullet_manager = _bullet_manager
	$HitboxLayer.add_child(_hitbox_overlay)


# ═══ 关卡加载 / 重跑 ═══

## 加载关卡（start_from >= 0 = 从该时刻续跑，数据关卡专用）
## 供创作台切页时停止本工作台承载的关卡
func stop_stage() -> void:
	_stage_runtime.stop_stage()


func _load_stage() -> void:
	# 统一复位运行状态（防残留：快进打断后 time_scale/静音错乱）
	_playback.stop_fast_forward()
	_apply_playback_runtime()
	# 停止旧关卡 + 清空
	_stage_runtime.stop_stage()
	_bullet_manager.reset_world()  # 重跑：回收内核 program/弹型（原生表只增不减）
	AudioManager.stop_bgm()  # 重跑时 BGM 从头播（play_bgm 有同流防重保护，必须先停）
	# 清 World 残留：退场中的 Boss（_is_exit_controlled 不 queue_free、已从
	# active_enemies 移除）stop_stage 清不到 → 立即脱离树，避免卡在画面上
	for child in _world.get_children():
		if child == _player or child == _stage_runtime:
			continue  # StageRuntime 是 World 下的常驻结构节点，不能清
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
	SaveData.is_restarting = false
	SaveData.reset_all(_stage_runtime.entity_registry)
	if _diff_sel:
		SaveData.selected_difficulty = _diff_sel.selected
	# 固定种子：重跑弹幕序列可复现（调参看效果必备）；关闭则随机化
	if _playback.fixed_seed:
		RNG.set_seed(_playback.fixed_seed_value())
	else:
		RNG.randomize_seed()
	# 幽灵复位（重头走路径）
	if _player:
		_player.reset()
	# 背景：必须先设 current_background（load_stage 会启动背景里的协程脚本）
	# 挂 3D 专用 SubViewport（与真游戏同规格）→ 纵横比/相机/构图一致
	if _playback.show_bg and _stage_data.background_scene:
		_background = _stage_data.background_scene.instantiate()
		if _background is StageBackground:
			_stage_runtime.current_background = _background
		# 显式 PAUSABLE：背景演出也随暂停冻结（否则继承 root 的 ALWAYS）
		_background.process_mode = Node.PROCESS_MODE_PAUSABLE
		_bg_viewport.add_child(_background)
	# 真实加载（跑 stage01.gd 的 Timeline）
	_stage_runtime.load_stage(_stage_data)
	# 时间轴 + 书签（自动 = 静态提取 timeline.at() 时刻；人工 = 缓存恢复）
	_timeline.set_window(60.0)
	_load_bookmarks()
	_prev_time = -1.0
	_log_line("▶ 加载 Stage %d（难度 %s）" % [_stage_data.stage_id, DIFFICULTIES[_diff_sel.selected]])


# ═══ 书签（模型在 Bookmarks；这里只管落盘与时间轴）═══

## 打开关卡的书签：读缓存（人工打点）+ 静态提取（自动书签）
func _load_bookmarks() -> void:
	var info := _bookmarks.open(_stage_data)
	_bookmark_panel.refresh()
	_refresh_timeline_bookmarks()
	_log_line("＊ 书签：自动 %d 个 · 人工 %d 个（%s）"
		% [info.auto, info.manual, _bookmark_source_text(info)])


## 缓存来历（首次 / 命中 / 脚本变了 —— 三件事在日志里要能分清）
func _bookmark_source_text(info: Dictionary) -> String:
	if not info.cache_hit:
		return "首次，无缓存"
	return "缓存命中" if info.cache_fresh else "缓存失效（关卡脚本已改，自动书签重收集）"


## 时间轴书签刷新（与列表面板同源的合并视图）
func _refresh_timeline_bookmarks() -> void:
	_timeline.clear_bookmarks()
	for it in _bookmarks.merged():
		_timeline.add_bookmark(it.t, it.label, "manual" if it.get("is_manual", false) else "")


## 书签被编辑（BookmarkPanel data_changed）→ 落盘 + 刷时间轴
func _on_bookmarks_changed() -> void:
	_bookmarks.save()
	_refresh_timeline_bookmarks()


# ═══ 播放 / 暂停 / 快进（状态机在 Playback；这里只发起与转发）═══

func _restart() -> void:
	_playback.stop_fast_forward()
	_load_stage()
	_log_line("＊ 重跑")


# ═══ 快捷键 / 逐帧 ═══

## 逐帧推进：暂停状态下精确走一帧物理（弹幕排布/碰撞细节检查）
## 注：physics_frame 信号先于节点物理处理发射 → await 两次 = 恰好一个物理步
## `begin_step/end_step` 各自发 changed → 宿主下发"这一瞬放行物理、time_scale 归 1"
func _frame_step() -> void:
	if not _playback.begin_step():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_playback.end_step()


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
			_playback.toggle_play()
			get_viewport().set_input_as_handled()
		KEY_R:
			_restart()
			get_viewport().set_input_as_handled()
		KEY_F:
			_frame_step()
			get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_RIGHT:
			var step := 5.0 if event.ctrl_pressed else 1.0
			_jump_to(maxf(_current_time() + (step if k == KEY_RIGHT else -step), 0.0))
			get_viewport().set_input_as_handled()
		KEY_B:
			_bookmark_panel.open_add()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7:
			var idx: int = k - KEY_1
			if idx >= 0 and idx < Playback.SPEEDS.size():
				_playback.select_speed(idx)  # 播放控制行的下拉由 changed 回落同步
				get_viewport().set_input_as_handled()
		KEY_HOME:
			_restart()
			get_viewport().set_input_as_handled()
		KEY_G:
			if event.ctrl_pressed:
				_debug_force_clear()
			get_viewport().set_input_as_handled()


## 跳转（时间轴点击 / 书签列表 / ←→ 键）：协程关卡不能倒带 → 目标在过去时先重跑
func _jump_to(t: float) -> void:
	var cur := _current_time()
	if _playback.jump_reload_needed(t, cur):
		_log_line("＊ 目标 %.1fs 在过去（当前 %.1fs），重跑后快进" % [t, cur])
		_load_stage()
	_playback.jump_to(t)


## 当前游戏内时刻（无 runner = 0）
func _current_time() -> float:
	var runner := _stage_runtime.current_stage_script()
	return runner.game_time() if runner != null else 0.0


# ═══ 选项回调 ═══

func _on_stage_selected(idx: int) -> void:
	_stage_data = STAGE1_COROUTINE
	_restart()
	_log_line("＊ 切换关卡：%s" % (_stage_sel.get_item_text(idx)))


## 固定种子：重跑复用同一随机序列（弹幕可复现）
func _on_seed_toggled(on: bool) -> void:
	_playback.set_fixed_seed(on)
	_restart()


## 命中框覆盖层开关（覆盖层不是播放状态，直接设）
func _on_hitbox_toggled(on: bool) -> void:
	if _hitbox_overlay:
		_hitbox_overlay.is_enabled = on


func _on_bg_toggled(on: bool) -> void:
	_playback.set_show_bg(on)
	_restart()


func _on_difficulty_changed(_i: int) -> void:
	_restart()


# ═══ 状态下发 ═══

## `Playback.changed` 的唯一落点：把状态机投影下发到引擎 / 音频 / 播放控制行。
## 静音 → 总线；暂停/逐帧 → tree.paused；速度/快进 → time_scale + 物理步上限 + BGM 音高。
func _apply_playback_runtime() -> void:
	var scene_tree := get_tree()
	if scene_tree != null:
		scene_tree.paused = _playback.should_pause_tree()
	Engine.time_scale = _playback.desired_time_scale()
	Engine.max_physics_steps_per_frame = _playback.desired_physics_steps()
	AudioManager.set_bgm_pitch(_playback.desired_bgm_pitch())
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, _playback.is_audio_muted())
	if _playback_bar != null:
		_playback_bar.set_playing(not _playback.paused)
		_playback_bar.set_speed(_playback.speed_index)
	# 背景开关会改变「框外压暗 / 网格」的形态 ⇒ 两层都要重画
	_redraw_stage()


## 舞台视觉重画：根 `_draw`（框外压暗）+ 画框层（金边 / 网格）。
## 画框必须画在 3D 背景**之上**，所以它在 `FrameOverlay` 里而不是根 `_draw`（见 frame_overlay.gd）。
func _redraw_stage() -> void:
	queue_redraw()
	if _frame_overlay == null:
		return
	var has_bg: bool = _playback.show_bg and _background != null and is_instance_valid(_background)
	_frame_overlay.sync(_stage_shift_y, not has_bg)


# ═══ UI 刷新 / 日志 ═══

func _update_ui() -> void:
	var t := _current_time()
	_status_bar.set_time(t, _playback.ff_active())
	if absf(t - _prev_time) >= 0.05:
		_prev_time = t
		_timeline.time = t
		_timeline.queue_redraw()
	var boss = _stage_runtime.entity_registry.get_boss()
	_status_bar.set_status(
		_bullet_manager.active_count(),
		_stage_runtime.entity_registry.get_active_enemies().size(),
		is_instance_valid(boss),
		int(Engine.get_frames_per_second()))


func _log_line(text: String) -> void:
	if _event_log:
		_event_log.log_line(text)


## Ctrl+G：强制击破当前 Boss 阶段（调试解锁 + 跳阶段）
## 配置入记录后：Boss.start_phase 时解锁自动带上战斗配置（无需注册表/CardDef）
## 工作台跑关卡到 Boss → 按 Ctrl+G 击破当前阶段 → 解锁记录 + 阶段链推进到下一张
func _debug_force_clear() -> void:
	var boss = _stage_runtime.entity_registry.get_boss()
	if not boss:
		_log_line("＊ 无 Boss（先跑到 Boss 阶段再按 Ctrl+G）")
		return
	var p_name: String = boss._phase_data.name if boss._phase_data else "?"
	boss.clear_phase(true)
	_log_line("！ 强制击破：%s（记录已解锁，阶段链继续）" % p_name)


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
				_log_line("⚠ uid 冲突：%d 同时用于 %s 和 %s" % [phase.uid, seen[phase.uid], path])
			else:
				seen[phase.uid] = path

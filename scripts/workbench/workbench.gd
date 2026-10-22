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
##   · 关卡切换（[code]StageCatalog.playable()[/code]）+ 难度切换 / 静音 / 背景开关 / 固定种子（重跑弹幕序列可复现）
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
##   workbench.gd        —— 主控制器：装配 + 关卡生命周期 + 状态路由（只接线）
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

const PREVIEW_SUSPENDER := preload("res://scripts/workbench/preview_suspender.gd")
const PREVIEW_LAYOUT := preload("res://scripts/workbench/preview_layout.gd")
const PREVIEW_INPUT := preload("res://scripts/workbench/preview_input.gd")
const PREVIEW_STAGE_WORLD := preload("res://scripts/workbench/preview_stage_world.gd")
const PREVIEW_PHASE_TIMER := preload("res://scripts/workbench/preview_phase_timer.gd")
const PREVIEW_DEBUG_TOOLS := preload("res://scripts/workbench/preview_debug_tools.gd")
const PREVIEW_UI := preload("res://scripts/workbench/preview_ui.gd")
const PREVIEW_STAGE_LOADER := preload("res://scripts/workbench/preview_stage_loader.gd")
const PREVIEW_PLAYBACK := preload("res://scripts/workbench/preview_playback.gd")
const PREVIEW_BOOKMARKS := preload("res://scripts/workbench/preview_bookmarks.gd")
## Stage 1 = 协程版（stage01.gd Timeline 编排；数据关卡系统已移除）
const STAGE1_COROUTINE := preload("res://data/stages/stage01/stage_data/stage01.tres")

const DIFFICULTIES: Array[String] = ["Easy", "Normal", "Hard", "Lunatic"]

# ═══ .tscn 框架节点 ═══

@onready var _timeline: TimelineBar = %Timeline
@onready var _stage_grid: GridContainer = %StageGrid
@onready var _world: Node2D = $World
@onready var _stage_runtime: StageRuntime = %StageRuntime
## 3D 背景专用子视口。与真游戏同规格（2026-10-02 BG7 对齐）：
##   场地本体（东方框）= 768×896 @(64,32)，唯一来源 [code]GameConfig[/code]；
##   容器 = 场地每边 over-scan [code]GameConfig.BACKGROUND_OVERSCAN[/code]（16px）⇒ 800×928，
##     与 [code]game_scene.tscn[/code] 的容器同尺寸、相机/fov 相同 ⇒ 预览与真游戏同构图；
## 画框（金边/网格）在 [code]FrameOverlay[/code] 里、画在背景之上 ⇒ 别再为"别盖住金边"把背景内缩
##     （以前内缩 3px，代价是预览与真游戏差 ≈4% 横向 FOV）。
@onready var _bg_viewport: SubViewport = %BgViewport
## 画框层（金边/网格）：必须叠在 3D 背景之上，故单独成节点
@onready var _frame_overlay: FrameOverlay = $FrameOverlay

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
var _hitbox_overlay: Node2D  # 实际是 HitboxOverlay（preload，避免类缓存依赖）
## 关卡的弹幕世界（组合根创建并注入）
var _bullet_manager: BulletManager

# 播放状态（全部在 Playback 里；本文件只读投影）
var _prev_time := -1.0   # 时间轴刷新去重

## 嵌入创作台时：隐藏内部“目录”页签，统一走创作台的全局目录抽屉。
var _embedded: bool = false
## 创作台 canvas_transform 的 x 偏移；Timeline/phase 计时器要跟场地
var _view_offset_x: float = 0.0
## 冻结/恢复服务（D3：CanvasLayer + process 子树 + BGM + 全局引擎状态）
var _preview_suspender
## 嵌入创作台坐标归一（World/右栏/背景/计时器/画框）
var _preview_layout
## 键盘快捷键翻译（D3：输入服务）
var _preview_input
## 舞台世界装配（D3：BulletManager/Player/Hitbox）
var _preview_stage_world
## Boss 符卡倒计时（D3：phase timer 服务）
var _phase_timer
## 调试工具（D3：强制击破 / uid 冲突扫描）
var _preview_debug
## 右栏/顶栏 UI 装配（D3：控件 + 信号 + 页签）
var _preview_ui
## 关卡加载/重跑流水线（D3：停关/清 World/背景/复位/load_stage）
var _preview_stage_loader
## 播放投影/逐帧/跳转（D3）
var _preview_playback
## 书签 open/保存/时间轴（D3）
var _preview_bookmarks
# UI 控件（关卡/难度下拉）
var _stage_sel: OptionButton
var _diff_sel: OptionButton
## 关卡下拉的数据源 = [code]StageCatalog.playable()[/code]（下标 = 下拉项下标）
var _stages: Array[StageData] = []


# ═══ 初始化 ═══

func _ready() -> void:
	# UI 在暂停/快进时也要活着
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 创作台可能用 viewport canvas_transform 平移游戏画布；命中框要跟着走
	$HitboxLayer.follow_viewport_enabled = true
	# 服务：先建起来（UI 装配时要把信号接上去）
	_playback = Playback.new()
	_playback.changed.connect(_apply_playback_runtime)
	_preview_suspender = PREVIEW_SUSPENDER.new()
	_preview_suspender.setup(self, Callable(self, "_apply_playback_runtime"))
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
	if not _embedded:
		get_window().size = Vector2i(1280, 960)
	%Title.text = "内容工作台 %s" % VERSION
	_build_ui()
	_preview_playback = PREVIEW_PLAYBACK.new()
	_preview_playback.setup(self, _playback, _playback_bar, _stage_runtime,
		Callable(self, "_redraw_stage"), Callable(self, "_load_stage"), Callable(self, "_log_line"))
	_preview_bookmarks = PREVIEW_BOOKMARKS.new()
	_preview_bookmarks.setup(_bookmarks, _bookmark_panel, _timeline, Callable(self, "_log_line"))
	_preview_input = PREVIEW_INPUT.new()
	_preview_input.setup(self, _playback, _bookmark_panel,
		Callable(self, "_restart"), Callable(self, "_frame_step"),
		Callable(self, "_jump_to"), Callable(self, "current_time"),
		Callable(self, "_debug_force_clear"))
	_preview_debug = PREVIEW_DEBUG_TOOLS.new()
	_preview_debug.setup(_stage_runtime, Callable(self, "_log_line"))
	_phase_timer = PREVIEW_PHASE_TIMER.new()
	_phase_timer.setup($UI, _stage_runtime)
	set_view_offset_x(_view_offset_x)
	_preview_layout = PREVIEW_LAYOUT.new()
	_preview_layout.setup(self, _world, %RightPanel as Control, $BgContainer as Control,
		_phase_timer.label(), Callable(self, "embedded"), Callable(self, "_redraw_stage"))
	_sync_ui_layer_offset()  # 同步执行：首帧渲染即正确（见函数注释）
	call_deferred("_sync_ui_layer_offset")  # 布局完成后再同步一次：嵌入创作台时首帧 get_global_rect 可能还是 (0,0)
	_setup_world()
	_preview_stage_loader = PREVIEW_STAGE_LOADER.new()
	_preview_stage_loader.setup(_playback, _stage_runtime, _bullet_manager, _player, _world,
		_bg_viewport, _timeline, _diff_sel,
		Callable(self, "_load_bookmarks"), Callable(self, "_apply_playback_runtime"))
	_load_stage()
	_check_phase_uid_conflicts()




func _process(_delta: float) -> void:
	if _preview_playback != null:
		_preview_playback.poll()
	_update_ui()
	if _phase_timer != null:
		_phase_timer.update()


func _draw() -> void:
	# 场景底：有背景时让 3D 背景透出，只在东方框外画暗色；无背景时全屏实心。
	# 金边 / 网格**不在这里** —— 它们要画在 3D 背景**之上**，见 `FrameOverlay`。
	var background = _preview_stage_loader.background() if _preview_stage_loader != null else null
	var has_bg: bool = _playback.show_bg and background != null and is_instance_valid(background)
	var stage_shift: float = _preview_layout.stage_shift_y() if _preview_layout != null else 0.0
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP - stage_shift,
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

## 场地空间 UI 的 x 偏移：Timeline / phase 计时器跟 canvas_transform 走；
## 右面板是屏幕右锚定，不动。
func set_view_offset_x(offset: float) -> void:
	_view_offset_x = offset
	if _timeline != null:
		_timeline.offset_left = GameConfig.FIELD_LEFT + offset
		_timeline.offset_right = GameConfig.FIELD_RIGHT + offset
	if _phase_timer != null:
		_phase_timer.set_x_offset(offset)


## CanvasLayer 平移到页面全局位置（独立运行 = 0，嵌入创作台 = 页签横栏下方）。
## 具体坐标归一见 PreviewLayout（D3 拆出的服务）；这里只委托。
func _sync_ui_layer_offset() -> void:
	if _preview_layout != null:
		_preview_layout.sync()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8  # 恢复默认
	AudioManager.set_bgm_pitch(1.0)
	var idx := AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, false)


# ═══ 装配 ═══

func _build_ui() -> void:
	_preview_ui = PREVIEW_UI.new()
	_preview_ui.setup(self, _stage_data, _playback, _bookmarks, _stage_runtime, _stage_grid, _timeline,
		Callable(self, "_on_stage_selected"), Callable(self, "_on_difficulty_changed"),
		Callable(self, "_restart"), Callable(self, "_on_bg_toggled"),
		Callable(self, "_on_hitbox_toggled"), Callable(self, "_on_seed_toggled"),
		Callable(self, "_jump_to"), Callable(self, "_on_bookmarks_changed"),
		Callable(self, "_log_line"))
	_preview_ui.build()
	_stages = _preview_ui.stages()
	_stage_sel = _preview_ui.stage_selector()
	_diff_sel = _preview_ui.difficulty_selector()
	_playback_bar = _preview_ui.playback_bar()
	_status_bar = _preview_ui.status_bar()
	_bookmark_panel = _preview_ui.bookmark_panel()
	_event_log = _preview_ui.event_log()
	_catalog = _preview_ui.catalog_panel()


## 舞台世界：幽灵自机 + 弹幕世界 + 命中框覆盖层（构造在 PreviewStageWorld，D3）。
func _setup_world() -> void:
	_preview_stage_world = PREVIEW_STAGE_WORLD.new()
	_preview_stage_world.setup(self, _world, _stage_runtime, $HitboxLayer)
	_preview_stage_world.build()
	_bullet_manager = _preview_stage_world.bullet_manager()
	_player = _preview_stage_world.player()
	_hitbox_overlay = _preview_stage_world.hitbox_overlay()

# ═══ 关卡加载 / 重跑 ═══

## 加载关卡（start_from >= 0 = 从该时刻续跑，数据关卡专用）
## 供创作台切页时停止本工作台承载的关卡（旧契约；保活路径用 suspend_preview）
func stop_stage() -> void:
	_stage_runtime.stop_stage()


## 创作台切走：冻结舞台 + 暂停 BGM，但保留运行时/时间/书签/播放状态。
## 必须解掉全局 paused / time_scale / 静音，否则切到别的台会被整关预览的暂停状态卡住。
func suspend_preview() -> void:
	if _preview_suspender != null:
		_preview_suspender.suspend()
	_sync_bg_viewport()


func resume_preview() -> void:
	if _preview_suspender != null:
		_preview_suspender.resume()
	_sync_bg_viewport()


func preview_suspended() -> bool:
	return _preview_suspender.is_suspended() if _preview_suspender != null else false


## 当前游戏内时刻（创作台/测试用；不摸私有 runner）
func current_time() -> float:
	return _current_time()


# ═══ 公开接缝（创作台宿主用；不摸 `_私有`）═══

func catalog_panel():
	return _catalog


func bullet_manager() -> BulletManager:
	return _bullet_manager


func stage_runtime() -> StageRuntime:
	return _stage_runtime


## 当前整关预览的 StageData（创作台脚手架用）。
func current_stage_data() -> StageData:
	return _stage_data


## 嵌入创作台：隐藏内部“目录”页签（全局抽屉接管），右侧默认落在书签页。
func set_embedded(on: bool) -> void:
	_embedded = on
	if _preview_ui != null:
		_preview_ui.set_embedded(on)


func embedded() -> bool:
	return _embedded


func catalog_tab_visible() -> bool:
	return _preview_ui.catalog_tab_visible() if _preview_ui != null else false


func _load_stage() -> void:
	if _preview_stage_loader == null:
		return
	_preview_stage_loader.load_stage(_stage_data)
	_sync_bg_viewport()
	_prev_time = -1.0
	_log_line("▶ 加载 Stage %d（难度 %s）" % [_stage_data.stage_id, DIFFICULTIES[_diff_sel.selected]])

# ═══ 书签（实现见 PreviewBookmarks）═══

func _load_bookmarks() -> void:
	if _preview_bookmarks != null:
		_preview_bookmarks.open(_stage_data)


func _on_bookmarks_changed() -> void:
	if _preview_bookmarks != null:
		_preview_bookmarks.on_changed()

# ═══ 播放 / 逐帧 / 跳转（实现见 PreviewPlayback）═══

func _restart() -> void:
	_load_stage()
	_log_line("＊ 重跑")


func _frame_step() -> void:
	if _preview_playback != null:
		_preview_playback.frame_step()


func _unhandled_input(event: InputEvent) -> void:
	if _preview_input != null and _preview_input.handle(event):
		get_viewport().set_input_as_handled()


func _jump_to(target_time: float) -> void:
	if _preview_playback != null:
		_preview_playback.jump_to(target_time)


func _current_time() -> float:
	return _preview_playback.current_time() if _preview_playback != null else 0.0

# ═══ 选项回调 ═══



func _on_stage_selected(idx: int) -> void:
	if idx < 0 or idx >= _stages.size():
		return
	_stage_data = _stages[idx]
	_restart()   # 重跑会按新 `_stage_data` 重建背景、并重载**该面**的书签
	_log_line("＊ 切换关卡：%s" % StageCatalog.display_name_of(_stage_data.stage_id))


## 固定种子：重跑复用同一随机序列（弹幕可复现）
func _on_seed_toggled(on: bool) -> void:
	_playback.set_fixed_seed(on)
	_restart()


## 命中框覆盖层开关（覆盖层不是播放状态，直接设）
func _on_hitbox_toggled(on: bool) -> void:
	if _preview_stage_world != null:
		_preview_stage_world.set_hitbox_enabled(on)


func _on_bg_toggled(on: bool) -> void:
	_playback.set_show_bg(on)
	_restart()


func _on_difficulty_changed(_index: int) -> void:
	_restart()


# ═══ 状态下发 ═══

func _apply_playback_runtime() -> void:
	if _preview_playback != null:
		_preview_playback.apply_runtime()
	_sync_bg_viewport()


## 背景视口只在"真的要看"时渲染：暂停（逐帧推进那一瞬除外）、切走、无背景都停。
## SubViewport 的 render_target_update_mode 与 process_mode 无关 —— 不显式关掉，
## 暂停时 3D 背景仍会每帧跑完整条管线（game_scene 实测省 ≈8.7 ms/帧，见 BGT5）。
func _sync_bg_viewport() -> void:
	if _bg_viewport == null or _playback == null:
		return
	var background = _preview_stage_loader.background() if _preview_stage_loader != null else null
	var has_bg: bool = _playback.show_bg and background != null and is_instance_valid(background)
	var frozen: bool = _playback.paused and not _playback.stepping
	_bg_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED \
		if not has_bg or frozen or preview_suspended() else SubViewport.UPDATE_ALWAYS

## 舞台视觉重画：根 [code]_draw[/code]（框外压暗）+ 画框层（金边 / 网格）。
## 画框必须画在 3D 背景之上，所以它在 [code]FrameOverlay[/code] 里而不是根 [code]_draw[/code]（见 frame_overlay.gd）。
func _redraw_stage() -> void:
	queue_redraw()
	if _frame_overlay == null:
		return
	var background = _preview_stage_loader.background() if _preview_stage_loader != null else null
	var has_bg: bool = _playback.show_bg and background != null and is_instance_valid(background)
	var stage_shift: float = _preview_layout.stage_shift_y() if _preview_layout != null else 0.0
	_frame_overlay.sync(stage_shift, not has_bg)


# ═══ UI 刷新 / 日志 ═══

func _update_ui() -> void:
	var now_time := _current_time()
	_status_bar.set_time(now_time, _playback.ff_active())
	if absf(now_time - _prev_time) >= 0.05:
		_prev_time = now_time
		_timeline.time = now_time
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


## Ctrl+G：强制击破当前 Boss 阶段（实现见 PreviewDebugTools）
func _debug_force_clear() -> void:
	if _preview_debug != null:
		_preview_debug.force_clear()


## 启动检查：扫描全部阶段 .tres 的 uid（实现见 PreviewDebugTools）
func _check_phase_uid_conflicts() -> void:
	if _preview_debug != null:
		_preview_debug.check_phase_uid_conflicts()

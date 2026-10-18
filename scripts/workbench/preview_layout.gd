extends RefCounted
## 整关预览的嵌入坐标归一（D3：从 Workbench 拆出的第二块）。
##
## Workbench 独立运行时页面 y=0；嵌进创作台后页面在页签横栏下方，需要把：
##   - 右面板顶部下移
##   - World / 背景 / 画框归一到游戏坐标
##   - phase 计时器跟着下移
## 但**不能**把舞台整体上移 pos.y（会裁掉场地顶边）——只上移 FIELD_TOP。
##
## 本服务只碰节点坐标，不碰 StageRuntime / 播放状态；重绘由宿主回调。

var _host: Control
var _world: Node2D
var _right_panel: Control
var _bg_container: Control
var _phase_timer: Label
var _is_embedded: Callable
var _redraw: Callable
var _stage_shift_y: float = 0.0
var _ui_page_y: float = 0.0
var _ui_offset_applied: bool = false


func setup(host: Control, world: Node2D, right_panel: Control, bg_container: Control,
		phase_timer: Label, is_embedded: Callable, redraw: Callable) -> void:
	_host = host
	_world = world
	_right_panel = right_panel
	_bg_container = bg_container
	_phase_timer = phase_timer
	_is_embedded = is_embedded
	_redraw = redraw


## 当前舞台视觉偏移（游戏坐标归一量；独立运行 = 0）
func stage_shift_y() -> float:
	return _stage_shift_y


## 平移到页面全局位置（独立运行 = 0，嵌入创作台 = 页签横栏下方）。
func sync() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var pos := _host.get_global_rect().position
	if _ui_offset_applied and is_equal_approx(pos.y, _ui_page_y):
		return
	_ui_offset_applied = true
	_ui_page_y = pos.y
	# 嵌入时只上移 FIELD_TOP，让顶边正好落到页签栏下方；上移 pos.y 会裁掉顶边。
	var stage_shift := pos.y
	if _is_embedded.is_valid() and _is_embedded.call() and pos.y != 0.0:
		stage_shift = GameConfig.FIELD_TOP
	_stage_shift_y = stage_shift
	if pos.y != 0.0:
		# 不能用 CanvasLayer.offset：会对锚定视口的时间轴二次平移。
		# 逐节点下移：右面板顶部 +pos.y；底边 960 是窗口锚定值，不动。
		if _right_panel != null:
			_right_panel.offset_top += pos.y
		if _world != null:
			_world.position.y -= stage_shift
		if _bg_container != null:
			var over := GameConfig.BACKGROUND_OVERSCAN
			_bg_container.position = Vector2(
				GameConfig.FIELD_LEFT - over, GameConfig.FIELD_TOP - over - stage_shift)
			_bg_container.size = Vector2(
				GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT + over * 2.0,
				GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP + over * 2.0)
		if _phase_timer != null:
			_phase_timer.position.y -= stage_shift
	if _redraw.is_valid():
		_redraw.call()

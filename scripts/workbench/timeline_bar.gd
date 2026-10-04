## 时间轴 —— 工作台（关卡沙盒版）
##
## 细条（32px）：刻度 + 播放头 + 书签菱形 + 演出事件标记 + 点击跳转（预览友好）
## 真实关卡不支持任意 seek（协程/状态机/玩家交互），时间轴只做两件事：
##   1. 显示当前游戏内时间（播放头）+ 书签标记
##   2. 点击 = 快进到该时刻；右键 = 加人工书签
##
## 信号：
##   jump_to(t)          —— 点击 → 快进
##   right_clicked(t)    —— 右键 → 添加人工书签
@tool
extends Control
class_name TimelineBar

signal jump_to(time_sec: float)
signal right_clicked(time_sec: float)

var time: float = 0.0                 ## 当前游戏内时间（秒）
var window_start: float = 0.0         ## 时间窗口起点（滚动/缩放后）
var window_len: float = 60.0          ## 时间窗口（秒）
var bookmarks: Array[Dictionary] = [] ## [{t, label}]，升序
## 演出事件标记（bgm=绿 / dialogue=紫 / custom=黄）
var events: Array = []

const BAR_HEIGHT := 32.0

# 平移状态（空白拖动浏览时间窗口）
var _panning := false
var _pan_mouse_start := 0.0
var _pan_start_ws := 0.0
var _pan_moved := false
const PAN_CLICK_TOLERANCE := 4.0  # 超过该像素位移才算拖动（否则视为点击）


func _ready() -> void:
	set_process(true)  # 播放跟随窗口平移
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	offset_top = -BAR_HEIGHT


## 播放跟随：播放头接近窗口边缘时平移窗口
func _process(_delta: float) -> void:
	if time > window_start + window_len * 0.95:
		window_start = maxf(0.0, time - window_len * 0.5)
		queue_redraw()
	elif time < window_start:
		window_start = maxf(0.0, time - window_len * 0.1)
		queue_redraw()


## 设置演出事件
func set_events(evs: Array) -> void:
	events = evs.duplicate()
	queue_redraw()


func set_window(seconds: float) -> void:
	window_len = maxf(seconds, 1.0)
	window_start = 0.0
	queue_redraw()


func add_bookmark(bookmark_time: float, label: String, bm_type: String = "") -> void:
	bookmarks.append({"t": bookmark_time, "label": label, "type": bm_type})
	bookmarks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	queue_redraw()


func clear_bookmarks() -> void:
	bookmarks.clear()
	queue_redraw()


# ═══ 绘制 ═══

func _draw() -> void:
	var width := size.x
	var cy := size.y / 2.0
	# 背景
	draw_rect(Rect2(0, 0, width, size.y), Color(0.07, 0.07, 0.11))
	_draw_ticks(width, 0.0, size.y)
	_draw_events(width, 0.0, size.y)
	_draw_bookmark_diamonds(width, cy)
	# 播放头（唯一移动的东西，贯穿全高）
	var hx := clampf((time - window_start) / maxf(window_len, 0.001), 0.0, 1.0) * width
	draw_line(Vector2(hx, 0), Vector2(hx, size.y), Color(1.0, 0.9, 0.4, 0.95), 2.0)


## 演出事件标记（小方块：bgm 绿 / 对话 紫 / 自定义 黄）
func _draw_events(width: float, y0: float, y1: float) -> void:
	var cy := y0 + (y1 - y0) / 2.0
	for ev in events:
		var event_time := float(ev.get("t", 0.0))
		var pixel_x := (event_time - window_start) / maxf(window_len, 0.001) * width
		if pixel_x < -6.0 or pixel_x > width + 6.0:
			continue
		var col := Color(0.4, 1.0, 0.5, 0.9)
		match str(ev.get("type", "")):
			"dialogue":
				col = Color(0.75, 0.5, 1.0, 0.9)
			"custom":
				col = Color(1.0, 0.8, 0.3, 0.9)
		draw_rect(Rect2(pixel_x - 3, cy - 3, 6, 6), col)


func _draw_ticks(width: float, y0: float, y1: float) -> void:
	var ticks := int(ceil(window_len))
	for i in ticks + 1:
		var pixel_x := i / maxf(window_len, 0.001) * width
		draw_line(Vector2(pixel_x, y0), Vector2(pixel_x, y1), Color(1, 1, 1, 0.04))
		if i % 5 == 0:
			_draw_tick_label(pixel_x, int(window_start) + i)


func _draw_bookmark_diamonds(width: float, cy: float) -> void:
	# 颜色：自动书签统一青色；人工书签（用户右键标记）金色区分
	for bm in bookmarks:
		var pixel_x := (float(bm.t) - window_start) / maxf(window_len, 0.001) * width
		if pixel_x < -6.0 or pixel_x > width + 6.0:
			continue
		var col: Color = Color(0.4, 0.8, 1.0, 0.9)
		if str(bm.get("type", "")) == "manual":
			col = Color(1.0, 0.8, 0.3, 0.9)
		draw_colored_polygon(PackedVector2Array([
			Vector2(pixel_x, cy - 5), Vector2(pixel_x + 5, cy), Vector2(pixel_x, cy + 5), Vector2(pixel_x - 5, cy)
		]), col)


func _draw_tick_label(pixel_x: float, sec: int) -> void:
	var font: Font = _font()
	if font == null:
		return
	draw_string(font, Vector2(pixel_x + 2, 10), str(sec), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))


func _font() -> Font:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		font = get_theme_default_font()
	return font


## 时刻 → 像素 x（当前窗口）
func _time_to_pixel_x(time_sec: float, width: float) -> float:
	return (time_sec - window_start) / maxf(window_len, 0.001) * width


# ═══ 输入 ═══

func _gui_input(event: InputEvent) -> void:
	# 拖拽中（motion）：空白平移
	if event is InputEventMouseMotion:
		if _panning:
			var pm := event as InputEventMouseMotion
			if absf(pm.position.x - _pan_mouse_start) > PAN_CLICK_TOLERANCE:
				_pan_moved = true
			if _pan_moved:
				var pdx: float = pm.position.x - _pan_mouse_start
				var pdt: float = pdx / maxf(size.x, 1.0) * window_len
				# 右拖 → 窗口向过去移（内容跟随鼠标向右）
				window_start = maxf(0.0, _pan_start_ws - pdt)
				queue_redraw()
			accept_event()
			return
	# 松开：空白 pan 结束或点击跳转
	if event is InputEventMouseButton and not event.pressed:
		if _panning:
			var pan_moved := _pan_moved
			var pos: Vector2 = (event as InputEventMouseButton).position
			_stop_pan()
			if not pan_moved:
				jump_to.emit(_x_to_time(pos.x))  # 轻点（无拖动）= 快进跳转
			accept_event()
			return
		return
	if not (event is InputEventMouseButton and event.pressed):
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			# 空白：按住拖动 = 平移时间窗口；轻点 = 快进（松开时判定）
			_start_pan(event.position.x)
			accept_event()
		MOUSE_BUTTON_RIGHT:
			right_clicked.emit(_x_to_time(event.position.x))
			accept_event()
		MOUSE_BUTTON_WHEEL_UP:
			_zoom(event.position.x, 0.8)
			accept_event()
		MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(event.position.x, 1.25)
			accept_event()


## 空白按下：开始平移（记录起点，松手判定点击/拖动）
func _start_pan(mouse_x: float) -> void:
	_panning = true
	_pan_mouse_start = mouse_x
	_pan_start_ws = window_start
	_pan_moved = false


func _stop_pan() -> void:
	_panning = false
	_pan_moved = false


## 滚轮缩放：以鼠标位置为中心缩放时间窗口
func _zoom(mouse_x: float, factor: float) -> void:
	var ratio := clampf(mouse_x / maxf(size.x, 1.0), 0.0, 1.0)
	var anchor_t := window_start + ratio * window_len  # 鼠标处时刻保持不动
	window_len = clampf(window_len * factor, 5.0, 600.0)
	window_start = maxf(0.0, anchor_t - ratio * window_len)
	queue_redraw()


## 像素 x → 时刻（含窗口起点）
func _x_to_time(pixel_x: float) -> float:
	var total := maxf(window_len, 0.001)
	return window_start + clampf(pixel_x / maxf(size.x, 1.0), 0.0, 1.0) * total

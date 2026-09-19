# NavPage — 带选项导航的菜单页面（替代 BaseMenu）
##
## 继承 BasePage，增加:
##   - 选项列表管理（从容器自动收集子节点）
##   - 上下/左右导航 + 锁定项跳过
##   - 选中脉冲高亮 + 确认闪烁特效
##   - 入场动画（元素依次滑入）

@tool
class_name NavPage
extends BasePage

# ═══ 配置 ═══

@export var container_path: NodePath          ## 选项容器

## 导航冷却（秒）
@export var nav_cooldown: float = 0.08
## 确认冷却（秒）
@export var accept_cooldown: float = 0.2
## 是否允许回绕（到头后回到另一端）
@export var allow_wrap: bool = true
## 选中项颜色
@export var highlight_color: Color = Color.WHITE
## 普通项颜色
@export var normal_color: Color = Color(0.4, 0.4, 0.4)
## 锁定项颜色
@export var locked_color: Color = Color(0.15, 0.15, 0.15)
## 入场间隔（秒/元素）
@export var entrance_stagger: float = 0.03
## 入场单元素动画时长
@export var entrance_duration: float = 0.2

# ═══ 内部 ═══

var _nav_items: Array[Control] = []
var _nav_index: int = -1
var _is_nav_enabled: bool = false
var _container: Control
var _pulse_tween: Tween
var _entrance_tween: Tween
var _last_nav_time: float = 0.0
var _last_accept_time: float = 0.0


# ═══ 初始化 ═══

func on_enter() -> void:
	_setup_nav()
	_play_entrance()


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	queue_free()


## R3：场景期依赖自文档（编辑器场景停靠栏）
func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if container_path.is_empty():
		warnings.append("NavPage：container_path 未设置（选项容器）——导航不会工作。")
	elif get_node_or_null(container_path) == null:
		warnings.append("NavPage：container_path 指向的节点不存在：%s" % container_path)
	return warnings


func _setup_nav() -> void:
	if not container_path:
		push_warning("NavPage：container_path 未设置，导航不工作。")
		return
	_container = get_node_or_null(container_path)
	if not _container:
		push_warning("NavPage：container_path 无效：%s" % container_path)
		return

	_nav_items.clear()
	for child in _container.get_children():
		if child is Control:
			_nav_items.append(child)

	if _nav_items.is_empty():
		return

	# 初始状态：全部透明
	for item in _nav_items:
		item.modulate = Color(normal_color.r, normal_color.g, normal_color.b, 0.0)
		if item is Control:
			item.scale = Vector2(0.9, 0.9)

	# 选第一个未锁定项
	_nav_index = _find_first_unlocked()
	_is_nav_enabled = false  # 入场动画结束后再启用


# ═══ 锁定判断 ═══

## 返回 true 则该选项不可选，被跳过
func _is_locked(index: int) -> bool:
	if index < 0 or index >= _nav_items.size():
		return true
	var item := _nav_items[index]
	if item.has_meta("is_locked"):
		var cond = item.get_meta("is_locked")
		if cond is Callable:
			return cond.call()
		return true
	return false


func _find_first_unlocked() -> int:
	for i in _nav_items.size():
		if not _is_locked(i):
			return i
	return -1


# ═══ 颜色刷新 ═══

func refresh_colors() -> void:
	for i in _nav_items.size():
		var item := _nav_items[i]
		if i == _nav_index:
			_set_color(item, highlight_color)
		elif _is_locked(i):
			_set_color(item, locked_color)
		else:
			_set_color(item, normal_color)


func _item_color(index: int) -> Color:
	return locked_color if _is_locked(index) else normal_color


# ═══ 入场动画 ═══

func _play_entrance() -> void:
	if _nav_items.is_empty():
		_is_nav_enabled = true
		return

	_entrance_tween = create_tween().set_parallel(true)
	for i in _nav_items.size():
		var item := _nav_items[i]
		var col: Color
		if i == _nav_index:
			col = highlight_color
		elif _is_locked(i):
			col = locked_color
		else:
			col = normal_color

		var delay: float = i * entrance_stagger
		_entrance_tween.tween_property(item, "modulate", col, entrance_duration * 0.8).set_delay(delay)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if item is Control:
			_entrance_tween.tween_property(item, "scale", Vector2.ONE, entrance_duration).set_delay(delay)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var total: float = (_nav_items.size() - 1) * entrance_stagger + entrance_duration
	_entrance_tween.tween_callback(func():
		_is_nav_enabled = true
		_entrance_tween = null
		if _nav_index >= 0 and _nav_index < _nav_items.size():
			_start_pulse(_nav_items[_nav_index])
	).set_delay(total)


## 跳过入场动画，所有选项立刻到位
func skip_entrance() -> void:
	if not _entrance_tween or not _entrance_tween.is_valid():
		return
	_entrance_tween.kill()
	_entrance_tween = null
	for i in _nav_items.size():
		var item := _nav_items[i]
		if i == _nav_index:
			item.modulate = highlight_color
		elif _is_locked(i):
			item.modulate = locked_color
		else:
			item.modulate = normal_color
		if item is Control:
			item.scale = Vector2.ONE
	_is_nav_enabled = true
	_last_accept_time = Time.get_ticks_msec() / 1000.0  # 防跳过误触
	if _nav_index >= 0 and _nav_index < _nav_items.size():
		_start_pulse(_nav_items[_nav_index])


# ═══ 导航 ═══

func navigate(delta: int) -> void:
	if _nav_items.is_empty() or not _is_nav_enabled:
		return

	sfx_nav()

	var steps: int = 0
	var new_idx: int = _nav_index
	while steps < _nav_items.size():
		new_idx += delta
		if allow_wrap:
			new_idx = wrapi(new_idx, 0, _nav_items.size())
		elif new_idx < 0 or new_idx >= _nav_items.size():
			return
		if not _is_locked(new_idx):
			break
		steps += 1

	if new_idx != _nav_index and not _is_locked(new_idx):
		_select(new_idx)


func _select(index: int) -> void:
	if index < 0 or index >= _nav_items.size():
		return

	# 旧项恢复颜色
	var prev: int = _nav_index
	if prev >= 0 and prev < _nav_items.size():
		_stop_pulse()
		_set_color(_nav_items[prev], _item_color(prev), false)

	# 新项高亮
	_nav_index = index
	_set_color(_nav_items[index], highlight_color, false)
	_start_pulse(_nav_items[index])


# ═══ 确认 ═══

func accept_current() -> void:
	if _nav_index < 0 or _nav_index >= _nav_items.size():
		return
	if _is_locked(_nav_index):
		return

	sfx_confirm()

	var item := _nav_items[_nav_index]
	var idx: int = _nav_index
	_is_nav_enabled = false

	# 闪烁特效
	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_loops(3)
	tween.tween_property(item, "modulate", Color(0.4, 0.4, 0.4), 0.08)
	tween.tween_property(item, "modulate", highlight_color, 0.08)
	await tween.finished

	_is_nav_enabled = true
	_on_item_selected(idx)


# ═══ 高亮脉冲 ═══

func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if not is_instance_valid(item) or item.modulate.a < 0.01:
		return
	var dimmed := Color(
		highlight_color.r * 0.5,
		highlight_color.g * 0.5,
		highlight_color.b * 0.5,
		1.0
	)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(item, "modulate", highlight_color, 0.3)
	_pulse_tween.tween_property(item, "modulate", dimmed, 0.3)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null


# ═══ 颜色设置 ═══

func _set_color(item: Control, color: Color, instant: bool = true) -> void:
	if not is_instance_valid(item):
		return
	if instant:
		item.modulate = color
		return
	var tw := item.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate", color, 0.12)


# ═══ 输入处理（R4：事件驱动，不 _process 轮询）═══

func _unhandled_input(event: InputEvent) -> void:
	if not _is_nav_enabled or _nav_items.is_empty():
		return
	if _nav_accept(event) or _nav_cancel(event):
		return
	_nav_directional(event)


## 子类覆写：方向键 → 导航（默认四方向；难度/音乐页只取左右或上下）
func _nav_directional(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
		_nav_move(-1)
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
		_nav_move(1)


## 确认键（含冷却）；已消费返回 true
func _nav_accept(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_accept"):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_accept_time >= accept_cooldown:
		_last_accept_time = now
		accept_current()
	get_viewport().set_input_as_handled()
	return true


## 取消键（含冷却）；已消费返回 true
func _nav_cancel(event: InputEvent) -> bool:
	if not event.is_action_pressed("ui_cancel"):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_accept_time >= accept_cooldown:
		_last_accept_time = now
		sfx_back()
		_on_cancel()
	get_viewport().set_input_as_handled()
	return true


## 方向导航（带冷却，防连按/回显）
func _nav_move(delta: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_nav_time < nav_cooldown:
		return
	_last_nav_time = now
	navigate(delta)


# ═══ 子类覆写 ═══

func _on_item_selected(_index: int) -> void:
	pass

func _on_cancel() -> void:
	go_back()

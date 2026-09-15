# DifficultyScreen.gd — 难度选择子页面（横排贴图 + 滑动切换 + 黑白未选中）
extends NavPage

const ITEM_SIZE := Vector2(256, 156)
const ITEM_GAP := 375.0
const SLIDE_DURATION := 0.5
const SKEW_ANGLE := deg_to_rad(6.0)

## 未选中项最终亮度倍率（0.0=全黑, 1.0=原亮）
const UNSELECTED_BRIGHTNESS: float = 0.2
## 未选中项最终灰度强度（0.0=彩色, 1.0=完全黑白）
const UNSELECTED_GRAY: float = 1.0
## 过渡时长（秒）
const TRANSITION_DURATION: float = 0.5

## 灰度着色器
var _grayscale_shader: Shader

var _center_x: float
var _center_y: float


func on_enter() -> void:
	_setup_nav()
	allow_wrap = false
	_center_x = get_viewport().get_visible_rect().size.x / 2.0
	_center_y = get_viewport().get_visible_rect().size.y / 2.0
	_nav_index = SaveData.selected_difficulty

	_grayscale_shader = preload("res://gdshader/grayscale.gdshader")

	# 每个选项分配独立材质，方便独立 Tween 灰度参数
	for item in _nav_items:
		var mat := ShaderMaterial.new()
		mat.shader = _grayscale_shader
		mat.set_shader_parameter("grayscale", 0.0)
		item.material = mat

	# 遮罩淡入
	_fade_overlay_in(0.4)

	var tex: TextureRect = $"TitleTexture"
	tex.modulate.a = 0.0
	var tw := tex.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(tex, "modulate:a", 1.0, 0.5)

	# 黑遮罩展开 + 初始倾斜
	var bar := $"CenterBar"
	bar.pivot_offset = bar.size / 2.0
	bar.scale.y = 0.0
	_update_bar_tilt(bar, _nav_index, true)
	var tw_bar := create_tween()
	tw_bar.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw_bar.tween_property(bar, "scale:y", 1.0, 0.5)

	_play_entrance()


func on_leave() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	queue_free()


func _on_item_selected(index: int) -> void:
	_is_nav_enabled = false
	_stop_pulse()
	finished.emit({"difficulty": index})


func _on_cancel() -> void:
	_is_nav_enabled = false
	_stop_pulse()
	finished.emit({})


# ═══ 位置计算 ═══

func _target_x(i: int) -> float:
	var offset := i - _nav_index
	return _center_x + offset * (ITEM_SIZE.x + ITEM_GAP)


func _target_y(i: int) -> float:
	return _center_y + (_target_x(i) - _center_x) * tan(SKEW_ANGLE)


func _target_global(item: Control, x: float, y: float) -> void:
	# 用 global_position 绕过容器坐标系统
	var tw := item.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(item, "global_position:x", x - ITEM_SIZE.x / 2.0, SLIDE_DURATION)
	tw.tween_property(item, "global_position:y", y - ITEM_SIZE.y / 2.0, SLIDE_DURATION)


## 根据选中索引更新黑遮罩倾斜角度
func _update_bar_tilt(bar: Control, index: int, instant: bool = false) -> void:
	# 以 Normal(index=1) 为基准
	var offset := index - 1
	# 左偏（offset<0）→ 正角度（右下），右偏（offset>0）→ 负角度（右上）
	var target_rot := -offset * deg_to_rad(6.0)
	if instant:
		bar.rotation = target_rot
	else:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(bar, "rotation", target_rot, 0.5)


## 刷新外观。选中项过渡完成后自动链式启动脉冲呼吸。
func refresh_all() -> void:
	for i in _nav_items.size():
		var item := _nav_items[i]
		_target_global(item, _target_x(i), _target_y(i))
		if i == _nav_index:
			_appear_to(item, 0.0, 1.0, true)
		else:
			_appear_to(item, UNSELECTED_GRAY, UNSELECTED_BRIGHTNESS)
	# 黑遮罩跟随选中项倾斜
	_update_bar_tilt($"CenterBar", _nav_index)


func refresh_colors() -> void:
	refresh_all()


func _item_color(_index: int) -> Color:
	# 颜色由着色器的 brightness 控制，modulate 只控制透明度
	return Color.WHITE


## 每个 item 当前的过渡 Tween，快速切换时 kill 旧 Tween 防止两个 Tween 同时改亮度/灰度
var _item_tweens: Dictionary = {}


## 渐变为指定灰度强度 + 亮度。直接在着色器里控制亮度，绕过 Godot modulate 的限制。
func _appear_to(item: Control, gray: float, brightness: float, start_pulse_after: bool = false) -> void:
	if not is_instance_valid(item):
		return
	var mat := item.material as ShaderMaterial
	if mat and mat.shader == _grayscale_shader:
		# kill 旧 Tween，防止新旧两个 Tween 同时改 brightness/grayscale 打架
		var old_tw: Tween = _item_tweens.get(item)
		if old_tw and old_tw.is_valid():
			old_tw.kill()
		_item_tweens.erase(item)

		# 从当前实际值开始过渡
		var start_gray: float = mat.get_shader_parameter("grayscale")
		var start_bright: float = mat.get_shader_parameter("brightness")
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.set_parallel(true)
		tw.tween_method(func(v): mat.set_shader_parameter("grayscale", v), start_gray, gray, TRANSITION_DURATION)
		tw.tween_method(func(v): mat.set_shader_parameter("brightness", v), start_bright, brightness, TRANSITION_DURATION)
		_item_tweens[item] = tw
		tw.finished.connect(func():
			_item_tweens.erase(item)
		, CONNECT_ONE_SHOT)
		if start_pulse_after:
			tw.finished.connect(func():
				_start_pulse(item)
			, CONNECT_ONE_SHOT)
	# modulate 只控制 alpha（透明度）
	var col := item.modulate
	col.r = 1.0; col.g = 1.0; col.b = 1.0
	modulate_to(item, col)


# ═══ 脉冲 ═══

func _start_pulse(item: Control) -> void:
	_stop_pulse()
	if not is_instance_valid(item):
		return
	var mat := item.material as ShaderMaterial
	if not mat or mat.shader != _grayscale_shader:
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(func(v): mat.set_shader_parameter("brightness", v), 1.0, 0.6, 0.3)
	_pulse_tween.tween_method(func(v): mat.set_shader_parameter("brightness", v), 0.6, 1.0, 0.3)


func _set_color(item: Control, color: Color, instant: bool = true) -> void:
	modulate_to(item, color, instant)


func modulate_to(item: Control, color: Color, instant: bool = false) -> void:
	if not is_instance_valid(item):
		return
	if instant:
		item.modulate = color
		return
	var tw := item.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(item, "modulate", color, TRANSITION_DURATION)


# ═══ 入场 ═══

func _play_entrance() -> void:
	if _nav_items.is_empty():
		_is_nav_enabled = true
		return

	for i in _nav_items.size():
		var item := _nav_items[i]
		item.size = ITEM_SIZE
		item.global_position = Vector2(
			_target_x(_nav_index) - ITEM_SIZE.x / 2.0,
			_target_y(_nav_index) - ITEM_SIZE.y / 2.0
		)

	# 设置初始位置 + 灰度/亮度（instant，入场动画只淡入 alpha）
	for i in _nav_items.size():
		var item := _nav_items[i]
		_target_global(item, _target_x(i), _target_y(i))
		var mat := item.material as ShaderMaterial
		if i == _nav_index:
			if mat:
				mat.set_shader_parameter("grayscale", 0.0)
				mat.set_shader_parameter("brightness", 1.0)
			item.modulate = Color(1.0, 1.0, 1.0, 0.0)
		else:
			if mat:
				mat.set_shader_parameter("grayscale", UNSELECTED_GRAY)
				mat.set_shader_parameter("brightness", UNSELECTED_BRIGHTNESS)
			item.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var tw := create_tween().set_parallel(true)
	for i in _nav_items.size():
		var item := _nav_items[i]
		var delay: float = abs(i - _nav_index) * entrance_stagger
		tw.tween_property(item, "modulate:a", 1.0, entrance_duration).set_delay(delay)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 入场：选中项已经 instant 设好了 brightness=1.0 / grayscale=0.0，直接起脉冲
	_is_nav_enabled = true
	if _nav_index >= 0 and _nav_index < _nav_items.size():
		_start_pulse(_nav_items[_nav_index])


# ═══ 导航 ═══

func navigate(delta: int) -> void:
	var old_idx := _nav_index
	super.navigate(delta)
	if _nav_index != old_idx:
		_stop_pulse()
		refresh_all()


func _nav_directional(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_nav_move(-1)
	elif event.is_action_pressed("ui_right"):
		_nav_move(1)


# ═══ 确认 ═══

func accept_current() -> void:
	if _nav_index < 0 or _nav_index >= _nav_items.size():
		return

	sfx_confirm()
	var item := _nav_items[_nav_index]
	var idx := _nav_index
	_is_nav_enabled = false

	var mat := item.material as ShaderMaterial
	if mat and mat.shader == _grayscale_shader:
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.set_loops(3)
		tw.tween_method(func(v): mat.set_shader_parameter("brightness", v), 0.5, 1.0, 0.06)
		tw.tween_method(func(v): mat.set_shader_parameter("brightness", v), 1.0, 0.5, 0.06)
		await tw.finished
	else:
		await get_tree().create_timer(0.3).timeout

	_is_nav_enabled = true
	_on_item_selected(idx)

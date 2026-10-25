extends Node2D
## 只读路径展示层：把 LifecyclePreview 算出的折线画出来，不挂任何判定。
##
## 两层 Line2D（外发光 + 亮核）；只做视觉，不生成弹、不参与碰撞。
## [code]points[/code] 使用本节点的局部坐标；通常把本节点挂在 World 原点下。

## 亮核线宽（像素）。
const CORE_WIDTH := 3.0
## 外发光线宽倍率。
const GLOW_WIDTH_MULT := 3.0

var _core: Line2D
var _glow: Line2D
var _is_showing: bool = false
var _remaining: float = 0.0
var _has_lifetime: bool = false


func _ready() -> void:
	z_index = LayerConfig.EFFECT
	z_as_relative = false
	_ensure_lines()
	set_process(false)
	visible = false


## 显示一条路径；少于 2 个点视为清空。
## [code]lifetime > 0[/code] 时到点自动清空；0 = 保持到下一次 show/clear。
func show_path(points: PackedVector2Array, color: Color = Color(1.0, 0.82, 0.35, 0.85),
		width: float = CORE_WIDTH, lifetime: float = 0.0) -> void:
	_ensure_lines()
	if points.size() < 2:
		clear_path()
		return

	_glow.points = points
	_glow.width = width * GLOW_WIDTH_MULT
	_glow.default_color = Color(color.r, color.g, color.b, color.a * 0.28)
	_glow.visible = true

	_core.points = points
	_core.width = width
	_core.default_color = color
	_core.visible = true

	_is_showing = true
	visible = true
	_has_lifetime = lifetime > 0.0
	_remaining = lifetime
	set_process(_has_lifetime)


## 立即清空路径并隐藏。
func clear_path() -> void:
	_ensure_lines()
	_core.clear_points()
	_glow.clear_points()
	_core.visible = false
	_glow.visible = false
	_is_showing = false
	_has_lifetime = false
	_remaining = 0.0
	set_process(false)
	visible = false


## 当前是否有一条可见路径。
func is_showing() -> bool:
	return _is_showing


## 当前路径点数（测试 / 调试用）。
func point_count() -> int:
	return _core.points.size() if _core != null else 0


func _process(delta: float) -> void:
	if not _has_lifetime:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		clear_path()


func _ensure_lines() -> void:
	if _core != null:
		return
	_glow = _make_line(0.0)
	_core = _make_line(1.0)


func _make_line(depth: float) -> Line2D:
	var line := Line2D.new()
	line.z_index = int(depth)   # 外发光在下、亮核在上
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.antialiased = true
	line.visible = false
	add_child(line)
	return line

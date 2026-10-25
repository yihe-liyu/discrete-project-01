extends Node2D
## 只读路径展示层：把 LifecyclePreview 算出的折线画出来，不挂任何判定。
##
## 用 MultiMeshInstance2D 合批：每个线段 = 一个 quad，亮核/外发光由同一个 shader 画；
## 整批路径一次提交；只做视觉，不生成弹、不参与碰撞。
## [code]points[/code] 使用本节点的局部坐标；通常把本节点挂在 World 原点下。

## 亮核线宽（像素）。
const CORE_WIDTH := 1.5
## 外发光线宽倍率。
const GLOW_WIDTH_MULT := 2.5
## 外发光 shader。
const GLOW_SHADER := preload("res://gdshader/telegraph_glow.gdshader")

var _batch: MultiMeshInstance2D
var _multimesh: MultiMesh
var _material: ShaderMaterial
var _paths: Array[PackedVector2Array] = []
var _is_showing: bool = false
var _remaining: float = 0.0
var _has_lifetime: bool = false
## 逐帧跟踪回调（TelegraphService 绑定真实弹时设置；空 = 不跟踪）。
var tracker: Callable = Callable()


func _ready() -> void:
	# 路径是辅助信息，压在敌弹之下，避免盖住真正要躲的东西。
	z_index = LayerConfig.ENEMY_BULLET - 1
	z_as_relative = false
	_ensure_batch()
	set_process(false)
	visible = false


## 显示一条路径；少于 2 个点视为清空。
## [code]lifetime > 0[/code] 时到点自动清空；0 = 保持到下一次 show/clear。
func show_path(points: PackedVector2Array, color: Color = Color(1.0, 0.82, 0.35, 0.85),
		width: float = CORE_WIDTH, lifetime: float = 0.0) -> void:
	show_paths([points], color, width, lifetime)


## 同时显示多条路径（每颗弹一条）；点不足 2 的路径跳过。
func show_paths(paths: Array, color: Color = Color(1.0, 0.82, 0.35, 0.85),
		width: float = CORE_WIDTH, lifetime: float = 0.0) -> void:
	_ensure_batch()
	_paths.clear()
	for path in paths:
		if path.size() >= 2:
			_paths.append(path)
	if _paths.is_empty():
		clear_path()
		return
	_rebuild_batch(color, width)
	_is_showing = true
	visible = true
	_has_lifetime = lifetime > 0.0
	_remaining = lifetime
	set_process(_has_lifetime or tracker.is_valid())


## 立即清空路径并隐藏。
func clear_path() -> void:
	_ensure_batch()
	_paths.clear()
	_multimesh.instance_count = 0
	_batch.visible = false
	_is_showing = false
	_has_lifetime = false
	_remaining = 0.0
	set_process(tracker.is_valid())
	visible = false


## 当前是否有一条可见路径。
func is_showing() -> bool:
	return _is_showing


## 当前路径点数（测试 / 调试用）。
func point_count() -> int:
	return _paths[0].size() if not _paths.is_empty() else 0


## 当前路径条数。
func path_count() -> int:
	return _paths.size()


## 设置逐帧跟踪回调；空 Callable = 停止跟踪。
func set_tracker(value: Callable) -> void:
	tracker = value
	set_process(tracker.is_valid() or _has_lifetime)


func _process(delta: float) -> void:
	if tracker.is_valid():
		tracker.call(delta)
	if not _has_lifetime:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		clear_path()


func _ensure_batch() -> void:
	if _batch != null:
		return
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_2D
	_multimesh.use_colors = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_multimesh.mesh = quad
	_multimesh.instance_count = 0
	_batch = MultiMeshInstance2D.new()
	_batch.multimesh = _multimesh
	_batch.texture = _make_white_texture()
	_material = ShaderMaterial.new()
	_material.shader = GLOW_SHADER
	_batch.material = _material
	_batch.visible = false
	add_child(_batch)


func _rebuild_batch(color: Color, width: float) -> void:
	var transforms: Array[Transform2D] = []
	for path in _paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var segment := b - a
			var length := segment.length()
			if length < 0.001:
				continue
			var direction := segment / length
			var perpendicular := Vector2(-direction.y, direction.x)
			# 一个 quad 覆盖外发光宽度；亮核由 shader 的中心遮罩画。
			transforms.append(Transform2D(
				direction * length,
				perpendicular * width * GLOW_WIDTH_MULT,
				(a + b) * 0.5))
	_multimesh.instance_count = transforms.size()
	for i in transforms.size():
		_multimesh.set_instance_transform_2d(i, transforms[i])
	_material.set_shader_parameter("line_color", color)
	_material.set_shader_parameter("core_ratio", 1.0 / GLOW_WIDTH_MULT)
	_batch.visible = true


func _make_white_texture() -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

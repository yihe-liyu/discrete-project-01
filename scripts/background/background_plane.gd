class_name BackgroundPlane
extends MeshInstance3D

## 平面大小（地面用 256×256，远景可用更小）
@export var plane_size: Vector2 = Vector2(256, 256)

## UV 重复次数
@export var tiling: Vector2 = Vector2(6, 6)

## 滚动速度（像素/秒，最终乘 delta）
@export var scroll_speed: Vector2 = Vector2(0, 1.0)

## 颜色叠加（白色 = 原图，变暗/变色用）
@export var modulate: Color = Color.WHITE

## 贴图（在 Inspector 拖入）
@export var base_texture: Texture2D

var _scroll_mult: float = 1.0
var _speed_tween: Tween


func _ready() -> void:
	if not mesh:
		var plane_mesh := PlaneMesh.new()
		plane_mesh.size = plane_size
		plane_mesh.orientation = PlaneMesh.FACE_Y

		var mat := ShaderMaterial.new()
		mat.shader = preload("res://gdshader/background_plane.gdshader")
		mat.set_shader_parameter("tiling", tiling)
		mat.set_shader_parameter("modulate", modulate)
		if base_texture:
			mat.set_shader_parameter("base_texture", base_texture)
		mat.set_shader_parameter("uv_offset", Vector2.ZERO)

		plane_mesh.material = mat
		self.mesh = plane_mesh
	else:
		# tscn 预制网格 → 只同步尺寸，不重写材质（材质已在 tscn 里配好）
		var pm := mesh as PlaneMesh
		if pm and pm.size != plane_size:
			pm.size = plane_size
		var mat := _get_material()
		if mat:
			mat.set_shader_parameter("uv_offset", Vector2.ZERO)


func _get_material() -> ShaderMaterial:
	var plane_mesh := mesh as PlaneMesh
	if plane_mesh and plane_mesh.material is ShaderMaterial:
		return plane_mesh.material
	if material_override is ShaderMaterial:
		return material_override
	return null


func _process(delta: float) -> void:
	var mat := _get_material()
	if not mat:
		return
	var uv: Vector2 = mat.get_shader_parameter("uv_offset")
	uv += scroll_speed * delta * _scroll_mult
	mat.set_shader_parameter("uv_offset", uv)


func set_scroll_mult(m: float) -> void:
	_scroll_mult = m


## **有效滚动速度** = 作者在 .tscn 填的 `scroll_speed` × 当前倍率。
## ⚠️ 跟随本平面的装饰物**必须**读它。读裸 `scroll_speed` 会在倍率变化时**与地面分家** ——
## 2026-10-04 作者实测「树和地面的速度不一样了」就是这么来的（`speed_ramp` 改的是倍率，
## 而 `DecorManager` 直接读 `scroll_speed`）。
func effective_scroll_speed() -> Vector2:
	return scroll_speed * _scroll_mult


## 本平面每秒的**世界位移**（跟随它的装饰物用的**唯一换算点**）。
## `plane_size / tiling` 这条换算只写在这里**一次** —— 旧实现把它抄在 `DecorManager` 的两处内联里，
## 而"读 `scroll_speed` 还是读倍率后"正是那两处与地面分家的根因。
func world_scroll_per_second() -> Vector3:
	var rx: float = plane_size.x / maxf(tiling.x, 1.0)
	var ry: float = plane_size.y / maxf(tiling.y, 1.0)
	var v := effective_scroll_speed()
	return Vector3(v.x * rx, 0.0, -v.y * ry)


## 滚动速度的**意图动词**：`dur` 秒内把速度倍率从 `from` 平滑推到 `to`（缓入 + QUAD）。
## 内容**不再自己 `create_tween()` 改 `scroll_speed`** —— 那是"怎么做"，而且调用方得懂
## 「地面速度 = scroll_speed ×（plane_size / tiling）」这条换算才敢写常数。
## 倍率只乘在 `_process` 的 uv 增量上 ⇒ 作者在 .tscn 里填的 `scroll_speed` 保持为**基准值**。
func speed_ramp(from: float, to: float, dur: float) -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()          # 同一实例被重复调用（重跑）时别让两个 tween 抢同一个倍率
	_speed_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_speed_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_speed_tween.tween_method(set_scroll_mult, from, to, dur)

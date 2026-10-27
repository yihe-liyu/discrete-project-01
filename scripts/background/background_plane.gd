## 背景滚动平面：用 ShaderMaterial 的 uv_offset 滚动地面 / 远景。
## 跟随它的装饰物应读 effective_scroll_speed()，不要直接读 scroll_speed。
class_name BackgroundPlane
extends MeshInstance3D

## 平面大小（地面用 256×256，远景可用更小）
@export var plane_size: Vector2 = Vector2(256, 256)

## UV 重复次数
@export var tiling: Vector2 = Vector2(6, 6)

## 滚动速度（像素/秒，最终乘 delta）
@export var scroll_speed: Vector2 = Vector2(0, 1.0)

## 颜色叠加（白色 = 原图，变暗/变色用）。
## 这是权威值：每个 BackgroundPlane 实例会复制材质，节点上的 Modulate 不会被别的层覆盖。
## 改材质里的 shader_parameter/modulate 会被本值覆盖。
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
		if pm:
			# Layers 2/3/4 在 tscn 里引用同一个 PlaneMesh；resource_local_to_scene
			# 只保证“每场景一份”，不保证“每节点一份”。不复制网格 + 材质，
			# 最后一层的 modulate 会覆盖所有层。
			pm = pm.duplicate()
			self.mesh = pm
			if pm.size != plane_size:
				pm.size = plane_size
			var mat := _get_material()
			if mat:
				mat = mat.duplicate()
				pm.material = mat
				mat.set_shader_parameter("uv_offset", Vector2.ZERO)
		else:
			var mat_override := material_override as ShaderMaterial
			if mat_override:
				mat_override = mat_override.duplicate()
				material_override = mat_override
				mat_override.set_shader_parameter("uv_offset", Vector2.ZERO)
	_apply_modulate(modulate)


func _get_material() -> ShaderMaterial:
	var plane_mesh := mesh as PlaneMesh
	if plane_mesh and plane_mesh.material is ShaderMaterial:
		return plane_mesh.material
	if material_override is ShaderMaterial:
		return material_override
	return null


## 立即写颜色（同时写属性 + ShaderMaterial 参数；Ground 变黑/恢复用）。
func set_modulate(color: Color) -> void:
	modulate = color
	_apply_modulate(color)


## 从当前颜色平滑过渡到 target；返回 Tween，便于外部取消。
func tween_modulate(target: Color, duration: float,
		ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> Tween:
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_method(_apply_modulate, modulate, target, duration)
	tw.set_ease(ease_type).set_trans(trans_type)
	return tw


func _apply_modulate(color: Color) -> void:
	modulate = color
	var mat := _get_material()
	if mat:
		mat.set_shader_parameter("modulate", color)


func _process(delta: float) -> void:
	var mat := _get_material()
	if not mat:
		return
	var uv: Vector2 = mat.get_shader_parameter("uv_offset")
	uv += scroll_speed * delta * _scroll_mult
	mat.set_shader_parameter("uv_offset", uv)


## 设滚动倍率（speed_ramp 的 tween 用；不直接改 scroll_speed）。
func set_scroll_mult(m: float) -> void:
	_scroll_mult = m


## 有效滚动速度 = 作者在 .tscn 填的 [code]scroll_speed[/code] × 当前倍率。
## 跟随本平面的装饰物必须读它。读裸 [code]scroll_speed[/code] 会在倍率变化时与地面分家 ——
## 2026-10-04 作者实测「树和地面的速度不一样了」就是这么来的（[code]speed_ramp[/code] 改的是倍率，
## 而 [code]DecorManager[/code] 直接读 [code]scroll_speed[/code]）。
func effective_scroll_speed() -> Vector2:
	return scroll_speed * _scroll_mult


## 本平面每秒的世界位移（跟随它的装饰物用的唯一换算点）。
## [code]plane_size / tiling[/code] 这条换算只写在这里一次 —— 旧实现把它抄在 [code]DecorManager[/code] 的两处内联里，
## 而"读 [code]scroll_speed[/code] 还是读倍率后"正是那两处与地面分家的根因。
func world_scroll_per_second() -> Vector3:
	var rx: float = plane_size.x / maxf(tiling.x, 1.0)
	var ry: float = plane_size.y / maxf(tiling.y, 1.0)
	var v := effective_scroll_speed()
	return Vector3(v.x * rx, 0.0, -v.y * ry)


## 滚动速度的意图动词：[code]dur[/code] 秒内把速度倍率从 [code]from[/code] 平滑推到 [code]to[/code]（缓入 + QUAD）。
## 内容不再自己 [code]create_tween()[/code] 改 [code]scroll_speed[/code] —— 那是"怎么做"，而且调用方得懂
## 「地面速度 = scroll_speed ×（plane_size / tiling）」这条换算才敢写常数。
## 倍率只乘在 [code]_process[/code] 的 uv 增量上 ⇒ 作者在 .tscn 里填的 [code]scroll_speed[/code] 保持为基准值。
func speed_ramp(from: float, to: float, dur: float) -> void:
	if _speed_tween and _speed_tween.is_valid():
		_speed_tween.kill()          # 同一实例被重复调用（重跑）时别让两个 tween 抢同一个倍率
	_speed_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_speed_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_speed_tween.tween_method(set_scroll_mult, from, to, dur)

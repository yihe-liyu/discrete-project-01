class_name ScreenFogFX
extends Node

## 全屏蒙眼雾组件：CanvasLayer + ColorRect + screen_fog shader（canvas_item）
## 太阳屏幕位置每帧 unproject（相机动雾跟动）
## 由演出脚本调用 setup(sun) 创建（practice 模式不调 → 无雾层，与旧行为一致）
## setup() 幂等：重复调用不重复创建（重跑安全）
## 全部参数 @export → 场景里选中本节点即可在 Inspector 调（每关可配不同雾）
## 噪声纹理：预生成资源（cloud_noise.tres），setup 即用 → 零生成等待/零卡顿/无过渡期
## 改纹理参数（texture_size/contrast）后重跑 tools/regenerate_fog_tex.gd

const CLOUD_NOISE_PATH := "res://assets/Textures/background/stage01/cloud_noise.tres"

# ── 雾纹理（预生成资源；参数供 regenerate 工具用，运行时读资源）──
@export var texture_size: int = 512          ## 云斑纹理分辨率（预生成用）
@export var texture_contrast: float = 1.8    ## 云斑对比度（预生成用）

# ── 整体蒙眼 ──
@export var fog_dark: float = 0.65           ## 整体蒙眼浓度
@export var fog_color: Color = Color(0.02, 0.02, 0.03)  ## 雾色（暗蓝灰）
@export var flow_speed: float = 0.03         ## 流动速度
@export var noise_scale: float = 1.0         ## 云斑大小

# ── 太阳处 ──
@export var sun_fog_radius: float = 0.1      ## 太阳处雾团范围
@export var sun_fog_extra: float = 1.0       ## 太阳处额外浓度

# ── 精细化效果 ──
@export var detail_scale: float = 3.0        ## 第二层噪声频率倍率
@export var detail_strength: float = 0.35    ## 第二层混合权重（0=关）
@export var vignette_strength: float = 0.15  ## 边缘渐晕（0=关）
@export var breath_amplitude: float = 0.03   ## 呼吸感幅度（0=关）
@export var ring_strength: float = 0.0       ## 太阳漏光亮环（0=关）
@export var ring_radius: float = 0.16        ## 亮环半径
@export var ring_width: float = 0.03         ## 亮环宽度

var _rect: ColorRect
var _mat: ShaderMaterial
var sun: Node3D
var _stage_background: StageBackground


func setup(p_sun: Node3D = null) -> void:
	if _rect:
		return
	sun = p_sun
	var layer := CanvasLayer.new()
	layer.name = "FogLayer"
	layer.layer = 5  # 背景 SubViewport 内叠在 3D 之上
	add_child(layer)
	var rect := ColorRect.new()
	rect.name = "FogRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://gdshader/screen_fog.gdshader")
	# 预生成纹理：毫秒级就绪，雾层一次性完整出现（无均匀雾过渡/无卡顿）
	var img: Image = load(CLOUD_NOISE_PATH)
	if img == null:
		push_error("ScreenFogFX: 预生成纹理缺失，请运行 tools/regenerate_fog_tex.gd；本次用同步生成兜底")
		img = _make_cloud_image(texture_size, texture_contrast)
	mat.set_shader_parameter("noise_tex", ImageTexture.create_from_image(img))
	rect.material = mat
	layer.add_child(rect)
	_rect = rect
	_mat = mat
	_apply_params()
	_update_sun_pos()  # 立即同步太阳位置（不等 _process 首帧，消除覆盖延迟）


func _process(_delta: float) -> void:
	_update_sun_pos()


func _update_sun_pos() -> void:
	if not _mat:
		return
	var background := _get_bg()
	if not background or not background.camera:
		return
	if sun and is_instance_valid(sun):
		var sp: Vector2 = background.camera.unproject_position(sun.global_position)
		var vp: Vector2 = background.get_viewport().get_visible_rect().size
		if vp.x > 0 and vp.y > 0:
			_mat.set_shader_parameter("sun_pos", sp / vp)


## 把 @export 参数写入 shader（setup 时调用一次；改参数后重跑/重挂即生效）
func _apply_params() -> void:
	if not _mat:
		return
	_mat.set_shader_parameter("fog_dark", fog_dark)
	_mat.set_shader_parameter("fog_color", fog_color)
	_mat.set_shader_parameter("flow_speed", flow_speed)
	_mat.set_shader_parameter("noise_scale", noise_scale)
	_mat.set_shader_parameter("sun_fog_radius", sun_fog_radius)
	_mat.set_shader_parameter("sun_fog_extra", sun_fog_extra)
	_mat.set_shader_parameter("detail_scale", detail_scale)
	_mat.set_shader_parameter("detail_strength", detail_strength)
	_mat.set_shader_parameter("vignette_strength", vignette_strength)
	_mat.set_shader_parameter("breath_amplitude", breath_amplitude)
	_mat.set_shader_parameter("ring_strength", ring_strength)
	_mat.set_shader_parameter("ring_radius", ring_radius)
	_mat.set_shader_parameter("ring_width", ring_width)


func _get_bg() -> StageBackground:
	if _stage_background and is_instance_valid(_stage_background):
		return _stage_background
	_stage_background = get_parent() as StageBackground
	return _stage_background


## 云斑纹理（主线程入口，测试用）：生成 + 上传
func _make_cloud_texture(size: int) -> ImageTexture:
	return ImageTexture.create_from_image(_make_cloud_image(size, texture_contrast))


## 值噪声云斑纹理（fbm 多频叠加，格点按周期取模 → 四方无缝可平铺）：有机雾斑，非正弦波浪
## 供预生成工具 tools/regenerate_fog_tex.gd 使用；格点预计算加速（512² 约 350ms 一次性）
func _make_cloud_image(size: int, contrast: float) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var layers: Array[int] = [6, 12, 24]
	var weights: Array[float] = [0.55, 0.30, 0.15]
	var noise_seed := 20240808
	# 预计算各层格点值（每层 period×period 个，sin hash 只算一次）
	var grids: Array[PackedFloat32Array] = []
	for i in layers.size():
		var period := layers[i]
		var g := PackedFloat32Array()
		g.resize(period * period)
		for gy in period:
			for gx in period:
				g[gy * period + gx] = _noise_hash(gx, gy, noise_seed + i)
		grids.append(g)
	# 逐像素双线性插值（无 sin，纯 lerp）
	for y in range(size):
		for x in range(size):
			var v := 0.0
			for i in layers.size():
				var period := layers[i]
				v += _sample_grid(grids[i], period, float(x) * period / size, float(y) * period / size) * weights[i]
			# 增强对比（云斑更分明）
			v = clampf((v - 0.5) * contrast + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	return img


## 格点双线性插值采样（u/v ∈ [0, period)，邻居格点 period 折回 0 → 四方无缝）
func _sample_grid(g: PackedFloat32Array, period: int, u: float, v: float) -> float:
	var x0 := int(floor(u)) % period
	var y0 := int(floor(v)) % period
	var fx: float = u - floor(u)
	var fy: float = v - floor(v)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var x1 := (x0 + 1) % period
	var y1 := (y0 + 1) % period
	var a := g[y0 * period + x0]
	var b := g[y0 * period + x1]
	var c := g[y1 * period + x0]
	var d2 := g[y1 * period + x1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d2, fx), fy)


func _noise_hash(x: int, y: int, s: int) -> float:
	# sin 小数 hash（经典 GLSL 技巧）：无溢出、确定性、0~1
	var n: float = sin(float(x * 127.1 + y * 311.7 + s * 74.7)) * 43758.5453
	return n - floor(n)

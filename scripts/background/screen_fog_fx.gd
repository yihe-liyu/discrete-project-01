## 全屏蒙眼雾组件。看得见的部分全部场景声明（2026-10-04 BGA/B）：
##   FogFX（本节点，只装逻辑）
##   └── FogLayer（CanvasLayer，layer = 5 —— 背景 SubViewport 内叠在 3D 之上）
##       └── FogRect（ColorRect 全屏）+ ShaderMaterial(screen_fog.gdshader)
##
## 参数就在 Inspector 里调材质的 [code]shader_parameter/*[/code]（唯一来源）。
## 旧实现是 [code]new()[/code] 出来 + [code]@export[/code] × 12 + [code]_apply_params()[/code] 镜像 ⇒ 同一个值有三份默认
## （shader 文件 / [code]@export[/code] / [code].tscn[/code]），而运行时真值只有 [code].tscn[/code] 那份 ⇒
## 改 shader 文件里的数字是静默 no-op。那套镜像与 12 个 [code]@export[/code] 已删。
##
## 太阳屏幕位置每帧 unproject（相机动雾跟动）：相机与太阳由宿主接进来
## （[code]StageBackground._resolve_showcase()[/code] 按类型找本组件后调 [code]bind(camera, sun)[/code]）——
## 内容脚本不需要任何调用；本组件也不 [code]get_parent()[/code] 摸宿主（挪层级/嵌套都不会静默失效）。
##
## 声明即显示。旧写法是内容脚本调 [code]setup(sun, camera)[/code] + [code]_ready[/code] 藏起来等调用
## ⇒ 忘了调就永远隐形、且零报错（stage02 2026-10-04 实况）。那套"记得调用才显示"已废止。
## 噪声纹理也在场景里（材质的 [code]shader_parameter/noise_tex[/code] = [code]cloud_noise.tres[/code]）。
## 本层在背景 SubViewport 内 ⇒ 只压暗背景，不挡弹幕/自机。
class_name ScreenFogFX
extends Node

# ── 仅**预生成工具**用（运行时纹理在场景里；改这两个值要重跑
#    tools/regenerate_fog_tex.gd，**不影响已生成的纹理**）──
## 云斑纹理分辨率
@export var texture_size: int = 512
## 云斑对比度
@export var texture_contrast: float = 1.8

@onready var _layer: CanvasLayer = get_node_or_null("FogLayer") as CanvasLayer
@onready var _rect: ColorRect = get_node_or_null("FogLayer/FogRect") as ColorRect

## 太阳（把它的世界位置投影到屏幕）
var sun: Node3D
## 投影用相机（宿主注入）
var camera: Camera3D
var _mat: ShaderMaterial
var _is_bound := false
## 雾的本地时间：不用 shader 的 TIME（全局时间不会随 process 冻结，切页回来会跳）
var _time: float = 0.0


func _ready() -> void:
	if _rect:
		_mat = _rect.material as ShaderMaterial
		if _mat:
			_mat.set_shader_parameter("time", _time)
	elif _layer:
		push_error("ScreenFogFX: 场景里没声明 FogLayer/FogRect —— 雾不会出现（见本文件头）")


## 由宿主调用：注入投影用相机与太阳（[code]StageBackground._resolve_showcase()[/code]）。
## 幂等，重跑安全（[code]_process[/code] 在 [code]bind[/code] 之前不做事）。
func bind(p_camera: Camera3D, p_sun: Node3D = null) -> void:
	camera = p_camera
	sun = p_sun
	if _rect == null or _mat == null:
		push_error("ScreenFogFX: 场景里没声明 FogLayer/FogRect（或材质不是 ShaderMaterial）—— 雾不会出现")
		return
	_is_bound = true
	if _mat:
		_mat.set_shader_parameter("time", _time)
	_update_sun_pos()  # 立即同步太阳位置（不等 _process 首帧，消除覆盖延迟）


func _process(delta: float) -> void:
	if not _is_bound:
		return
	_time += delta
	if _mat:
		_mat.set_shader_parameter("time", _time)
	_update_sun_pos()


## 把太阳的世界位置投影到屏幕（归一化）。相机由外部注入（[code]bind()[/code]），
## viewport 用 [code]self.get_viewport()[/code] ⇒ 本组件不再需要知道自己的父节点是谁。
##
## 取的是 [code]BackgroundSun.drawn_position()[/code]（真正被画出来的 [code]SunSprite[/code]），
## 不是 [code]sun.global_position[/code]（本节点）—— 两者在 [code]SunSprite[/code] 有局部位移时不同，
## 而作者在编辑器里拖的正是那个 sprite。旧实现用本节点 ⇒ 太阳一改 y 就与黑雾错位
## （2026-10-04 作者实测：「一改太阳的 y 坐标，黑雾的对准就不准了」）。
func _update_sun_pos() -> void:
	if _mat == null:
		return
	if not is_instance_valid(camera) or not is_instance_valid(sun):
		return
	var target: Vector3 = sun.global_position
	if sun is BackgroundSun:
		target = (sun as BackgroundSun).drawn_position()
	var sp: Vector2 = camera.unproject_position(target)
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x > 0 and vp.y > 0:
		_mat.set_shader_parameter("sun_pos", sp / vp)


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

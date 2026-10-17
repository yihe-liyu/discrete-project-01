extends Node3D
class_name StageBackground

## 公开：背景脚本可直接读写
var camera: Camera3D
var world_environment: WorldEnvironment
## 装饰物管理器（**场景声明式**：背景场景里放一个 DecorManager 子节点即可）。
## 首次访问时按**类型**解析并缓存 —— 不按节点名找、也不运行时动态建节点（与 `_find_camera()` 同一套思路）。
## ⚠️ 别用 node 类型 `@export` + `.tscn` 的 `NodePath("...")`：本引擎实测该写法**不解析**（恒为 null，
## `scenes/ui/game_over_menu.tscn` 的 `title_label` 同样中招），所以走类型解析。
var decor_manager: DecorManager
## **环境唯一来源**（在背景场景里声明）：`_ready()` 自动应用，重跑/开演前 `reset()` 再应用一次。
## 有了它，内容脚本**不必**在 `_ready` 里摸背景（旧写法 `get_parent() as StageBackground` = R2 禁的往上摸）；
## 练习模式（不跑内容 `start()`）也照样有环境 —— 旧实现正是靠内容子节点的 `_ready` 才成立的。
@export var env_preset: BackgroundEnvPreset
## **初始相机姿态**（在背景场景里声明）：勾上 `override_camera_home` 后，`_ready` 会把解析到的
## 那台相机摆成下面这套值 —— **在抓"初始姿态"之前**应用 ⇒ `reset_camera()` 天然复位到**这套**。
## 不勾 = 沿用**宿主**相机的姿态（`game_scene.tscn` / `workbench.tscn` 里那台）。
## ⚠️ 勾了之后**改宿主的相机不再影响这一面** —— 构图归本背景所有（这就是"每面自己定构图"）。
## ⚠️ 只在**进树时**应用一次：`move_camera_by` / `set_camera_rotation` / `tween_camera_fov` 照常叠加在它之上。
@export var override_camera_home := false
@export var camera_home_position := Vector3(0, 10, 6)
@export var camera_home_rotation_degrees := Vector3(-30, 0, 0)
@export var camera_home_fov := 90.0
## 相机初始姿态（`_ready` 抓一次）——`reset_camera()` 复位到**它**，而不是写死 `fov = 90`
var _cam_home_pos := Vector3.ZERO
var _cam_home_rot := Vector3.ZERO
var _cam_home_fov := 90.0
## 相机动词的**目标记忆**（**不是**实时值）：相对动词从这里累加，见 `move_camera_by`
var _cam_target_pos := Vector3.ZERO
var _cam_target_rot := Vector3.ZERO
var _cam_target_fov := 90.0
## 每个属性只留一条活动 tween（新指令先杀旧的）——见 `_replace_camera_tween`
var _cam_tween_pos: Tween
var _cam_tween_rot: Tween
var _cam_tween_fov: Tween
var _warned_no_decor := false
var _elapsed: float = 0.0
var _is_active: bool = false


## 目标记忆 ← 相机当前实际值（入树 / 复位时调用：让"相对"从真实起点开始累加）
func _sync_camera_targets() -> void:
	if camera == null:
		return
	_cam_target_pos = camera.transform.origin
	_cam_target_rot = camera.rotation
	_cam_target_fov = camera.fov


## 建一条用**物理帧时钟**的相机 tween（相机演出随暂停冻结），并**先杀掉同属性的旧 tween**。
## ⚠️ 不杀就会两条 tween 同时写同一个属性 ⇒ 谁赢取决于创建顺序（不是"后一条接管"）。
func _replace_camera_tween(prop: NodePath, value: Variant, duration: float,
		ease_type: int, trans_type: int, old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_ease(ease_type).set_trans(trans_type)
	tw.tween_property(camera, prop, value, duration)
	return tw


## 把相机摆成场景声明的初始姿态（仅在 `override_camera_home` 打开时）。
## **必须在 `_capture_camera_home()` 之前调用** —— 这样 `reset_camera()` 复位到的就是这套值。
func _apply_camera_home_override() -> void:
	if not override_camera_home or camera == null:
		return
	camera.transform.origin = camera_home_position
	camera.rotation_degrees = camera_home_rotation_degrees
	camera.fov = camera_home_fov


## 装饰物管理器（懒解析：内容子节点的 `_ready` 早于父节点，但 `start()` 在父 `_ready` 之后，
## 这里仍做成用时就查，任何调用点都安全）。无声明节点 ⇒ null + **响亮一次**
## （否则 `ctx.decor` 为 null，内容每调一次就静默空转/崩，且看不出缺什么）。
func get_decor_manager() -> DecorManager:
	if decor_manager != null:
		return decor_manager
	for child in get_children():
		if child is DecorManager:
			decor_manager = child
			break
	if decor_manager == null and not _warned_no_decor:
		_warned_no_decor = true
		push_warning("StageBackground(%s): 没声明 DecorManager 子节点 —— `ctx.decor` 会是 null" % name)
	return decor_manager

func _ready():
	if camera == null:
		camera = _find_camera()
	world_environment = _find_world_environment()
	# 关键：Environment 是场景 SubResource，多个实例共享同一资源！
	# 重跑/多背景实例会互相污染（雾/环境光状态残留）→ duplicate 成实例私有
	# （否则每次实例化拿到的是上一次 tween 改过的状态 → "越重跑越暗"）
	# 注：2026-10-02 起 `stage01_background.tscn` **不再带内联 Environment**（唯一来源 = 预设 .tres，
	# 见 `apply_env_preset`）⇒ 这里的 duplicate 只对"仍自带内联环境"的背景场景有意义，故有 null 守卫。
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate()
	# 无外部相机（工作台等复用场景）→ 自建随本实例销毁的相机
	# 这样重跑时旧相机随背景销毁、新背景拿初始相机，零残留、无需手动复位
	if camera == null:
		_own_camera()
	if world_environment == null:
		push_warning("StageBackground(%s): 场景里没声明 WorldEnvironment —— 环境/雾动词不会生效" % name)
	_apply_camera_home_override()   # 必须在抓 home **之前**：reset 要回"声明的"那套
	_capture_camera_home()
	if env_preset:
		apply_env_preset(env_preset)
	_resolve_showcase()
	_on_setup()


## 故事演出层（蒙眼雾 / 太阳）：**按类型**解析（不按名字 —— 同 `DecorManager` / `WorldEnvironment`），
## 并把**相机与太阳**接进雾里（雾要靠它们把太阳投影到屏幕）。
##
## ⚠️ 为什么必须由宿主接线：这两个组件"声明即显示"，但雾还需要相机 + 太阳。
## 旧设计让**内容脚本**调 `fog.setup(sun, camera)` —— 忘一次就隐形 / 不跟相机，**且零报错**
## （stage02 2026-10-04 实况：作者把节点都摆好了，却看不见太阳和黑雾）。
## 接线是宿主的活，内容脚本不该有机会忘。
func _resolve_showcase() -> void:
	var fog: ScreenFogFX = null
	var sun: BackgroundSun = null
	for child in get_children():
		if child is ScreenFogFX:
			fog = child
		elif child is BackgroundSun:
			sun = child
	if fog:
		fog.bind(camera, sun)


## 抓相机初始姿态：`reset_camera()` 的复位目标（外部注入的相机也照抓，所以别写死 90）
func _capture_camera_home() -> void:
	if camera == null:
		return
	_cam_home_pos = camera.transform.origin
	_cam_home_rot = camera.rotation
	_cam_home_fov = camera.fov
	_sync_camera_targets()   # 目标起点 = 初始姿态（相对动词从这里累加）



## 自建相机：初始姿态与真游戏 SubViewport 相机一致；随本背景实例销毁
func _own_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 10, 6)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 90.0
	add_child(cam)
	camera = cam

func _process(delta):
	if not _is_active:
		_is_active = true
	_elapsed += delta
	_on_update(delta, _elapsed)

func _exit_tree():
	_on_cleanup()

## 按**类型**在兄弟节点里找相机（BG6）—— **不按名字**：旧实现 `parent.get_node_or_null("Camera3D")`
## 把行为绑在节点名上（一改名就**静默**掉进 `_own_camera()` 兜底、悄悄多出一台相机）。
## 也不用 `get_viewport().get_camera_3d()`：本项目相机没有显式 `current`
## （实测默认 false、置 true 后仍返回 null）⇒ 拿不到，按类型找才稳。
func _find_camera() -> Camera3D:
	var parent := get_parent()
	if parent:
		for child in parent.get_children():
			if child is Camera3D:
				return child
	return null

func _find_world_environment() -> WorldEnvironment:
	for child in get_children():
		if child is WorldEnvironment:
			return child
	return null

## 相机 FOV：立即设置（无 tween）。也要同步目标记忆，否则后续相对动词会从旧目标算。
func set_camera_fov(fov: float) -> void:
	_cam_target_fov = fov
	if camera:
		camera.fov = fov

func set_camera_y(y: float):
	if camera:
		var t = camera.transform
		t.origin.y = y
		camera.transform = t

func set_camera_x(x: float):
	if camera:
		var t = camera.transform
		t.origin.x = x
		camera.transform = t

func set_camera_pos(pos: Vector3):
	if camera:
		var t = camera.transform
		t.origin = pos
		camera.transform = t

func get_camera_offset() -> Vector3:
	if camera:
		return camera.transform.origin
	return Vector3.ZERO

# ═══ 相机动词（**绝对 / 相对**，名字里写清楚）═══
# ⚠️ 历史坑（2026-10-04 作者实测「摄像机的 y 角度最后没回到 0」）：旧名 `rotate_camera` 是
# **绝对**、旧名 `pan_camera` 是**相对** —— 一对动词两种语义、名字看不出来；作者按增量写了 4 条
# （−10/+25/−30/+15，和 = 0）却停在 +15°。现在：
#   `set_camera_position` / `set_camera_rotation` / `tween_camera_fov` = **绝对**
#   `move_camera_by`       / `rotate_camera_by`                        = **相对**（在上一条指令的**目标**上累加）
# ⚠️ 单位：所有 `*rotation*` 一律 **弧度**（与 `Node3D.rotation` 一致）⇒ 写 `deg_to_rad(...)`。
#    （场景里那两个 `Camera Home Rotation Degrees` 是**度** —— 别搞混。）

## 相机位置：**绝对**（tween 到 `target_pos`）
func set_camera_position(target_pos: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	_cam_target_pos = target_pos
	_cam_tween_pos = _replace_camera_tween("position", target_pos, duration, ease_type, trans_type, _cam_tween_pos)


## 相机位置：**相对**（在上一条指令的**目标**上再加 `offset`）
## ⚠️ 从**目标**累加、**不是**从 `camera.transform.origin`（实时值）：否则两条重叠调用会以
## "飞行途中的位置"为基准 ⇒ 漂移（旧 `pan_camera` 的坑）。
func move_camera_by(offset: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	set_camera_position(_cam_target_pos + offset, duration, ease_type, trans_type)


## 相机旋转：**绝对**（弧度）
func set_camera_rotation(target_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	_cam_target_rot = target_rot
	_cam_tween_rot = _replace_camera_tween("rotation", target_rot, duration, ease_type, trans_type, _cam_tween_rot)


## 相机旋转：**相对**（弧度；在上一条指令的**目标**上再加 `delta_rot`）
## 用途：写"转过去再转回来"—— 增量序列和为 0 就自然回正（旧 `rotate_camera` 是绝对，做不到）。
func rotate_camera_by(delta_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	set_camera_rotation(_cam_target_rot + delta_rot, duration, ease_type, trans_type)


## 相机 FOV：**绝对**（tween）
func tween_camera_fov(fov: float, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	_cam_target_fov = fov
	_cam_tween_fov = _replace_camera_tween("fov", fov, duration, ease_type, trans_type, _cam_tween_fov)

func _on_setup():
	# 子 CoroutineScript 由 StageRuntime 统一 start()
	pass

func _on_update(_delta: float, _t: float):
	pass

func _on_cleanup():
	pass

# ═══ 环境服务（预设 + 联动 tween）═══

## WorldEnvironment **懒查找**：子节点的 `_ready` 早于父节点 —— 内容脚本（挂在 `Decor` 子节点上）
## 会在自己的 `_ready` 里 `apply_env_preset()`，那时本节点还没跑过 `_ready`、`world_environment` 还是 null
## ⇒ 以前那次调用**静默返回**（练习模式于是用场景内联环境、改预设它不变）。改成用时就查。
func _env_node() -> WorldEnvironment:
	if world_environment == null:
		world_environment = _find_world_environment()
	return world_environment


## 应用环境预设：替换为全新 Environment（每次全新实例 → 重跑/多背景零共享污染）
## 配套 BackgroundEnvPreset（.tres）：**初始环境一律从预设来**，不手写裸属性
## ⚠️ 本函数可能在父节点 `_ready` 之前被调用（内容脚本在自己 `_ready` 里调用）⇒ 靠 `_env_node()` 兜住。
func apply_env_preset(preset: BackgroundEnvPreset) -> void:
	var we := _env_node()
	if we == null:
		return
	we.environment = preset.build_environment()

## 雾量 → DEPTH 模式的等效字段（**当前不用**，留作已量过的结论）：
## ⚠️ **DEPTH 模式在本项目实测更差**（2026-10-02）：树是 **z −220…−50 的一带纸片**（纵深 170），
## 每棵树被雾化的程度不同 ⇒ 树线出现**台阶**：远端最大行间跳变 **0.0046 → 0.0326**（t=15s）；
## 而"可得距离"只有 0…324（地面平面远缘），**没有足够的远处地面**给 DEPTH 铺开渐淡。
## 另：**DEPTH 下 `fog_density` 几乎失效**（冻结滚动实测 0.02 vs 0.30 行均值差 ≤0.0044）⇒
## 若哪天真要换 DEPTH，必须把雾量落到 `fog_depth_end`（否则演出会哑）。
## 结论：**保持 EXPONENTIAL**，靠"留一层残雾"实现远处渐淡（见 `stage01_decor.gd` 的雾量取值）。


## 联动 tween：雾色 + **雾量** + 天球地面水平色一起变（改雾色不露地平线）
## `amount` = 雾量（0 = 最清 … 1 = 最浓）→ `fog_density`（EXPONENTIAL，本项目现行模式）。
## ⚠️ **别把雾量调到 0 附近**：那样远处就没有渐淡了（"不现实"的来源），
## 演出里的残雾取值见 `data/stages/stage01/background/stage01_decor.gd`。
## 地面底色按雾色暗化 25%（与预设默认 ground_bottom ≈ 雾色×0.75 一致）
func tween_env_fog(color: Color, amount: float, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	var we := _env_node()
	var env := we.environment if we != null else null
	if not env:
		return
	var sm := _sky_material(env)
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	tw.tween_property(env, "fog_light_color", color, duration)
	tw.tween_property(env, "fog_density", amount, duration)
	if sm:
		tw.tween_property(sm, "ground_horizon_color", color, duration)
		tw.tween_property(sm, "ground_bottom_color", color.darkened(0.25), duration)
	tw.set_ease(ease_type).set_trans(trans_type)

## FOV tween（相机）
## 相机复位到 `_ready` 抓的初始姿态（重跑防 tween 残留）。
## ⚠️ 旧实现只把 `fov` 写回 90、不管 position/rotation ⇒ 相机动词跑过之后的重跑**不会回正**（现同时**杀光活动 tween**）。
func reset_camera() -> void:
	if not camera:
		return
	# 先杀光活动 tween：否则复位后旧 tween 还在写同一属性 ⇒ "复位了但又被拉走"
	for tw in [_cam_tween_pos, _cam_tween_rot, _cam_tween_fov]:
		if tw and tw.is_valid():
			tw.kill()
	camera.transform.origin = _cam_home_pos
	camera.rotation = _cam_home_rot
	camera.fov = _cam_home_fov
	_sync_camera_targets()   # 目标也回初始姿态


## 开演 / 重跑前的**完整复位**：环境从**场景声明的** `env_preset` 重建 + 相机回初始姿态。
## 内容脚本只写这一句，不必再各自 `apply_env_preset(...)` + `reset_camera()` 两连，
## 更不必为了拿本节点而在 `_ready` 里 `get_parent()`（R2 禁往上摸）。
func reset() -> void:
	if env_preset:
		apply_env_preset(env_preset)
	reset_camera()

## 取天球材质（`ProceduralSkyMaterial`）：`tween_env_fog()` 靠它把地平线色跟着雾色走。
## ⚠️ **天球配在内容预设里**（`data/stages/stage01/background/stage01_env.tres`：`background_mode = BG_SKY`
## + `Sky` + `ProceduralSkyMaterial` + `fog_sky_affect = 0`；参数取自作者原版 `486766c` /
## `d2a7d7d:new_environment.tres`）。2026-10-02 BG2/BG3 之前预设**没有** sky ⇒ 本函数恒返回 null，
## 那条"改雾色不露地平线"的联动是**静默 no-op**；`test/test_stage_background.gd` 现在钉住它。
func _sky_material(env: Environment) -> ProceduralSkyMaterial:
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		return env.sky.sky_material
	return null

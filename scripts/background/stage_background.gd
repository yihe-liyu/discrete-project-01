## 背景宿主：相机 / 环境 / 雾 / 装饰物的统一入口（背景场景根节点）。
## 由背景 .tscn 声明；内容通过 ctx.background 拿它，不再 get_parent() 摸树。
##
## [b]模型[/b][br]
## _ready 时按类型解析相机（兄弟节点）/ WorldEnvironment / DecorManager / ScreenFogFX / BackgroundSun，
## 应用 env_preset，并抓相机初始姿态。动作用绝对 / 相对相机 tween + 环境 tween。
## [codeblock]
## ctx.background.tween_camera_position(...)
## ctx.background.move_camera_by(...)
## ctx.background.tween_env_fog(...)
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 相机按类型解析，不按节点名；无外部相机时自建一台随背景销毁的相机。[br]
## - rotation 类参数一律弧度；camera_home_rotation_degrees 是度。[br]
## - 相对动词语义是从“上一条指令的目标”累加，不是实时值。[br]
## - reset() 重建环境预设 + 相机回初始姿态；重跑 / 开演前调。
class_name StageBackground
extends Node3D

## 背景相机（_ready 按类型解析；无外部相机时自建）。
var camera: Camera3D
## 背景 WorldEnvironment（_ready 解析）。
var world_environment: WorldEnvironment
## 装饰物管理器（按类型解析并缓存；无声明节点 = null）。
var decor_manager: DecorManager
## 环境唯一来源（背景场景里声明）：_ready 自动应用，reset() 再应用一次。
@export var env_preset: BackgroundEnvPreset
## 是否使用本背景声明的相机初始姿态；不勾 = 沿用 BackgroundCameraHome 默认。
## 勾了之后构图归本背景所有，改默认姿态不再影响这一面。
@export var override_camera_home := false
## 相机初始位置（仅 override_camera_home 时生效）。
@export var camera_home_position: Vector3 = BackgroundCameraHome.POSITION
## 相机初始旋转（度；仅 override_camera_home 时生效）。
@export var camera_home_rotation_degrees: Vector3 = BackgroundCameraHome.ROTATION_DEGREES
## 相机初始 FOV（仅 override_camera_home 时生效）。
@export var camera_home_fov: float = BackgroundCameraHome.FOV
## 相机初始姿态（_ready 抓一次；reset_camera 复位到它）。
var _cam_home_pos := Vector3.ZERO
var _cam_home_rot := Vector3.ZERO
var _cam_home_fov: float = BackgroundCameraHome.FOV
## 相机动词的目标记忆（不是实时值）；相对动词从这里累加。
var _cam_target_pos := Vector3.ZERO
var _cam_target_rot := Vector3.ZERO
var _cam_target_fov: float = BackgroundCameraHome.FOV
## 每个属性只留一条活动 tween（新指令先杀旧的）。
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


## 建一条用物理帧时钟的相机 tween（随暂停冻结），并先杀掉同属性的旧 tween。
## 不杀会让两条 tween 同时写同一属性，谁赢取决于创建顺序。
func _replace_camera_tween(prop: NodePath, value: Variant, duration: float,
		ease_type: int, trans_type: int, old: Tween) -> Tween:
	if old and old.is_valid():
		old.kill()
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.set_ease(ease_type).set_trans(trans_type)
	tw.tween_property(camera, prop, value, duration)
	return tw


## 把相机摆成场景声明的初始姿态（仅 override_camera_home 打开时）。
## 必须在 _capture_camera_home() 之前调用，reset_camera 才会复位到这套值。
func _apply_camera_home_override() -> void:
	if not override_camera_home or camera == null:
		return
	camera.transform.origin = camera_home_position
	camera.rotation_degrees = camera_home_rotation_degrees
	camera.fov = camera_home_fov


## 按类型找 DecorManager 子节点并缓存；没有则警告一次并返回 null。
func get_decor_manager() -> DecorManager:
	if decor_manager != null:
		return decor_manager
	for child in get_children():
		if child is DecorManager:
			decor_manager = child
			break
	if decor_manager == null and not _warned_no_decor:
		_warned_no_decor = true
		push_warning("StageBackground(%s): 没声明 DecorManager 子节点 —— ctx.decor 会是 null" % name)
	return decor_manager

func _ready():
	if camera == null:
		camera = _find_camera()
	world_environment = _find_world_environment()
	# 关键：Environment 是场景 SubResource，多个实例共享同一资源！
	# 重跑/多背景实例会互相污染（雾/环境光状态残留）→ duplicate 成实例私有
	# （否则每次实例化拿到的是上一次 tween 改过的状态 → "越重跑越暗"）
	# 环境唯一来源是预设 .tres；这里的 duplicate 只对仍自带内联环境的场景有意义。
	if world_environment and world_environment.environment:
		world_environment.environment = world_environment.environment.duplicate()
	# 无外部相机（工作台等复用场景）→ 自建随本实例销毁的相机
	# 这样重跑时旧相机随背景销毁、新背景拿初始相机，零残留、无需手动复位
	if camera == null:
		_own_camera()
	if world_environment == null:
		push_warning("StageBackground(%s): 场景里没声明 WorldEnvironment —— 环境/雾动词不会生效" % name)
	_apply_camera_home_override()   # 必须在抓 home 之前：reset 要回“声明的”那套
	_capture_camera_home()
	if env_preset:
		apply_env_preset(env_preset)
	_resolve_showcase()
	_on_setup()


## 故事演出层（蒙眼雾 / 太阳）：按类型解析，并把相机与太阳接进雾里。
## 组件“声明即显示”，但雾还需要相机 + 太阳；接线是宿主的活，内容脚本不必自己 setup。
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


## 抓相机初始姿态（reset_camera 的复位目标；外部注入的相机也照抓）。
func _capture_camera_home() -> void:
	if camera == null:
		return
	_cam_home_pos = camera.transform.origin
	_cam_home_rot = camera.rotation
	_cam_home_fov = camera.fov
	_sync_camera_targets()   # 目标起点 = 初始姿态（相对动词从这里累加）



## 自建相机：初始姿态唯一来源 = [BackgroundCameraHome]；随本背景实例销毁
func _own_camera() -> void:
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = BackgroundCameraHome.POSITION
	cam.rotation_degrees = BackgroundCameraHome.ROTATION_DEGREES
	cam.fov = BackgroundCameraHome.FOV
	add_child(cam)
	camera = cam

func _process(delta):
	if not _is_active:
		_is_active = true
	_elapsed += delta
	_on_update(delta, _elapsed)

func _exit_tree():
	_on_cleanup()

## 按类型在兄弟节点里找相机（不按名字；一改名就会静默多建一台）。
## 不用 get_viewport().get_camera_3d()：本项目相机没有显式 current，拿不到。
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

## 取相机当前位置；无相机 = 零向量。
func get_camera_position() -> Vector3:
	if camera:
		return camera.transform.origin
	return Vector3.ZERO

# ═══ 相机动词（绝对 / 相对，名字里写清楚）═══
# 绝对：tween_camera_position / tween_camera_rotation / tween_camera_fov
# 相对：move_camera_by / rotate_camera_by（在上一条指令的目标上累加）
# rotation 参数一律弧度；camera_home_rotation_degrees 是度。

## 相机位置：绝对，tween 到 target_pos；会覆盖同属性的旧 tween。
func tween_camera_position(target_pos: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	_cam_target_pos = target_pos
	_cam_tween_pos = _replace_camera_tween("position", target_pos, duration, ease_type, trans_type, _cam_tween_pos)


## 相机位置：相对，在上一条指令的目标上再加 offset（不是从实时位置累加）。
func move_camera_by(offset: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	tween_camera_position(_cam_target_pos + offset, duration, ease_type, trans_type)


## 相机旋转：绝对（弧度），会覆盖同属性的旧 tween。
func tween_camera_rotation(target_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	_cam_target_rot = target_rot
	_cam_tween_rot = _replace_camera_tween("rotation", target_rot, duration, ease_type, trans_type, _cam_tween_rot)


## 相机旋转：相对（弧度），在上一条指令的目标上再加 delta_rot。
func rotate_camera_by(delta_rot: Vector3, duration: float, ease_type: int = Tween.EASE_IN_OUT, trans_type: int = Tween.TRANS_SINE) -> void:
	if camera == null:
		return
	tween_camera_rotation(_cam_target_rot + delta_rot, duration, ease_type, trans_type)


## 相机 FOV：绝对（tween）。
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

## WorldEnvironment 懒查找：子节点的 _ready 早于父节点，内容脚本可能先调 apply_env_preset。
func _env_node() -> WorldEnvironment:
	if world_environment == null:
		world_environment = _find_world_environment()
	return world_environment


## 用预设构建全新 Environment（每次新实例，重跑 / 多背景零共享污染）。
## 可能在父节点 _ready 之前被调用（内容脚本在自己的 _ready 里调）。
func apply_env_preset(preset: BackgroundEnvPreset) -> void:
	var we := _env_node()
	if we == null:
		return
	we.environment = preset.build_environment()

## DEPTH 模式实测更差（树是一带纸片，树线出台阶；fog_density 几乎失效）。
## 保持 EXPONENTIAL，靠“留一层残雾”实现远处渐淡。

## 雾色 + 雾量 + 天球地平线色联动 tween。
## amount = 雾量（0 = 最清，1 = 最浓）→ fog_density；地面底色按雾色暗化 25%。
## 不要把雾量调到 0 附近，否则远处没有渐淡。
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

## 相机复位到 _ready 抓的初始姿态：先杀掉所有相机 tween，再写回位置 / 旋转 / FOV。
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


## 完整复位：环境从 env_preset 重建 + 相机回初始姿态；重跑 / 开演前调。
func reset() -> void:
	if env_preset:
		apply_env_preset(env_preset)
	reset_camera()

## 取天球材质：tween_env_fog 靠它把地平线色跟着雾色走。
## 天球配在内容预设里；没有 sky 时返回 null，联动静默 no-op。
func _sky_material(env: Environment) -> ProceduralSkyMaterial:
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		return env.sky.sky_material
	return null

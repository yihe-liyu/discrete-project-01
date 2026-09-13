## MarisaLaserFade—— 魔理沙非 focus 激光「整批渐隐」控制器。
## 对应重建版的 LaserShot：漂移由内核 LaserFollowBehavior 管，本类只管
##   「按住射击 = 满亮；松手 / 切 focus = 整批 set_render_fade 到 0 后清掉 LASER 行」。
## 无 class_name；由 KernelBulletBackend preload。
extends RefCounted

const FADE_TIME: float = 0.2

var backend   # KernelBulletBackend
var _fading: bool = false
var _fade_t: float = 0.0
var _spawned: bool = false   # 自上次淡完后是否又生成过激光段


func setup(p_backend) -> void:
	backend = p_backend


## 每帧（由 KernelBulletBackend._physics_process 驱动）。
func process(delta: float) -> void:
	var system = backend.system
	if system == null:
		return
	if _fading:
		_fade_t -= delta
		system.set_render_fade(BulletType.Kind.LASER, clampf(_fade_t / FADE_TIME, 0.0, 1.0))
		if _fade_t <= 0.0:
			_fading = false
			_spawned = false
			_despawn_lasers(system)
	elif _spawned and _is_released():
		_fading = true
		_fade_t = FADE_TIME


## 新激光段发射时复位（按住射击期间保持满亮）。
func on_laser_spawned() -> void:
	_fading = false
	_spawned = true
	_fade_t = FADE_TIME
	if backend.system != null:
		backend.system.set_render_fade(BulletType.Kind.LASER, 1.0)


func _is_released() -> bool:
	return not Input.is_action_pressed("shoot") or Input.is_action_pressed("focus")


func _despawn_lasers(system) -> void:
	for i in range(system.get_active_count() - 1, -1, -1):
		var bt = system.get_type(i)
		if bt != null and bt.kind == BulletType.Kind.LASER:
			system.despawn(i)

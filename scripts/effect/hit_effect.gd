extends Node2D
class_name HitEffect
# 命中特效基类 — 支持对象池回收
#
# 用法（池化）：
#   FxLayer.play(scene, pos, vel, tint)
#   effect.activate(pos, vel, tint)
#   # 播完后自动 invisible + _on_finish()

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _on_finish: Callable  # 回收回调，池化时由 FxLayer 注入


func activate(p_pos: Vector2, p_vel: Vector2, p_tint: Color, p_on_finish: Callable = Callable()) -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	scale = Vector2.ONE
	rotation = 0.0
	global_position = p_pos
	_age = 0.0
	visible = true
	_on_finish = p_on_finish
	set_velocity(p_vel)
	set_tint(p_tint)
	_setup()


## 播完后调此方法，而不是 queue_free
func _finish() -> void:
	visible = false
	if _on_finish.is_valid():
		_on_finish.call(self)
	else:
		queue_free()


# ── 公共接口 ──

func set_velocity(vel: Vector2) -> void:
	velocity = vel.normalized() * _get_speed()
	_on_velocity_set()


func set_tint(_color: Color) -> void:
	pass


# ── 子类覆写 ──

func _get_speed() -> float:
	return 300.0


## 存活上限（秒），超时自动 _finish
func _get_life_limit() -> float:
	return 2.0


## 每次 activate 时调用一次，播放动画、创建 tween 等
func _setup() -> void:
	pass


## set_velocity 注入速度后调用，用于设置 rotation 等
func _on_velocity_set() -> void:
	pass


## 每物理帧额外逻辑（缩放等）
func _process_extra(_delta: float) -> void:
	pass


# ── 内部 ──

func _physics_process(delta: float) -> void:
	position += velocity * delta
	_process_extra(delta)
	_age += delta
	if _age > _get_life_limit():
		_finish()

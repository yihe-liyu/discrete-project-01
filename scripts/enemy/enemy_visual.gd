extends AnimatedSprite2D
class_name EnemyVisual
## 根据父节点移动速度自动切换动画
##
## 速度阈值：
##   speed < 2.0  → idle (loop)
##   speed >= 2.0 → righting(过渡) → right (loop)
##
## flip_h 由移动方向自动控制

const IDLE    = "idle"
const RIGHTING = "righting"
const RIGHT   = "right"

var anim_state: String = IDLE
var _parent: Node2D
var _last_pos: Vector2
var _speed: float = 0.0
var _idle_timer: float = 0.0  # speed 连续低于阈值的时间
const MOVE_THRESHOLD: float = 30.0   # 像素/秒，超过算移动
const IDLE_HOLD: float = 0.2         # 低于阈值持续多久才切idle (防抖闪)


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)
	_parent = get_parent()
	if _parent:
		_last_pos = _parent.global_position
	# righting 只播一次，不循环
	var frames := sprite_frames
	if frames and frames.has_animation(RIGHTING):
		frames.set_animation_loop(RIGHTING, false)


func _process(delta: float) -> void:
	if not _parent:
		return
	var dx := _parent.global_position.x - _last_pos.x
	_speed = abs(dx) / max(delta, 0.001)
	_last_pos = _parent.global_position

	# 翻向
	if dx > 0.1:
		flip_h = false
	elif dx < -0.1:
		flip_h = true

	var moving := _speed >= MOVE_THRESHOLD

	# ── 延迟退出：低于阈值才累加 timer，超过阈值立刻清零 ──
	if not moving:
		_idle_timer += delta
	else:
		_idle_timer = 0.0
		if anim_state == IDLE:
			change_state(RIGHTING)

	match anim_state:
		IDLE:
			if moving:
				change_state(RIGHTING)
		RIGHTING:
			if _idle_timer >= IDLE_HOLD:
				change_state(IDLE)
		RIGHT:
			if _idle_timer >= IDLE_HOLD:
				change_state(IDLE)


func change_state(new_state: String) -> void:
	if anim_state == new_state:
		return
	anim_state = new_state
	play(anim_state)


func _on_animation_finished() -> void:
	match anim_state:
		RIGHTING:
			change_state(RIGHT)

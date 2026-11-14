## 内容侧 behavior 构造器：把裸 float 数组参数收成具名 API。
## 运行层仍然是 behavior_id + 固定 params；这里只做参数编码与校验。
class_name BulletBehaviors
extends RefCounted


static func linear() -> BehaviorSpec:
	return BehaviorSpec.new(&"linear")


static func homing(speed: float, turn: float) -> BehaviorSpec:
	return BehaviorSpec.new(&"homing", PackedFloat32Array([speed, turn]))


static func accel(acceleration: Vector2) -> BehaviorSpec:
	return BehaviorSpec.new(&"accel", PackedFloat32Array([acceleration.x, acceleration.y]))


## 种子弹：线性减速到 0，结束时向四周 emit 一圈。
static func seed_burst(template: EmitTemplate, duration: float, initial_speed: float,
		count: int, child_speed: float, spread: float = TAU) -> BehaviorSpec:
	var tid := template.numeric_id if template != null else -1
	return BehaviorSpec.new(&"seed_burst", PackedFloat32Array([
		duration, initial_speed, float(tid), float(count), child_speed, spread,
	]))


## 雨弹阶段：首次上移 offset，受重力；到 y 阈值 emit 下一阶段。
static func rain_stage(template: EmitTemplate, gravity: float, threshold_y: float,
		offset_y: float = 0.0, clear_fx: bool = true, despawn: bool = true,
		laser_template: LaserTemplate = null) -> BehaviorSpec:
	var tid := template.numeric_id if template != null else -1
	var lid := laser_template.numeric_id if laser_template != null else -1
	return BehaviorSpec.new(&"stage03B.mid01.rain_stage", PackedFloat32Array([
		gravity, threshold_y, float(tid), offset_y,
		1.0 if clear_fx else 0.0, 1.0 if despawn else 0.0, float(lid),
	]))


## 旋转一段时间后反向旋转、沿 heading 减速；到速度阈值时可选清弹/回收。
static func spin_then_slow(spin: float, duration: float, reverse_factor: float,
		accel_px: float, speed_threshold: float, clear_fx: bool = true,
		despawn: bool = true) -> BehaviorSpec:
	return BehaviorSpec.new(&"stage02.enemy02.spin_then_slow", PackedFloat32Array([
		spin, duration, reverse_factor, accel_px, speed_threshold,
		1.0 if clear_fx else 0.0, 1.0 if despawn else 0.0,
	]))


## 撞上墙后 emit 一个模板并回收自己。
static func top_emit(template: EmitTemplate, accel_px: float,
		angle: float = PI, child_speed: float = 0.0) -> BehaviorSpec:
	if template == null or template.numeric_id < 0:
		push_error("BulletBehaviors.top_emit(): template 未注册")
		return null
	return BehaviorSpec.new(&"stage01.enemy04.top_emit", PackedFloat32Array([
		accel_px, template.numeric_id, child_speed, angle,
	]))


## 沿自身 heading 加速。
static func accel_heading(acceleration: float) -> BehaviorSpec:
	return BehaviorSpec.new(&"accel_heading", PackedFloat32Array([acceleration]))


## 减速到时间点后，按概率在 template_a / template_b 间选一个子弹出。
static func split_after(template_a: EmitTemplate, template_b: EmitTemplate,
		duration: float, accel_px: float, chance: float, child_speed: float = 0.0,
		spread: float = 0.0) -> BehaviorSpec:
	if template_a == null or template_b == null:
		push_error("BulletBehaviors.split_after(): template 不能为空")
		return null
	if template_a.numeric_id < 0 or template_b.numeric_id < 0:
		push_error("BulletBehaviors.split_after(): template 尚未注册")
		return null
	return BehaviorSpec.new(&"split_after", PackedFloat32Array([
		accel_px, duration, template_a.numeric_id, template_b.numeric_id,
		chance, child_speed, spread,
	]))


## 撞墙 emit + 可选回收。
## child_speed <= 0 = 沿用父弹当前速度；despawn = 撞墙后是否回收父弹。
static func bounce_emit(template: EmitTemplate, child_speed: float = 0.0,
		accel_px: float = 0.0, angle: float = 0.0, despawn: bool = true) -> BehaviorSpec:
	if template == null:
		push_error("BulletBehaviors.bounce_emit(): template 不能为空")
		return null
	if template.numeric_id < 0:
		push_error("BulletBehaviors.bounce_emit(): template 尚未注册（numeric_id < 0）")
		return null
	return BehaviorSpec.new(&"bounce_emit", PackedFloat32Array([
		template.numeric_id,
		child_speed,
		accel_px,
		angle,
		1.0 if despawn else 0.0,
	]))

## 内容侧 behavior 构造器：把裸 float 数组参数收成具名 API。
## 运行层仍然是 behavior_id + 固定 params；这里只做参数编码与校验。
class_name BulletBehaviors
extends RefCounted


static func linear() -> BehaviorSpec:
	return BehaviorSpec.new(&"linear")


const HOMING_PLAYER := 0
const HOMING_NEAREST_ENEMY := 1


## 追踪。只给前两个参数 = 旧语义（追自机、固定速度）。
## target_mode = 1 时追最近敌人；speed_end + speed_ramp 做线性变速；
## turn_ramp / dist_weight / steer_until 对应 lifecycle steer 的 ramp / 距离权重 / 转向时长。
static func homing(speed: float, turn: float, target_mode: int = HOMING_PLAYER,
		speed_end: float = 0.0, speed_ramp: float = 0.0, turn_ramp: float = 0.0,
		dist_weight: float = 0.0, steer_until: float = 0.0) -> BehaviorSpec:
	return BehaviorSpec.new(&"homing", PackedFloat32Array([
		speed, turn, float(target_mode), speed_end, speed_ramp,
		turn_ramp, dist_weight, steer_until,
	]))


static func accel(acceleration: Vector2) -> BehaviorSpec:
	return BehaviorSpec.new(&"accel", PackedFloat32Array([acceleration.x, acceleration.y]))


## 声呐弹：靠近自机折返，回到 Boss 附近后炸开。
static func sonar(flower: EmitTemplate, string_bullet: EmitTemplate,
		return_radius: float, flower_count: int, string_mode: int,
		string_speed_base: float = 400.0) -> BehaviorSpec:
	var fid := flower.numeric_id if flower != null else -1
	var sid := string_bullet.numeric_id if string_bullet != null else -1
	return BehaviorSpec.new(&"stage01.mid01.sonar", PackedFloat32Array([
		return_radius, float(fid), float(sid), float(flower_count),
		float(string_mode), string_speed_base,
	]))


## 锚定宿主节点做线性漂移（激光段）。anchor 由 SpawnSpec.anchor 提供。
static func anchor_drift(angle: float, speed: float, initial: float = 0.0,
		render_heading: bool = true) -> BehaviorSpec:
	return BehaviorSpec.new(&"anchor_drift", PackedFloat32Array([
		angle, speed, initial, 1.0 if render_heading else 0.0,
	]))


## 持续旋转渲染朝向 + 沿 heading 加速。
static func spin_accel(spin: float, accel_px: float) -> BehaviorSpec:
	return BehaviorSpec.new(&"spin_accel", PackedFloat32Array([spin, accel_px]))


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
static func accel_heading(acceleration: float, lifetime: float = 0.0,
		clear: bool = false) -> BehaviorSpec:
	return BehaviorSpec.new(&"accel_heading", PackedFloat32Array([
		acceleration, lifetime, 1.0 if clear else 0.0,
	]))


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
		accel_px: float = 0.0, angle: float = 0.0, despawn: bool = true,
		reflect: bool = false) -> BehaviorSpec:
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
		1.0 if reflect else 0.0,
	]))

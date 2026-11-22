## 原生弹幕存储的 GDScript 桥接层。
##
## 原生 [code]DanmakuStore[/code] 是唯一存储（spawn / despawn / integrate / behavior / collision）；
## 本类维护 BulletType / render_fade / spawn_fx 表与每帧只读快照，供渲染 / 物理 / 调试读取。
##
## 契约：遍历中 [code]despawn[/code] 必须倒序（swap-with-last；快照在帧内不即时更新）。
## 没有 GDScript BulletSystem 回退；扩展缺失时 [code]is_native_ready()[/code] 为 false。
class_name KernelNativeSystem
extends Node
## 消弹消散特效（与出生雾同一套 EffectType 模型）——「消弹消散」的唯一来源：
## 死亡清弹圈扫掠（KernelBulletPhysics）与 behavior 的 clear_fx / despawn_clear 都走 play_clear_fx。
const CLEAR_FX: EffectType = preload("res://data/fx/enemy_clear_fx.tres")

@export_group("Pool")
## 弹池初始容量（@export，建池时用）。
@export var initial_capacity: int = 1024
## 默认最长存活秒数；<=0 = 由行为/超时决定。
@export var default_lifetime: float = 20.0

@export_group("World bounds (cull)")
## 世界坐标失效区：超出即回收；空 = 不剔除。
@export var cull_rect: Rect2
## 剔除余量。
@export var cull_margin: float = 32.0

var _accel: Object = null
## 内核 RNG 种子（宿主 RNG 派生；原生 store 建好/重播种时应用）
var _seed: int = 0
## 诊断计数器：真正走了原生路径的帧数。
var native_frames: int = 0

# ── 原生行为执行（由 KernelBulletHost 装配）──
## 是否启用原生行为管道。
var enable_native_behaviors: bool = false
## 原生行为使用的 BehaviorContext。
var behavior_ctx: BehaviorContext
## 原生行为宿主（KernelBehaviorHost）。
var behavior_host          # KernelBehaviorHost
## 取当前 Boss 的回调（行为目标用）。
var boss_getter: Callable

# ── 每帧只读快照（pull 自原生权威 SoA）──
var _active_count: int = 0
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _color := PackedColorArray()
var _type_index := PackedInt32Array()      # 行 → _type_registry 下标
var _faction := PackedByteArray()
var _life_left := PackedFloat32Array()
var _fx_phase := PackedFloat32Array()
var _fx_type_index := PackedInt32Array()   # 行 → _fx_registry 下标（-1 = 无特效）
var _timer := PackedFloat32Array()
var _render_rot := PackedFloat32Array()   # 逐弹渲染朝向覆盖（NAN = 用 velocity 推）
var _out_grace := PackedFloat32Array()    # 逐弹出界宽限（秒；0 = 出界立即剔除）

# ── 宿主侧表 ──
var _type_registry: Array[BulletType] = []
var _render_fade: Dictionary = {}          # Kind → 整批淡出 0..1
var _spawn_fx: Dictionary = {}             # Faction → 出生特效 EffectType
var _fx_registry: Array[EffectType] = []   # 特效表（发弹/消弹共用；行按下标引用）
## 内容层子弹出模板；C++ Outcome 只带 numeric_id，本层负责解析。
var emit_templates := EmitTemplateRegistry.new()
## 由 KernelBulletHost 注入：模板 → 真正 spawn。
var emit_spawner: Callable
## 内容层激光模板；C++ Outcome 只带 numeric_id。
var laser_templates: Dictionary = {}
var _next_laser_template_id: int = 1
## behavior 激光生成回调（KernelBulletHost 注入）。
var laser_spawner: Callable
## 每帧返回 PackedVector2Array 的锚点位置（下标 = set_anchor_slot 的 slot）；空 = 无锚点。
var anchor_provider: Callable
## behavior 撞墙音效表：内容注册 stream，C++ outcome 只带下标。
var behavior_sfx: Array[AudioStream] = []

## 确定性 RNG（宿主 seed；行为已原生，仅保留宿主接口）。
var _random := RandomNumberGenerator.new()



func _init() -> void:
	_ensure_native()


func _ensure_native() -> void:
	if _accel == null and ClassDB.class_exists("DanmakuStore"):
		_accel = ClassDB.instantiate("DanmakuStore")
		_accel.setup(initial_capacity, cull_rect)
		_accel.set_field(GameConfig.FIELD_LEFT, GameConfig.FIELD_RIGHT, GameConfig.FIELD_TOP)
		_accel.set_margin(cull_margin)
		_accel.set_default_life(default_lifetime)
		_accel.set_seed(_seed)
		if behavior_sfx.is_empty():
			behavior_sfx.append(AssetRegistry.sounds.get("kira"))
			behavior_sfx.append(AssetRegistry.sounds.get("shoot"))


## 原生扩展是否已加载；首次调用会尝试实例化 DanmakuStore。
func is_native_ready() -> bool:
	_ensure_native()
	return _accel != null


# ═══ 容量 ═══

func _ensure_capacity(capacity: int) -> void:
	if _positions.size() >= capacity:
		return
	var n: int = maxi(maxi(capacity, _positions.size() * 2), 16)
	_positions.resize(n)
	_velocities.resize(n)
	_color.resize(n)
	_type_index.resize(n)
	_faction.resize(n)
	_life_left.resize(n)
	_fx_phase.resize(n)
	_fx_type_index.resize(n)
	_timer.resize(n)
	_render_rot.resize(n)
	_out_grace.resize(n)
	if _accel != null:
		_accel.reserve(n)


# ═══ 发射 / 回收 ═══

## 弹型懒注册（find or append），返回下标。
func _type_registry_index_of(bullet_type: BulletType) -> int:
	var idx := _type_registry.find(bullet_type)
	if idx == -1:
		idx = _type_registry.size()
		_type_registry.append(bullet_type)
	return idx


## 某阵营的出生特效（改一处全变）。注册进特效表，渲染端按行下标取贴图/参数。
func set_spawn_fx(faction: BulletType.Faction, effect: EffectType) -> void:
	_spawn_fx[faction] = effect
	if effect != null:
		_fx_registry_index_of(effect)


## 特效懒注册（find or append），返回下标；渲染端经 get_fx_registry() 取下标的贴图。
func _fx_registry_index_of(effect: EffectType) -> int:
	var idx := _fx_registry.find(effect)
	if idx == -1:
		idx = _fx_registry.size()
		_fx_registry.append(effect)
	return idx


func _set_row_fx(id: int, effect: EffectType) -> void:
	if effect != null and effect.duration > 0.0:
		_fx_phase[id] = effect.duration
		_fx_type_index[id] = _fx_registry_index_of(effect)
	else:
		_fx_phase[id] = 0.0
		_fx_type_index[id] = -1


## 发射（写快照行 + 原生权威行）。
func spawn(bullet_data: BulletType, position: Vector2, velocity: Vector2, color: Color = Color.WHITE) -> int:
	var ti := _type_registry_index_of(bullet_data)
	var id := _active_count
	_ensure_capacity(id + 1)
	_active_count += 1
	_positions[id] = position
	_velocities[id] = velocity
	_color[id] = color
	_type_index[id] = ti
	_faction[id] = bullet_data.faction
	_life_left[id] = default_lifetime
	_timer[id] = 0.0
	_render_rot[id] = NAN
	_out_grace[id] = bullet_data.out_grace
	var effect: EffectType = null
	if bullet_data.is_spawn_fog:
		effect = bullet_data.spawn_fx if bullet_data.spawn_fx != null else _spawn_fx.get(bullet_data.faction)
	_set_row_fx(id, effect)
	var nid := id
	if _accel != null:
		nid = _accel.spawn(position, velocity, ti, int(bullet_data.faction), color)
		if nid < 0:
			push_error("[KernelNativeSystem] 原生 store 溢出（capacity=%d）" % _accel.get_capacity())
			return id
		_accel.set_hitbox(nid, bullet_data.hitbox_radius, bullet_data.hitbox_offset, bullet_data.hitbox_size, bullet_data.follow_dir, bullet_data.dir_offset)
		_accel.set_life(nid, _life_left[id])
		_accel.set_fx(nid, _fx_phase[id])
		_accel.set_fx_type(nid, _fx_type_index[id])
		_accel.set_timer(nid, _timer[id])
		_accel.set_out_grace(nid, _out_grace[id])
		_accel.set_wrap(nid, bullet_data.wrap_mask)
	return nid


## 播一条纯特效行（消弹/爆发）：无弹型、无碰撞，寿命 = effect.duration（原生 integrate 到期回收）。
## 返回行 id；effect 为空或时长为 0 → -1（静默）。
func spawn_fx(effect: EffectType, position: Vector2, color: Color = Color.WHITE, faction: BulletType.Faction = BulletType.Faction.ENEMY) -> int:
	if effect == null or effect.duration <= 0.0:
		return -1
	var fi := _fx_registry_index_of(effect)
	var id := _active_count
	_ensure_capacity(id + 1)
	_active_count += 1
	_positions[id] = position
	_velocities[id] = Vector2.ZERO
	_color[id] = color
	_type_index[id] = -1
	_faction[id] = faction
	_life_left[id] = effect.duration
	_fx_phase[id] = effect.duration
	_fx_type_index[id] = fi
	_timer[id] = 0.0
	_render_rot[id] = NAN
	_out_grace[id] = 0.0   # 纯特效行不参与出界宽限
	if _accel != null:
		_accel.spawn_fx(fi, position, color, int(faction), effect.duration)
	return id


## 播一次「消弹消散」：同色提亮 1.5×（与死亡清弹圈扫掠完全一致）。
## 纯特效行，无节点/tween 分配。调用方：KernelBulletPhysics 的 sweep，以及生命周期 op 47（[code]clear_fx[/code]）。
func play_clear_fx(pos: Vector2, tint: Color) -> void:
	var bright := Color(
		minf(tint.r * 1.5, 1.0),
		minf(tint.g * 1.5, 1.0),
		minf(tint.b * 1.5, 1.0),
		tint.a
	)
	spawn_fx(CLEAR_FX, pos, bright, BulletType.Faction.ENEMY)


## 回收：快照 swap-with-last（供帧内一致性）+ 原生权威 swap。
func despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	var tail := _active_count - 1
	if id != tail:
		_positions[id] = _positions[tail]
		_velocities[id] = _velocities[tail]
		_color[id] = _color[tail]
		_type_index[id] = _type_index[tail]
		_faction[id] = _faction[tail]
		_life_left[id] = _life_left[tail]
		_fx_phase[id] = _fx_phase[tail]
		_fx_type_index[id] = _fx_type_index[tail]
		_timer[id] = _timer[tail]
		_render_rot[id] = _render_rot[tail]
		_out_grace[id] = _out_grace[tail]
	_active_count -= 1
	if _accel != null:
		_accel.despawn(id)


## 逐弹出界宽限（秒）—— 与原生 [code]DanmakuStore.set_out_grace[/code] 同名同义。
## 常规发射路径不需要它（grace 随 [code]BulletType.out_grace[/code] 在 spawn 时推下去）；
## 本方法供 parity / 调试在发射后改。
func set_out_grace(id: int, grace: float) -> void:
	if id < 0 or id >= _active_count:
		return
	_out_grace[id] = grace
	if _accel != null:
		_accel.set_out_grace(id, grace)


## 读原生行的出界宽限（测试/调试用；无原生或越界 → -1）。
func get_out_grace(id: int) -> float:
	if id < 0 or id >= _active_count or _accel == null:
		return -1.0
	return _accel.get_out_grace(id)


## 清空所有行（快照 + 原生 store），保留容量与注册表。
func clear() -> void:
	_active_count = 0
	if _accel != null:
		_accel.clear()


## 重置内核注册表：丢弃全部已注册弹型 / 特效，并重建原生 store（只在清场后调用）。
func reset_registries() -> void:
	_active_count = 0
	_accel = null            # 丢旧 store：SoA 一并释放，下次 _ensure_native 新建
	_type_registry.clear()
	_fx_registry.clear()
	_ensure_native()


# ═══ 写访问器（工具 / 回退 / 测试）═══

## 改一行速度（会转发原生；普通行为优先用速度原语）。
func set_velocity(id: int, value: Vector2) -> void:
	_velocities[id] = value
	if _accel != null:
		_accel.set_velocity(id, value)


## 直接设定世界位置（锚定型行为用；普通行为请用 set_velocity）。
func set_position(id: int, value: Vector2) -> void:
	_positions[id] = value
	if _accel != null:
		_accel.set_position(id, value)


## 改一行剩余寿命（秒）。
func set_life(id: int, value: float) -> void:
	_life_left[id] = value
	if _accel != null:
		_accel.set_life(id, value)


## 改一行特效相位（秒）。
func set_fx(id: int, value: float) -> void:
	_fx_phase[id] = value
	if _accel != null:
		_accel.set_fx(id, value)


## 改一行自定义计时器。
func set_timer(id: int, value: float) -> void:
	_timer[id] = value
	if _accel != null:
		_accel.set_timer(id, value)


# ═══ 判定（权威在原生；宽相网格）═══

## 宽相圆查询；返回候选行 id，仍需 hit_test 精确判定。
func query_circle(center: Vector2, search_radius: float) -> PackedInt32Array:
	if _accel != null:
		return _accel.query_circle(center, search_radius)
	return PackedInt32Array()


## 单行精确判定。
func hit_test(id: int, center: Vector2, radius: float) -> bool:
	return _accel.hit_test(id, center, radius) if _accel != null else false


## 单行扫掠判定：用上一帧位置到当前位置的线段代替点，防止高速弹在两次采样之间穿过。
func hit_test_swept(id: int, center: Vector2, radius: float) -> bool:
	return _accel.hit_test_swept(id, center, radius) if _accel != null else false


## 最近一次积分帧的最大位移（像素）。宽相查询半径需加上它，否则高速弹的端点可能落在查询圆外。
func get_max_step() -> float:
	return _accel.get_max_step() if _accel != null else 0.0


## 该行本帧是否已擦弹过。
func is_grazed(id: int) -> bool:
	return _accel.is_grazed(id) if _accel != null else false


## 标记该行当前 tick 已擦弹。
func mark_grazed(id: int) -> void:
	if _accel != null:
		_accel.mark_grazed(id)


## 同一颗弹两次擦弹之间至少间隔的 tick 数（1 = 每 tick 都可计）。
func set_graze_interval_ticks(ticks: int) -> void:
	if _accel != null:
		_accel.set_graze_interval_ticks(ticks)


## native behavior 名字 → registry id；未知 → -1。
func get_behavior_id(behavior_name: String) -> int:
	return _accel.get_behavior_id(behavior_name) if _accel != null else -1


## registry id → 名字；未知 → 空。
func get_behavior_name(behavior: int) -> String:
	return _accel.get_behavior_name(behavior) if _accel != null else ""


## 给一行绑定 native behavior（低层 API；内容接入前先由测试/工具使用）。
func set_behavior(id: int, behavior: int, params := PackedFloat32Array()) -> bool:
	return _accel.set_behavior(id, behavior, params) if _accel != null else false


## 当前行绑定的 behavior id；无 → -1。
func set_anchor_slot(id: int, slot: int) -> void:
	if _accel != null:
		_accel.set_anchor_slot(id, slot)


func get_anchor_slot(id: int) -> int:
	return _accel.get_anchor_slot(id) if _accel != null else -1


func get_behavior(id: int) -> int:
	return _accel.get_behavior(id) if _accel != null else -1


## 注册内容层子弹出模板；返回 false 时看 last_errors。
func register_emit_template(template: EmitTemplate) -> bool:
	if template == null:
		return false
	if emit_templates.has(template.id):
		# 同 id 的模板会在卡重试 / 多只同类敌人时重新 new；
		# 复用已注册模板的 numeric_id，让 behavior 拿到的 id 与真实模板表一致。
		var existing: EmitTemplate = emit_templates.get_template(template.id)
		template.numeric_id = existing.numeric_id
		return true
	return emit_templates.register(template)


func register_laser_template(template: LaserTemplate) -> bool:
	if template == null:
		return false
	var errors: Array[String] = template.validate()
	if not errors.is_empty():
		push_error("[KernelNativeSystem] LaserTemplate 校验失败：%s" % [errors])
		return false
	if template.numeric_id < 0:
		template.numeric_id = _next_laser_template_id
		_next_laser_template_id += 1
	laser_templates[template.numeric_id] = template
	return true


func get_laser_template(numeric_id: int) -> LaserTemplate:
	return laser_templates.get(numeric_id)


## 注册 / 复用 behavior 音效；返回绑定给 C++ 的下标。
func register_behavior_sfx(stream: AudioStream) -> int:
	if stream == null:
		return -1
	var idx := behavior_sfx.find(stream)
	if idx >= 0:
		return idx
	behavior_sfx.append(stream)
	return behavior_sfx.size() - 1


## 逐弹颜色（下一帧渲染快照生效）。
func set_color(id: int, color: Color) -> void:
	if _accel != null:
		_accel.set_color(id, color)
	if id >= 0 and id < _color.size():
		_color[id] = color


## 单行渲染朝向；NAN = 按 velocity。
func get_render_rot(id: int) -> float:
	return _accel.get_render_rot(id) if _accel != null else NAN


## 当前帧渲染朝向覆盖。
func set_render_rot(id: int, rot: float) -> void:
	if _accel != null:
		_accel.set_render_rot(id, rot)


## {radius, offset, size, follow_dir, dir_offset}；无效 → 空字典。
func get_hitbox(id: int) -> Dictionary:
	return _accel.get_hitbox(id) if _accel != null else {}


## 边环绕掩码：1 左 / 2 右 / 4 上 / 8 下。
func get_wrap(id: int) -> int:
	return _accel.get_wrap(id) if _accel != null else 0


func set_wrap(id: int, mask: int) -> void:
	if _accel != null:
		_accel.set_wrap(id, mask)


## 累计贴图自转。
func get_spin_rot(id: int) -> float:
	return _accel.get_spin_rot(id) if _accel != null else 0.0


func set_spin_rot(id: int, rot: float) -> void:
	if _accel != null:
		_accel.set_spin_rot(id, rot)


## 当前 phase / behavior 累计秒数。
func get_elapsed(id: int) -> float:
	return _accel.get_elapsed(id) if _accel != null else 0.0


## behavior 固定 8 槽 state（debug / 预览）。
func get_behavior_state(id: int) -> PackedFloat32Array:
	return _accel.get_behavior_state(id) if _accel != null else PackedFloat32Array()


## behavior 固定 8 槽 params（debug / 预览）。
func get_behavior_params(id: int) -> PackedFloat32Array:
	return _accel.get_behavior_params(id) if _accel != null else PackedFloat32Array()


# ═══ 读访问器（快照）═══

## 当前活跃行数；快照数组按容量分配，只有前 count 行有效。
func get_active_count() -> int:
	return _active_count

## 位置快照。
func get_positions() -> PackedVector2Array:
	return _positions

## 速度快照。
func get_velocities() -> PackedVector2Array:
	return _velocities

## 颜色快照。
func get_colors() -> PackedColorArray:
	return _color

## 行 → 弹型表下标。
func get_type_indices() -> PackedInt32Array:
	return _type_index


## 单行取类型下标（不要为读一个元素拉整张 _type_index）。
func get_type_index(id: int) -> int:
	if _accel != null:
		return _accel.get_type_index(id)
	return _type_index[id] if id >= 0 and id < _type_index.size() else -1

## 行 → 阵营（BulletType.Faction）。
func get_factions() -> PackedByteArray:
	return _faction

## 该行弹型；越界/纯特效行 → null。
func get_type(id: int) -> BulletType:
	var ti: int = _type_index[id]
	return _type_registry[ti] if ti >= 0 and ti < _type_registry.size() else null

## 单行位置。
func get_position(id: int) -> Vector2:
	return _positions[id]

## 单行速度。
func get_velocity(id: int) -> Vector2:
	return _velocities[id]

## 单行颜色。
func get_color(id: int) -> Color:
	return _color[id]

## 单行剩余寿命（秒）。
func get_life_left(id: int) -> float:
	return _life_left[id]

## 单行特效相位（秒）。
func get_fx_phase(id: int) -> float:
	return _fx_phase[id]

## 行 → 稳定句柄；纯特效 / 无效 / 无原生 = 0。
func get_uid(id: int) -> int:
	if _accel == null:
		return 0
	return int(_accel.get_uid(id))

## 稳定句柄 → 当前行；已回收 / 无原生 = -1。
func find_uid(uid: int) -> int:
	if _accel == null:
		return -1
	return int(_accel.find_uid(uid))

## 单行自定义计时器。
func get_timer(id: int) -> float:
	return _timer[id]

## 逐弹渲染朝向覆盖（NAN = 未设，渲染端按 velocity 推）。
func get_render_rots() -> PackedFloat32Array:
	return _render_rot

## 弹型表（行里的 type index 指向它）。
func get_type_registry() -> Array[BulletType]:
	return _type_registry


## 每帧快照：相位中的弹/纯特效行（渲染桥读它算缩放/淡出）。
func get_fx_phases() -> PackedFloat32Array:
	return _fx_phase


## 行 → 特效表下标（-1 = 无特效）。
func get_fx_type_indices() -> PackedInt32Array:
	return _fx_type_index


## 特效表（渲染桥按行下标取贴图/参数）。
func get_fx_registry() -> Array[EffectType]:
	return _fx_registry


## 按弹型类别（Kind）设/取整批渲染淡出（0..1）。
func set_render_fade(kind: int, value: float) -> void:
	_render_fade[kind] = clampf(value, 0.0, 1.0)

## 读某弹型类别的整批渲染淡出（0..1）。
func get_render_fade(kind: int) -> float:
	return _render_fade.get(kind, 1.0)


# ═══ 确定性 RNG（宿主 seed）═══

## 设宿主 RNG 种子，并转发原生 store。
func set_seed(seed_value: int) -> void:
	_seed = seed_value
	_random.seed = seed_value
	if _accel != null:
		_accel.set_seed(seed_value)   # 转发原生 store（行为随机走内核单通道）

## 宿主 RNG：0..1。
func randf() -> float:
	return _random.randf()

## 宿主 RNG：区间浮点。
func randf_range(from: float, to: float) -> float:
	return _random.randf_range(from, to)

## 宿主 RNG：区间整数。
func randi_range(from: int, to: int) -> int:
	return _random.randi_range(from, to)


# ═══ 每帧 ═══

## 手动推进一帧（无树 / 测试 / 预览工具用；与 _physics_process 同一条路径）。
## 手动推进（测试 / 预览）：显式 dt；生产 _physics_process 固定用 SimClock.DT。
func step(delta: float) -> void:
	_step_with(delta)


func _physics_process(_delta: float) -> void:
	_step_with(SimClock.DT)


func _step_with(dt: float) -> void:
	_ensure_native()
	if _accel == null:
		return
	_accel.set_cull(cull_rect)
	_accel.set_margin(cull_margin)
	_accel.set_default_life(default_lifetime)
	if _accel.get_active_count() == 0:
		_pull_snapshot()
		return
	native_frames += 1
	_accel.integrate(dt)
	if enable_native_behaviors:
		_run_native_behaviors(dt)
	_pull_snapshot()


func _run_native_behaviors(delta: float) -> void:
	if _accel.get_active_count() == 0:
		return
	var player := Vector2.ZERO
	var enemies := PackedVector2Array()
	if behavior_ctx != null:
		player = behavior_ctx.get_player_position()
		for e in behavior_ctx.get_world().get_enemies():
			enemies.append(e.global_position)
	var boss = boss_getter.call() if boss_getter.is_valid() else null
	var has_boss: bool = is_instance_valid(boss)
	var boss_pos: Vector2 = boss.global_position if has_boss else Vector2.ZERO
	var anchors := PackedVector2Array()
	if anchor_provider.is_valid():
		var raw: Variant = anchor_provider.call()
		if raw is PackedVector2Array:
			anchors = raw
	var res: Dictionary = _accel.behavior_tick(delta, player, boss_pos, has_boss, enemies, anchors)
	_drain_events(res)


## 把原生权威 SoA pull 成 GDScript 只读快照。
func _pull_snapshot() -> void:
	_active_count = _accel.get_active_count()
	_positions = _accel.get_positions()
	_velocities = _accel.get_velocities()
	_color = _accel.get_colors()
	_type_index = _accel.get_type_indices()
	_faction = _accel.get_factions_bytes()
	_life_left = _accel.get_life_lefts()
	_fx_phase = _accel.get_fx_phases()
	_fx_type_index = _accel.get_fx_type_indices()
	_timer = _accel.get_timers()
	_render_rot = _accel.get_render_rots()


func _drain_events(res: Dictionary) -> void:
	var kinds: PackedInt32Array = res.kind
	if kinds.is_empty():
		return
	var local: PackedInt32Array = res.local
	var xs: PackedFloat32Array = res.x
	var ys: PackedFloat32Array = res.y
	var dxs: PackedFloat32Array = res.dx
	var dys: PackedFloat32Array = res.dy
	var event_colors: PackedColorArray = res.get("color", PackedColorArray())
	for k in kinds.size():
		match kinds[k]:
			3:
				var tint: Color = event_colors[k] if k < event_colors.size() else Color.WHITE
				play_clear_fx(Vector2(xs[k], ys[k]), tint)
			5:
				var tpl: EmitTemplate = emit_templates.get_by_numeric(local[k])
				if tpl == null:
					push_error("[KernelNativeSystem] 未注册 EmitTemplate numeric_id=%d" % local[k])
				elif emit_spawner.is_valid():
					emit_spawner.call(tpl, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]), event_colors[k] if k < event_colors.size() else Color.WHITE)
				else:
					push_error("[KernelNativeSystem] emit_spawner 未注入")
			6:
				var sfx_id := local[k]
				if sfx_id >= 0 and sfx_id < behavior_sfx.size():
					AudioManager.play_sfx(behavior_sfx[sfx_id], 1.0, AudioManager.BULLET_SFX_MIN_INTERVAL)
				else:
					push_error("[KernelNativeSystem] 未注册 behavior sfx id=%d" % sfx_id)
			7:
				var lt: LaserTemplate = laser_templates.get(local[k])
				if lt == null:
					push_error("[KernelNativeSystem] 未注册 LaserTemplate id=%d" % local[k])
				elif laser_spawner.is_valid():
					laser_spawner.call(lt, Vector2(xs[k], ys[k]), Vector2(dxs[k], dys[k]))
				else:
					push_error("[KernelNativeSystem] laser_spawner 未注入")

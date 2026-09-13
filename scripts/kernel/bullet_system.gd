## 弹幕数据黑板：SoA 对象池（pos/vel 用 PackedVector2Array，标量字段各自独立 array）。S9
## 每颗弹是池里一"行"（不是 Node）→ 几千发零逐弹分配；本节点无 transform，只用全局坐标。
## 生命周期契约（必守）：spawn 先 _reset_row 整行归零 | 回收用 _copy_row 把尾行整行搬进空槽
## （新增 per-bullet 字段 = 这两处各加一行）；spawn/despawn 禁止在行为/碰撞遍历中途发生。
class_name BulletSystem
extends Node

## 行为槽：0 = 无（直线）；非 0 由 BehaviorProcessor 解析。
const BEHAVIOR_NONE: int = 0

## 宽相 uniform grid：桶边长（像素）。网格只在碰撞查询前按需重建（读多写少）。
const BROADPHASE_CELL: float = 64.0
## 低于此弹数不值得开宽相（线性扫描更省）。
const BROADPHASE_MIN_COUNT: int = 64
## 网格单元数上限；超了退回线性（防坐标异常时爆内存）。
const BROADPHASE_MAX_CELLS: int = 8192

@export_group("Pool")
## 初始容量，按需翻倍。
@export var initial_capacity: int = 1024
## 默认最长存活秒数，防泄漏；<=0 = 由行为/超时决定。
@export var default_lifetime: float = 20.0

@export_group("World bounds (cull)")
## 世界坐标失效区：超出即回收；空 = 不剔除（可只靠 lifetime）。
@export var cull_rect: Rect2
## 剔除余量：须走出 cull_rect + margin 才回收，防贴边消失。
@export var cull_margin: float = 32.0

# ==== 池字段（SoA：每弹一行） ====
# 活跃弹占 [0, _active_count)；标量字段各自独立 array，不混进 Vector2。
var _active_count: int = 0
var _positions := PackedVector2Array()
var _velocities := PackedVector2Array()
var _hitbox_radius := PackedFloat32Array()		# 受击判定半径
var _hitbox_offset := PackedVector2Array()		# 判定中心偏移（本地坐标，随弹朝向旋转）
var _hitbox_size := PackedVector2Array()		# 矩形判定尺寸（零 = 圆判定）
var _has_offset: bool = false					# 是否出现过非零偏移（查询走偏移路径的门）
var _has_rect: bool = false						# 是否出现过矩形判定（同上）
var _life_left := PackedFloat32Array()			# 剩余秒；-1 表示永存
var _color := PackedColorArray()				# 渲染颜色
var _type_index := PackedInt32Array()			# 索引到 _type_registry
var _faction := PackedByteArray()				# 该行阵营（渲染按阵营分批用）
var _frame := PackedInt32Array()				# 多帧弹型：该行当前帧（0 = 首帧）
var _type_registry: Array[BulletType] = []		# 已注册弹型表
# --- 特效（一等公民，与弹型分离）---
var _fx_type_registry: Array[EffectType] = []	# 已注册特效表
var _fx_type_index := PackedInt32Array()		# 每行 -> _fx_type_registry 下标（-1 = 无特效）
var _spawn_fx: Dictionary = {}					# 阵营 -> 出生特效（EffectType）；未设 = 无
var _render_fade: Dictionary = {}				# BulletType.Kind -> 整批淡出 0..1；缺省 1.0（不淡）
# --- 行为状态 + 通用计时（同受 _copy_row/_reset_row 管理）---
var _behavior_id := PackedInt32Array()			# 行为槽（0=无）
var _behavior_phase := PackedInt32Array()		# 行为阶段（状态机）
var _timer := PackedFloat32Array()				# 通用倒计时；到 0 由使用者判定，不自动回收
var _despawn_req := PackedInt32Array()			# 待回收标记；由 BehaviorProcessor 遍历后统一 despawn
var _behavior_params: Array = []				# 发射时参数：同波共享同一对象 → 只读（debug 冻结）
var _behavior_state: Array = []					# 行为私有状态：每弹一份，懒建 → 可写
var _grazed := PackedByteArray()				# 已擦弹标记（防重复计数）
var _fx_phase := PackedFloat32Array()			# 特效相位剩余秒（0=已出生）；>0 时不动/不可命中/不跑行为
# --- 移动名表：对外 StringName，池内存 int 槽 ---
var _move_names: Array[StringName] = [&""]		# 槽 -> 名字（0 = 无）
var _move_slot: Dictionary[StringName, int] = {}# 名字 -> 槽

## 确定性 RNG：同 seed 同弹幕（S10）。
var _random := RandomNumberGenerator.new()

## 最近一次物理帧 delta（秒），dt 型行为经 get_delta() 取。
var _last_delta: float = 0.0

# --- 宽相 uniform grid（桶 = 链在 _grid_head 上的行 id；只在查询时按需重建）---
var _grid_dirty: bool = true			# 行集合/位置变过 → 下次查询前重挂
var _grid_active: bool = false			# 网格是否可用（false = 走线性回退）
var _grid_origin := Vector2.ZERO		# 网格原点（世界坐标）
var _grid_gx: int = 0					# x 方向格子数
var _grid_gy: int = 0					# y 方向格子数
var _grid_max_bound: float = 0.0		# 本帧最大"弹触达"（判定半径 / 矩形半对角+偏移）→ 查询外扩用
var _grid_head := PackedInt32Array()	# cell -> 首个行 id（-1 = 空）
var _grid_prev := PackedInt32Array()	# 行 id -> 同桶前驱（-1 = 无）
var _grid_next := PackedInt32Array()	# 行 id -> 同桶后继（-1 = 无）
var _grid_cell_of := PackedInt32Array()	# 行 id -> cell（-1 = 未挂）
var _type_bound := PackedFloat32Array()	# 弹型下标 -> 触达半径（缓存，避免每帧开方）


# ==== ⓪ 节点装配 ====
# KERNEL-VENDOR(S0)：已删除 BulletRenderer 注入（上游的 _ready / setup_renderers）。
# 内核本体不引用宿主渲染器类型（R2/R9）；原项目渲染由 adapter 负责——S2 把本池快照喂给 BulletMultiMesh。


# ==== ① 生命周期：唯一的"整行搬运/归零"点 ====

func _init() -> void:
	_ensure_capacity(initial_capacity)

func _ensure_capacity(capacity: int) -> void:
	if _positions.size() >= capacity:
		return
	var new_capacity: int = max(capacity, _positions.size() * 2)
	new_capacity = max(new_capacity, 16)
	_positions.resize(new_capacity)
	_velocities.resize(new_capacity)
	_hitbox_radius.resize(new_capacity)
	_hitbox_offset.resize(new_capacity)
	_hitbox_size.resize(new_capacity)
	_life_left.resize(new_capacity)
	_color.resize(new_capacity)
	_type_index.resize(new_capacity)
	_faction.resize(new_capacity)
	_frame.resize(new_capacity)
	_behavior_id.resize(new_capacity)
	_behavior_phase.resize(new_capacity)
	_timer.resize(new_capacity)
	_behavior_params.resize(new_capacity)
	_behavior_state.resize(new_capacity)
	_grazed.resize(new_capacity)
	_fx_phase.resize(new_capacity)
	_fx_type_index.resize(new_capacity)
	_grid_prev.resize(new_capacity)
	_grid_next.resize(new_capacity)
	_grid_cell_of.resize(new_capacity)

## 整行拷贝（swap-with-last 回收用）；漏搬一个字段就串档。
func _copy_row(dst: int, src: int) -> void:
	_positions[dst] = _positions[src]
	_velocities[dst] = _velocities[src]
	_hitbox_radius[dst] = _hitbox_radius[src]
	_hitbox_offset[dst] = _hitbox_offset[src]
	_hitbox_size[dst] = _hitbox_size[src]
	_life_left[dst] = _life_left[src]
	_color[dst] = _color[src]
	_type_index[dst] = _type_index[src]
	_faction[dst] = _faction[src]
	_frame[dst] = _frame[src]
	_behavior_id[dst] = _behavior_id[src]
	_behavior_phase[dst] = _behavior_phase[src]
	_timer[dst] = _timer[src]
	_behavior_params[dst] = _behavior_params[src]
	_behavior_state[dst] = _behavior_state[src]
	_grazed[dst] = _grazed[src]
	_fx_phase[dst] = _fx_phase[src]
	_fx_type_index[dst] = _fx_type_index[src]

## 整行归零，spawn 前调用（无残留）。
func _reset_row(id: int) -> void:
	_positions[id] = Vector2.ZERO
	_velocities[id] = Vector2.ZERO
	_hitbox_radius[id] = 0.0
	_hitbox_offset[id] = Vector2.ZERO
	_hitbox_size[id] = Vector2.ZERO
	_life_left[id] = default_lifetime
	_color[id] = Color.WHITE
	_type_index[id] = -1
	_faction[id] = BulletType.Faction.NONE
	_frame[id] = 0
	_behavior_id[id] = BEHAVIOR_NONE
	_behavior_phase[id] = 0
	_timer[id] = 0.0
	_behavior_params[id] = null
	_behavior_state[id] = null
	_grazed[id] = 0
	_fx_phase[id] = 0.0
	_fx_type_index[id] = -1

# ==== ② 发射与回收 ====

## 弹型懒注册（find or append），返回索引。
func _type_registry_index_of(bullet_type: BulletType) -> int:
	var registry_index := _type_registry.find(bullet_type)
	if registry_index == -1:
		registry_index = _type_registry.size()
		_type_registry.append(bullet_type)
		_type_bound.append(_bound_of(bullet_type))
	return registry_index


## 弹型"触达"半径：判定圆半径；矩形 = 半对角 + 判定偏移（偏移越长，弹心离判定中心越远）。
static func _bound_of(bt: BulletType) -> float:
	if bt.hitbox_size != Vector2.ZERO:
		return bt.hitbox_size.length() * 0.5 + bt.hitbox_offset.length()
	return bt.hitbox_radius


## 特效懒注册（find or append），返回索引。
func _fx_registry_index_of(effect: EffectType) -> int:
	var idx := _fx_type_registry.find(effect)
	if idx == -1:
		idx = _fx_type_registry.size()
		_fx_type_registry.append(effect)
	return idx


## 注册某阵营的"出生特效"（发弹特效）。同一份 EffectType → 该阵营所有弹共用（改一处全变）。
## 不注册 = 该阵营弹出生即可动/可命中（自机弹现状）。
func set_spawn_fx(faction: BulletType.Faction, effect: EffectType) -> void:
	_spawn_fx[faction] = effect


## 给某行挂出生特效；effect 为空或时长为 0 → 清掉（出生即真弹）。
func _set_row_fx(id: int, effect: EffectType) -> void:
	if effect != null and effect.duration > 0.0:
		_fx_type_index[id] = _fx_registry_index_of(effect)
		_fx_phase[id] = effect.duration
	else:
		_fx_type_index[id] = -1
		_fx_phase[id] = 0.0


# --- 生命周期契约的唯一落点：新增字段在此两处各加一行 ---

## debug 下冻结发射时参数：误写立刻报错而非静默污染全波（冻结是浅的，参数表用扁平字典）。
func _freeze_params(params: Variant) -> Variant:
	if OS.is_debug_build() and params is Dictionary and not params.is_read_only():
		params.make_read_only()
	return params

## 发射一颗弹，返回 id（在 [0, 活跃数)）。
func spawn(bullet_data: BulletType, position: Vector2, velocity: Vector2, color: Color = Color.WHITE, move: StringName = &"", behavior_params: Variant = null) -> int:
	_active_count += 1
	_ensure_capacity(_active_count)
	var bullet_id: int = _active_count - 1
	_reset_row(bullet_id)   # 先归零，杜绝残留
	_positions[bullet_id] = position
	_velocities[bullet_id] = velocity
	_hitbox_radius[bullet_id] = bullet_data.hitbox_radius
	_hitbox_offset[bullet_id] = bullet_data.hitbox_offset
	_hitbox_size[bullet_id] = bullet_data.hitbox_size
	if bullet_data.hitbox_offset != Vector2.ZERO:
		_has_offset = true
	if bullet_data.hitbox_size != Vector2.ZERO:
		_has_rect = true
	_color[bullet_id] = color
	_type_index[bullet_id] = _type_registry_index_of(bullet_data)
	_faction[bullet_id] = bullet_data.faction
	_behavior_id[bullet_id] = intern_move(move)   # 名字 intern 成槽
	_behavior_params[bullet_id] = _freeze_params(behavior_params)   # 共享只读（debug 冻结）
	# 出生特效：按阵营默认（发弹特效）；没配 = 出生即可动/可命中
	_set_row_fx(bullet_id, _spawn_fx.get(bullet_data.faction))
	# 网格有效（碰撞派发中途 spawn）→ 增量挂格；否则标脏，下次查询重建。
	if _grid_active:
		_grid_insert(bullet_id)
	else:
		_grid_dirty = true
	return bullet_id

## 回收一颗弹（swap-with-last，O(1)）。
## 网格有效时同步增删：swap 会改 id，必须把"被覆盖行"与"尾行"都摘掉、再按新 id 挂回。
func despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	var tail: int = _active_count - 1
	if _grid_active:
		_grid_remove(id)
		if id != tail:
			_grid_remove(tail)
	else:
		_grid_dirty = true
	if id != tail:
		_copy_row(id, tail)           # 尾行整行搬进空槽
		if _grid_active:
			_grid_insert(id)
	_active_count -= 1

## 清空全部（换关/重开）。
func clear() -> void:
	_active_count = 0
	_despawn_req = PackedInt32Array()
	_has_offset = false   # 整池清空：门复位（之后首次特殊判定发射会再置起）
	_has_rect = false
	_grid_active = false   # 网格作废（下次查询重建）
	_grid_dirty = true

# ==== ②b 消弹（炸弹/清场）与纯特效行 ====


## 播一条"纯特效行"：无速度、无碰撞、无弹型，寿命 = effect.duration（到期自动回收）。color 是染色 tint。
## faction 决定它归哪一批渲染（默认 ENEMY：消弹特效多为敌弹）；行没有弹型，阵营只能由调用方给。
func spawn_fx(effect: EffectType, position: Vector2, color: Color = Color.WHITE, faction: BulletType.Faction = BulletType.Faction.ENEMY) -> int:
	_active_count += 1
	_ensure_capacity(_active_count)
	var id: int = _active_count - 1
	_reset_row(id)                 # 整行归零
	_positions[id] = position
	_color[id] = color
	_type_index[id] = -1           # 纯特效：不属于任何弹型
	_faction[id] = faction
	_set_row_fx(id, effect)
	_life_left[id] = effect.duration if effect != null else 0.0
	if _grid_active:
		_grid_insert(id)
	else:
		_grid_dirty = true
	return id


## 消弹（炸弹/清场）：回收 center 半径内指定阵营的弹，含相位中还没出生的弹。
## effect 非空则原地补消散特效（颜色继承该弹）；on_clear 逐弹回调（掉道具/计数用）。
## 纯特效行（type_index < 0）不参与清场，所以不会被炸弹"再消一次"。
func cancel_bullets(center: Vector2, radius: float, effect: EffectType = null, faction: BulletType.Faction = BulletType.Faction.ENEMY, on_clear: Callable = Callable()) -> int:
	var count: int = _active_count
	if count == 0:
		return 0
	var r2: float = radius * radius
	# 池索引会因 swap-with-last 变动，先记位置/颜色再统一回收（颜色给消散特效当 tint）。
	var spots := PackedVector2Array()
	var spot_colors := PackedColorArray()
	# 倒序遍历：despawn 把尾行换进槽 i，换进来的一定是已检查过的高位行。
	for i in range(count - 1, -1, -1):
		if _type_index[i] < 0:
			continue   # 纯特效行：不是弹
		if _type_registry[_type_index[i]].faction != faction:
			continue   # 阵营不符：不动
		# 用弹位置（不是判定中心）：消弹是"范围清场"，特效也落在弹位置上
		var offset: Vector2 = _positions[i] - center
		if offset.length_squared() <= r2:
			spots.append(_positions[i])   # 先记再回收
			spot_colors.append(_color[i])
			despawn(i)
	if on_clear.is_valid():
		for k in spots.size():
			on_clear.call(spots[k])
	# 特效行最后追加：回收中追加会打乱倒序前提
	if effect != null and effect.duration > 0.0:
		for k in spots.size():
			spawn_fx(effect, spots[k], spot_colors[k], faction)
	return spots.size()

func _physics_process(delta: float) -> void:
	_last_delta = delta   # 记下本帧时长（get_delta）
	if _active_count == 0:
		return
	# 本帧位置全部会变（积分 + 行为 set_position）→ 碰撞查询前重建网格
	_grid_active = false
	_grid_dirty = true

	# 空 cull_rect 会把任何点判为界外（弹"只闪不动"的根因），所以先查 has_area()
	var should_cull: bool = cull_rect.has_area()
	# 倒序遍历：despawn 是 swap-with-last，前向遍历会漏判被换进来的弹（密度微顿挫）。
	for i in range(_active_count - 1, -1, -1):
		# 生命倒计时先做：纯特效行靠它到期回收
		if _life_left[i] >= 0.0:
			_life_left[i] -= delta
			if _life_left[i] <= 0.0:
				despawn(i)
				continue
		# 特效相位：相位内跳过积分/剔除；相位在本帧结束则本帧即开始动（不丢一帧）。
		if _fx_phase[i] > 0.0:
			_fx_phase[i] -= delta
			if _fx_phase[i] > 0.0:
				continue
			_fx_phase[i] = 0.0
		# 位置积分
		var position := _positions[i]
		position += _velocities[i] * delta
		_positions[i] = position
		# 通用计时递减（>0 才减；到 0 不自动回收）
		if _timer[i] > 0.0:
			_timer[i] -= delta
		# 越界剔除：须走出 cull_rect + margin
		if should_cull and not cull_rect.grow(cull_margin).has_point(_positions[i]):
			despawn(i)

# ==== ④ 查询 ====

## 该弹的判定中心（语义在 BulletType.hit_center_for，调试工具共用同一份）。
## 命中判定的唯一入口：query_circle 与自机精判都必须用它，否则画面与判定会错位。
func get_hit_center(id: int) -> Vector2:
	var t: BulletType = get_type(id)
	if t == null:
		return _positions[id]
	return t.hit_center_for(_positions[id], _velocities[id])


## 窄相位：圆(center, radius) 是否真的命中这颗弹（含判定偏移与矩形判定）。
## 自机精判走它，别自己重算几何——否则偏移/矩形弹会与查询结果不一致。
func hit_test(id: int, center: Vector2, radius: float) -> bool:
	if _fx_phase[id] > 0.0:
		return false   # 相位中的弹还没"出生"（与 query_circle 同规则）
	var t: BulletType = get_type(id)
	if t == null:
		return false   # 纯特效行不可命中
	var hit_size: Vector2 = _hitbox_size[id]
	var hit_position: Vector2 = get_hit_center(id)
	if hit_size == Vector2.ZERO:
		return HitGeometry.circle_hits_circle(center, radius, hit_position, _hitbox_radius[id])
	var rot: float = t.rotation_for(_velocities[id])
	return HitGeometry.circle_hits_rect(center, radius, hit_position, rot, hit_size)


## 窄相位判定（query 用）：圆(center, search_radius) 是否命中第 i 行（含 fx 相位跳过 / 偏移 / 矩形）。
## 网格与线性两条路径共用，避免两份几何分叉；hit_test 是它的自机精判同义实现。
func _narrow_hit(i: int, center: Vector2, search_radius: float) -> bool:
	if _fx_phase[i] > 0.0:
		return false   # 相位中的弹还没"出生"：不参与命中/擦弹（消弹走 cancel_bullets）
	var hit_position: Vector2 = _positions[i]
	var hit_offset: Vector2 = _hitbox_offset[i]
	var hit_size: Vector2 = _hitbox_size[i]
	if hit_offset != Vector2.ZERO or hit_size != Vector2.ZERO:
		var vel: Vector2 = _velocities[i]
		var t: BulletType = _type_registry[_type_index[i]]
		var rot: float = vel.angle() + t.dir_offset if t.follow_dir and vel != Vector2.ZERO else 0.0
		if hit_offset != Vector2.ZERO:
			hit_position += hit_offset.rotated(rot)
		if hit_size != Vector2.ZERO:
			# 矩形判定：忽略 hitbox_radius；几何唯一实现见 HitGeometry（只给矩形弹付这次调用）
			return HitGeometry.circle_hits_rect(center, search_radius, hit_position, rot, hit_size)
	var offset: Vector2 = hit_position - center
	var distance_squared: float = offset.dot(offset)
	var radius: float = search_radius + _hitbox_radius[i]
	return distance_squared <= radius * radius


## 返回与 center 半径 search_radius 相交的弹 id（真实半径 = search_radius + 弹触达）。
## 弹多时走宽相网格（查询前按需重建）：候选集 = 覆盖 [center ± (search_radius + 最大触达)] 的桶；
## 弹少 / 坐标退化 / 未重建时回退线性。两条路径共用 _narrow_hit（几何唯一）。
func query_circle(center: Vector2, search_radius: float) -> PackedInt32Array:
	if _active_count == 0:
		return PackedInt32Array()
	_ensure_broadphase()
	if _grid_active:
		return _query_circle_grid(center, search_radius)
	if not _has_offset and not _has_rect:
		return _query_circle_plain(center, search_radius)
	var result := PackedInt32Array()
	for i in _active_count:
		if _narrow_hit(i, center, search_radius):
			result.append(i)
	return result


## 网格候选查询：只遍历与查询 AABB 相交的桶，桶内再走 _narrow_hit。
func _query_circle_grid(center: Vector2, search_radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var reach: float = search_radius + _grid_max_bound
	var gx: int = _grid_gx
	var gy: int = _grid_gy
	var ox: float = _grid_origin.x
	var oy: float = _grid_origin.y
	var x0: int = clampi(floori((center.x - reach - ox) / BROADPHASE_CELL), 0, gx - 1)
	var x1: int = clampi(floori((center.x + reach - ox) / BROADPHASE_CELL), 0, gx - 1)
	var y0: int = clampi(floori((center.y - reach - oy) / BROADPHASE_CELL), 0, gy - 1)
	var y1: int = clampi(floori((center.y + reach - oy) / BROADPHASE_CELL), 0, gy - 1)
	var heads := _grid_head
	var nexts := _grid_next
	for cy in range(y0, y1 + 1):
		var row_base: int = cy * gx
		for cx in range(x0, x1 + 1):
			var i: int = heads[row_base + cx]
			while i >= 0:
				if _narrow_hit(i, center, search_radius):
					result.append(i)
				i = nexts[i]
	return result


## 无偏移快路径：判定中心 = 弹位置。几何与 query_circle 相同，改一处必须同步另一处。
func _query_circle_plain(center: Vector2, search_radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i in _active_count:
		if _fx_phase[i] > 0.0:
			continue
		var offset: Vector2 = _positions[i] - center
		var distance_squared: float = offset.dot(offset)
		var radius: float = search_radius + _hitbox_radius[i]
		if distance_squared <= radius * radius:
			result.append(i)
	return result


# ==== ④b 宽相网格（uniform grid + 行链表桶）====

## 行集合 / 位置变过才重建；一次重建供本帧所有查询复用（碰撞前首个查询触发）。
func _ensure_broadphase() -> void:
	if not _grid_dirty:
		return
	_grid_dirty = false
	_rebuild_broadphase()


## 重建网格：定位（cull_rect 有界 → 固定网格；否则按活跃弹包围盒）+ 桶链表 + 最大触达。
## 弹少 / 格子过多 → 关闭网格（线性回退）。
func _rebuild_broadphase() -> void:
	_grid_active = false
	var count: int = _active_count
	if count < BROADPHASE_MIN_COUNT:
		return
	var gx: int
	var gy: int
	var origin: Vector2
	if cull_rect.has_area():
		origin = cull_rect.position
		gx = maxi(1, ceili(cull_rect.size.x / BROADPHASE_CELL) + 1)
		gy = maxi(1, ceili(cull_rect.size.y / BROADPHASE_CELL) + 1)
	else:
		# 无边界（测试 / 纯逻辑）：按活跃弹包围盒临时定网格
		var minp := Vector2(INF, INF)
		var maxp := Vector2(-INF, -INF)
		for i in count:
			var p: Vector2 = _positions[i]
			minp.x = minf(minp.x, p.x); minp.y = minf(minp.y, p.y)
			maxp.x = maxf(maxp.x, p.x); maxp.y = maxf(maxp.y, p.y)
		origin = minp
		gx = maxi(1, floori((maxp.x - minp.x) / BROADPHASE_CELL) + 1)
		gy = maxi(1, floori((maxp.y - minp.y) / BROADPHASE_CELL) + 1)
	if gx * gy > BROADPHASE_MAX_CELLS:
		return   # 坐标异常：退回线性，别爆内存
	_grid_origin = origin
	_grid_gx = gx
	_grid_gy = gy
	_grid_head.resize(gx * gy)
	_grid_head.fill(-1)
	var max_bound: float = 0.0
	for i in count:
		var ti: int = _type_index[i]
		if ti >= 0:
			max_bound = maxf(max_bound, _type_bound[ti])
		var ci: int = _cell_index(i)
		_grid_cell_of[i] = ci
		_grid_prev[i] = -1
		_grid_next[i] = _grid_head[ci]
		if _grid_head[ci] >= 0:
			_grid_prev[_grid_head[ci]] = i
		_grid_head[ci] = i
	_grid_max_bound = max_bound
	_grid_active = true


## 行 → 网格单元（超界钳到边缘格：贴边 / 瞬间出界的弹也找得到）。
func _cell_index(i: int) -> int:
	var p: Vector2 = _positions[i]
	var cx: int = clampi(floori((p.x - _grid_origin.x) / BROADPHASE_CELL), 0, _grid_gx - 1)
	var cy: int = clampi(floori((p.y - _grid_origin.y) / BROADPHASE_CELL), 0, _grid_gy - 1)
	return cy * _grid_gx + cx


## 把行挂进当前网格（spawn / swap 搬位后用）；网格未启用则忽略。
func _grid_insert(id: int) -> void:
	if not _grid_active:
		return
	var ci: int = _cell_index(id)
	_grid_cell_of[id] = ci
	_grid_prev[id] = -1
	_grid_next[id] = _grid_head[ci]
	if _grid_head[ci] >= 0:
		_grid_prev[_grid_head[ci]] = id
	_grid_head[ci] = id


## 把行从网格摘下（despawn / 搬位前用）；未挂则忽略。
func _grid_remove(id: int) -> void:
	if not _grid_active:
		return
	var ci: int = _grid_cell_of[id]
	if ci < 0:
		return
	var p: int = _grid_prev[id]
	var n: int = _grid_next[id]
	if p >= 0:
		_grid_next[p] = n
	else:
		_grid_head[ci] = n
	if n >= 0:
		_grid_prev[n] = p
	_grid_cell_of[id] = -1


# ==== ⑤ 读访问器（核心字段） ====

func get_active_count() -> int:
	return _active_count

func get_capacity() -> int:
	return _positions.size()

func get_position(id: int) -> Vector2:
	return _positions[id]

func get_velocity(id: int) -> Vector2:
	return _velocities[id]

func get_hitbox_radius(id: int) -> float:
	return _hitbox_radius[id]

func get_life_left(id: int) -> float:
	return _life_left[id]

func get_color(id: int) -> Color:
	return _color[id]

## 该行的弹型；纯特效行没有弹型 → null。
func get_type(id: int) -> BulletType:
	return _type_registry[_type_index[id]] if _type_index[id] >= 0 else null

## 多帧弹型：该弹当前帧。
func get_frame(id: int) -> int:
	return _frame[id]


## 特效相位剩余秒（0 = 已出生）；>0 = 还在发弹特效里，尚未成为真弹幕。
func get_fx_phase(id: int) -> float:
	return _fx_phase[id]


## 最近一次物理帧 delta（秒），dt 型行为经 get_delta() 取。
func get_delta() -> float:
	return _last_delta

# ==== ⑥ 写访问器 + 擦弹标记 ====

func set_velocity(id: int, value: Vector2) -> void:
	_velocities[id] = value


## 直接设定世界位置：**锚定型行为专用**（如激光段跟随发射口）。
## 普通行为请用 set_velocity 交系统积分，别用这个绕过物理。
func set_position(id: int, value: Vector2) -> void:
	_positions[id] = value
	_grid_active = false   # 位置在积分之外变了 → 网格作废（下次查询重建）
	_grid_dirty = true


## 多帧弹型：设该弹当前帧（0 = 首帧）。发射后由发射方按序轮换。
func set_frame(id: int, value: int) -> void:
	_frame[id] = value

## 是否已擦过（擦弹只计一次，防每帧重复）。
func is_grazed(id: int) -> bool:
	return _grazed[id] != 0

func mark_grazed(id: int) -> void:
	_grazed[id] = 1

# ==== ⑦ 行为接口（槽/阶段/计时/参数/状态/待回收队列） ====

func get_behavior_id(id: int) -> int:
	return _behavior_id[id]

func get_behavior_phase(id: int) -> int:
	return _behavior_phase[id]

func set_behavior_phase(id: int, value: int) -> void:
	_behavior_phase[id] = value

## 通用倒计时（秒）：>0 后系统每帧递减，到 0 由使用者判定。
func get_timer(id: int) -> float:
	return _timer[id]

func set_timer(id: int, value: float) -> void:
	_timer[id] = value

## 发射时参数（只读）：同波共享同一对象；写它会污染全波（debug 下报错）。
func get_behavior_params(id: int) -> Variant:
	return _behavior_params[id]

## 本弹私有状态（可写）：默认 null，行为自建；每弹一份，随行走。
func get_behavior_state(id: int) -> Variant:
	return _behavior_state[id]

func set_behavior_state(id: int, value: Variant) -> void:
	_behavior_state[id] = value


# NOTE: "每弹冷数据伴生裸 Object"试过、已撤——当前每弹字段全是热字段，落在这里纯亏（见 log）。

## 标记待回收（不在遍历中途 despawn；由处理器遍历后统一执行）。
func request_despawn(id: int) -> void:
	if id < 0 or id >= _active_count:
		return
	if not _despawn_req.has(id):
		_despawn_req.append(id)

## 取走并清空待回收队列。
func take_despawn_requests() -> PackedInt32Array:
	var q: PackedInt32Array = _despawn_req
	_despawn_req = PackedInt32Array()
	return q

# ==== ⑧ 移动名表（名字 ↔ 槽，对外名字、对内 int） ====

## 名字 intern 成槽（首次分配）；&"" → 0。对外名字、池内槽。
func intern_move(move_name: StringName) -> int:
	if move_name == &"":
		return BEHAVIOR_NONE
	var s: int = _move_slot.get(move_name, -1)
	if s >= 0:
		return s
	s = _move_names.size()
	_move_names.append(move_name)
	_move_slot[move_name] = s
	return s

## 已 intern 的槽数量（含槽 0）。BehaviorProcessor 据此判断缓存过期。
func get_move_slot_count() -> int:
	return _move_names.size()

## 槽 → 名字（0 或越界 → &""）。
func get_move_name(slot: int) -> StringName:
	return _move_names[slot] if slot >= 0 and slot < _move_names.size() else &""

# ==== ⑨ 渲染快照（只读，仅 BulletRenderer 用） ====

## ATTENTION: 返回池内部数组（CoW 共享、读零拷贝）。每帧现取，禁止跨帧缓存（系统写会触发整块拷贝）。
func get_positions() -> PackedVector2Array:
	return _positions

func get_velocities() -> PackedVector2Array:
	return _velocities


func get_colors() -> PackedColorArray:
	return _color

func get_type_indices() -> PackedInt32Array:
	return _type_index


## 每行当前帧（多帧弹型用）。
func get_frames() -> PackedInt32Array:
	return _frame

## 每行阵营（渲染按阵营分批：自机弹 / 敌弹各一批）。
func get_factions() -> PackedByteArray:
	return _faction

## 已注册弹型表（只读）；数量变化时渲染器重建缓存。
## 特效相位快照（同其它快照：每帧现取，禁止缓存）。
func get_fx_phases() -> PackedFloat32Array:
	return _fx_phase

## 每行的特效档下标（-1 = 无）；渲染器据此取特效缓存。
func get_fx_type_indices() -> PackedInt32Array:
	return _fx_type_index

## 已注册特效表（只读）；数量变化时渲染器重建特效缓存。
func get_fx_type_registry() -> Array[EffectType]:
	return _fx_type_registry


func get_type_registry() -> Array[BulletType]:
	return _type_registry


## 按弹型类别（BulletType.Kind）设整批渲染淡出（0..1）：激光段释放后由 LaserShot 逐帧写入。
func set_render_fade(kind: int, value: float) -> void:
	_render_fade[kind] = clampf(value, 0.0, 1.0)


## 取某类别的整批淡出值；未设 = 1.0（不淡）。
func get_render_fade(kind: int) -> float:
	return _render_fade.get(kind, 1.0)

# ==== ⑩ 确定性 RNG（S10） ====

func set_seed(seed_value: int) -> void:
	_random.seed = seed_value

func randf() -> float:
	return _random.randf()

func randf_range(from: float, to: float) -> float:
	return _random.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _random.randi_range(from, to)

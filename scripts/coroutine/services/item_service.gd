class_name ItemService
extends RefCounted
## 道具服务

## 弱引用 ctx：避免 StageContext ↔ ItemService 形成 RefCounted 环导致关卡退出后泄漏
var _ctx_ref: WeakRef
var ctx: StageContext:
	get:
		return _ctx_ref.get_ref() as StageContext if _ctx_ref else null
	set(value):
		_ctx_ref = weakref(value) if value else null

func spawn(type: int, position: Vector2) -> void:
	if not ctx or not ctx.active():
		return
	var pool: ItemPool = ctx.stage.item_pool if ctx.stage else null
	if pool:
		pool.spawn(position, type)


## 扇形爆发投点：把 `targets`（一般在自机处）一次撒出，每个点用 `hang` 秒**直线飞到目标**，
## 随后径向初速归零 → 竖直下落。目标点由 `fan_targets()` 算（含左右边界夹取）。
## 典型用法：miss 时 `spawn_fan(POWER, 自机, ItemService.fan_targets(…), hang)` → 向上半圆扇形。
func spawn_fan(type: int, origin: Vector2, targets: Array[Vector2], hang: float) -> void:
	if not ctx or not ctx.active():
		return
	var pool: ItemPool = ctx.stage.item_pool if ctx.stage else null
	spawn_fan_in_pool(pool, type, origin, targets, hang)


## `spawn_fan` 的实体部分（不依赖 ctx，便于直接喂池测试）——返回真正撒出的个数。
static func spawn_fan_in_pool(pool: ItemPool, type: int, origin: Vector2,
		targets: Array[Vector2], hang: float) -> int:
	if pool == null:
		return 0
	var spawned := 0
	for target in targets:
		var item: Item = pool.spawn(origin, type)
		if item:
			var offset: Vector2 = target - origin
			item.burst(offset.normalized(), offset.length() / maxf(hang, 0.001), hang)
			spawned += 1
	return spawned


## 扇形**目标点**（弧向飞行的终点，纯函数、便于测试）：`count` 个点排在以 `origin` 为心、
## `radius` 为半径、以 `center_dir` 为中轴、张角 `spread_deg` 的**均匀圆弧**上（含两端点）；
## 再把横坐标**夹进 [x_min, x_max]** —— 贴左右墙时靠墙一侧横向压扁（**纵向半径不变**），
## 于是这 10 个点（以及随后从它们竖直下落的轨迹）都不会跑出场地框。
static func fan_targets(count: int, origin: Vector2, center_dir: Vector2, spread_deg: float,
		radius: float, x_min: float, x_max: float) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	for dir in fan_directions(count, center_dir, spread_deg):
		var target: Vector2 = origin + dir * radius
		target.x = clampf(target.x, x_min, x_max)
		targets.append(target)
	return targets


## 均匀圆弧方向（纯函数，便于测试）：`count` 个**单位向量**，以 `center_dir` 为中轴、总张角
## `spread_deg`，**含两端点**（故相邻夹角 = spread/(count-1)，10 个 / 180° → 每档 20°）。
## 例：`fan_directions(10, Vector2.UP, 180)` = 从正左 → 正上 → 正右（向上半圆）。
static func fan_directions(count: int, center_dir: Vector2, spread_deg: float) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	if count <= 0 or center_dir == Vector2.ZERO:
		return dirs
	if count == 1:
		dirs.append(center_dir.normalized())
		return dirs
	var half := deg_to_rad(spread_deg) * 0.5
	var base := center_dir.angle()
	for i in range(count):
		var t := float(i) / float(count - 1)
		dirs.append(Vector2.from_angle(base - half + 2.0 * half * t))
	return dirs

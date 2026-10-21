## LifecycleCatalog —— F10c 后只剩遗留 [code]kernel_port[/code] 的 lifecycle 入口。
##
## 旧 [code]move + params[/code]（bounce / homing / radial_accel …）的 9 个 preset 组合已删除：
## 内容直接写 [code]BulletLifecycle[/code] 原语，或工作台拼装器生成后再写成代码。
## 这里保留 [code]{lifecycle: BulletLifecycle}[/code] 是因为 [code]KernelBulletHost[/code] / 旧测试仍走
## [code]kernel_port()[/code] 的 lifecycle 字段；不要再往这里加组合分支。
class_name LifecycleCatalog
extends RefCounted

const MOVE_LIFECYCLE := &"lifecycle"


## 只认 lifecycle 入口；旧 move 名一律返回 null（由 KernelBulletHost 报 unmapped）。
static func build(move: StringName, params: Dictionary) -> BulletLifecycle:
	if move == MOVE_LIFECYCLE:
		return params.get(&"lifecycle", null) as BulletLifecycle
	return null


## 签名：同 lifecycle（或同 old move+params）只编译一次。
static func signature(move: StringName, params: Dictionary) -> int:
	if move == MOVE_LIFECYCLE:
		var lc: BulletLifecycle = params.get(&"lifecycle", null)
		var lc_sig: int = lc.content_signature() if lc != null else 0
		return hash(move) * 31 + lc_sig * 7 + hash(params.get(&"anchor"))
	return hash(move) * 31 + hash(params) * 7


## 缓存键：在 int 签名上再混入 phase_count / slots。
## signature() 本身是 hash，碰撞时只凭它命中就会静默复用错误 layout；形状参与键 + 命中校验是兜底。
## 返回 int 是为了热路径（每发 spawn 都会查）不做 String 分配。
static func cache_key(move: StringName, params: Dictionary) -> int:
	var sig := signature(move, params)
	if move == MOVE_LIFECYCLE:
		var lc: BulletLifecycle = params.get(&"lifecycle", null)
		if lc != null:
			return sig * 31 + lc.phases.size() * 8 + lc.slots
	return sig


static func _compatible(cached: Variant, incoming: Variant) -> bool:
	if cached == null or incoming == null:
		return cached == incoming
	var a := cached as BulletLifecycle
	var b := incoming as BulletLifecycle
	if a == null or b == null:
		return false
	return a.phases.size() == b.phases.size() and a.slots == b.slots


var _cache: Dictionary = {}


## 带缓存取 lifecycle（可返回 null 并缓存，避免重复 build）。
## 键碰撞（同 key 但 phase/slots 不同）时不返回旧值，改为 build 本次并修正缓存。
func get_lifecycle(move: StringName, params: Dictionary) -> BulletLifecycle:
	var key := cache_key(move, params)
	if _cache.has(key):
		var cached: Variant = _cache[key]
		if _compatible(cached, params.get(&"lifecycle")):
			return cached as BulletLifecycle
	var lc := build(move, params)
	_cache[key] = lc
	return lc


## 当前 lifecycle 缓存条目数（测试 / 诊断）。
func cache_size() -> int:
	return _cache.size()

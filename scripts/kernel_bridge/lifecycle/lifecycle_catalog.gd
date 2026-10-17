class_name LifecycleCatalog
extends RefCounted
## LifecycleCatalog —— F10c 后只剩**遗留 `kernel_port` 的 lifecycle 入口**。
##
## 旧 `move + params`（bounce / homing / radial_accel …）的 9 个 preset 组合已删除：
## 内容直接写 `BulletLifecycle` 原语，或工作台拼装器生成后再写成代码。
## 这里保留 `{lifecycle: BulletLifecycle}` 是因为 `KernelBulletHost` / 旧测试仍走
## `kernel_port()` 的 lifecycle 字段；不要再往这里加组合分支。

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


var _cache: Dictionary = {}


## 带缓存取 lifecycle（可返回 null 并缓存，避免重复 build）。
func get_lifecycle(move: StringName, params: Dictionary) -> BulletLifecycle:
	var sig := signature(move, params)
	if _cache.has(sig):
		return _cache[sig]
	var lc := build(move, params)
	_cache[sig] = lc
	return lc


func cache_size() -> int:
	return _cache.size()

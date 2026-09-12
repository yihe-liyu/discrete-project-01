extends GutTest
## S4a：行为管道 + world_accel + 内容端口契约（见 docs/NEW_KERNEL_REFACTOR_PLAN.md §21）。

const GRAVITY_BULLET = preload("res://data/stages/stage01/bullet/gravity_bullet.gd")
const MOVE_HOMING = preload("res://scripts/coroutine/player/move_homing.gd")

var _backend: KernelBulletBackend


func before_each() -> void:
	_backend = KernelBulletBackend.new()
	add_child_autofree(_backend)
	_backend.setup_behaviors(null, Callable())


func _enemy(tex := "小玉") -> BulletData:
	var d := BulletData.new().enemy().tex(tex)
	d.spawn_fog = false
	return d


## 世界 accel：行为只改 velocity，位置由系统积分（别双倍）。
func test_world_accel_changes_velocity() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 1000.0
	d.accel = Vector2(0, 500.0)
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var before: Vector2 = _backend.system.get_velocity(0)
	_backend.system._physics_process(0.1)
	_backend.behavior.process()
	var after: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 50.0, 0.01, "世界 accel 应给速度 +a·dt")
	assert_almost_eq(after.x, before.x, 0.01, "x 分量不应变")


## 内容端口：gravity_bullet.kernel_port() → world_accel。
func test_gravity_port_maps_to_world_accel() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = GRAVITY_BULLET
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	var slot: int = _backend.system.get_behavior_id(0)
	assert_eq(_backend.system.get_move_name(slot), &"world_accel", "gravity_bullet 端口应映射到 world_accel")
	var before: Vector2 = _backend.system.get_velocity(0)
	_backend.system._physics_process(0.5)
	_backend.behavior.process()
	var after: Vector2 = _backend.system.get_velocity(0)
	assert_almost_eq(after.y, before.y + 200.0 * 0.5, 0.01, "默认 gravity=200 → 向下加速")


## BulletData.accel（无 coroutine）直接映射 world_accel。
func test_accel_field_without_coroutine_maps() -> void:
	var d := _enemy()
	d.velocity = Vector2.RIGHT * 100.0
	d.accel = Vector2(0, 100.0)
	_backend.shoot(d, Vector2.ZERO, Vector2.RIGHT)
	assert_eq(_backend.system.get_move_name(_backend.system.get_behavior_id(0)), &"world_accel",
		"BulletData.accel 应映射到 world_accel")


## 无端口的行为：计数 + 直线（homing 留 S4b）。
func test_unmapped_behavior_counted_and_straight() -> void:
	var d := _enemy()
	d.velocity = Vector2.UP * 100.0
	d.coroutine_script = MOVE_HOMING
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_backend.unmapped_behavior_count, 1, "无端口的行为应计数")
	assert_eq(_backend.system.get_behavior_id(0), BulletSystem.BEHAVIOR_NONE, "未映射应无行为（直线）")


## 端口缓存：同一内容签名只探测一次（不每发 instantiate 探测）。
func test_port_cached_by_signature() -> void:
	var d := _enemy()
	d.coroutine_script = GRAVITY_BULLET
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	_backend.shoot(d, Vector2.ZERO, Vector2.UP)
	assert_eq(_backend._port_by_sig.size(), 1, "同 Script×params 应命中缓存")
	assert_eq(_backend.unmapped_behavior_count, 0, "已映射不应计数")

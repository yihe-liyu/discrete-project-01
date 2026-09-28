extends GutTest
## 冻结参照（oracle）自足性：`test/reference/BulletSystem` 能**独立** new / spawn / 查询。
## 目的：证明这份 GDScript 参照实现不依赖原项目任何 autoload / 实体层 —— 它要当原生内核
## parity 的逐位基准（见 docs/TEST_INDEX.md「B1 parity 套件」、docs/archive/N2_NATIVE_INTEGRATION_PLAN.md）。
##
## 前身 = `test_kernel_vendor`：内核 vendor 流程已废止（`scripts/kernel/` 与
## `tools/vendor_kernel.sh` 均已删），该名字与文档不再成立，故更名。


func _make_type() -> BulletType:
	var bt := BulletType.new()
	bt.id = &"reference_oracle_probe"
	bt.faction = BulletType.Faction.ENEMY
	bt.hitbox_radius = 8.0
	bt.follow_dir = false
	return bt


func test_oracle_standalone() -> void:
	var sys := BulletSystem.new()
	add_child_autofree(sys)
	assert_eq(sys.get_active_count(), 0, "空池初始为 0")

	var id := sys.spawn(_make_type(), Vector2(100, 100), Vector2(10, 0))
	assert_eq(sys.get_active_count(), 1, "spawn 后应有 1 行")
	assert_eq(sys.get_position(id), Vector2(100, 100), "初始位置应为 spawn 传入值")

	var found := sys.query_circle(Vector2(100, 100), 20.0)
	assert_eq(found.size(), 1, "宽相应命中该弹")
	assert_true(sys.hit_test(id, Vector2(104, 100), 0.0), "判定半径内应为真")
	assert_false(sys.hit_test(id, Vector2(200, 100), 0.0), "远离应为假")

	sys.despawn(id)
	assert_eq(sys.get_active_count(), 0, "despawn 后应清空")


func test_oracle_has_no_host_dependency() -> void:
	# 纯 new 即可用（若 import 了原项目 autoload，这里直接编译/运行失败）。
	var sys := BulletSystem.new()
	add_child_autofree(sys)
	assert_true(sys.get_capacity() >= 16, "容量应隐式初始化（_init）")
	assert_eq(sys.get_type_registry().size(), 0, "未 spawn 过则弹型表为空")

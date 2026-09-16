extends GutTest
## orbit_probe 迁移到原生描述符（K2 运动 + K1 随机瞄准）后的形状检查。
## 行为数值 parity 由 test_native_* 覆盖；这里锁"内容真的搭出了描述符"。

const SPIRAL := preload("res://data/stages/stage03B/phase/spell03/orbit_spiral.gd")


func test_probe_lifecycle_shape() -> void:
	var spiral = SPIRAL.new()
	autofree(spiral)
	var lc: BulletLifecycle = spiral._probe_lifecycle(false)
	assert_not_null(lc, "应有探测弹描述符")
	var c: Dictionary = lc.compile()
	assert_eq(int(c["phase_count"]), 1, "单相位")
	assert_eq(int(c["act_count"][0]), 6, "on_end = sfx + 4×emit + despawn")


func test_probe_hold_differs_by_aim_chance() -> void:
	var spiral = SPIRAL.new()
	autofree(spiral)
	var normal: BulletLifecycle = spiral._probe_lifecycle(false)
	var hold: BulletLifecycle = spiral._probe_lifecycle(true)
	assert_ne(normal.content_signature(), hold.content_signature(), "hold/非 hold 瞄准概率不同 → 应不同 program")
	assert_same(spiral._probe_lifecycle(true), hold, "同 hold 应复用缓存")


func test_probe_split_data_has_lifecycle() -> void:
	var spiral = SPIRAL.new()
	autofree(spiral)
	var d: BulletData = spiral._probe_split_data()
	assert_not_null(d, "应有分裂弹数据")
	assert_not_null(d.lifecycle, "分裂弹应挂自己的描述符（缓慢加速）")


func test_probe_split_has_color_variant() -> void:
	var spiral = SPIRAL.new()
	autofree(spiral)
	var lc: BulletLifecycle = spiral._probe_lifecycle(true)
	var acts: Array = lc.compile()["actions"]
	assert_eq(acts.size(), 4, "4 次变体发射 → actions 4 项")
	for a in acts:
		assert_true(a is Array, "每项应是 [普通, 自机狙] 两模板")
		assert_eq((a as Array).size(), 2, "变体发射两模板")
	assert_eq(spiral._probe_split_data(false).tint, Color.AQUA, "普通分裂弹 AQUA")
	assert_eq(spiral._probe_split_data(true).tint, Color.RED, "自机狙分裂弹 RED")

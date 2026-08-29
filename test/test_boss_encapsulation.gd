extends GutTest
## 债 E：Boss 封装 —— hp/boss_data/hitbox_radius 只读（getter）+ hp_changed 信号。
## 白盒（GDScript 不强制私有）：测 _set_hp 唯一改写入口 + 只读取值。

func test_hp_readonly_and_signal():
	var b := Boss.new()
	var pb := PhaseData.new()
	pb.hp = 1000
	b._current_phase = pb                       # 白盒设阶段（_set_hp 取满血用）
	var got: Array = []
	b.hp_changed.connect(func(h: int, m: int): got.append([h, m]))
	b._set_hp(250)                             # 唯一改写入口（内部）
	assert_eq(b.hp, 250, "hp 走只读 getter（读 _hp）")
	assert_eq(got[0][0], 250, "hp_changed 广播新血量")
	assert_eq(got[0][1], 1000, "hp_changed 广播满血")
	assert_eq(b.boss_data, null, "未 setup 时 boss_data 为 null（只读 getter）")

func test_hp_zero_via_set_hp():
	var b := Boss.new()
	var pb := PhaseData.new()
	pb.hp = 500
	b._current_phase = pb
	b._set_hp(0)
	assert_eq(b.hp, 0, "重置血量走 _set_hp")
	b._set_hp(999999)
	assert_eq(b.hp, 999999, "时符满血走 _set_hp")

func test_boss_data_readonly():
	var b := Boss.new()
	var d := BossData.new()
	d.boss_name = "测试"
	b._boss_data = d
	assert_eq(b.boss_data, d, "boss_data 走只读 getter")
	assert_eq(b.get_boss_name(), "测试", "get_boss_name 读 _boss_data")

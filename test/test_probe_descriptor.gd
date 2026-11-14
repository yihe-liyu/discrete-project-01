extends GutTest
## spell053「哆来咪三符」内容脚本 → 原生描述符的形状检查。
## 前身 = `orbit_spiral.gd` / `orbit_probe.gd`（K2 运动 + K1 随机瞄准）的迁移用例；
## 行为数值 parity 由 `test_native_*` 覆盖，这里只锁「内容真的搭出了描述符」。

## ⚠️ **内容形状测试**：这里**故意**绑真实内容 —— 它验的就是「作者写的这张符卡真的搭出了我要的描述符」。
## 所以内容改名/重构时它**该红**（提醒你复核），这跟 test_data_validity 是一类；机制测试不该学它。
const SPELL053 := preload("res://data/stages/stage03B/phase/哆来咪三符/哆来咪三符.gd")


## 按难度建一份内容脚本：`难度为Hard以上` 在 .new() 时就读取难度，所以必须先设；
## `_on_start()` 是建弹型钩子（不依赖 ctx / target），可独立调用。
func _bind(shot) -> void:
	var reg := EmitTemplateRegistry.new()
	assert_true(reg.register(shot.夹角模板))
	assert_true(reg.register(shot.夹角狙模板))
	shot._bind_parent_behavior()


func _build(difficulty: int):
	var saved := int(SaveData.selected_difficulty)
	SaveData.selected_difficulty = difficulty
	var shot = SPELL053.new()
	autofree(shot)
	shot._on_start()
	SaveData.selected_difficulty = saved
	return shot


func test_probe_bullet_uses_split_behavior() -> void:
	var shot = _build(0)
	_bind(shot)
	var b = shot.往返弹.behavior_spec
	assert_not_null(b, "往返弹应挂 behavior")
	assert_eq(b.id, &"split_after", "应使用 split_after")


func test_variant_emits_the_two_split_templates() -> void:
	var shot = _build(0)
	_bind(shot)
	var b = shot.往返弹.behavior_spec
	assert_eq(int(b.params[2]), shot.夹角模板.numeric_id, "params[2] = 普通模板")
	assert_eq(int(b.params[3]), shot.夹角狙模板.numeric_id, "params[3] = 自机狙模板")


func test_split_templates_carry_own_lifecycle_and_color() -> void:
	var shot = _build(0)
	assert_not_null(shot.夹角弹.lifecycle, "普通分裂弹应挂描述符（沿朝向加速）")
	assert_not_null(shot.夹角狙.lifecycle, "自机狙分裂弹应挂描述符")
	assert_eq(shot.夹角弹.tint, Color.AQUA, "普通分裂弹 AQUA")
	assert_eq(shot.夹角狙.tint, Color.RED, "自机狙分裂弹 RED")


## 难度改变分裂弹的**收尾方式**：E/N 的 `夹角弹` 不自我回收（靠出界宽限 `.grace(4)` 清理），
## H/L 加了 `until_elapsed(4)` + `despawn_clear()`。
## ⚠️ 这里**不数 action 个数** —— 那是「内容形状」，作者当天就把 `despawn` 换成了 `despawn_clear`
## （1 → 2 个 action）。锁形状的测试会跟着内容迭代天天红；只锁「有没有收尾 / 难度是否分派」。
func test_split_lifecycle_differs_by_difficulty() -> void:
	var easy = _build(0)
	var hard = _build(2)
	assert_ne(easy.夹角弹.lifecycle.content_signature(),
		hard.夹角弹.lifecycle.content_signature(),
		"难度不同 → 夹角弹 program 应不同")
	assert_eq(int(easy.夹角弹.lifecycle.compile()["act_count"][0]), 0, "E/N 夹角弹不自我回收")
	assert_gt(int(hard.夹角弹.lifecycle.compile()["act_count"][0]), 0, "H/L 夹角弹应有 on_end（收尾）")


## 变自机狙概率 0（E/N）vs 0.1（H/L）会进 program 参数 → 两份 program 必须不同。
func test_aim_chance_differs_by_difficulty() -> void:
	var easy = _build(0)
	var hard = _build(2)
	_bind(easy)
	_bind(hard)
	assert_ne(easy.往返弹.behavior_spec.params[4],
		hard.往返弹.behavior_spec.params[4],
		"变自机狙概率 0 vs >0 → behavior 参数不同")

extends GutTest
## 工作台（嵌入创作台）坐标一致性：场地 / BulletManager / BenchWorld 都在画布坐标，
## 子弹出生（全局）== Boss 全局 == 场地标记全局。

func _embed_bench() -> Node:
	var host := Control.new()
	add_child_autofree(host)
	host.position = Vector2(0.0, 34.0)   # 模拟页签横栏下
	var bench = preload("res://scenes/workbench/phase_bench.tscn").instantiate()
	host.add_child(bench)
	return bench


func test_embedded_bench_world_matches_field() -> void:
	var bench = _embed_bench()
	await get_tree().process_frame
	await get_tree().process_frame
	bench._boss_pos = Vector2(448.0, 250.0)
	# 自建夹具阶段：本用例只验坐标系，与"是哪张符卡"无关（绑真实内容 = 每次内容改名都白红一次）。
	var phase := PhaseData.new()
	phase.hp = 100
	phase.time_limit = 10.0
	var boss = bench._stage_runtime.start_spell_card(phase, bench._shell.boss_scene(), "T", bench._boss_pos)
	await get_tree().physics_frame
	assert_not_null(boss, "Boss 应生成")
	var field: Control = bench._field
	var bm: Node2D = bench._bullet_manager
	assert_true(field.top_level, "场地在画布坐标")
	assert_true(bm.top_level, "BulletManager 在画布坐标")
	assert_eq(field.global_position, Vector2.ZERO, "场地原点 = 画布原点")
	assert_eq(boss.global_position, Vector2(448.0, 250.0), "Boss 全局 = 游戏坐标")
	assert_eq(field.global_position + bench._boss_pos, boss.global_position, "标记 == Boss")
	var data := BulletData.new().tex("小玉").speed(100.0).enemy()
	var id: int = bm._kernel_bullet_host.shoot(data, boss.global_position, Vector2.DOWN)
	await get_tree().physics_frame
	var bullet_global: Vector2 = bm.global_position + bm._kernel_bullet_host.system.get_position(id)
	assert_eq(bullet_global, boss.global_position, "子弹出生全局 == Boss 全局")

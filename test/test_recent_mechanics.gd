extends GutTest
## 近期新增机制测试：out_grace（出界宽限）/ open_reduce（开局减伤）/ boss_name（记录补全）


# ═══════════ out_grace：出界宽限 ═══════════

func test_grace_default_zero():
	var bd := BulletData.new()
	assert_eq(bd.out_grace, 0.0, "默认 0 = 出界立即回收（行为不变）")


func test_grace_chain_method():
	var bd := BulletData.new().grace(2.5)
	assert_eq(bd.out_grace, 2.5, ".grace(2.5) 链式设置")


func test_grace_offscreen_judgement():
	# 复刻 bullet_manager 出屏回收判定：宽限内不回收、超时回收、回界重置
	var grace := 2.0
	var out_time := 0.0
	var dt := 0.016
	var frames_alive := 0
	var collected := false
	for _i in 300:
		var offscreen := true  # 一直出界
		if offscreen:
			if grace > 0.0:
				out_time += dt
				if out_time < grace:
					frames_alive += 1
					continue
			collected = true
			break
		else:
			out_time = 0.0
	assert_eq(collected, true, "超宽限后回收")
	assert_between(frames_alive, 120, 130, "2.0s/0.016 ≈ 125 帧存活")


func test_grace_zero_immediate():
	# grace=0：出界立即回收（保持旧行为）
	var grace := 0.0
	var out_time := 0.0
	var dt := 0.016
	var frames_alive := 0
	for _i in 10:
		if grace > 0.0:
			out_time += dt
			if out_time < grace:
				frames_alive += 1
				continue
		break
	assert_eq(frames_alive, 0, "grace=0 出界立即回收，无宽限帧")


# ═══════════ open_reduce：开局减伤 ═══════════

func test_open_reduce_default_off():
	var phase := PhaseData.new()
	assert_eq(phase.open_reduce_time, 0.0, "默认关闭")
	assert_eq(phase.open_reduce_ratio, 0.9, "默认比例 0.9")


func _make_boss_with_reduce() -> Node:
	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)  # 需要进树：涨血 tween / _process 才跑
	var phase := PhaseData.new()
	phase.hp = 1000
	phase.time_limit = 10.0
	phase.open_reduce_time = 3.0
	phase.open_reduce_ratio = 0.9
	boss.start_phase(phase)
	return boss


func test_open_reduce_timing_starts_after_invincible():
	# 减伤计时从"无敌解除"（涨血完）开始：涨血中剩余=0，解除后=完整时长
	var boss = _make_boss_with_reduce()
	assert_eq(boss._open_reduce_left, 0.0, "涨血中（无敌期）还没开始计时")
	await wait_seconds(1.3)  # 涨血 tween 1s 完成 → 无敌解除
	assert_between(boss._open_reduce_left, 2.0, 3.0, "无敌解除时减伤满额开始")
	# 此时 hp 已涨满，减伤生效
	boss.take_damage(100.0)
	assert_between(boss.hp, 988, 992, "减伤中 100 伤只扣 ~10（90% 减免；float 容差）")


func test_open_reduce_expires():
	var boss = _make_boss_with_reduce()
	await wait_seconds(4.5)  # 无敌 1s + 减伤 3s 完
	assert_eq(boss._open_reduce_left, 0.0, "减伤耗尽")
	boss.take_damage(100.0)
	assert_between(boss.hp, 898, 902, "减伤结束后扣满 100（float 容差）")


# ═══════════ 瘦身：记录不再存卡定义快照 ═══════════
# name / boss_name / phase_data / boss_scene 已从 SpellRecord 移除，
# 卡定义统一由 BossCatalog 按 (stage, boss_index, phase_index, difficulty) 提供。


func test_practice_miss_records_failure():
	# 练习 miss：practice_attempts+1、captures 不加（防重复：击破路径 _cleared=true 已记）
	# 用独立键（stage=99）避免撞真实持久记录；手动预建记录模拟"已解锁"
	# 备份/还原 book（record_practice 会改 autoload 内存记录；退出时若触发 save 会污染真实文件）
	var book_backup: Array = GameState.spell_book.records.duplicate(true)
	GameState.selected_character = 0
	GameState.selected_difficulty = 1
	var phase := PhaseData.new()
	phase.uid = 303
	phase.name = "黄粱"
	phase.hp = 1000
	phase.time_limit = 10.0
	var book: SpellRecordBook = GameState.spell_book
	book.get_or_create(99, 7, 0, 0, 1, 303, 1, 2)
	GameState.is_practice_mode = true
	GameState.start_practice(phase, null, "卡摩瑞", 99, 7)
	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	boss._stage_id = 99  # 裸 new() 无 setup，直设（spawn_boss 会走 setup 自动取 practice_stage_id）
	boss.start_phase(phase)
	# 先记录一次击破（_cleared=true）
	boss._invincible = false
	boss.take_damage(99999.0)
	var r := book.get_record(99, 7, 0, 0, 1)
	assert_eq(r.practice_attempts, 1, "击破记 1 次尝试")
	assert_eq(r.practice_captures, 1, "击破记 1 次收取")
	# miss：新 Boss（未击破）→ die() → 失败尝试
	var boss2 = load("res://scripts/enemy/boss.gd").new()
	add_child(boss2)
	boss2._stage_id = 99
	boss2.start_phase(phase)
	boss2.die()
	await get_tree().physics_frame  # 冲掉 boss2 的 queue_free，避免脚本结束时残留子节点
	var r2 := book.get_record(99, 7, 0, 0, 1)
	assert_eq(r2.practice_attempts, 2, "miss 后再 +1（共 2 次）")
	assert_eq(r2.practice_captures, 1, "miss 不加收取")
	GameState.is_practice_mode = false
	GameState.spell_book.records = book_backup  # 还原，防污染持久记录

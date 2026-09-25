extends GutTest
## 近期新增机制测试：out_grace（出界宽限）/ open_reduce（开局减伤）/ boss_name（记录补全）


# ═══════════ out_grace：出界宽限 ═══════════

func test_grace_default_zero():
	var bd := BulletData.new()
	assert_eq(bd.out_grace, 0.0, "默认 0 = 出界立即回收（行为不变）")


func test_grace_chain_method():
	var bd := BulletData.new().grace(2.5)
	assert_eq(bd.out_grace, 2.5, ".grace(2.5) 链式设置")
	assert_eq(bd.to_bullet_type().out_grace, 2.5, "且随类型级字段快照进 BulletType")


func test_grace_flows_into_kernel_row():
	## 真链路：BulletData.grace → BulletType.out_grace → KernelNativeSystem.spawn → 原生行。
	## （2026-09-23 之前的 4 条 out_grace「测试」要么只断言 setter、要么把判定逻辑在测试里重抄
	##  一遍 —— 全都不碰真代码，所以功能是空的门禁却一直绿。真行为 parity 见
	##  test_lifecycle_primitives 的 out_grace 四条。）
	if not ClassDB.class_exists("DanmakuStore"):
		pending("未构建原生扩展")
		return
	var sys: KernelNativeSystem = autofree(KernelNativeSystem.new())
	var bt: BulletType = BulletData.new().grace(1.5).to_bullet_type()
	var id: int = sys.spawn(bt, Vector2(448.0, 480.0), Vector2.ZERO)
	assert_eq(sys.get_out_grace(id), 1.5, "原生行拿到了逐弹宽限")
	var plain: int = sys.spawn(BulletType.new(), Vector2(448.0, 480.0), Vector2.ZERO)
	assert_eq(sys.get_out_grace(plain), 0.0, "未设宽限 = 0（出界立即剔除）")


# ═══════════ open_reduce：开局减伤 ═══════════

## 默认值只锁**不变量**（时长非负、比例 0~1）。
## ⚠️ 别锁具体数值 —— 曾断言"默认关闭(=0)"，作者把默认调成 3.0 后测试白红一次。
func test_open_reduce_defaults_are_sane():
	var phase := PhaseData.new()
	assert_gte(phase.open_reduce_time, 0.0, "默认减伤时长非负（0 = 关闭）")
	assert_between(phase.open_reduce_ratio, 0.0, 1.0, "默认减伤比例在 0~1")


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
	# 练习 miss：practice_attempts+1、captures 不加（防重复：击破路径 _is_cleared=true 已记）
	# 用独立键（stage=99）避免撞真实持久记录；手动预建记录模拟"已解锁"
	# 备份/还原 book（record_practice 会改 autoload 内存记录；退出时若触发 save 会污染真实文件）
	var book_backup: Array = SaveData.spell_book.records.duplicate(true)
	SaveData.selected_character = 0
	SaveData.selected_difficulty = 1
	var phase := PhaseData.new()
	phase.uid = 303
	phase.name = "黄粱"
	phase.hp = 1000
	phase.time_limit = 10.0
	var book: SpellRecordBook = SaveData.spell_book
	# 防污染：清掉历史运行可能残留的 (99,7) 记录——stage 99 不存在于游戏中，
	# 否则 get_or_create 会命中旧记录，练习次数从旧值继续累加导致本测试假失败。
	var stale := book.get_record(99, 7, 0, 0, 1)
	if stale:
		book.records.erase(stale)
	book.get_or_create(99, 7, 0, 0, 1, 303, 1, 2)
	PracticeSession.is_practice_mode = true
	PracticeSession.start(phase, null, "卡摩瑞", 99, 7)
	var boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	boss._stage_id = 99  # 裸 new() 无 setup，直设（spawn_boss 会走 setup 自动取 practice_stage_id）
	boss.start_phase(phase)
	# 先记录一次击破（_is_cleared=true）
	boss._is_invincible = false
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
	PracticeSession.is_practice_mode = false
	SaveData.spell_book.records = book_backup  # 还原，防污染持久记录

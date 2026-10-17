extends GutTest
## ctx.* 服务（BossService / DifficultyService / EnemyService）纯逻辑测试：无树，校验"查询/按难度取值/生成容错"。
## 直接测服务类（内容经由 ctx.boss / ctx.diff / ctx.enemies 触达它们）。

const BossService = preload("res://scripts/coroutine/services/boss_service.gd")
const DifficultyService = preload("res://scripts/coroutine/services/difficulty_service.gd")
const EnemyService = preload("res://scripts/coroutine/services/enemy_service.gd")
## 夹具替身脚本（机制测试不绑内容 —— 见 docs/TEST_INDEX.md「内容绑定契约」）
const ENEMY_SCRIPT = preload("res://test/fixtures/no_port_behavior.gd")


## 记录型特效池：不改 `FxPool` 私有状态，只记「谁被播了、播在哪」（沿用 FakeEnemy 那套子类替换）
class RecordingFxPool extends FxPool:
	var played: Array = []
	func play(scene: PackedScene, pos: Vector2, _vel: Vector2 = Vector2.ZERO, _tint: Color = Color.WHITE) -> HitEffect:
		played.append({"scene": scene, "pos": pos})
		return null

func test_boss_service_no_boss():
	var s := BossService.new()
	assert_null(s.current(), "无活动 Boss 时 current 应为 null")
	assert_false(s.exists(), "无活动 Boss 时 exists 应为 false")

func test_diff_service_picks_by_difficulty():
	var orig := int(SaveData.selected_difficulty)
	SaveData.selected_difficulty = 2
	var s := DifficultyService.new()
	assert_eq(s.picked(), 2, "picked 应返回当前难度")
	assert_eq(s.pick([1, 3, 5, 8]), 5, "arr[2] 应为 5")
	assert_true(s.at_least(2), "难度 2 应 at_least(2)")
	assert_true(s.at_least(1), "难度 2 应 at_least(1)")
	assert_false(s.at_least(3), "难度 2 不应 at_least(3)")
	assert_eq(s.pick_from({0: {"a": 1}, 2: {"a": 9}}, "a", 0), 9, "字典按难度取值")
	SaveData.selected_difficulty = orig

func test_diff_service_at_least_lunatic():
	var orig := int(SaveData.selected_difficulty)
	SaveData.selected_difficulty = 3
	var s := DifficultyService.new()
	assert_true(s.at_least(3), "Lunatic 应 at_least(3)")
	assert_false(s.at_least(4), "Lunatic 不应 at_least(4)")
	SaveData.selected_difficulty = orig

func test_enemy_service_without_stage_returns_null():
	# 配置合法但无世界 → null（不崩）；实例化机制在 StageRuntime，单测不启世界
	var data := EnemyData.new().with_script(ENEMY_SCRIPT)
	assert_null(EnemyService.new().spawn(data), "ctx 为空时 spawn 应返回 null")
	assert_null(StageContext.new(null).enemies.spawn(data), "ctx 无 stage 时 spawn 应返回 null")


# ═══ ctx.enemies 回收动词（2026-10-04 新增：此前内容只能裸调 target.queue_free()）═══

## 单只回收：**静默**（不掉道具 / 不计分 / 不发 `enemy_killed`），且**不需要 ctx/stage**
func test_enemy_despawn_recycles_silently():
	var e := Enemy.new()
	add_child_autofree(e)
	watch_signals(GameEvents)
	assert_true(EnemyService.new().despawn(e), "无 ctx 也能回收（只是一次 queue_free）")
	assert_true(e.is_queued_for_deletion(), "应已排队释放")
	assert_signal_not_emitted(GameEvents, "enemy_killed", "静默回收**不算战果**（对照：die() 才会发）")


## 容错：空 / 已释放 ⇒ **响亮** + false；重复回收 ⇒ false（静默，不算错）
func test_enemy_despawn_rejects_null_and_is_idempotent():
	var s := EnemyService.new()
	s.despawn(null)
	assert_push_error("传入空 / 已释放")
	var e := Enemy.new()
	add_child_autofree(e)
	assert_true(s.despawn(e), "第一次回收成功")
	assert_false(s.despawn(e), "重复回收 ⇒ false（已经排队释放了）")


## 类型守卫：传非 Enemy（例如 Boss 位）⇒ **响亮报出它到底是什么**，
## 而不是像 `target as Enemy` 那样静默变 null、再被误诊成"敌人为空"（2026-10-04 被测试顶出来的）
func test_enemy_despawn_rejects_non_enemy_loudly():
	var s := EnemyService.new()
	var not_enemy := Area2D.new()          # 替身：Boss 也是 Area2D 且不是 Enemy 子类
	not_enemy.name = "FakeBoss"
	add_child_autofree(not_enemy)
	assert_false(s.despawn(not_enemy), "非 Enemy ⇒ false")
	assert_push_error("传进来的不是 Enemy")
	assert_false(not_enemy.is_queued_for_deletion(), "不该被回收")


## 批量：只收杂兵，**不动 Boss 位**（Boss 不是 Enemy 子类，天然被筛掉），并返回数量
func test_enemy_despawn_all_skips_non_enemy():
	var rt := StageRuntime.new()
	autofree(rt)                      # 只要一个"注入槽"（不挂树，免 _ready 副作用）
	var ctx := StageContext.new(null)
	ctx.stage = rt
	var a := Enemy.new()
	var b := Enemy.new()
	add_child_autofree(a)
	add_child_autofree(b)
	rt.entity_registry.register_enemy(a)
	rt.entity_registry.register_enemy(b)
	var boss_slot := Area2D.new()          # 替身：Boss 也是 Area2D 且不是 Enemy 子类
	add_child_autofree(boss_slot)
	rt.entity_registry.register_enemy(boss_slot)
	var pool := RecordingFxPool.new()
	add_child_autofree(pool)
	rt.fx_pool = pool                  # ⚠️ 注入点是 **stage**：`ctx.effects` 的 getter 每次访问都会重刷 `fx_pool = stage.fx_pool`
	a.death_effect = PackedScene.new()
	b.death_effect = PackedScene.new()

	assert_eq(ctx.enemies.despawn_all(), 2, "只回收杂兵，返回数量")
	assert_eq(pool.played.size(), 2, "**清场要看得见**：每只被清的杂兵各播一次击破特效（假 Boss 不播）")
	assert_true(a.is_queued_for_deletion(), "杂兵 a 应被回收")
	assert_true(b.is_queued_for_deletion(), "杂兵 b 应被回收")
	assert_false(boss_slot.is_queued_for_deletion(), "非 Enemy（Boss 位）不该被动 —— 它有自己那条退场路径")


## 击破特效：`despawn_clear` = 回收 + **恰好一次**击破特效（位置 = 敌人位置、用它的 `death_effect`）
## ⚠️ 且仍然**不算战果**（不发 `enemy_killed`）—— 与 `die()` 的分界就在这
func test_enemy_despawn_clear_plays_break_fx():
	var pool := RecordingFxPool.new()
	add_child_autofree(pool)
	var rt := StageRuntime.new()
	autofree(rt)
	var ctx := StageContext.new(null)
	ctx.stage = rt
	rt.fx_pool = pool                  # 注入点是 stage（见上一条测试的注释）
	var e := Enemy.new()
	add_child_autofree(e)
	e.global_position = Vector2(123, 456)
	e.death_effect = PackedScene.new()

	watch_signals(GameEvents)
	assert_true(ctx.enemies.despawn_clear(e), "应回收成功")
	assert_eq(pool.played.size(), 1, "应播**恰好一次**击破特效")
	assert_eq(pool.played[0]["pos"], Vector2(123, 456), "特效位置 = 敌人位置")
	assert_eq(pool.played[0]["scene"], e.death_effect, "用的就是该敌人的 death_effect")
	assert_true(e.is_queued_for_deletion(), "敌人应被回收")
	assert_signal_not_emitted(GameEvents, "enemy_killed", "仍然不算战果（不发光信号、不掉道具）")


## 没配 `death_effect`（无 EnemyData）⇒ 只回收、不报错（不是"必须配"）
func test_enemy_despawn_clear_without_effect_is_fine():
	var pool := RecordingFxPool.new()
	add_child_autofree(pool)
	var rt := StageRuntime.new()
	autofree(rt)
	var ctx := StageContext.new(null)
	ctx.stage = rt
	rt.fx_pool = pool                  # 注入点是 stage（见上一条测试的注释）
	var e := Enemy.new()          # death_effect 默认 null
	add_child_autofree(e)
	assert_true(ctx.enemies.despawn_clear(e), "仍应回收成功")
	assert_eq(pool.played.size(), 0, "没配特效就只回收")

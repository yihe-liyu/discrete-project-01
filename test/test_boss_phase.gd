extends GutTest
## Boss 符卡判定测试 —— 捕获/超时/时符/防双清/掉落表
## 策略：stub autoload 副作用，只测判定逻辑

const BOSS_CLASS = preload("res://scripts/enemy/boss.gd")

var _boss: Boss


## 覆写 spawn_item 记录调用的测试上下文
class CtxSpy:
	extends StageContext
	var calls: Array = []

	func _init(p_runner: CoroutineRunner) -> void:
		super(p_runner)

	func spawn_item(type: int, position: Vector2) -> void:
		calls.append([type, position])


## 记录 death_clear 调用的弹幕服务桩（回归：门面是 ctx.bullets，不是 ctx.bullet_manager）
class BulletSpy:
	extends BulletService
	var calls: Array = []

	func death_clear(pos: Vector2, max_radius: float, duration: float,
			_start_radius: float = 30.0, _on_clear: Callable = Callable()) -> void:
		calls.append([pos, max_radius, duration])


func before_each():
	_boss = BOSS_CLASS.new()
	autofree(_boss)
	# 注：这里不再 stub autoload —— 传字符串名在 GUT 里不是
	# 有效路径，是静默 no-op（stub_target 保持 null），只会产生假警告还给人"已隔离"的错觉。
	# 真实调用 SaveData.record_spell / unlock_spell / BulletManager.start_death_clear 的
	# 副作用由 run_tests.sh 兜底隔离：XDG_DATA_HOME 重定向 user:// + spell_records.tres 备份还原。


func _make_phase(hp: int = 100, time_limit: float = 10.0, timeout_only: bool = false, uid: int = 0) -> PhaseData:
	var p := PhaseData.new()
	p.name = "测试符卡" if not timeout_only else ""
	p.hp = hp
	p.time_limit = time_limit
	p.is_timeout_only = timeout_only
	p.uid = uid   # uid != 0 = 符卡（才有奖励分，见 SpellBonus）
	return p


## 辅助：跳过 HP 上涨 tween，直接进入可受击状态
func _skip_hp_tween() -> void:
	_boss._is_invincible = false


## 普通符卡：超时未击破 → captured=false
func test_normal_spell_timeout_is_not_captured():
	var phase := _make_phase(100, 5.0)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_boss._process(5.0 + 0.01)  # 超过时限
	assert_signal_emitted(_boss, "phase_cleared", "超时应触发 phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], false, "普通符卡超时不应算捕获")


## 时符：超时撑过去 → captured=true
func test_timeout_spell_timeout_is_captured():
	var phase := _make_phase(100, 5.0, true)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_boss._process(5.0 + 0.01)
	assert_signal_emitted(_boss, "phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], true, "时符撑到超时应算捕获")


## 击破捕获：HP 打空 → captured=true
func test_destroy_spell_is_captured():
	var phase := _make_phase(100)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(100)  # 打空
	assert_signal_emitted(_boss, "phase_cleared")
	var params = get_signal_parameters(_boss, "phase_cleared", 0)
	assert_eq(params[0], true, "击破应算捕获")


## 无敌期间：伤害无效
func test_damage_ignored_while_invincible():
	var phase := _make_phase(100)
	_boss.start_phase(phase)
	_boss._hp = 100
	_boss._is_invincible = true
	_boss.take_damage(100)
	assert_eq(_boss.hp, 100, "无敌期间不应扣血")


## 时符 hp 无限：伤害不触发清除（is_timeout_only 时 hp=999999）
func test_timeout_spell_immune_to_damage():
	var phase := _make_phase(100, 10.0, true)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(999999)
	assert_false(_boss._is_cleared, "时符不应因伤害清除")


## 双重清除保护：phase_cleared 只发一次
func test_no_double_clear():
	var phase := _make_phase(50, 5.0)
	watch_signals(_boss)
	_boss.start_phase(phase)
	_skip_hp_tween()
	_boss.take_damage(50)     # 击破
	_boss.take_damage(50)     # 再来一下（应被 _is_cleared 保护挡住）
	_boss._process(5.0 + 0.01)  # 超时（也应被挡住）
	assert_signal_emit_count(_boss, "phase_cleared", 1, "phase_cleared 只能发出一次")


## 非时符：奖励分在**时限内均匀**衰减到初始的 30%（规则见 `SpellBonus`，内容不再手填）
func test_bonus_decays_uniformly_to_30_percent_over_time_limit():
	_boss._stage_id = 7                             # 面序号 7（无该面内容 → 身份解析 null，不碰存档）
	var phase := _make_phase(100, 40.0, false, 1)   # uid != 0 = 符卡
	_boss.start_phase(phase)
	var start := _boss._bonus
	assert_gt(start, 0, "符卡应有初始奖励分（非符才是 0）")

	_boss._process(20.0)                            # 走一半时限 → 线性 → 初始的 65%
	assert_almost_eq(float(_boss._bonus), float(start) * 0.65, float(start) * 0.02,
		"半程 ≈ 初始的 65%%（线性）")

	_boss._process(20.0)                            # 走满时限 → 30%
	assert_almost_eq(float(_boss._bonus), float(SpellBonus.decay_floor(start)), float(start) * 0.02,
		"满时限 ≈ 初始的 30%%")


## 下限兜底：时限内怎么掉都不会低于 30%
func test_bonus_never_below_30_percent():
	_boss._stage_id = 7
	var phase := _make_phase(100, 10.0, false, 1)
	_boss.start_phase(phase)
	var start := _boss._bonus
	for i in 30:
		_boss._process(1.0)
		assert_gte(_boss._bonus, SpellBonus.decay_floor(start), "第 %d 秒仍不低于 30%%" % (i + 1))


## 时符：奖励分**不**衰减（作者 2026-09-26 规则）
func test_timeout_only_spell_bonus_does_not_decay():
	_boss._stage_id = 7                             # 挂个面序号，否则初始奖励分本身就是 0
	var phase := _make_phase(100, 60.0, true, 2)    # 时符 + 符卡
	_boss.start_phase(phase)
	var start := _boss._bonus
	assert_gt(start, 0, "时符也是符卡 → 有初始奖励分")
	_boss._process(30.0)
	assert_eq(_boss._bonus, start, "时符不掉奖励分")


## 非符：没有奖励分（原作口径）→ 不掉、也不加分
func test_nonspell_bonus_is_zero():
	var phase := _make_phase(100, 60.0, false, 0)
	_boss.start_phase(phase)
	assert_eq(_boss._bonus, 0, "非符奖励分 = 0")
	_boss._process(10.0)
	assert_eq(_boss._bonus, 0, "非符不掉（本来就是 0）")


## 掉落表：按配置精确生成掉落（用 CtxSpy 记录）
func test_drop_items_matches_config():
	var phase := _make_phase()
	phase.item_power = 2
	phase.item_point = 1
	phase.item_life = 3
	phase.item_bomb = 4
	phase.item_life_full = 1
	phase.item_bomb_full = 2
	_boss._phase_data = phase
	_boss.global_position = Vector2(448, 240)

	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := CtxSpy.new(runner)
	_boss._stage_context = ctx

	_boss._drop_items()
	var calls: Array = ctx.calls
	assert_eq(calls.size(), 2 + 1 + 3 + 4 + 1 + 2, "掉落总数应为 13")
	# 分类验证
	var power := 0
	var point := 0
	var life := 0
	var bomb := 0
	var life_full := 0
	var bomb_full := 0
	for c in calls:
		match c[0]:
			Item.Type.POWER: power += 1
			Item.Type.POINT: point += 1
			Item.Type.LIFE_FRAGMENT: life += 1
			Item.Type.BOMB_FRAGMENT: bomb += 1
			Item.Type.LIFE_FULL: life_full += 1
			Item.Type.BOMB_FULL: bomb_full += 1
	assert_eq(power, 2, "POWER 应掉 2 个")
	assert_eq(point, 1, "POINT 应掉 1 个")
	assert_eq(life, 3, "LIFE_FRAGMENT 应掉 3 个")
	assert_eq(bomb, 4, "BOMB_FRAGMENT 应掉 4 个")
	assert_eq(life_full, 1, "LIFE_FULL 应掉 1 个")
	assert_eq(bomb_full, 2, "BOMB_FULL 应掉 2 个")


## 练习模式不掉落
func test_no_drops_in_practice_mode():
	var phase := _make_phase()
	phase.item_power = 2
	_boss._phase_data = phase
	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := CtxSpy.new(runner)
	_boss._stage_context = ctx

	var original := PracticeSession.is_practice_mode
	PracticeSession.is_practice_mode = true
	_boss._drop_items()
	PracticeSession.is_practice_mode = original

	assert_eq(ctx.calls.size(), 0, "练习模式不应掉落")


## 回归：clear_phase 必须走 ctx 门面 `ctx.bullets`（StageContext 没有 bullet_manager）。
## 曾把门面名误改成 bullet_manager → 带 ctx 的击破清弹运行期报错，且 death_clear 根本没被调。
func test_clear_phase_death_clear_via_bullets_facade() -> void:
	_boss.start_phase(_make_phase(10, 10.0))
	_skip_hp_tween()

	var runner := CoroutineRunner.new()
	autofree(runner)
	var ctx := CtxSpy.new(runner)
	var spy := BulletSpy.new()
	ctx._bullet_service = spy
	_boss._stage_context = ctx

	_boss.clear_phase(false)
	assert_eq(spy.calls.size(), 1, "clear_phase 应经 ctx.bullets.death_clear 清一次弹")

## ── 难度差分 ──

func _mk_phase(p_name: String) -> PhaseData:
	var pd := PhaseData.new()
	pd.name = p_name
	pd.time_limit = 30.0
	pd.hp = 1000
	pd.shoot_script = load("res://scripts/coroutine/timeline/timeline.gd")
	return pd

func test_phases_for_difficulty_groups():
	var bd := BossData.new()
	bd.normal_phase(_mk_phase("N1")).easy_phase(_mk_phase("E1")).hard_phase(_mk_phase("H1")).lunatic_phase(_mk_phase("L1")).extra_phase(_mk_phase("X1"))
	assert_eq(bd.phases_for_difficulty(1)[0].name, "N1", "Normal 取 phases_normal")
	assert_eq(bd.phases_for_difficulty(0)[0].name, "E1", "Easy 取 phases_easy")
	assert_eq(bd.phases_for_difficulty(2)[0].name, "H1", "Hard 取 phases_hard")
	assert_eq(bd.phases_for_difficulty(3)[0].name, "L1", "Lunatic 取 phases_lunatic")
	assert_eq(bd.phases_for_difficulty(4)[0].name, "X1", "Extra 取 phases_extra")

func test_phases_for_difficulty_no_fallback():
	var bd := BossData.new()
	bd.normal_phase(_mk_phase("N1"))
	# 其他难度未配置 → 空，**不回落 Normal**
	assert_true(bd.phases_for_difficulty(0).is_empty(), "Easy 未配置应为空")
	assert_true(bd.phases_for_difficulty(2).is_empty(), "Hard 未配置应为空")
	assert_true(bd.phases_for_difficulty(3).is_empty(), "Lunatic 未配置应为空")
	assert_true(bd.phases_for_difficulty(4).is_empty(), "Extra 未配置应为空")
	assert_eq(bd.phases_for_difficulty(1)[0].name, "N1", "Normal 取 phases_normal")
	assert_eq(bd.phases_for_difficulty(99)[0].name, "N1", "未知难度按 Normal 处理")

func test_difficulty_name_extra():
	assert_eq(BossData.difficulty_name(4), "Extra", "难度 4 应叫 Extra")
	assert_eq(BossData.difficulty_name(1), "Normal", "难度 1 应叫 Normal")

func test_validate_checks_all_difficulty_groups():
	var bd := BossData.new()
	bd.normal_phase(_mk_phase("N1"))
	var bad := PhaseData.new()
	bad.name = "坏符"
	bad.time_limit = 0.0  # 非法时限 → 校验应报错
	bd.lunatic_phase(bad)
	var errs := bd.validate()
	assert_true(errs.size() >= 1, "Lunatic 组非法阶段应被校验捕获")

func test_boss_index_in_phase_identity():
	var pid := PhaseIdentity.from_phase(PhaseData.new(), 1, 0, 0, 0, 2)
	assert_eq(pid.boss_index, 2, "boss_index 传入")
	var pid2 := PhaseIdentity.from_phase(PhaseData.new(), 1, 0, 0, 0)
	assert_eq(pid2.boss_index, 0, "默认 boss_index = 0")


## 同一 Boss 多段战斗（道中战 + 面战）：段 BossData 带完整阶段链，start_phase 从链定位序号 → 记录连续、不撞键
## （回归：stage01 最终 Boss 曾漏设延续，导致 NON01 与道中非符同键被吞 / 或误用 boss_index 拆成两个 Boss）
func test_same_boss_continued_phases_are_separate_records():
	SaveData.selected_character = 0
	SaveData.selected_difficulty = 1
	# 阶段身份走规范顺序（BossCatalog.stage_phase_order）→ 用**注入的夹具名册**而不是真实内容：
	# 本用例测的是「同一 Boss 多段链的序号不撞键」，与内容是哪张符卡无关（内容改名不该让它红）。
	# 备份/还原 spell_book 记录，避免污染持久存档（不泄露 —— 与 test_recent_mechanics 同法）。
	var book_backup: Array = SaveData.spell_book.records.duplicate(true)
	SaveData.current_stage_id = 1
	PracticeSession.is_practice_mode = false
	var non_mid := PhaseData.new()
	non_mid.name = "夹具道中非符1"
	non_mid.hp = 1000
	non_mid.time_limit = 30.0
	var non01 := PhaseData.new()
	non01.name = "夹具非符1"
	non01.hp = 1000
	non01.time_limit = 30.0

	# 道中 Boss：完整链 → 规范顺序定位 (phase_index 0, 非符1)
	var bd := BossData.new().name("夹具").normal_phase(non_mid).normal_phase(non01)
	BossCatalog.set_catalog_override({1: [bd]})
	var boss1: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss1)
	boss1.setup(bd, null)
	boss1._stage_id = 1
	boss1.start_phase(non_mid)
	var mid_rec: SpellRecord = SaveData.spell_book.get_record(1, 0, 0, 0, 1)
	assert_not_null(mid_rec, "道中非符应入簿 (phase 0)")
	if mid_rec:
		assert_eq(mid_rec.phase_number, 1, "道中非符是'非符1'")

	# 面 Boss：同一完整链，start_phase(non01) 规范序定位 → (phase_index 1, 非符2)
	var boss2: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss2)
	boss2.setup(bd, null)
	boss2._stage_id = 1
	boss2.start_phase(non01)
	var final_rec: SpellRecord = SaveData.spell_book.get_record(1, 1, 0, 0, 1)
	assert_not_null(final_rec, "面非符应入簿 (phase 1)")
	if final_rec:
		assert_eq(final_rec.phase_number, 2, "面非符是'非符2'")
	if mid_rec:
		assert_eq(mid_rec.phase_number, 1, "道中记录不被覆盖")
	SaveData.spell_book.records = book_backup  # 还原，防污染持久记录
	BossCatalog.clear_catalog_override()       # 还原名册（static 缓存全局可见，必须清）
	SaveData.current_stage_id = 1


## 发动前走位：`PhaseData.pre_move_script` **跑完才宣言**（phase_start）
func test_pre_move_delays_declaration():
	var boss: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	var phase := PhaseData.new()
	phase.name = "夹具符卡"
	phase.uid = 7
	phase.hp = 1000
	phase.time_limit = 30.0
	phase.pre_move_script = preload("res://test/fixtures/pre_move_probe.gd")   # 走 0.6 秒
	var fired := [false]
	var cb := func(_p: PhaseData) -> void: fired[0] = true
	GameEvents.phase_start.connect(cb, CONNECT_ONE_SHOT)
	boss.start_phase(phase)
	assert_false(fired[0], "走位没跑完，还不该宣言")
	await wait_physics_frames(60)                 # 0.6 秒 ≈ 36 物理帧
	assert_true(fired[0], "走位跑完 → 宣言")
	if GameEvents.phase_start.is_connected(cb):
		GameEvents.phase_start.disconnect(cb)


## 没配 pre_move_script → 宣言立即发生（不引入额外延迟）
func test_without_pre_move_declares_immediately():
	var boss: Boss = load("res://scripts/enemy/boss.gd").new()
	add_child_autofree(boss)
	var phase := PhaseData.new()
	phase.name = "夹具符卡"
	phase.uid = 7
	phase.hp = 1000
	phase.time_limit = 30.0
	var fired := [false]
	var cb := func(_p: PhaseData) -> void: fired[0] = true
	GameEvents.phase_start.connect(cb, CONNECT_ONE_SHOT)
	boss.start_phase(phase)
	assert_true(fired[0], "没配走位 → 立刻宣言")
	if GameEvents.phase_start.is_connected(cb):
		GameEvents.phase_start.disconnect(cb)


# ═══════════ 全破演出（play_defeat） ═══════════

## 全破定格必须**保存原 time_scale 再恢复**，不能硬写 1.0 ——
## 工作台有 12x 快进（同样是 Engine.time_scale），硬写会把工具拉回常速。
## 无 ctx 时演出其余部分全走守卫（静默跳过），所以本用例只锁定格这条不变量。
func test_play_defeat_hitstop_saves_and_restores_time_scale():
	add_child(_boss)                     # create_tween / 计时器需要入树
	var original := Engine.time_scale
	Engine.time_scale = 4.0              # 模拟工作台快进
	_boss.play_defeat()
	assert_almost_eq(Engine.time_scale, 4.0 * Boss.DEFEAT_HITSTOP_SCALE, 0.001,
		"定格应把时间倍率压低（保存原值 × 倍率）")
	_boss._restore_time_scale()          # 等价于定格计时器到点
	assert_almost_eq(Engine.time_scale, 4.0, 0.001, "必须恢复**原值** 4.0，而不是硬写 1.0")
	Engine.time_scale = original


## 定格途中 Boss 被回收（关卡结束/切场景）→ _exit_tree 兜底恢复，绝不把游戏留在慢动作
func test_play_defeat_exit_tree_restores_time_scale():
	var boss := Boss.new()
	add_child_autofree(boss)
	Engine.time_scale = 1.0
	boss.play_defeat()
	assert_lt(Engine.time_scale, 1.0, "已进入定格")
	boss._exit_tree()
	assert_almost_eq(Engine.time_scale, 1.0, 0.001, "出树兜底恢复")


## 记录被加进层的反色圈（只关心"加了几发、圆心/半径"）
class RingLayerSpy:
	extends MissCircleLayer
	var centers: Array[Vector2] = []
	var radii: Array[float] = []
	func add_circle(world_pos: Vector2, _duration: float = 0.8, max_radius: float = 1280.0,
			_start_radius: float = 0.0, _start_delay: float = 0.0, _fade_out: float = 0.0) -> void:
		centers.append(world_pos)
		radii.append(max_radius)


## 全破的反色圈必须**与自机 miss 同一套参数**（作者指出过：同心不等半径不是 miss 的做法）：
## 5 发同半径、圆心呈十字 ±100 偏移，外加 1 发延迟补闪 —— 共 6 发。
func test_play_defeat_spawns_miss_style_inverted_rings():
	var rt := StageRuntime.new()
	rt.miss_layer = RingLayerSpy.new()   # 注入槽可直接写 → 拿来数圈
	var ctx := StageContext.new(null)
	ctx.stage = rt
	var boss := Boss.new()
	add_child_autofree(boss)
	boss.setup(BossData.new(), ctx)
	boss.global_position = Vector2(111.0, 222.0)

	boss.play_defeat()

	var layer: RingLayerSpy = rt.miss_layer
	assert_eq(layer.centers.size(), 6, "5 发十字 + 1 发延迟补闪 = 6 发")
	var expected_centers := 0
	for offset in Boss.DEFEAT_RING_OFFSETS:
		if layer.centers.has(boss.global_position + offset):
			expected_centers += 1
	assert_eq(expected_centers, 5, "五发圆心 = Boss 位置 + 十字偏移（与 miss 同）")
	for radius in layer.radii:
		assert_almost_eq(radius, Boss.DEFEAT_RING_RADIUS, 0.001, "六发同半径（1280 满屏）")
	Engine.time_scale = 1.0
	rt.free()


# ═══════════ 奖励分作废（miss / 用 bomb） ═══════════

## 轻量玩家桩：`EntityRegistry.get_player_resources()` 只认 `player.get("resources")`
class PlayerResStub:
	extends Node2D
	var resources: PlayerResources


## 接一个能读分数的 registry（`Boss._refs()` 优先用它）
func _bind_score_registry(p_boss: Boss) -> PlayerResources:
	var res := PlayerResources.new()
	res.reset_all()
	var player_stub := PlayerResStub.new()
	player_stub.resources = res
	add_child_autofree(player_stub)
	var registry := EntityRegistry.new()
	registry.bind_player(player_stub)
	p_boss.registry = registry
	return res


## bomb 与 miss **同罪**：本符卡奖励分作废，且奖励分**定格**（不再衰减、不再发数字 tick）
func test_bomb_fails_bonus_and_freezes_it():
	_boss.setup(BossData.new(), null)
	_boss._stage_id = 7
	var phase := _make_phase(1000, 30.0, false, 11)
	_boss.start_phase(phase)
	assert_false(_boss.is_bonus_failed(), "刚开卡不该作废")
	assert_gt(_boss.current_bonus(), 0, "符卡应有初始奖励分")

	GameEvents.player_bomb.emit("测试 bomb")

	assert_true(_boss.is_bonus_failed(), "用 bomb 应作废本符卡奖励分")
	var frozen := _boss.current_bonus()
	var ticks := [0]
	var cb := func(_b: int) -> void: ticks[0] += 1
	GameEvents.phase_bonus_tick.connect(cb)
	_boss._process(5.0)
	GameEvents.phase_bonus_tick.disconnect(cb)
	assert_eq(_boss.current_bonus(), frozen, "作废后不再衰减（UI 的「失败」要定格）")
	assert_eq(ticks[0], 0, "作废后不再发数字 tick（否则下一帧会覆盖「失败」）")


## miss 也作废（原有"miss 不算干净收取"的规则之上，再断掉奖励分）
func test_miss_fails_bonus():
	PracticeSession.is_practice_mode = false        # 正篇才走 miss 标记（练习走 _die）
	_boss.setup(BossData.new(), null)
	_boss._stage_id = 7
	_boss.start_phase(_make_phase(1000, 30.0, false, 12))
	GameEvents.player_missed.emit()
	assert_true(_boss.is_bonus_failed(), "miss 应作废本符卡奖励分")


## 还没开卡就用 bomb → 不作废（没在打这张卡）
func test_bomb_before_phase_does_not_fail_bonus():
	_boss.setup(BossData.new(), null)
	GameEvents.player_bomb.emit("测试 bomb")
	assert_false(_boss.is_bonus_failed(), "阶段开始前用 bomb 不该算在符卡头上")


## 作废后击破：**一分不给**（阶段本身照样算击破）
func test_failed_bonus_awards_no_score():
	_boss.setup(BossData.new(), null)
	_boss._stage_id = 7
	_boss.start_phase(_make_phase(100, 30.0, false, 13))
	var res := _bind_score_registry(_boss)
	GameEvents.player_bomb.emit("测试 bomb")
	_skip_hp_tween()
	_boss.take_damage(100)
	assert_eq(res.current_score, 0, "作废 → 奖励分一分不给")


## 对照组：没作废时照常给分（锁住"不是把给分整个关掉了"）
func test_clean_capture_awards_bonus():
	_boss.setup(BossData.new(), null)
	_boss._stage_id = 7
	_boss.start_phase(_make_phase(100, 30.0, false, 14))
	var res := _bind_score_registry(_boss)
	var expect := _boss.current_bonus()
	assert_gt(expect, 0, "符卡应有正奖励分（否则这条测试没意义）")
	_skip_hp_tween()
	_boss.take_damage(100)
	assert_eq(res.current_score, expect, "干净击破应照常给奖励分")
	assert_false(_boss.is_bonus_failed(), "没 miss / 没用 bomb → 不作废")


## **回归（作者报）**：作废后「只跳过奖励分」，`_process` 其余职责照常 ——
## 曾写成 `if is_bonus_failed(): return`（早退），把**开卡减伤倒计时**与**时限判定**一起掐掉：
## 后果是 miss 后符卡倒计时到 0 也不结束、减伤永久挂着。
func test_failed_bonus_still_times_out_and_clears_open_reduce():
	PracticeSession.is_practice_mode = false
	_boss.setup(BossData.new(), null)
	_boss._stage_id = 7
	var phase := _make_phase(1000, 1.0, false, 15)
	_boss.start_phase(phase)
	_boss._open_reduce_left = 0.5            # 开卡减伤还有 0.5s
	_boss._open_reduce_ratio = 0.5
	watch_signals(_boss)

	GameEvents.player_bomb.emit("测试 bomb")
	assert_true(_boss.is_bonus_failed(), "作废了")

	_boss._process(0.6)                      # 走掉减伤
	assert_eq(_boss._open_reduce_left, 0.0, "作废后减伤倒计时仍要照常走完")

	_boss._process(0.6)                      # 累计 1.2s > 时限 1.0s
	assert_signal_emitted(_boss, "phase_cleared", "作废后符卡仍应到点结束")
	assert_true(_boss._is_cleared, "阶段应已收尾（clear_phase 只置标记，不清 _phase_data）")

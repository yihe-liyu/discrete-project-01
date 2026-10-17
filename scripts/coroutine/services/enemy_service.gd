## EnemyService —— ctx.enemies（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 敌人生成服务 —— ctx.enemies 下的"生成 / 回收敌人"动词。
## 与 ctx.bullets.shoot_spread 对称：内容只说"生成这份配置"，机制（实例化/挂载协程/入场景）在 StageRuntime。

var ctx: StageContext


## 按 EnemyData 生成敌人（配置非法 → 响亮报错并返回 null；无 ctx/stage → null）
func spawn(data: EnemyData) -> Enemy:
	var errs := data.validate()
	for e in errs:
		push_error("EnemyData 配置错误: " + e)
	if not errs.is_empty():
		return null
	if ctx == null or ctx.stage == null:
		return null
	return ctx.stage.spawn_enemy_data(data, ctx)


## 回收一只敌人 —— **静默**：不掉道具、不计分、不发 `enemy_killed`、不播死亡特效。
## 用途：离场 / 超时清理（多数回收都属于这两类 —— 对齐子弹 `despawn()` 的"静默"口径）。
## ⚠️ **"被打死"是另一条路**：让 hp≤0（`Enemy.die()`）—— 那条才掉道具 / 播特效 / 计分。
## ⚠️ **只收杂兵 `Enemy`**：`Boss` 是 `Area2D` 的**兄弟类**不是子类，Boss 有自己的退场路径。
## 参数收 `Node2D`（= `CoroutineScript.target` 的静态类型 ⇒ 内容直接 `despawn(target)`，不必写 `as`），
## 类型不对时**响亮报出它到底是什么** —— 而不是像 `target as Enemy` 那样静默变 null
## 再被误诊成"敌人为空"（2026-10-04：这个误诊就是被测试顶出来的）。
## 不需要 ctx / stage（只是一次 `queue_free`，注销由 `Enemy._on_tree_exited` 自动做）。
## 返回是否真的回收了（空/已释放/类型不对 ⇒ false + 响亮；已排队释放 ⇒ false，静默不算错）。
func despawn(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		push_error("EnemyService.despawn(): 传入空 / 已释放的对象 —— 回收空跑")
		return false
	if not (enemy is Enemy):
		push_error("EnemyService.despawn(): 传进来的不是 Enemy（%s / %s）—— 本动词只收杂兵；Boss 走它自己的退场路径"
			% [enemy.name, enemy.get_class()])
		return false
	if enemy.is_queued_for_deletion():
		return false          # 已经要走了（打死 / 上一次回收 / 关卡拆掉）—— 静默，不算错
	enemy.queue_free()
	return true


## 回收一只敌人 **并播击破特效**（= `despawn()` + `ctx.effects.play_hit_effect(death_effect, 弹位置)`）。
## 用途：**看得见**的收兵（屏上清场）—— 与 `despawn()`（静默：屏外 / 超时回收）相对，
## 正好对应子弹那边的 `despawn()` / `despawn_clear()` 之分（2026-10-04 作者要求"清场要有击破特效"）。
## ⚠️ 仍然**不算战果**：不掉道具、不计分、不发 `enemy_killed`、不播死亡音效（那些是 `Enemy.die()`）。
## 敌人没配 `death_effect`（无 `EnemyData`）⇒ 只回收，不报错。
func despawn_clear(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not (enemy is Enemy):
		return despawn(enemy)      # 让 despawn 出**那一条**精确诊断（空 / 不是 Enemy）
	var e: Enemy = enemy
	if e.is_queued_for_deletion():
		return false
	if e.death_effect and ctx != null:
		ctx.effects.play_hit_effect(e.death_effect, e.global_position)
	return despawn(e)


## 回收场上**所有杂兵**（**不动 Boss**：Boss 不是 `Enemy`，天然被筛掉），**并逐只播击破特效**。
## 返回实际回收数量。用途：道中收尾 / 换段落时清场 —— 与 `EntityRegistry.clear()` 的区别是
## **那个连 Boss 一起释放**且清空名单（那是"拆关卡"语义），本动词是内容语义的"清杂兵"。
## ⚠️ 要**静默**逐只清场（不想满屏爆特效）就自己循环 `despawn()`。
func despawn_all() -> int:
	if ctx == null or ctx.stage == null:
		return 0
	var reg: EntityRegistry = ctx.stage.entity_registry
	if reg == null:
		return 0
	var n := 0
	for e in reg.get_active_enemies():
		if e is Enemy and despawn_clear(e):
			n += 1
	return n

## EnemyService —— ctx.enemies（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 敌人生成服务 —— ctx.enemies 下的"生成敌人"动词。
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

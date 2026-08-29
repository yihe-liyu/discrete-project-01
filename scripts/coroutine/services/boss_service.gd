## BossService —— ctx.boss（无 class_name：使用处 preload 引用，避免 headless 全局类缓存问题）
extends RefCounted
## 关卡 Boss 查询服务 —— ctx.boss 下的"现在场上有没有 Boss / 取哪个"动词。
## 内容只问"有没有/取哪个"，内部才摸 GameState.active_enemies（机制）。
## 注意：不叫 get() —— 会遮蔽 Object.get(property)，故用 current()/exists()。

## 当前场上的 Boss（无 → null）
func current() -> Boss:
	return GameState.get_boss()

## 当前场上是否有 Boss
func exists() -> bool:
	return current() != null

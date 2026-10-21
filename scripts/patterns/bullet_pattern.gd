## 弹幕 pattern 基类（内容层）。
##
## **边界**：pattern 只负责“一次发射”的生成（方向/数量/调用 `ctx.bullets`），
## 不做每帧逐弹逻辑——那类逻辑必须编译进原生 `BulletLifecycle`。
##
## 具体 pattern 放在 `data/patterns/*.gd`，**不写 `class_name`**，由内容 preload；
## 只有这个基类 / `PatternParams` 进全局类表。
class_name BulletPattern
extends RefCounted

## 发射一次。`params` 是手感数据的默认值；代码可以在调用前改它。
func fire(_ctx: StageContext, _params: PatternParams, _origin: Vector2, _direction: Vector2) -> void:
	push_error("BulletPattern.fire(): 未实现（具体 pattern 应覆写）")

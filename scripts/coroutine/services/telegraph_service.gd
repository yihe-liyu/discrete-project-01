## 路径预览服务 —— ctx.telegraph（无 class_name：使用处 preload，避免 headless 全局类缓存问题）。
## 内容只给 lifecycle + 出生状态；服务负责跑 chain、把 points 交给场景里的 TelegraphPath。
## 无注入节点（测试 / 无场景）时静默跳过，不改变内容行为。

const PREVIEW := preload("res://scripts/telegraph/lifecycle_preview.gd")

## 场景里的展示节点（组合根 GameScene 注入；为空 = 静默跳过）。
var telegraph_path: Node


## 从当前 phase 起顺序预览，并立即显示。
## [code]max_time[/code] 是整个 chain 的上限；[code]phase_index[/code] 通常 0。
func show_chain(lifecycle: BulletLifecycle, origin: Vector2, direction: Vector2,
		speed: float, max_time: float = 4.0, phase_index: int = 0,
		color: Color = Color(1.0, 0.82, 0.35, 0.85), width: float = 3.0) -> Dictionary:
	var heading := direction.normalized() if direction != Vector2.ZERO else Vector2.UP
	var result := PREVIEW.evaluate_chain(
		lifecycle, phase_index, origin, heading * speed, heading,
		1.0 / 60.0, max_time)
	if telegraph_path != null and is_instance_valid(telegraph_path) \
			and result.points.size() >= 2:
		telegraph_path.call("show_path", result.points, color, width)
	return result


## 清掉当前预览。
func clear() -> void:
	if telegraph_path != null and is_instance_valid(telegraph_path):
		telegraph_path.call("clear_path")

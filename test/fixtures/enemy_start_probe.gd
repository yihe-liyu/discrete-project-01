extends CoroutineScript
## 夹具：验证敌人行为在 _on_start() 里 target 已经入树，且可以直接创建 tween。

var started_in_tree: bool = false


func _on_start() -> void:
	started_in_tree = target != null and target.is_inside_tree()
	ctx.enemies.move_to(target, target.global_position + Vector2(10.0, 0.0), 0.5)

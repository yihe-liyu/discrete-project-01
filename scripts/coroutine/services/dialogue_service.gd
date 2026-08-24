class_name DialogueService
extends RefCounted
## 对话服务

## 弱引用 ctx：避免 StageContext ↔ DialogueService 形成 RefCounted 环导致关卡退出后泄漏
var _ctx_ref: WeakRef
var ctx: StageContext:
	get:
		return _ctx_ref.get_ref() as StageContext if _ctx_ref else null
	set(value):
		_ctx_ref = weakref(value) if value else null

const DialogueBoxScene = preload("res://scenes/ui/dialogue_box.tscn")

## 播放一段对话（DialogueSteps 步骤序列，台词已内联）—— 唯一入口
func play_steps(steps: Array) -> float:
	if not ctx or not ctx.active() or not is_instance_valid(ctx.runner):
		return 0.0
	var box := DialogueBoxScene.instantiate()
	ctx.runner.get_tree().current_scene.add_child(box)
	ctx.runner.pause()
	box.finished.connect(func(): ctx.runner.resume(), CONNECT_ONE_SHOT)
	box.play_steps(steps)
	return 0.0



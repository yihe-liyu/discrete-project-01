## 对话服务
class_name DialogueService
extends RefCounted

## 弱引用 ctx：避免 StageContext ↔ DialogueService 形成 RefCounted 环导致关卡退出后泄漏
var _ctx_ref: WeakRef
var ctx: StageContext:
	get:
		return _ctx_ref.get_ref() as StageContext if _ctx_ref else null
	set(value):
		_ctx_ref = weakref(value) if value else null

const DIALOGUE_BOX_SCENE = preload("res://scenes/ui/dialogue_box.tscn")

## 播放一段对话（DialogueSteps 步骤序列，台词已内联）—— 唯一入口
func play_steps(steps: Array) -> float:
	if not ctx or not ctx.active() or not is_instance_valid(ctx.runner):
		return 0.0
	if not is_instance_valid(ctx.stage):
		push_error("DialogueService: ctx.stage 未注入，无法挂对话框（不再摸 current_scene）")
		return 0.0
	var box := DIALOGUE_BOX_SCENE.instantiate()
	# 对话框自己是 CanvasLayer；挂到组合根注入的 StageRuntime 即可，层级由 box.layer=40 决定。
	ctx.stage.add_child(box)
	ctx.runner.pause()
	box.finished.connect(func(): ctx.runner.resume(), CONNECT_ONE_SHOT)
	box.play_steps(steps)
	return 0.0



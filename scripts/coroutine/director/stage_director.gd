class_name StageDirector
extends RefCounted
## 场景导演 —— 内容层的"场景动词"入口。
## 持有 StageContext；提供 bgm / boss / 对话 / 事件路由 等跨子系统场景动词。
## 内部才碰 ctx.stage / ctx.objects / GameEvents / 机制；内容只调动词。
## 动词时序无关：可单独调用（符卡练习），也可被 Timeline 摆放。
##
## 事件路由：on(key, handler) 取代内容里的大 match _on_dialogue_event。

var ctx: StageContext

var _handlers: Dictionary = {}   # event_name -> Callable
var _is_connected: bool = false

func _init(p_ctx: StageContext) -> void:
	ctx = p_ctx

## 播 BGM（接受 AssetRegistry 的 key）
func bgm(key: String) -> StageDirector:
	var stream: AudioStream = AssetRegistry.get_bgm(key)
	if stream:
		ctx.audio.play_bgm(stream)
	else:
		push_warning("StageDirector.bgm: 未找到 BGM '%s'" % key)
	return self

## 生成 Boss：spawn + 注册命名槽位 + 进场，返回 BossHandle（默认隐藏真名）。
## **同名槽位幂等**：已经有一只就只返回句柄（不重复生成/进场）——
## 于是内容侧不必自己写 `if not handle.exists()` 之类的防重入判断。
func boss(key: String, data: BossData, from: Vector2, to: Vector2,
		hide: String = "？？？") -> BossHandle:
	var handle := BossHandle.new(key, data, hide, ctx.objects)
	if handle.exists():
		return handle
	if ctx.stage == null:
		push_warning("StageDirector.boss: ctx.stage 未装配（由 StageRuntime 回填）")
		return handle
	var boss_node := ctx.stage.spawn_boss(data, from, ctx) as Boss
	if boss_node == null:
		push_warning("StageDirector.boss: spawn_boss 返回 null（槽位 %s）" % key)
		return handle
	ctx.objects.register(key, boss_node, Boss)
	if hide != "":
		handle.hide_name()
	handle.enter(to, from)
	return handle

## 播对话（`DialogueSteps` 版 DSL，台词已内联）。
## 收 **DialogueSteps 本身**，不是它的 `.steps` 数组：内容层不必知道步骤容器的内部结构，
## 且参数有类型 → 传错东西在**编译期**就被拦住（Array 参数要等运行时才炸）。
func dialogue(p_steps: DialogueSteps) -> StageDirector:
	if p_steps == null:
		push_warning("StageDirector.dialogue: steps 为 null，跳过")
		return self
	ctx.play_dialogue_steps(p_steps.steps)
	return self

## **这关到此为止**（内容唯一收尾动词）。落点是 `StageRuntime.finish_stage()`
## （保留 current_stage 只停脚本 → 走完整 stage_cleared 收尾；**不是** stop_stage）。
## 延迟请用时间线摆：`timeline.wait(3.0).do(func(): director.finish_stage())`。
func finish_stage() -> StageDirector:
	if ctx.stage == null:
		push_warning("StageDirector.finish_stage: ctx.stage 未装配（由 StageRuntime 回填）")
		return self
	ctx.stage.finish_stage()
	return self

## 监听对话事件（GameEvents.dialogue_event）→ 路由到 handler。
## **handler 里不需要再写 `if ctx.active()`**：关卡拆掉/未装配后事件一律不派发（见 `_route`）。
func on(event_name: String, handler: Callable) -> StageDirector:
	if not _is_connected:
		GameEvents.dialogue_event.connect(_route)
		_is_connected = true
	_handlers[event_name] = handler
	return self

## 事件派发的**唯一**关卡存活判据：关卡已拆（脚本 stop / runner 失效）→ 一律忽略。
## 集中在这里，handler 才能只写"要做什么"。
## 注意对话播放期间 runner 是 **paused 而非 stopped**，`active()` 仍为 true ——
## 所以战前那些行间事件（boss_enter/bgm_switch/boss_fight）照常生效。
func _route(event_name: String) -> void:
	if ctx == null or not ctx.active():
		return
	var handler: Callable = _handlers.get(event_name, Callable())
	if handler.is_valid():
		handler.call()

## 断开事件连接 + 清空本关命名槽位（关卡 _exit_tree 调用）
func dispose() -> void:
	if _is_connected and GameEvents.dialogue_event.is_connected(_route):
		GameEvents.dialogue_event.disconnect(_route)
	_is_connected = false
	_handlers.clear()
	ctx.objects.clear()

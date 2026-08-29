class_name StageDirector
extends RefCounted
## 场景导演 —— 内容层的"场景动词"入口。
## 持有 StageContext；提供 bgm / boss / 对话 / 事件路由 等跨子系统场景动词。
## 内部才碰 StageManager / StageObjects / GameEvents / 机制；内容只调动词。
## 动词时序无关：可单独调用（符卡练习），也可被 Timeline 摆放。
##
## 事件路由：on(key, handler) 取代内容里的大 match _on_dialogue_event。

var ctx: StageContext

var _handlers: Dictionary = {}   # event_name -> Callable
var _connected: bool = false

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
func boss(key: String, data: BossData, from: Vector2, to: Vector2,
		hide: String = "？？？") -> BossHandle:
	var b := StageManager.spawn_boss(data, from, ctx) as Boss
	StageObjects.register(key, b, Boss)
	var h := BossHandle.new(key, data, hide)
	if hide != "":
		h.hide_name()
	h.enter(to, from)
	return h

## 对已存在的 Boss 拿句柄（事件路由里操控用，不重复生成；name 用于揭名）。
func boss_ref(key: String, data: BossData) -> BossHandle:
	return BossHandle.new(key, data, "")

## 播对话（steps 版 DSL，台词内联）
func dialogue(steps: Array) -> StageDirector:
	ctx.play_dialogue_steps(steps)
	return self

## 监听对话事件（GameEvents.dialogue_event）→ 路由到 handler
func on(event_name: String, handler: Callable) -> StageDirector:
	if not _connected:
		GameEvents.dialogue_event.connect(_route)
		_connected = true
	_handlers[event_name] = handler
	return self

func _route(event_name: String) -> void:
	var h: Callable = _handlers.get(event_name, Callable())
	if h.is_valid():
		h.call()

## 断开事件连接 + 清空本关命名槽位（关卡 _exit_tree 调用）
func dispose() -> void:
	if _connected and GameEvents.dialogue_event.is_connected(_route):
		GameEvents.dialogue_event.disconnect(_route)
	_connected = false
	_handlers.clear()
	StageObjects.clear()

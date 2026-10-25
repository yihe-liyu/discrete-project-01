## 关卡上下文：协程脚本通过它访问内容动词，替代旧 StageAPI / autoload。
##
## [b]模型[/b][br]
## StageRuntime 创建 ctx 并回填 [member stage]；每个协程拿一份 ctx，服务按需懒加载：
## [codeblock]
## ctx.clock / bullets / player / enemies / boss / diff
## ctx.items / audio / effects / dialogue / objects
## ctx.background / decor / entity_registry / stage / runner / telegraph
## [/codeblock]
## 高频路径（每颗协程弹一个 ctx）只建实际用到的服务，默认从 8 个对象降到 2 个。
## [br]
## [b]边界[/b][br]
## - 无 stage 绑定时 bullets / effects / entity_registry 等为 null 或静默 no-op，测试友好。[br]
## - 不读 BulletManager.current / 全局实体注册表；由宿主显式注入 stage。[br]
## - boss / diff / enemies 是内部服务，不注册全局 class_name，由本类 preload 构造；
##   避免全局类名与 StageContext ↔ Service 的相互类型引用。[br]
## - objects 是 per-ctx 命名对象表，随关卡生命周期，不是 autoload。[br]
## - dialogue.play_steps 会暂停 runner 直到对话框结束。
class_name StageContext
extends RefCounted

## BossService 脚本（ctx.boss 的内部实现；不注册 class_name，只在本类 preload 构造）。
const BossService = preload("res://scripts/coroutine/services/boss_service.gd")
## DifficultyService 脚本（ctx.diff 的内部实现；不注册 class_name，只在本类 preload 构造）。
const DifficultyService = preload("res://scripts/coroutine/services/difficulty_service.gd")
## EnemyService 脚本（ctx.enemies 的内部实现；不注册 class_name，只在本类 preload 构造）。
const EnemyService = preload("res://scripts/coroutine/services/enemy_service.gd")
## TelegraphService 脚本（ctx.telegraph 的内部实现；不注册 class_name，只在本类 preload 构造）。
const TelegraphService = preload("res://scripts/coroutine/services/telegraph_service.gd")

## 协程时钟 / 生命周期（active、对话暂停都看它）。
var runner: CoroutineRunner
## 关卡运行时（由 StageRuntime 创建 ctx 时回填；内容经此拿注入槽 / 工厂）。
var stage: StageRuntime

# 服务懒加载（高频路径优化：每颗协程弹 new 一次 ctx，只创建用到的服务）
# 大多数子弹协程只用 bullets/player —— 从 8 个对象降到 2 个
var _clock_service: ClockService
var _bullet_service: BulletService
var _player_service: PlayerService
var _dialogue_service: DialogueService
var _item_service: ItemService
var _audio_service: AudioService
var _effect_service: EffectService
var _boss: BossService
var _diff: DifficultyService
var _enemy_service: EnemyService
var _telegraph_service: TelegraphService
var _stage_objects: StageObjects

## 时间服务：wait / wait_frames / next_tick / delay；内容的唯一时钟。
var clock: ClockService:
	get:
		if _clock_service == null:
			_clock_service = ClockService.new()
			_clock_service.runner = runner
		return _clock_service

## 弹幕 / 激光服务；无 stage 绑定 = null，方法静默 no-op。
## 每次取都重新指向当前 stage 的 BulletManager：自机射击 ctx 在 Player._ready 里创建，
## 那时组合根还没注入 bullet_manager，不能把第一次读到的 null 缓存下来。
var bullets: BulletService:
	get:
		if _bullet_service == null:
			_bullet_service = BulletService.new()
		_bullet_service.bullet_manager = stage.bullet_manager if stage else null
		return _bullet_service

## 只读自机查询：get_player / get_position（无自机 = null / ZERO）。
var player: PlayerService:
	get:
		if _player_service == null:
			_player_service = PlayerService.new()
			_player_service.ctx = self
		return _player_service

## 对话服务：play_steps（播放期间暂停 runner）。
var dialogue: DialogueService:
	get:
		if _dialogue_service == null:
			_dialogue_service = DialogueService.new()
			_dialogue_service.ctx = self
		return _dialogue_service

## 道具服务：spawn / spawn_fan。
var items: ItemService:
	get:
		if _item_service == null:
			_item_service = ItemService.new()
			_item_service.ctx = self
		return _item_service

## 音频服务：play_bgm / stop_bgm / play_sfx（不依赖 stage）。
var audio: AudioService:
	get:
		if _audio_service == null: _audio_service = AudioService.new()
		return _audio_service

## 特效服务：Miss 圈 / 命中特效；无 stage 时静默跳过。
var effects: EffectService:
	get:
		if _effect_service == null: _effect_service = EffectService.new()
		# 只认绑定的 stage，不回退全局。
		_effect_service.miss_layer = stage.miss_layer if stage else null  # 组合根注入；每取一次保持最新
		_effect_service.fx_pool = stage.fx_pool if stage else null        # 特效层同样由组合根注入
		return _effect_service

## Boss 查询 / 移动：current / exists / move_to / move_path。
var boss: BossService:
	get:
		if _boss == null:
			_boss = BossService.new()
			_boss.ctx = self
		return _boss

## 敌人生成服务：spawn / move_to / despawn（机制在 StageRuntime.spawn_enemy_data）。
var enemies: EnemyService:
	get:
		if _enemy_service == null:
			_enemy_service = EnemyService.new()
			_enemy_service.ctx = self
		return _enemy_service

## 难度服务：picked / pick / pick_from / at_least。
var diff: DifficultyService:
	get:
		if _diff == null: _diff = DifficultyService.new()
		return _diff

## 路径预览服务：show_chain / track_bullets / clear。
## 有 stage 时挂在 StageRuntime 上共享：敌人 ctx 释放不应清掉它发射的弹路径。
var telegraph: TelegraphService:
	get:
		if stage:
			if stage.telegraph_service == null:
				stage.telegraph_service = TelegraphService.new()
			_telegraph_service = stage.telegraph_service as TelegraphService
		elif _telegraph_service == null:
			_telegraph_service = TelegraphService.new()
		_telegraph_service.telegraph_path = stage.telegraph if stage else null
		_telegraph_service.bullet_manager = stage.bullet_manager if stage else null
		return _telegraph_service

## 战场实体注册表（自机 / 敌机 / Boss）——只认绑定的 stage。
## 无 stage 的 ctx（自机射击 / 子弹共享 ctx）由宿主显式绑定同一 StageRuntime，不再回退全局。
var entity_registry: EntityRegistry:
	get:
		return stage.entity_registry if stage and stage.entity_registry else null

## 命名对象注册表（per-ctx，随关卡生命周期；原 StageObjects autoload）
var objects: StageObjects:
	get:
		if _stage_objects == null: _stage_objects = StageObjects.new()
		return _stage_objects

## 构造；runner 是时钟与生命周期来源，通常由 StageRuntime / CoroutineScript 传入。
func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

## 从当前背景取装饰物管理器；无背景 = null。
## 背景场景用 StageBackground.get_decor_manager() 声明式持有，不再按节点名摸树。
func get_decor() -> DecorManager:
	var bg := get_background()
	if not is_instance_valid(bg):
		return null
	return bg.get_decor_manager()

## 装饰物管理器（同 get_decor()）。
var decor: DecorManager:
	get: return get_decor()


## 背景宿主（背景场景声明的 StageBackground）：相机 / 环境 / 雾 / FOV 的意图动词都在它上面。
## rotation 类参数一律弧度；内容不再 get_parent() 摸背景，拿它即可。
## 背景场景是自己的树：ctx.background.get_node("Ground") 这类按名字访问是允许的。
func get_background() -> StageBackground:
	return stage.current_background if stage else null


## 背景宿主（同 get_background()）。
var background: StageBackground:
	get: return get_background()

## runner 存在且 is_running；runner 停 = ctx 失效。
func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

## 播放步骤版对话（台词内联）；播放期间暂停 runner，结束后恢复。
## 返回值为历史占位（当前恒 0.0）。
func play_dialogue_steps(steps: Array) -> float:
	return dialogue.play_steps(steps)

## 取 runner 视口的可见矩形；无 runner = Rect2()。
## 这是 viewport 尺寸，不是 FIELD_* 场地框。
func get_field_rect() -> Rect2:
	if not is_instance_valid(runner): return Rect2()
	return runner.get_viewport().get_visible_rect()

## 道具便捷委托：items.spawn(type, position)。
func spawn_item(type: int, position: Vector2) -> void:
	items.spawn(type, position)

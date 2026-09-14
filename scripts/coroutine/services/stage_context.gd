class_name StageContext
extends RefCounted
## 关卡上下文 —— 协程拿这个代替 StageAPI

const BossService = preload("res://scripts/coroutine/services/boss_service.gd")
const DifficultyService = preload("res://scripts/coroutine/services/difficulty_service.gd")

var runner: CoroutineRunner
## 关卡运行时（由 StageRuntime 创建 ctx 时回填；内容经此拿注入槽/工厂）
var stage: StageRuntime
var _decor_manager: DecorManager

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
var _stage_objects: StageObjects

var clock: ClockService:
	get:
		if _clock_service == null: _clock_service = ClockService.new()
		return _clock_service

var bullets: BulletService:
	get:
		if _bullet_service == null:
			_bullet_service = BulletService.new()
			# 只认绑定的 stage，不回退 BulletManager.current（无 stage 的 ctx 由宿主显式绑 stage）。
			_bullet_service.bullet_manager = stage.bullet_manager if stage else null
		return _bullet_service

var player: PlayerService:
	get:
		if _player_service == null:
			_player_service = PlayerService.new()
			_player_service.ctx = self
		return _player_service

var dialogue: DialogueService:
	get:
		if _dialogue_service == null:
			_dialogue_service = DialogueService.new()
			_dialogue_service.ctx = self
		return _dialogue_service

var items: ItemService:
	get:
		if _item_service == null:
			_item_service = ItemService.new()
			_item_service.ctx = self
		return _item_service

var audio: AudioService:
	get:
		if _audio_service == null: _audio_service = AudioService.new()
		return _audio_service

var effects: EffectService:
	get:
		if _effect_service == null: _effect_service = EffectService.new()
		# 只认绑定的 stage，不回退全局。
		_effect_service.miss_layer = stage.miss_layer if stage else null  # 组合根注入；每取一次保持最新
		_effect_service.fx_pool = stage.fx_pool if stage else null        # 特效层同样由组合根注入
		return _effect_service

var boss: BossService:
	get:
		if _boss == null:
			_boss = BossService.new()
			_boss.ctx = self
		return _boss

var diff: DifficultyService:
	get:
		if _diff == null: _diff = DifficultyService.new()
		return _diff

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

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

## 装饰物管理器（树附着，懒加载）
func get_decor() -> DecorManager:
	if _decor_manager: return _decor_manager
	var background: StageBackground = stage.current_background if stage else null
	if not background: return null
	var mgr: DecorManager = background.get_node_or_null("DecorManager") as DecorManager
	if not mgr:
		mgr = DecorManager.new()
		mgr.name = "DecorManager"
		background.add_child(mgr)
	_decor_manager = mgr
	return mgr

## 便捷属性
var decor: DecorManager:
	get: return get_decor()

func active() -> bool:
	return is_instance_valid(runner) and runner.is_running

## 步骤版对话（DSL 步骤，台词内联）—— 唯一入口
func play_dialogue_steps(steps: Array) -> float:
	return dialogue.play_steps(steps)

func get_field_rect() -> Rect2:
	if not is_instance_valid(runner): return Rect2()
	return runner.get_viewport().get_visible_rect()

## 道具（便捷委托）
func spawn_item(type: int, position: Vector2) -> void:
	items.spawn(type, position)

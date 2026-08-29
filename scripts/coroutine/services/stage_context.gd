class_name StageContext
extends RefCounted
## 关卡上下文 —— 协程拿这个代替 StageAPI

const BossService = preload("res://scripts/coroutine/services/boss_service.gd")
const DifficultyService = preload("res://scripts/coroutine/services/difficulty_service.gd")

var runner: CoroutineRunner
var _decor_mgr: DecorManager

# 服务懒加载（高频路径优化：每颗协程弹 new 一次 ctx，只创建用到的服务）
# 大多数子弹协程只用 bullets/player —— 从 8 个对象降到 2 个
var _clock: ClockService
var _bullets: BulletService
var _player: PlayerService
var _dialogue: DialogueService
var _items: ItemService
var _audio: AudioService
var _effects: EffectService
var _boss: BossService
var _diff: DifficultyService

var clock: ClockService:
	get:
		if _clock == null: _clock = ClockService.new()
		return _clock

var bullets: BulletService:
	get:
		if _bullets == null: _bullets = BulletService.new()
		return _bullets

var player: PlayerService:
	get:
		if _player == null: _player = PlayerService.new()
		return _player

var dialogue: DialogueService:
	get:
		if _dialogue == null:
			_dialogue = DialogueService.new()
			_dialogue.ctx = self
		return _dialogue

var items: ItemService:
	get:
		if _items == null:
			_items = ItemService.new()
			_items.ctx = self
		return _items

var audio: AudioService:
	get:
		if _audio == null: _audio = AudioService.new()
		return _audio

var effects: EffectService:
	get:
		if _effects == null: _effects = EffectService.new()
		return _effects

var boss: BossService:
	get:
		if _boss == null: _boss = BossService.new()
		return _boss

var diff: DifficultyService:
	get:
		if _diff == null: _diff = DifficultyService.new()
		return _diff

func _init(p_runner: CoroutineRunner) -> void:
	runner = p_runner

## 装饰物管理器（树附着，懒加载）
func get_decor() -> DecorManager:
	if _decor_mgr: return _decor_mgr
	var bg: StageBackground = StageManager.current_background
	if not bg: return null
	var mgr: DecorManager = bg.get_node_or_null("DecorManager") as DecorManager
	if not mgr:
		mgr = DecorManager.new()
		mgr.name = "DecorManager"
		bg.add_child(mgr)
	_decor_mgr = mgr
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

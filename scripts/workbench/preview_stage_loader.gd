extends RefCounted
## 整关预览的关卡加载/重跑流水线（D3：从 Workbench 拆出的 StageLoader）。
##
## 只做“换关/重跑”的副作用顺序：停旧关 → 清弹/清 World → 重建背景 → RNG/自机复位
## → StageRuntime.load_stage → 时间轴/书签刷新。播放状态仍归 Playback；UI 只收回调。
##
## 背景实例由本服务持有，Workbench 通过 background() 读取（绘制/画框/背景开关共用）。

var _playback: Playback
var _stage_runtime: StageRuntime
var _bullet_manager: BulletManager
var _player: Player
var _world: Node2D
var _bg_viewport: SubViewport
var _timeline_bar
var _diff_selector: OptionButton
var _load_bookmarks: Callable
var _apply_runtime: Callable
var _background: Node


func setup(playback: Playback, stage_runtime: StageRuntime, bullet_manager: BulletManager,
		player: Player, world: Node2D, bg_viewport: SubViewport, timeline_bar,
		diff_selector: OptionButton, load_bookmarks: Callable, apply_runtime: Callable) -> void:
	_playback = playback
	_stage_runtime = stage_runtime
	_bullet_manager = bullet_manager
	_player = player
	_world = world
	_bg_viewport = bg_viewport
	_timeline_bar = timeline_bar
	_diff_selector = diff_selector
	_load_bookmarks = load_bookmarks
	_apply_runtime = apply_runtime


func background() -> Node:
	return _background


## 重跑/换关：顺序不能乱；旧背景必须先脱离树（协程/Tween 会抢同一台相机）。
func load_stage(stage_data: StageData) -> void:
	_playback.stop_fast_forward()
	if _apply_runtime.is_valid():
		_apply_runtime.call()

	_stage_runtime.stop_stage()
	_bullet_manager.reset_world()
	AudioManager.stop_bgm()
	_clear_world()
	_clear_background()

	SaveData.is_restarting = false
	SaveData.reset_all(_stage_runtime.entity_registry)
	if _diff_selector != null:
		SaveData.selected_difficulty = _diff_selector.selected

	if _playback.fixed_seed:
		RNG.set_seed(_playback.fixed_seed_value())
	else:
		RNG.randomize_seed()

	if _player != null:
		_player.reset()

	if _playback.show_bg and stage_data.background_scene:
		_background = stage_data.background_scene.instantiate()
		if _background is StageBackground:
			_stage_runtime.current_background = _background
		# 显式 PAUSABLE：背景演出随暂停冻结（否则继承 root 的 ALWAYS）
		_background.process_mode = Node.PROCESS_MODE_PAUSABLE
		_bg_viewport.add_child(_background)

	_stage_runtime.load_stage(stage_data)
	_timeline_bar.set_window(60.0)
	if _load_bookmarks.is_valid():
		_load_bookmarks.call()


func _clear_world() -> void:
	for child in _world.get_children():
		if child == _player or child == _stage_runtime:
			continue  # StageRuntime 是 World 下的常驻结构节点
		_world.remove_child(child)
		child.queue_free()


func _clear_background() -> void:
	if _background == null or not is_instance_valid(_background):
		_background = null
		return
	var bg_parent := _background.get_parent()
	if bg_parent != null:
		bg_parent.remove_child(_background)
	_background.queue_free()
	_background = null

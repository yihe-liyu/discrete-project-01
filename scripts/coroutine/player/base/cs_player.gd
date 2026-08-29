extends CoroutineRunner
class_name PlayerShootScript

var _options: Array[Node2D] = []
var _phase: int = 0
var ctx: StageContext

func start_shooting(p_ctx: StageContext):
	ctx = p_ctx
	run(_on_step.bind(ctx))


## 主状态机 — 子类不覆写
func _on_step(_ctx: StageContext) -> Variant:
	match _phase:
		0:
			run_parallel(_main_step.bind(ctx))
			run_parallel(_option_step.bind(ctx))
			_phase = 1
			return true
		1:
			var player: Player = ctx.player.get_player()
			if not is_instance_valid(player):
				return true
			_sync_options(player, ctx)
			return true
		_:
			return false


func stop():
	_cleanup_options()
	super.stop()


# ── 子类覆写 ──

## 返回 {visual_script, counts[], offsets_focus[], offsets_spread[]}
## 其中 counts/offsets 按 power 升序索引，如 [2, 4] 表示 power_low→2, power_high→4
func _option_setup() -> Dictionary:
	return {}


## 主射击：返回 frame 间隔（seconds）
func _main_shoot(_ctx: StageContext, _player: Player) -> float:
	return 0.0


## 僚机射击：返回 frame 间隔（seconds）。options > 0 确保有僚机
func _option_shoot(_ctx: StageContext, _options_count: int) -> float:
	return 0.0


# ── 通用实现 ──

func _main_step(_ctx: StageContext) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true
	var player: Player = ctx.player.get_player()
	if not is_instance_valid(player):
		return true
	var interval := _main_shoot(_ctx, player)
	ctx.audio.play_sfx(AssetRegistry.sounds["player_shoot"], -12.0)
	return interval


func _option_step(_ctx: StageContext) -> Variant:
	if not Input.is_action_pressed("shoot"):
		return true
	if _options.size() > 0:
		return _option_shoot(_ctx, _options.size())
	return true


func _sync_options(leader: Node2D, _ctx: StageContext) -> void:
	var setup := _option_setup()
	if setup.is_empty():
		return
	
	var pw := GameState.power_raw
	var focused := Input.is_action_pressed("focus")
	
	var levels: Array = setup.get("counts", [])
	var offsets_focus: Array = setup.get("offsets_focus", [])
	var offsets_spread: Array = setup.get("offsets_spread", [])
	var visual_script: Script = setup.get("visual_script")
	
	# 确定当前 power 等级
	var idx := 0
	for i in range(levels.size() - 1, -1, -1):
		if pw >= setup.get("power_thresholds", [0])[i]:
			idx = i
			break
	
	var wanted: int = levels[idx] if idx < levels.size() else 0
	var offsets: Array = (offsets_focus[idx] if focused else offsets_spread[idx]) if idx < offsets_focus.size() else []
	
	while _options.size() < wanted:
		var opt := Node2D.new()
		opt.global_position = leader.global_position
		opt.z_index = LayerConfig.OPTION
		leader.get_parent().add_child(opt)

		var visual: OptionVisual = visual_script.new() as OptionVisual
		visual.name = "Visual"
		opt.add_child(visual)
		visual.setup(opt)

		var follow := OptionFollow.new()
		follow.name = "Follow"
		follow.leader = leader
		opt.add_child(follow)
		follow.start(ctx, opt)

		_options.append(opt)

	while _options.size() > wanted:
		var opt = _options.pop_back()
		opt.queue_free()

	if offsets.size() > 0:
		for i in _options.size():
			var follow = _options[i].get_node_or_null("Follow") as OptionFollow
			if follow:
				follow.offset = offsets[i]

	for opt in _options:
		var visual = opt.get_node_or_null("Visual") as OptionVisual
		if visual:
			visual.update_visual(ctx, leader)


func _shoot_options(_ctx: StageContext, bullet_data: BulletData, count: int, spread: float, dir: Vector2, offset: Vector2) -> void:
	for opt in _options:
		ctx.bullets.shoot_spread(bullet_data, count, spread, dir, opt.global_position + offset)


func _cleanup_options() -> void:
	for opt in _options:
		if is_instance_valid(opt):
			opt.queue_free()
	_options.clear()

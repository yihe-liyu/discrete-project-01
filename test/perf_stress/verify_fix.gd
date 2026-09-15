extends Node
## 手动验证：子机跟随（OptionFollow）。
## 运行：godot --path . res://test/perf_stress/verify_fix.tscn
## 注：诱导弹转向已原生（`test/reference/behavior/homing_behavior.gd`），不再经 GDScript 协程，本台只留子机项。
func _ready():
	# ── 子机跟随 ──
	var leader := Node2D.new()
	var opt := Node2D.new()
	add_child(leader)
	add_child(opt)
	leader.global_position = Vector2(448, 600)
	opt.global_position = Vector2(448, 600)
	var follow := OptionFollow.new()
	opt.add_child(follow)
	follow.leader = leader
	var ctx1 := StageContext.new(follow)
	follow.start(ctx1, opt)
	print("[dbg] start后 is_running=%s ctx.active=%s _lerp=%.3f" % [follow.is_running, ctx1.active(), follow._lerp_factor])
	await get_tree().physics_frame
	print("[dbg] 1帧后 opt=%s" % str(opt.global_position))
	leader.global_position = Vector2(600, 500)
	for i in 60:
		await get_tree().physics_frame
	print("[verify] 子机位置=%s（应接近 600,500）" % str(opt.global_position))
	opt.queue_free()
	leader.queue_free()
	get_tree().quit()

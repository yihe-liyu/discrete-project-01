extends Node
## 验证修复：子机跟随 + 诱导弹转向
func _ready():
	# ── 1. 子机跟随 ──
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

	# ── 2. 诱导弹转向（用带 velocity 的临时脚本）──
	var enemy := Node2D.new()
	enemy.global_position = Vector2(700, 300)
	add_child(enemy)
	var entity_registry := EntityRegistry.new()
	entity_registry.register_enemy(enemy)
	var bscript := GDScript.new()
	bscript.source_code = "extends Node2D\nvar velocity := Vector2.ZERO\nfunc _ready(): velocity = Vector2(0,-500)"
	bscript.reload()
	var bullet_node: Node2D = Node2D.new()
	bullet_node.set_script(bscript)
	bullet_node.global_position = Vector2(448, 480)
	add_child(bullet_node)
	bullet_node.velocity = Vector2(0, -500)
	var homing := MoveHoming.new()
	var ctx2 := StageContext.new(homing)
	homing.start(ctx2, bullet_node)
	print("[dbg] homing start后 _tl=%s is_running=%s" % [homing._timeline != null, homing.is_running])
	for i in 60:
		homing.tick_manual(1.0 / 60.0)
	print("[verify] 诱导弹位置=%s 速度=%s（应转向敌人方向）" % [str(bullet_node.global_position), str(bullet_node.velocity)])
	entity_registry.unregister_enemy(enemy)
	get_tree().quit()

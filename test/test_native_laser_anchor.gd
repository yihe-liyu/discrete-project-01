extends GutTest
## L3.5-3b 回归（端到端桥接）：魔理沙激光段必须贴在**子机锚点**上，而不是自机。
## 历史 bug：原生 anchor_drift 完全忽略 anchor_id / use_global，段全粘在 player 上。



func before_each() -> void:
	var bullet_manager := BulletManager.new()
	bullet_manager.name = "BulletManager"
	add_child_autofree(bullet_manager)


func after_each() -> void:
	BulletManager.current.clear_all()


func test_marisa_laser_segments_track_anchor() -> void:
	var ns = BulletManager.current.kernel_system() as KernelNativeSystem
	if ns == null or not ns.enable_native_behaviors:
		pending("无原生行为管道"); return
	var anchor: Node2D = add_child_autofree(Node2D.new())
	anchor.global_position = Vector2(340.0, 560.0)
	var d := BulletData.new().enemy().blend(true).tex("小玉")
	d.velocity = Vector2.UP * 100.0
	d.trajectory(BulletLifecycle.marisa_laser(0, Vector2.ZERO, 0.0, 800.0, 0.0),
		{&"id": anchor.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true})
	BulletManager.current.shoot_bullet(d, Vector2(200.0, 700.0), Vector2.UP)
	assert_eq(ns.get_active_count(), 1, "激光段应进内核池")
	for i in 3:
		await get_tree().physics_frame
	var pos: Vector2 = ns.get_position(0)
	# 旧原生用 player(=Vector2.ZERO) + offset → x=0；修复后 x 必须贴锚点。
	assert_almost_eq(pos.x, 340.0, 2.0, "段应贴在子机锚点 x（忽略锚点会停在 player.x=0）")
	assert_lt(pos.y, 561.0, "段应从锚点向上漂")
	assert_gt(pos.y, 470.0, "三帧只漂 ~27px，不应飞走")

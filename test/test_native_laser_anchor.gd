extends GutTest
## L3.5-3b 回归（端到端桥接）：魔理沙激光段必须贴在**子机锚点**上，而不是自机。
## 现在走原生 anchor_drift + 宿主 anchor slot，不再经过 lifecycle program。



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
	# no_spawn_fog：本用例只验锚点漂移，别被出生雾冻结 0.3s 干扰
	var d := SpawnSpec.new().enemy().no_spawn_fog().blend(true).tex("小玉")
	d.velocity = Vector2.UP * 100.0
	d.with_behavior(BulletBehaviors.anchor_drift(0.0, 800.0, 0.0, true))
	d.lifecycle_anchor = {&"id": anchor.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true}
	BulletManager.current.shoot_spec(d, Vector2(200.0, 700.0), Vector2.UP)
	assert_eq(ns.get_active_count(), 1, "激光段应进内核池")
	for i in 3:
		await get_tree().physics_frame
	var pos: Vector2 = ns.get_position(0)
	# 旧原生用 player(=Vector2.ZERO) + offset → x=0；修复后 x 必须贴锚点。
	assert_almost_eq(pos.x, 340.0, 2.0, "段应贴在子机锚点 x（忽略锚点会停在 player.x=0）")
	assert_lt(pos.y, 561.0, "段应从锚点向上漂")
	assert_gt(pos.y, 470.0, "三帧只漂 ~27px，不应飞走")


func test_clear_laser_bullets_only_clears_laser_kind() -> void:
	var ns = BulletManager.current.kernel_system() as KernelNativeSystem
	if ns == null:
		pending("无内核系统"); return
	var laser := SpawnSpec.new().enemy().no_spawn_fog()
	laser.kind = BulletType.Kind.LASER
	laser.velocity = Vector2.UP * 100.0
	laser.with_behavior(BulletBehaviors.anchor_drift(0.0, 800.0, 0.0, true))
	BulletManager.current.shoot_spec(laser, Vector2(200.0, 700.0), Vector2.UP)

	var point := SpawnSpec.new().enemy().no_spawn_fog()
	point.velocity = Vector2.UP * 100.0
	BulletManager.current.shoot_spec(point, Vector2(220.0, 700.0), Vector2.UP)

	assert_eq(ns.get_active_count(), 2, "先有 1 LASER + 1 POINT")
	BulletManager.current.clear_laser_bullets()
	assert_eq(ns.get_active_count(), 1, "只清 LASER，不动普通弹")

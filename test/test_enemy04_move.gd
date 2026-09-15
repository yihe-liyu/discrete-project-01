extends GutTest
## enemy04 移动测试：匀速下移直到离开屏幕（弹幕结束后移动不中断）

const ENEMY04 = preload("res://data/stages/stage01/enemy/enemy04.gd")


func test_moves_down_until_offscreen() -> void:
	var cs: CoroutineScript = ENEMY04.new()
	autofree(cs)  # CoroutineScript 是 Node，不挂树也不释放会成孤儿
	var tgt := Node2D.new()
	add_child_autofree(tgt)
	tgt.global_position = Vector2(448, 100)
	cs.target = tgt
	cs.start_fast(null, tgt)

	# 匀速下移 120px/s：每 0.1s 推进 12px。前 50 帧（y=100→700）应仍在屏内
	var frames := 0
	var is_alive := true
	while frames < 50:
		is_alive = cs.tick_fast(0.1)
		frames += 1
		if not is_alive:
			break
	assert_true(is_alive, "出屏前应持续移动")
	assert_gt(tgt.global_position.y, 100.0 + 120.0, "应已下移（120px/s × 等价推进）")

	# 继续：直到离开屏幕（下缘 + 32px 宽限）→ 返回 false
	# 从 y=100 到 VIEW_HEIGHT+32=992，120px/s 需 ~75 帧，200 内应绰绰有余
	var out_frames := 0
	while cs.tick_fast(0.1) and out_frames < 2000:
		out_frames += 1
		if out_frames >= 1999:
			break
	assert_lt(out_frames, 200, "应在 200 帧内出屏")
	assert_gt(tgt.global_position.y, GameConfig.VIEW_HEIGHT + 32.0, "结束时应在屏幕之外（下缘 + 32px）")

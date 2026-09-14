extends GutTest
## 回归：BehaviorProcessor 多弹**同帧** request_despawn 必须**全部回收**。
## 旧实现升序 drain：despawn 是 swap-with-last —— 先回收小 id 会把大 id 的行搬到小 id 槽
## 并缩小 _active_count，使后续大 id 越界被**静默丢弃**（症状：残留 / bounce 重复发射）。


class DespawnIds extends Behavior:
	## 请求回收指定的行 id（其余不动）。
	var ids: Array = []

	func process(sys: BulletSystem, id: int, _ctx: BehaviorContext) -> void:
		if ids.has(id):
			sys.request_despawn(id)


func _setup() -> Array:
	var system: BulletSystem = autofree(BulletSystem.new())
	var proc: BehaviorProcessor = autofree(BehaviorProcessor.new())
	proc.setup(system, BehaviorContext.new())
	return [system, proc]


func test_drain_removes_all_when_all_request() -> void:
	var s := _setup()
	var system: BulletSystem = s[0]
	var proc: BehaviorProcessor = s[1]
	var beh := DespawnIds.new()
	beh.ids = [0, 1, 2, 3, 4]
	proc.register_behavior(&"all_despawn", beh)
	var bt := BulletType.new()
	for i in 5:
		system.spawn(bt, Vector2(i, 0), Vector2.ZERO, Color.WHITE, &"all_despawn")
	proc.process()
	assert_eq(system.get_active_count(), 0, "全部请求回收 → 应清空（升序 drain 会残留）")


func test_drain_removes_high_id_same_frame() -> void:
	var s := _setup()
	var system: BulletSystem = s[0]
	var proc: BehaviorProcessor = s[1]
	var beh := DespawnIds.new()
	beh.ids = [0, 2]   # 小 id + 大 id 同帧回收
	proc.register_behavior(&"mix_despawn", beh)
	var bt := BulletType.new()
	for i in 3:
		system.spawn(bt, Vector2((i + 1) * 10.0, 0), Vector2.ZERO, Color.WHITE, &"mix_despawn")
	proc.process()
	assert_eq(system.get_active_count(), 1, "回收 #0/#2 后应剩 1 个（旧的升序 drain 会剩 2 个）")
	assert_true(system.get_position(0).is_equal_approx(Vector2(20.0, 0)), "剩下的是原 #1（pos=20）")

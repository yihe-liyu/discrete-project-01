extends GutTest
## `ctx.bullets`（BulletService）的清场动词：**即时**全屏清敌弹 **并逐颗播消弹特效**。
## 与 `death_clear()` 的膨胀圈相对 —— 这两条的语义差是本文件的重点。
##
## ⚠️ 数弹**不能**用 `active_count()`：内核把"纯特效行"也放进**同一个 store**
## （特效行 `_type_index = -1` ⇒ `get_type(i) == null`），所以 `active_count()` 是"弹 + 特效"的总数。
## `sweep_enemy_bullets` 自己也是这么区分的 —— 这里照抄同一条判据。

const BULLET_SERVICE = preload("res://scripts/coroutine/services/bullet_service.gd")


func _mk_manager() -> BulletManager:
	var bm := BulletManager.new()
	add_child_autofree(bm)          # 入树 ⇒ 装配内核后端
	return bm


func _mk_data() -> BulletData:
	var lc := BulletLifecycle.new()
	lc.until_elapsed(5.0).despawn()   # 活得够久，不会自己消失
	return BulletData.new().tex("小玉").speed(100.0).enemy().trajectory(lc)


func _bind(bm: BulletManager):
	var svc = BULLET_SERVICE.new()
	svc.bullet_manager = bm
	return svc


## 只数**真弹**（`get_type(i) != null`）
func _bullet_count(sys: KernelNativeSystem) -> int:
	var n := 0
	for i in sys.get_active_count():
		if sys.get_type(i) != null:
			n += 1
	return n


## 特效行数 = 总数 − 真弹数
func _fx_count(sys: KernelNativeSystem) -> int:
	return sys.get_active_count() - _bullet_count(sys)


## 即时全屏清弹：当帧一颗不剩（距离无关）**且每颗都留下一条消弹特效**
func test_clear_enemy_bullets_wipes_field_and_spawns_clear_fx() -> void:
	var bm := _mk_manager()
	await get_tree().process_frame
	var sys := bm.kernel_system()
	if sys == null or not sys.is_native_ready():
		pending("无原生扩展")
		return
	var data := _mk_data()
	bm.shoot_bullet(data, Vector2.ZERO, Vector2.DOWN)
	bm.shoot_bullet(data, Vector2(300, 100), Vector2.DOWN)
	assert_eq(_bullet_count(sys), 2, "应有 2 颗弹")
	var fx_before := _fx_count(sys)

	_bind(bm).clear_enemy_bullets()
	assert_eq(_bullet_count(sys), 0, "即时清弹后应一颗不剩（全屏，与距离无关）")
	assert_eq(_fx_count(sys) - fx_before, 2, "**清场要看得见**：每颗被清的弹各播一条消弹特效（同色提亮 1.5×）")

	# 无管理器 = 静默 no-op（服务契约：无场景上下文不崩）
	BULLET_SERVICE.new().clear_enemy_bullets()


## 与 `death_clear()` 的语义差：那是**膨胀圈**（当帧只清圈内、要时间胀开），本动词是**当帧清空**
func test_clear_is_immediate_unlike_death_clear() -> void:
	var bm := _mk_manager()
	await get_tree().process_frame
	var sys := bm.kernel_system()
	if sys == null or not sys.is_native_ready():
		pending("无原生扩展")
		return
	var data := _mk_data()
	bm.shoot_bullet(data, Vector2(300, 0), Vector2.DOWN)    # 离圈心很远 ⇒ 膨胀圈当帧清不到
	bm.shoot_bullet(data, Vector2(400, 0), Vector2.DOWN)
	assert_eq(_bullet_count(sys), 2, "应有 2 颗弹")

	var svc = _bind(bm)
	svc.death_clear(Vector2.ZERO, 100.0, 1.0, 30.0)          # 小圈、1 秒胀开
	assert_eq(_bullet_count(sys), 2, "死亡清弹圈是**膨胀**的：当帧清不到远处的弹")

	svc.clear_enemy_bullets()
	assert_eq(_bullet_count(sys), 0, "即时清弹不分距离、当帧清空")

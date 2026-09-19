extends GutTest
## FxPool 池化语义（取代 HitEffectPool autoload）。无场景依赖，直接实例化挂树。

const CLEAR_FX = preload("res://scenes/effect/hit_effect_marisa_option01.tscn")

var _fx_pool: FxPool


func before_each():
	_fx_pool = FxPool.new()
	add_child_autofree(_fx_pool)


func test_play_activates_visible_instance_under_layer():
	var eff: HitEffect = _fx_pool.play(CLEAR_FX, Vector2(10, 20))
	assert_not_null(eff, "应取到特效实例")
	assert_true(eff.visible, "播放后应可见")
	assert_eq(eff.get_parent(), _fx_pool, "应挂在 FxPool 下（不再全树找 World）")
	assert_eq(eff.global_position, Vector2(10, 20), "位置应为播放点")


func test_reuses_pooled_instance():
	var a: HitEffect = _fx_pool.play(CLEAR_FX, Vector2(1, 1))
	a._finish()   # 播完回池（→ visible=false）
	var b: HitEffect = _fx_pool.play(CLEAR_FX, Vector2(2, 2))
	assert_same(a, b, "应从池中复用同一实例，不新建")


func test_clear_pool_frees_instances():
	var a: HitEffect = _fx_pool.play(CLEAR_FX, Vector2.ZERO)
	_fx_pool.clear_pool()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(is_instance_valid(a), "clear_pool 后实例应释放")

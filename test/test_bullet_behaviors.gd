extends GutTest
## 内容侧 behavior 构造器：具名 API 必须编码成稳定的 id + 参数。


func test_linear_and_homing() -> void:
	assert_eq(BulletBehaviors.linear().id, &"linear")
	var h := BulletBehaviors.homing(220.0, 600.0)
	assert_eq(h.id, &"homing")
	assert_eq(h.params, PackedFloat32Array([220.0, 600.0]))


func test_accel_uses_vector_components() -> void:
	var a := BulletBehaviors.accel(Vector2(0, 200))
	assert_eq(a.id, &"accel")
	assert_eq(a.params, PackedFloat32Array([0.0, 200.0]))


func test_bounce_emit_requires_registered_template() -> void:
	var bullet := BulletData.new().enemy().tex("米弹").no_spawn_fog()
	var tpl := EmitTemplate.new(&"builder_rebound", bullet)
	assert_true(EmitTemplateRegistry.new().register(tpl))
	var b := BulletBehaviors.bounce_emit(tpl, 150.0, 96.0, 0.25, 3, true)
	assert_eq(b.id, &"bounce_emit")
	assert_eq(b.params, PackedFloat32Array([tpl.numeric_id, 150.0, 96.0, 0.25, 3.0, 1.0]))
	var keep := BulletBehaviors.bounce_emit(tpl, 150.0, 96.0, 0.25, 3, false)
	assert_eq(keep.params[5], 0.0)

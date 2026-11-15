extends GutTest
## EmitTemplate / Registry：内容层模板管理的边界。


func _valid() -> EmitTemplate:
	var d := SpawnSpec.new().enemy().tex("米弹").color(Color.GOLD)
	return EmitTemplate.new(&"rebound", d, BehaviorSpec.new(&"homing", PackedFloat32Array([220.0, 600.0])))


func test_register_valid_template() -> void:
	var reg := EmitTemplateRegistry.new()
	assert_true(reg.register(_valid()), "有效模板应注册")
	assert_true(reg.has(&"rebound"), "应能按 id 查到")
	assert_eq(reg.get_template(&"rebound").spawn_spec.texture != null, true, "模板保留弹型")
	var t := reg.get_template(&"rebound")
	assert_gt(t.numeric_id, 0, "注册应分配数字 id")
	assert_eq(reg.get_by_numeric(t.numeric_id), t, "数字 id 应能反查")
	assert_eq(reg.last_errors().size(), 0, "成功时无错误")


func test_duplicate_id_is_rejected() -> void:
	var reg := EmitTemplateRegistry.new()
	assert_true(reg.register(_valid()))
	assert_false(reg.register(_valid()), "重复 id 应拒绝")
	assert_string_contains(reg.last_errors()[0], "重复")


func test_empty_id_and_spec_are_rejected() -> void:
	var reg := EmitTemplateRegistry.new()
	var empty := EmitTemplate.new(&"", null)
	assert_false(reg.register(empty), "空 id / spawn_spec 应拒绝")
	assert_gt(reg.last_errors().size(), 0, "应给出错误")


func test_behavior_params_limit() -> void:
	var t := _valid()
	t.behavior = BehaviorSpec.new(&"homing", PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 1]))
	assert_false(EmitTemplateRegistry.new().register(t), "超过 8 参数应拒绝")


func test_emit_template_accepts_spawn_spec() -> void:
	var spec := SpawnSpec.new().tex("米弹").enemy()
	var tpl := EmitTemplate.new(&"from_spec", spec)
	assert_not_null(tpl.spawn_spec, "EmitTemplate 应保留 SpawnSpec 路径")
	assert_eq(tpl.spawn_spec.texture, BulletShapes.atlas_texture(&"米弹"), "外观应保留")


func test_re_register_same_id_reuses_numeric_id() -> void:
	var sys := KernelNativeSystem.new()
	add_child_autofree(sys)
	if not sys.is_native_ready():
		pending("无原生扩展")
		return
	var a := _valid()
	var b := _valid()
	assert_true(sys.register_emit_template(a), "首次注册应成功")
	assert_true(sys.register_emit_template(b), "同 id 再注册应幂等成功")
	assert_eq(b.numeric_id, a.numeric_id, "应复用已注册模板的 numeric_id")
	assert_eq(sys.emit_templates.size(), 1, "模板表仍只有一份")

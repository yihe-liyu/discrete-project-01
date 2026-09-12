extends GutTest
## Miss 圈特效（W1）：autoload → 场景节点 + 组合根注入。
## 覆盖：不再是 autoload / 节点 API 行为 / EffectService 注入路由 / StageContext 取注入。

const RUNNER_SCRIPT = preload("res://scripts/coroutine/base/coroutine_runner.gd")


func _make_layer() -> MissEffectManager:
	var layer := MissEffectManager.new()
	autofree(layer)
	add_child(layer)
	layer.set_process(false)  # 测试手动驱动 _process，避免树里自动跑
	return layer


func test_no_longer_autoload() -> void:
	assert_false(ProjectSettings.has_setting("autoload/MissEffectManager"),
		"MissEffectManager 应已从 autoload 移除（改为场景节点）")
	assert_false(ProjectSettings.has_setting("autoload/LayerConfig"),
		"LayerConfig 应已从 autoload 移除（改为 class_name 静态常量）")


func test_node_ready_builds_rect() -> void:
	var layer := _make_layer()
	assert_not_null(layer._rect, "场景节点应自建 ColorRect")
	assert_not_null(layer._mat, "场景节点应自建 ShaderMaterial")


func test_add_circle_appends_and_caps() -> void:
	var layer := _make_layer()
	for i in 9:
		layer.add_circle(Vector2(i, i), 0.8, 100.0)
	assert_eq(layer._circles.size(), MissEffectManager.MAX_CIRCLES, "超过上限应被丢弃")


func test_clear_all_empties() -> void:
	var layer := _make_layer()
	layer.add_circle(Vector2(10, 10), 0.8, 100.0)
	layer.clear_all()
	assert_true(layer._circles.is_empty(), "clear_all 应清空所有圈")


func test_process_expires_circle() -> void:
	var layer := _make_layer()
	layer.add_circle(Vector2(10, 10), 0.1, 100.0)
	layer._process(0.2)
	assert_true(layer._circles.is_empty(), "寿命到期的圈应被移除")


func test_effect_service_routes_to_injected_layer() -> void:
	var layer := _make_layer()
	var svc := EffectService.new()
	svc.miss_layer = layer
	svc.add_miss_circle(Vector2(3, 4), 0.8, 100.0)
	assert_eq(layer._circles.size(), 1, "EffectService 应把圈交给注入的节点")


func test_effect_service_without_layer_is_noop() -> void:
	var svc := EffectService.new()
	svc.add_miss_circle(Vector2.ZERO, 0.8, 100.0)  # 不应报错
	assert_true(true, "无注入层时应静默跳过（测试/无场景上下文）")


func test_stage_context_reads_injected_layer() -> void:
	var layer := _make_layer()
	var rt := StageRuntime.new()
	autofree(rt)
	rt.miss_layer = layer
	var runner := RUNNER_SCRIPT.new()
	autofree(runner)
	var ctx := StageContext.new(runner)
	ctx.stage = rt
	assert_eq(ctx.effects.miss_layer, layer, "ctx.effects 应取到 stage 注入的层")

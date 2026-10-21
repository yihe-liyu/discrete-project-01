extends GutTest
## StageData 难度变体：变体优先于基准，未覆盖字段回落；StageRuntime 真的使用变体脚本。

const VARIANT_SCRIPT := preload("res://test/fixtures/variant_stage_script.gd")

var _original_difficulty := Difficulty.NORMAL


func before_each() -> void:
	_original_difficulty = SaveData.selected_difficulty


func after_each() -> void:
	SaveData.selected_difficulty = _original_difficulty


func _stage_data() -> StageData:
	var data := StageData.new()
	data.stage_id = 99
	data.create_script = CoroutineScript
	data.bgm_key = "base"
	return data


func _runtime() -> StageRuntime:
	var rt := StageRuntime.new()
	add_child_autofree(rt)
	var world := Node2D.new()
	world.name = "World"
	add_child_autofree(world)
	rt.world = world
	return rt


func test_without_variant_falls_back_to_base() -> void:
	var data := _stage_data()
	assert_eq(data.script_for_difficulty(Difficulty.EXTRA), CoroutineScript, "无变体时回落基准脚本")
	assert_eq(data.bgm_key_for_difficulty(Difficulty.EXTRA), "base", "无变体时回落基准 BGM")
	assert_null(data.background_for_difficulty(Difficulty.EXTRA), "无变体时回落基准背景")


func test_variant_overrides_only_declared_fields() -> void:
	var data := _stage_data()
	var variant := StageVariant.new()
	variant.difficulty = Difficulty.EXTRA
	variant.create_script = VARIANT_SCRIPT
	variant.bgm_key = "extra"
	data.variants.append(variant)

	assert_eq(data.script_for_difficulty(Difficulty.EXTRA), VARIANT_SCRIPT, "Extra 应用变体脚本")
	assert_eq(data.bgm_key_for_difficulty(Difficulty.EXTRA), "extra", "Extra 应用变体 BGM")
	assert_eq(data.script_for_difficulty(Difficulty.NORMAL), CoroutineScript, "Normal 仍用基准脚本")
	assert_eq(data.bgm_key_for_difficulty(Difficulty.NORMAL), "base", "Normal 仍用基准 BGM")


func test_validation_rejects_duplicate_and_empty_variants() -> void:
	var data := _stage_data()
	var first := StageVariant.new()
	first.difficulty = Difficulty.HARD
	first.bgm_key = "hard"
	var second := StageVariant.new()
	second.difficulty = Difficulty.HARD
	second.bgm_key = "hard_2"
	var empty := StageVariant.new()
	data.variants.append_array([first, second, empty])

	var errs := data.validate()
	assert_true(errs.any(func(e: String) -> bool: return "变体重复" in e), "重复难度应报错")
	assert_true(errs.any(func(e: String) -> bool: return "没有任何覆盖" in e), "空变体应报错")


func test_stage_runtime_uses_variant_script() -> void:
	SaveData.selected_difficulty = Difficulty.EXTRA
	var data := _stage_data()
	var variant := StageVariant.new()
	variant.difficulty = Difficulty.EXTRA
	variant.create_script = VARIANT_SCRIPT
	data.variants.append(variant)

	var rt := _runtime()
	rt.load_stage(data)
	assert_not_null(rt.current_stage_script(), "关卡应已装载")
	if rt.current_stage_script() == null:
		return
	assert_eq(rt.current_stage_script().get_script(), VARIANT_SCRIPT, "StageRuntime 应使用 Extra 变体脚本")
	rt.stop_stage()

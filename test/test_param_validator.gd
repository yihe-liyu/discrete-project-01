extends GutTest
## ParamValidator —— 参数注入校验（打错键名/类型不匹配响亮报错，int/float、合法数字串放行）

const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")
const ParamProbeScript = preload("res://test/fixtures/param_probe.gd")

func _make() -> Node:
	var n := ParamProbeScript.new()
	autofree(n)   # 测试自建的 Node 由 GUT 收尾，避免孤儿
	return n


func test_valid_params_no_error():
	var errs := PARAM_VALIDATOR_SCRIPT.validate(_make(), {"max_speed": 2000.0, "accel_time": 1.5})
	assert_eq(errs.size(), 0, "合法键→无错误")


func test_int_for_float_ok():
	var errs := PARAM_VALIDATOR_SCRIPT.validate(_make(), {"max_speed": 2000})
	assert_eq(errs.size(), 0, "int 给 float 放行")


func test_unknown_key_is_warning_only():
	var errs := PARAM_VALIDATOR_SCRIPT.validate(_make(), {"speeed": 1.0})
	assert_eq(errs.size(), 0, "未知键→validate 0 错误（共享字典跨脚本合法）")
	var warns := PARAM_VALIDATOR_SCRIPT.validate_unknown_keys(_make(), {"speeed": 1.0})
	assert_eq(warns.size(), 1, "未知键→1 条 warning")
	var other := PARAM_VALIDATOR_SCRIPT.validate_unknown_keys(_make(), {"max_speed": 2000.0})
	assert_eq(other.size(), 0, "合法键无 warning")


func test_type_mismatch_is_error():
	var errs := PARAM_VALIDATOR_SCRIPT.validate(_make(), {"max_speed": "fast"})
	assert_eq(errs.size(), 1, "非数字串给 float→报错")


func test_numeric_string_ok():
	var errs := PARAM_VALIDATOR_SCRIPT.validate(_make(), {"max_speed": "2000.5"})
	assert_eq(errs.size(), 0, "合法数字串给 float 放行")
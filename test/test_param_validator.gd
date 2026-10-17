extends GutTest
## ParamValidator —— 参数注入校验（类型不匹配 / 严格模式未知键 / 多脚本并集未知键；int/float、合法数字串放行）

const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")
const ParamProbeScript = preload("res://test/fixtures/param_probe.gd")
const PRE_MOVE_PROBE = preload("res://test/fixtures/pre_move_probe.gd")

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


## 严格模式（EnemyData.params 只灌一个脚本）：未知键必须响亮
func test_strict_apply_reports_unknown_key():
	PARAM_VALIDATOR_SCRIPT.apply(_make(), {"speeed": 1.0}, true)
	assert_push_error("speeed")


## 严格模式不能误伤合法键
func test_strict_apply_sets_known_key():
	var n := _make()
	PARAM_VALIDATOR_SCRIPT.apply(n, {"max_speed": 1234.0}, true)
	assert_eq(n.get("max_speed"), 1234.0, "严格模式仍要设合法键")


## PhaseData.params 三脚本并集：键属于任一脚本即可
func test_union_accepts_keys_from_any_script():
	var warns := PARAM_VALIDATOR_SCRIPT.validate_unknown_keys_union(
		[ParamProbeScript, PRE_MOVE_PROBE], {"max_speed": 1.0, "duration": 0.5})
	assert_eq(warns.size(), 0, "键属于并集里任一脚本即可")


## PhaseData.params 三脚本并集：谁都不认识的键要点名
func test_union_reports_key_in_no_script():
	var warns := PARAM_VALIDATOR_SCRIPT.validate_unknown_keys_union(
		[ParamProbeScript, PRE_MOVE_PROBE], {"speeed": 1.0})
	assert_eq(warns.size(), 1, "不属于并集的键报 1 条")
	assert_true(warns[0].contains("speeed"), "报错要点名键")


## 集成：PhaseData.validate() 真的走并集校验
func test_phase_validate_uses_union():
	var phase := PhaseData.new()
	phase.move_script = ParamProbeScript
	phase.shoot_script = PRE_MOVE_PROBE
	phase.params = {"max_speed": 1.0, "duration": 0.5}
	assert_eq(phase.validate().size(), 0, "PhaseData 按三脚本并集放行")
	phase.params = {"speeed": 1.0}
	var errs := phase.validate()
	assert_eq(errs.size(), 1, "不在并集的键应报错")
	assert_true(errs[0].contains("speeed"), "报错要点名键")
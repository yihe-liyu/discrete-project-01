extends GutTest
## 债 C 第一步：EnemyData 可序列化（behavior_script/params @export）+ validate() 校验。
## 不动内容编排（stage01 仍用构造链），只把"数据类可序列化"补齐。

const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.gd")

func test_script_and_params_exportable():
	var e := EnemyData.new()
	e.with_script(ENEMY01)
	e.param("target_y", 200)
	e.param("rate", 4)
	assert_eq(e.get_enemy_script(), ENEMY01, "behavior_script 可读")
	assert_eq(e.get_params(), {"target_y": 200, "rate": 4}, "params 可读")
	assert_true(e.has_script(), "has_script 应 true")
	var cs := e.make_script() as CoroutineScript
	assert_true(cs != null, "make_script 应生成 CoroutineScript")
	assert_true(e.validate().is_empty(), "合法 EnemyData 无校验错误")
	if cs: cs.free()

func test_validate_catches_missing_script():
	var e := EnemyData.new()
	assert_true(not e.validate().is_empty(), "无行为脚本应报错")

func test_validate_catches_bad_hp():
	var e := EnemyData.new()
	e.with_script(ENEMY01)
	e.hp(0)
	assert_true(not e.validate().is_empty(), "hp=0 应报错")

# spawn() 对非法配置会 push_error + 拒绝（生产响亮）；GUT 会把它记成测试错误，故不在此测 spawn 失败路径

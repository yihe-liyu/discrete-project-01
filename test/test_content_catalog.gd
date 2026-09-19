extends GutTest
## ContentCatalog 目录扫描器测试（创作台）。
## 机制一律用**夹具目录**测；真实内容只做「不数数量、不写具体路径」的结构冒烟 —— 加内容不应红。

const CAT = preload("res://scripts/data/content_catalog.gd")

const FIXTURE := "res://test/_fixture_catalog"


func before_each() -> void:
	_build_fixture()


func after_each() -> void:
	_rmtree(FIXTURE)


## ── 夹具：角色分类 / 注解覆盖 / 边界 ──

func test_fixture_role_annotation_and_boundaries():
	var cat = CAT.new().scan(FIXTURE)
	var cases := {
		FIXTURE.path_join("stages/stageF/stage_script/f_stage.gd"): "stage",
		FIXTURE.path_join("stages/stageF/enemy/y_bullet.gd"): "bullet",
		FIXTURE.path_join("stages/stageF/background/decor.gd"): "bg",
		FIXTURE.path_join("loose.gd"): "misc",
	}
	for path in cases:
		var e = cat.find(path)
		assert_not_null(e, "应找到：%s" % path)
		if e:
			assert_eq(e.role, cases[path], "角色应为 %s（%s）" % [cases[path], path])
	# 注解覆盖：x_move 约定 boss_move → 注解 bullet
	var xe = cat.find(FIXTURE.path_join("stages/stageF/enemy/x_move.gd"))
	assert_not_null(xe, "x_move 在目录")
	if xe:
		assert_eq(xe.role, "bullet", "注解 @role 覆盖约定")
		assert_eq(xe.name, "测试弹", "@name 覆盖默认名")
		assert_eq(xe.description, "这是描述行", "描述行")
	assert_null(cat.find(FIXTURE.path_join("stages/stageF/enemy/plain.gd")), "非协程脚本排除")
	assert_null(cat.find(FIXTURE.path_join("dialogue/intro.gd")), "dialogue 排除")
	# 冲突警告（约定 boss_move vs 注解 bullet）
	var warned := false
	for w in cat.get_warnings():
		if w.contains("x_move.gd"):
			warned = true
	assert_true(warned, "约定/注解打架 → warning 响亮")


## ── 夹具：阶段 .tres ──

func test_fixture_phase_tres_fields():
	var cat = CAT.new().scan(FIXTURE)
	var phases = cat.by_role("phase")
	assert_eq(phases.size(), 1, "夹具应有 1 个阶段")
	var p = cat.find(FIXTURE.path_join("stages/stageF/phase/a/p.tres"))
	assert_not_null(p, "夹具阶段在目录")
	if p:
		assert_eq(p.extra["uid"], 42, "uid 入档")
		assert_eq(p.extra["hp"], 123, "hp 入档")
		assert_almost_eq(p.extra["time_limit"], 45.5, 0.01, "时限入档")
		assert_eq(p.stage_key, "stageF", "stage_key 从路径提取")
		for key in ["bonus", "is_timeout_only", "move_script", "shoot_script"]:
			assert_true(p.extra.has(key), "阶段 extra 应含 %s" % key)


## ── 夹具：const META ──

func test_fixture_meta_const():
	var cat = CAT.new().scan(FIXTURE)
	var e = cat.find(FIXTURE.path_join("boss_scripts/move/meta_move.gd"))
	assert_not_null(e, "meta_move 在目录")
	if e:
		assert_eq(e.name, "夹具元数据", "const META 名字")
		assert_eq(e.description, "描述开头", "const META 描述")
		assert_eq(e.extra["full_title"], "夹具元数据", "完整名保留在 extra")


## ── 夹具：preload 引用反查 ──

func test_fixture_refs_from():
	var cat = CAT.new().scan(FIXTURE)
	var enemy = cat.find(FIXTURE.path_join("stages/stageF/enemy/e.gd"))
	assert_not_null(enemy, "夹具敌人在目录")
	if enemy:
		assert_true(enemy.refs_from.has(FIXTURE.path_join("stages/stageF/stage_script/f_stage.gd")),
			"enemy 应被关卡脚本 preload 引用")


## ── 真实内容：结构冒烟（对内容增减不敏感）──

func test_real_content_smoke_is_content_agnostic():
	var cat = CAT.new().scan()
	assert_gt(cat.get_entries().size(), 0, "应扫到真实内容")
	for e in cat.get_entries():
		assert_true(e.path.begins_with("res://data"), "只收 data/（%s）" % e.path)
		assert_false(e.path.contains("/dialogue/"), "dialogue 排除（%s）" % e.path)
		assert_true(CAT.ROLE_ORDER.has(e.role), "角色合法（%s → %s）" % [e.role, e.path])
	for e in cat.by_role("phase"):
		for key in ["uid", "hp", "time_limit", "bonus", "is_timeout_only", "move_script", "shoot_script"]:
			assert_true(e.extra.has(key), "阶段 %s 缺字段 %s" % [e.path, key])


# ═══ 夹具 ═══

func _build_fixture() -> void:
	_rmtree(FIXTURE)
	# 关卡脚本 preload 敌人脚本 → 测 refs_from
	_write(FIXTURE.path_join("stages/stageF/stage_script/f_stage.gd"),
		"extends CoroutineScript\n## 夹具关卡\nconst E = preload(\"%s\")\n" % FIXTURE.path_join("stages/stageF/enemy/e.gd"))
	_write(FIXTURE.path_join("stages/stageF/enemy/e.gd"), "extends CoroutineScript\n## 夹具敌人\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/x_move.gd"),
		"extends CoroutineScript\n## @role: bullet\n## @name: 测试弹\n## 这是描述行\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/y_bullet.gd"), "extends CoroutineScript\n## 普通螺旋弹\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/plain.gd"), "extends Node\n## 不是协程脚本\n")
	_write(FIXTURE.path_join("stages/stageF/background/decor.gd"), "extends CoroutineScript\n## 背景演出脚本\n")
	_write(FIXTURE.path_join("dialogue/intro.gd"), "extends CoroutineScript\n## 对话脚本不入目录\n")
	_write(FIXTURE.path_join("loose.gd"), "extends CoroutineScript\n## 杂项\n")
	_write(FIXTURE.path_join("boss_scripts/move/meta_move.gd"),
		"extends CoroutineScript\nconst META = {\"name\": \"夹具元数据\", \"desc\": \"描述开头\"}\n## 注释\n")
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/a/p.tres"), "夹具阶段", 42, 123, 45.5)


func _phase_tres(path: String, p_name: String, uid: int, hp: int, time_limit: float) -> void:
	var text := "[gd_resource type=\"Resource\" script_class=\"PhaseData\" format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://scripts/data/phase_data.gd\" id=\"1\"]\n\n"
	text += "[resource]\nscript = ExtResource(\"1\")\nuid = %d\nname = \"%s\"\nhp = %d\ntime_limit = %s\n" % [uid, p_name, hp, str(time_limit)]
	_write(path, text)


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(f, "可写 %s" % path)
	if f:
		f.store_string(text)
		f.close()


func _rmtree(dir: String) -> void:
	var da := DirAccess.open(dir)
	if not da:
		return
	var subdirs: Array[String] = []
	da.list_dir_begin()
	var f := da.get_next()
	while f != "":
		if da.current_is_dir() and not f.begins_with("."):
			subdirs.append(f)
		else:
			da.remove(dir.path_join(f))
		f = da.get_next()
	da.list_dir_end()
	for d in subdirs:
		_rmtree(dir.path_join(d))
	DirAccess.remove_absolute(dir)

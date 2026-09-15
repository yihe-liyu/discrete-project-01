extends GutTest
## ContentCatalog 目录扫描器测试（创作台）
## 注：headless 下 class_name 全局缓存未刷新 → 用 preload 常量（项目惯例）

const CAT = preload("res://scripts/data/content_catalog.gd")

## ── 真实内容：角色分类 ──

func test_real_content_role_classification():
	var cat = CAT.new().scan()
	var cases := {
		"res://data/stages/stage01/stage_script/stage01.gd": "stage",
		"res://data/stages/stage01/phase/non_mid01/non_mid01_move.gd": "boss_move",
		"res://data/stages/stage01/phase/non_mid01/non_mid01_shoot.gd": "boss_shoot",
		"res://data/stages/stage03B/phase/spell03/orbit_spiral.gd": "boss_shoot",
		"res://data/stages/stage03B/phase/spell03/orbit_probe.gd": "bullet",
		"res://data/stages/stage01/enemy/enemy01.gd": "enemy",
		"res://data/stages/stage01/enemy/fly_away.gd": "enemy",
	}
	for path in cases:
		var e = cat.find(path)
		assert_not_null(e, "应找到：%s" % path)
		if e:
			assert_eq(e.role, cases[path], "角色应为 %s（%s）" % [cases[path], path])
	# 显示名来源：注释首行，取"："之后
	var e0 = cat.find("res://data/stages/stage01/phase/non_mid01/non_mid01_shoot.gd")
	if e0:
		assert_eq(e0.name, "每隔一段时间射一圈特殊弹丸", "默认名=注释首行冒号后")
	# 背景演出角色（/background/ 约定）
	var decor = cat.find("res://data/stages/stage01/background/stage01_decor.gd")
	if decor:
		assert_eq(decor.role, "bg", "背景脚本约定 bg")
	# 阶段 key
	var e1 = cat.find("res://data/stages/stage03B/phase/spell03/orbit_spiral.gd")
	if e1:
		assert_eq(e1.stage_key, "stage03B", "stage_key 从路径提取")


## ── 真实内容：阶段资源 ──

func test_real_content_phases_registered():
	var cat = CAT.new().scan()
	var phases = cat.by_role("phase")
	assert_eq(phases.size(), 7, "应有 7 个阶段（非符 2 + 符卡 5）")
	var mid = cat.find("res://data/stages/stage01/phase/non_mid01/non_mid01.tres")
	assert_not_null(mid, "道中非符1 阶段应在目录")
	if mid:
		assert_eq(mid.extra["move_script"], "res://data/stages/stage01/phase/non_mid01/non_mid01_move.gd")
		assert_eq(mid.extra["shoot_script"], "res://data/stages/stage01/phase/non_mid01/non_mid01_shoot.gd")
		assert_eq(mid.extra["uid"], 0, "非符 uid=0")
	var spy_limit = cat.find("res://data/stages/stage03B/phase/spell03/spell056.tres")
	if spy_limit:
		assert_eq(spy_limit.extra["uid"], 56, "符卡 uid 入档")


## ── 边界：不含 data/ 外、dialogue、非协程脚本 ──

func test_real_content_boundaries():
	var cat = CAT.new().scan()
	for e in cat.get_entries():
		assert_true(e.path.begins_with("res://data"), "只收 data/（%s）" % e.path)
		assert_false(e.path.contains("/dialogue/"), "dialogue 排除（%s）" % e.path)
	assert_null(cat.find("res://data/dialogue/stage01/intro.gd"), "对话脚本不入目录")


## ── 真实内容：引用关系（preload 反查）──

func test_real_content_refs():
	var cat = CAT.new().scan()
	var probe = cat.find("res://data/stages/stage03B/phase/spell03/orbit_probe.gd")
	if probe:
		assert_true(probe.refs_from.has("res://data/stages/stage03B/phase/spell03/orbit_spiral.gd"),
			"orbit_probe 被 orbit_spiral 引用")
	var enemy01 = cat.find("res://data/stages/stage01/enemy/enemy01.gd")
	if enemy01:
		assert_true(enemy01.refs_from.has("res://data/stages/stage01/stage_script/stage01.gd"),
			"enemy01 被关卡脚本引用")


## ── 夹具：注解覆盖 / 边界 / 名称 ──

func test_fixture_annotation_override_and_boundaries():
	var root := "res://test/_fixture_catalog"
	_rmtree(root)
	assert_eq(DirAccess.make_dir_recursive_absolute(root.path_join("stage01/enemy")), OK, "建段目录")
	assert_eq(DirAccess.make_dir_recursive_absolute(root.path_join("dialogue")), OK, "建对话目录")
	assert_eq(DirAccess.make_dir_recursive_absolute(root.path_join("stage01/background")), OK, "建背景目录")
	_write(root.path_join("stage01/enemy/x_move.gd"),
		"extends CoroutineScript\n## @role: bullet\n## @name: 测试弹\n## 这是描述行\n")
	_write(root.path_join("stage01/enemy/y_bullet.gd"),
		"extends CoroutineScript\n## 普通螺旋弹\n")
	_write(root.path_join("stage01/enemy/plain.gd"),
		"extends Node\n## 不是协程脚本\n")
	_write(root.path_join("stage01/background/decor.gd"),
		"extends CoroutineScript\n## 背景演出脚本\n")
	_write(root.path_join("dialogue/intro.gd"),
		"extends CoroutineScript\n## 对话脚本不入目录\n")
	_write(root.path_join("loose.gd"),
		"extends CoroutineScript\n## 杂项\n")

	var cat = CAT.new().scan(root)
	# 注解覆盖：x_move 约定 boss_move → 注解 bullet
	var xe = cat.find(root.path_join("stage01/enemy/x_move.gd"))
	assert_not_null(xe, "x_move 在目录")
	if xe:
		assert_eq(xe.role, "bullet", "注解 @role 覆盖约定")
		assert_eq(xe.name, "测试弹", "@name 覆盖默认名")
		assert_eq(xe.description, "这是描述行", "描述行")
	# 约定：y_bullet → bullet
	var ye = cat.find(root.path_join("stage01/enemy/y_bullet.gd"))
	if ye:
		assert_eq(ye.role, "bullet", "文件名约定 bullet")
	# 背景演出（/background/ 约定）
	var be = cat.find(root.path_join("stage01/background/decor.gd"))
	if be:
		assert_eq(be.role, "bg", "背景目录 → bg 角色")
	assert_null(cat.find(root.path_join("stage01/enemy/plain.gd")), "非协程脚本排除")
	assert_null(cat.find(root.path_join("dialogue/intro.gd")), "dialogue 排除")
	var misc = cat.find(root.path_join("loose.gd"))
	if misc:
		assert_eq(misc.role, "misc", "无约定 → 未分类")
	# 冲突警告（约定 boss_move vs 注解 bullet）
	var warned := false
	for w in cat.get_warnings():
		if w.contains("x_move.gd"):
			warned = true
	assert_true(warned, "约定/注解打架 → warning 响亮")

	_rmtree(root)


## ── const META：内容自带元数据 ──

func test_real_content_meta_const():
	var cat = CAT.new().scan()
	var e = cat.find("res://data/boss_scripts/move/random_dir_move.gd")
	assert_not_null(e, "random_dir_move 在目录")
	if e:
		assert_eq(e.name, "随机方向移动", "const META 名字（不再被冒号截断成描述）")
		assert_true(e.description.begins_with("每隔 jump_interval"), "const META 描述")
		assert_eq(e.extra["full_title"], "随机方向移动", "完整名保留在 extra")


## ── 工具 ──

func _write(path: String, text: String) -> void:
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
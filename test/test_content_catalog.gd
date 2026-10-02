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
	# 约定 = misc（没规则匹配）时，@role 是**补空缺**，不该被当成冲突
	var orphan = cat.find(FIXTURE.path_join("annotated_orphan.gd"))
	assert_not_null(orphan, "annotated_orphan 在目录")
	if orphan:
		assert_eq(orphan.role, "boss_move", "@role 给孤儿脚本补角色")
		assert_eq(orphan.name, "孤儿走位", "顶部隔开的注释块仍提供显示名")
	var noisy := false
	for w in cat.get_warnings():
		if w.contains("annotated_orphan.gd"):
			noisy = true
	assert_false(noisy, "补空缺不该报“冲突”（实得警告：%s）" % str(cat.get_warnings()))


## ── 夹具：阶段 .tres ──

func test_fixture_phase_tres_fields():
	var cat = CAT.new().scan(FIXTURE)
	var phases = cat.by_role("phase")
	assert_eq(phases.size(), 5, "夹具应有 5 个阶段（3 符卡 + 2 非符）")
	var p = cat.find(FIXTURE.path_join("stages/stageF/phase/a/p.tres"))
	assert_not_null(p, "夹具阶段在目录")
	if p:
		assert_eq(p.extra["uid"], 42, "uid 入档")
		assert_eq(p.extra["hp"], 123, "hp 入档")
		assert_almost_eq(p.extra["time_limit"], 45.5, 0.01, "时限入档")
		assert_eq(p.stage_key, "stageF", "stage_key 从路径提取")
		for key in ["is_timeout_only", "move_script", "pre_move_script", "shoot_script"]:
			assert_true(p.extra.has(key), "阶段 extra 应含 %s" % key)


## ── 夹具：`pre_move_script` 也要反推角色（2026-09-30 补）──────────────
## 回归：`data/boss_scripts/move/` 里被阶段以 `pre_move_script`（符卡发动**前**的走位）引用的脚本
## 曾经全落进「未分类」→ 目录里双击不跳台（`route_preset` 对 misc 直接 return，静默）。
func test_fixture_pre_move_script_gets_boss_move_role():
	var cat = CAT.new().scan(FIXTURE)
	var pre = cat.find(FIXTURE.path_join("boss_scripts/move/pre_walk.gd"))
	assert_not_null(pre, "pre_walk 在目录")
	if pre:
		assert_eq(pre.role, "boss_move", "被 pre_move_script 引用 → Boss 移动（而非未分类）")
	# 对照：没被任何阶段引用的松散脚本仍是 misc（别把规则放宽成"一律 boss_move"）
	var loose = cat.find(FIXTURE.path_join("loose.gd"))
	assert_not_null(loose, "loose 在目录")
	if loose:
		assert_eq(loose.role, "misc", "没人引用的脚本仍是未分类")


## ── 夹具：显示名只认**顶部且隔开**的注释块（2026-09-30 修）─────────────
## 回归：`enemy04.gd` 的成员文档（`## 匀速下移速度…` 紧贴 `var move_speed`）曾被当成脚本名，
## 下拉项显示成 `匀速下移速度（px/s），外部可用 param(…`；而且**静默**（警告 0）。
func test_fixture_header_must_be_top_and_detached():
	var cat = CAT.new().scan(FIXTURE)

	# ① 顶部 + 隔开 → 正常取名
	var good = cat.find(FIXTURE.path_join("stages/stageF/enemy/hdr_ok.gd"))
	assert_not_null(good, "hdr_ok 在目录")
	if good:
		assert_eq(good.name, "隔行顶部名", "顶部且与声明隔开的注释块 → 当脚本名")

	# ② 紧贴声明 → 那是成员文档，不许当名字（退化成文件名），且**要报警告**
	var doc = cat.find(FIXTURE.path_join("stages/stageF/enemy/hdr_member.gd"))
	assert_not_null(doc, "hdr_member 在目录")
	if doc:
		assert_eq(doc.name, "hdr_member", "贴住声明的注释块 = 成员文档 → 名字退化成文件名")
		assert_false(doc.description.contains("成员文档不该当名字"),
			"成员文档也不该混进描述（实得：%s）" % doc.description)
	var warned := false
	for w in cat.get_warnings():
		if w.contains("hdr_member.gd"):
			warned = true
	assert_true(warned, "名字退化成文件名要响亮（模块承诺「不静默」）")


## ── 夹具：阶段列表按 uid 升序（2026-09-30）─────────────────────────────
## 阶段台的下拉与工作台目录面板都只走 `by_role("phase")`；扫描顺序是文件系统给的
## （真内容实测会显示成 uid41/43/44/42 这种乱序），而 uid 才是符卡编号。
func test_fixture_phases_sorted_by_uid():
	var cat = CAT.new().scan(FIXTURE)
	var phases = cat.by_role("phase")
	assert_eq(phases.size(), 5, "夹具 5 个阶段（3 符卡 + 2 非符）")
	var uids: Array = []
	for p in phases:
		uids.append(int(p.extra.get("uid", 0)))
	# 符卡（uid>0）按 uid 升序在前；非符（uid 0）在后，且**顺序确定**（按路径）
	assert_eq(uids, [7, 42, 99, 0, 0], "符卡按 uid 升序在前、非符在后（实得 %s）" % str(uids))
	var tail: Array = []
	for i in range(3, 5):
		tail.append(phases[i].path.get_file())
	assert_eq(tail, ["n1.tres", "n2.tres"], "非符之间按路径定序（sort_custom 非稳定，必须给第二键）")
	# 反向哨兵：扫描原序确实不是升序 —— 否则上面那条断言是空转（排序没做事也会绿）
	var raw: Array = []
	for e in cat.get_entries():
		if e.role == "phase":
			raw.append(int(e.extra.get("uid", 0)))
	assert_ne(raw, uids, "夹具的扫描顺序应与 uid 顺序不同（否则测不出排序）")


# ── 夹具：显示名的「角色标签」只在敌人脚本里砍（2026-10-02 收紧）──────────
## 两个真实回归：
## ① `enemy01/03` 的头用**半角** `红杂鱼: …`，旧实现只认全角 `：` → 标签没砍、名字偏长，
##    而且两条注释逐字相同 → 下拉里**两项同名**（只能靠 tooltip 的路径区分）；
## ② 反方向误伤：`stage01_decor.gd` 的 `## Stage01 背景演出 —— 时间线版（组件化：环境/太阳…）`
##    被**句中的全角冒号**从中间劈开 → 目录里显示成 `环境/太阳/蒙眼雾已抽成组件与基类 …`。
func test_fixture_role_tag_stripping_is_enemy_only_and_tag_shaped():
	var cat = CAT.new().scan(FIXTURE)

	# ① 敌人 + `标签: 行为` → 砍标签，完整名留 tooltip
	var tagged = cat.find(FIXTURE.path_join("stages/stageF/enemy/tagged.gd"))
	assert_not_null(tagged, "tagged 在目录")
	if tagged:
		assert_eq(tagged.name, "快速下沉 + 三波自机狙", "半角 `: ` 标签也要砍")
		assert_eq(tagged.extra["full_title"], "红杂鱼: 快速下沉 + 三波自机狙", "完整名保留")

	# ② 句中冒号（前缀含空格）= 标点，不是标签 → 整句留住
	var mid = cat.find(FIXTURE.path_join("stages/stageF/enemy/midsentence.gd"))
	assert_not_null(mid, "midsentence 在目录")
	if mid:
		assert_true(mid.name.begins_with("Stage01 背景演出"),
			"句中冒号不许把标题劈两半（实得：%s）" % mid.name)

	# ③ 非敌人角色：冒号一律当句子标点（`走位到点：移动到…` 的前缀是标题，不是角色标签）
	var titled = cat.find(FIXTURE.path_join("boss_scripts/move/titled_move.gd"))
	assert_not_null(titled, "titled_move 在目录")
	if titled:
		assert_eq(titled.name, "走位到点：移动到指定站位后自己结束", "非敌人角色不按标签砍")


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
		for key in ["uid", "hp", "time_limit", "is_timeout_only", "move_script", "shoot_script"]:
			assert_true(e.extra.has(key), "阶段 %s 缺字段 %s" % [e.path, key])


# ═══ 夹具 ═══

func _build_fixture() -> void:
	_rmtree(FIXTURE)
	# 关卡脚本 preload 敌人脚本 → 测 refs_from
	_write(FIXTURE.path_join("stages/stageF/stage_script/f_stage.gd"),
		"extends CoroutineScript\n## 夹具关卡\n\nconst E = preload(\"%s\")\n" % FIXTURE.path_join("stages/stageF/enemy/e.gd"))
	_write(FIXTURE.path_join("stages/stageF/enemy/e.gd"), "extends CoroutineScript\n## 夹具敌人\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/x_move.gd"),
		"extends CoroutineScript\n## @role: bullet\n## @name: 测试弹\n## 这是描述行\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/y_bullet.gd"), "extends CoroutineScript\n## 普通螺旋弹\n")
	# 显示名规则：顶部且隔开 → 取名；紧贴声明 → 那是成员文档
	_write(FIXTURE.path_join("stages/stageF/enemy/hdr_ok.gd"),
		"extends CoroutineScript\n## 隔行顶部名\n\nvar speed := 1.0\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/hdr_member.gd"),
		"extends CoroutineScript\n\n## 成员文档不该当名字\nvar speed := 1.0\n")
	# 角色反推：卡前走位脚本（被阶段以 pre_move_script 引用）
	_write(FIXTURE.path_join("boss_scripts/move/pre_walk.gd"),
		"extends CoroutineScript\n## 卡前走位\n\nvar t := 0.0\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/plain.gd"), "extends Node\n## 不是协程脚本\n")
	_write(FIXTURE.path_join("stages/stageF/background/decor.gd"), "extends CoroutineScript\n## 背景演出脚本\n")
	# 角色标签：敌人 + 半角 `: ` → 砍；句中冒号 / 非敌人角色 → 不砍
	_write(FIXTURE.path_join("stages/stageF/enemy/tagged.gd"),
		"extends CoroutineScript\n## 红杂鱼: 快速下沉 + 三波自机狙\n\nvar t := 0.0\n")
	_write(FIXTURE.path_join("stages/stageF/enemy/midsentence.gd"),
		"extends CoroutineScript\n## Stage01 背景演出 —— 时间线版（组件化：环境/太阳）\n\nvar t := 0.0\n")
	_write(FIXTURE.path_join("boss_scripts/move/titled_move.gd"),
		"extends CoroutineScript\n## 走位到点：移动到指定站位后自己结束\n\nvar t := 0.0\n")
	_write(FIXTURE.path_join("dialogue/intro.gd"), "extends CoroutineScript\n## 对话脚本不入目录\n")
	_write(FIXTURE.path_join("loose.gd"), "extends CoroutineScript\n## 杂项\n")
	# 孤儿脚本：约定判不出（misc），靠 @role 补角色 —— **不该**报"冲突"警告
	_write(FIXTURE.path_join("annotated_orphan.gd"),
		"extends CoroutineScript\n## @role: boss_move\n## 孤儿走位\n\nvar t := 0.0\n")
	_write(FIXTURE.path_join("boss_scripts/move/meta_move.gd"),
		"extends CoroutineScript\nconst META = {\"name\": \"夹具元数据\", \"desc\": \"描述开头\"}\n## 注释\n")
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/a/p.tres"), "夹具阶段", 42, 123, 45.5)
	# 阶段顺序哨兵：uid 与"扫描顺序"故意错开（a=42 / b=7 / c=99）
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/b/q.tres"), "夹具阶段B", 7, 80, 30.0)
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/c/r.tres"), "夹具阶段C", 99, 200, 60.0)
	# 非符（uid 0）两个：验证"符卡优先 + 无 uid 按路径定序"
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/d/n1.tres"), "夹具非符1", 0, 50, 20.0)
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/e/n2.tres"), "夹具非符2", 0, 60, 25.0)


func _phase_tres(path: String, p_name: String, uid: int, hp: int, time_limit: float) -> void:
	var pre := FIXTURE.path_join("boss_scripts/move/pre_walk.gd")
	var text := "[gd_resource type=\"Resource\" script_class=\"PhaseData\" format=3]\n\n"
	text += "[ext_resource type=\"Script\" path=\"res://scripts/data/phase_data.gd\" id=\"1\"]\n"
	text += "[ext_resource type=\"Script\" path=\"%s\" id=\"2\"]\n\n" % pre
	text += "[resource]\nscript = ExtResource(\"1\")\nuid = %d\nname = \"%s\"\nhp = %d\ntime_limit = %s\n" % [uid, p_name, hp, str(time_limit)]
	text += "pre_move_script = ExtResource(\"2\")\n"
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

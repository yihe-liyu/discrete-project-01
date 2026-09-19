extends GutTest
## CatalogPanel 目录树渲染测试（组头完整 / 重名消歧 / 拖拽）。
## 数据源 = **夹具目录**（panel.catalog_root），不拿真实游戏内容当断言标准 —— 加内容不红。

const PANEL := preload("res://scripts/workbench/catalog_panel.gd")

const FIXTURE := "res://test/_fixture_panel"


func before_each() -> void:
	_build_fixture()


func after_each() -> void:
	_rmtree(FIXTURE)


func test_drag_follows_mouse_and_clamps():
	var host := VBoxContainer.new()
	host.size = Vector2(300, 700)
	add_child_autofree(host)
	var panel = PANEL.new()
	panel.catalog_root = FIXTURE
	host.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	var start_div: float = panel._divider_y
	assert_true(start_div > 100.0, "初始分隔条位置（%s）" % str(start_div))
	# 按下（全局坐标 y=300）
	var btn := InputEventMouseButton.new()
	btn.button_index = MOUSE_BUTTON_LEFT
	btn.pressed = true
	btn.global_position = Vector2(150, 300)
	panel._on_info_sep_input(btn)
	# 拖动 +200px：分隔条应精确跟随（非累加、无反馈环）
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.global_position = Vector2(150, 500)
	panel._on_info_sep_input(motion)
	var max_div: float = panel._split_area.size.y - 120.0
	var exp1: float = clampf(start_div + 200.0, 100.0, max_div)
	assert_true(absf(panel._divider_y - exp1) < 1.0,
		"拖动跟随鼠标+钳制（期望 %s 实际 %s）" % [str(exp1), str(panel._divider_y)])
	# 再次 +5px（分隔条移动后仍稳定）
	motion.global_position = Vector2(150, 505)
	panel._on_info_sep_input(motion)
	var exp2: float = clampf(start_div + 205.0, 100.0, max_div)
	assert_true(absf(panel._divider_y - exp2) < 1.0,
		"多次拖动稳定（期望 %s 实际 %s）" % [str(exp2), str(panel._divider_y)])
	# 拖出面板 → 钳制在 [100, h-120]
	motion.global_position = Vector2(150, 99999)
	panel._on_info_sep_input(motion)
	assert_true(panel._divider_y <= panel._split_area.size.y - 120.0 + 0.5,
		"上限钳制（%s / %s）" % [str(panel._divider_y), str(panel._split_area.size.y)])
	motion.global_position = Vector2(150, 0)
	panel._on_info_sep_input(motion)
	assert_true(panel._divider_y >= 100.0 - 0.5, "下限钳制（%s）" % str(panel._divider_y))
	btn.pressed = false
	panel._on_info_sep_input(btn)
	panel.queue_free()


func test_search_filter_and_double_click_signal():
	var panel = PANEL.new()
	panel.catalog_root = FIXTURE
	add_child_autofree(panel)
	await get_tree().process_frame
	# 搜索"夹具符卡" → 命中 2 张同名符卡
	panel._search.text = "夹具符卡"
	await get_tree().process_frame
	var root = panel._tree.get_root()
	var hit := 0
	for i in root.get_child_count():
		var h = root.get_child(i)
		for j in h.get_child_count():
			if h.get_child(j).get_text(0).contains("夹具符卡"):
				hit += 1
	assert_eq(hit, 2, "搜索命中试符条目（%d）" % hit)
	# 双击 → 信号带条目
	var got := {}
	panel.preset_requested.connect(func(e): got["e"] = e)
	for i in root.get_child_count():
		var h = root.get_child(i)
		for j in h.get_child_count():
			var it = h.get_child(j)
			panel._tree.set_selected(it, 0)
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.double_click = true
			ev.pressed = true
			panel._on_tree_input(ev)
			if got.has("e"):
				break
		if got.has("e"):
			break
	assert_true(got.has("e") and got["e"] is ContentCatalog.Entry, "双击发出条目")
	panel.queue_free()


func test_panel_tree_has_role_headers_and_unique_names():
	# 模拟真实 %Pages：面板放进固定尺寸容器，靠 size_flags 撑满（不手动设 size）
	var host := VBoxContainer.new()
	host.size = Vector2(300, 700)
	add_child_autofree(host)
	var panel = PANEL.new()
	panel.catalog_root = FIXTURE
	host.add_child(panel)
	await get_tree().process_frame  # _ready → refresh() + 首帧布局
	await get_tree().process_frame

	var root = panel._tree.get_root()
	assert_not_null(root, "树根存在")
	# 夹具角色：stage / phase / boss_move / boss_shoot / enemy / bg（bullet 空组不显示）
	assert_eq(root.get_child_count(), 6, "应有 6 个角色组头")
	if root.get_child_count() != 6:
		return
	assert_eq(root.get_child(0).get_text(0), "关卡编排（1）", "首个组头=关卡编排")
	assert_eq(root.get_child(0).get_child_count(), 1, "关卡编排含 1 个条目")
	assert_eq(root.get_child(1).get_text(0), "阶段（3）", "第二组头=阶段3")
	var h2 = root.get_child(1)
	assert_eq(h2.get_child_count(), 3, "阶段含 3 个条目")
	# 重名消歧：两张"夹具符卡" → 后缀 uid；"独苗"不重名 → 无后缀
	var labels: Array[String] = []
	for i in h2.get_child_count():
		labels.append(h2.get_child(i).get_text(0))
	assert_true(labels.has("夹具符卡 · uid101"), "重名符卡带 uid 消歧（%s）" % [labels])
	assert_true(labels.has("夹具符卡 · uid102"), "重名符卡带 uid 消歧（%s）" % [labels])
	assert_true(labels.has("独苗"), "非重名阶段不带 uid 后缀（%s）" % [labels])
	# 分割布局真实高度（防 ScrollContainer 塌陷回归）
	assert_eq(panel.size_flags_vertical, Control.SIZE_EXPAND_FILL, "面板自身 EXPAND_FILL（防容器给 0 高）")
	assert_true(panel._split_area.size.y > 200.0, "split_area 有真实高度（%s）" % str(panel._split_area.size.y))
	assert_true(panel._tree.size.y > 100.0, "树有真实高度（%s）" % str(panel._tree.size.y))
	assert_true(panel._info_panel.offset_top < 0.0, "信息卡偏移为负（底锚点）")
	assert_true(panel._info_panel.offset_top <= -100.0,
		"信息卡在分割区内（top=%s, 区高=%s）" % [str(panel._info_panel.offset_top), str(panel._split_area.size.y)])
	assert_true(panel._info_panel.size.y > 50.0,
		"信息卡可见高度（%s）" % str(panel._info_panel.size.y))
	panel.queue_free()


# ═══ 夹具 ═══

func _build_fixture() -> void:
	_rmtree(FIXTURE)
	_write(FIXTURE.path_join("stages/stageF/stage_script/f_stage.gd"), "extends CoroutineScript
## 夹具关卡
")
	_write(FIXTURE.path_join("stages/stageF/enemy/e.gd"), "extends CoroutineScript
## 夹具敌人
")
	_write(FIXTURE.path_join("stages/stageF/background/d.gd"), "extends CoroutineScript
## 夹具背景
")
	_write(FIXTURE.path_join("stages/stageF/phase/a/dup_a_move.gd"), "extends CoroutineScript
## 夹具移动
")
	_write(FIXTURE.path_join("stages/stageF/phase/a/dup_a_shoot.gd"), "extends CoroutineScript
## 夹具发射
")
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/a/dup_a.tres"), "夹具符卡", 101)
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/b/dup_b.tres"), "夹具符卡", 102)
	_phase_tres(FIXTURE.path_join("stages/stageF/phase/c/uniq.tres"), "独苗", 0)


func _phase_tres(path: String, p_name: String, uid: int) -> void:
	var text := "[gd_resource type=\"Resource\" script_class=\"PhaseData\" format=3]

"
	text += "[ext_resource type=\"Script\" path=\"res://scripts/data/phase_data.gd\" id=\"1\"]

"
	text += "[resource]
script = ExtResource(\"1\")
uid = %d
name = \"%s\"\nhp = 100\ntime_limit = 30.0
" % [uid, p_name]
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

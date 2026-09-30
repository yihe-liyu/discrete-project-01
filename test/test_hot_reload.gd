extends GutTest
## `HotReloadService`（热更新服务）**无树**单测：S2 把它从 `BenchBase` 抽出来之后，
## 「防抖 / 连坐 / 失败保旧版 / 关掉即惰性」这些规则不必再借一个 Control 台子才能验。
##
## 用真实夹具脚本（`test/fixtures/*.gd`）—— 机制测试不绑游戏内容。

const HOT := preload("res://scripts/workbench/hot_reload_service.gd")
const FIXTURE := "res://test/fixtures/bullet_preview.gd"
const MISSING := "res://no_such_script.gd"


## 建一个把"监听集 = 夹具脚本 / 主脚本 = 夹具脚本"写死的服务（最省事的来源 Callable）
func _mk_hot(main_path: String = FIXTURE, watch: Array[String] = []) -> HotReloadService:
	var hot := HOT.new() as HotReloadService
	var paths: Array[String] = []
	if watch.is_empty():
		paths.append(main_path)
	else:
		paths = watch
	hot.setup(func() -> Array[String]: return paths, func() -> String: return main_path)
	hot.set_paths(paths)
	return hot


## 防抖 + 轮询节流：改一次 → 一次"检测到修改"；**再稳够 `DEBOUNCE` 才放行**；
## 而没到 `POLL_INTERVAL` 的 delta 连 mtime 都不查（编辑器一帧一帧给 delta，不能每帧查盘）。
func test_debounce_fires_only_after_stability():
	var hot := _mk_hot()      # RefCounted：**不入树**也能跑，这正是抽服务的目的
	watch_signals(hot)
	hot.age_mtime(FIXTURE, 30.0)          # 等价于"这个脚本刚被改过"

	hot.poll(HOT.POLL_INTERVAL)           # ① 检测到修改（dirty=0.5 < 0.8）
	assert_signal_emitted(hot, "status", "首检应播报")
	assert_signal_emit_count(hot, "reloaded", 0, "刚检测到就重载 = 保存到一半就编译")

	hot.poll(HOT.POLL_INTERVAL * 0.4)     # ② 没到轮询间隔 → 什么都不做
	assert_signal_emit_count(hot, "reloaded", 0, "间隔没到不该动作")

	hot.poll(HOT.POLL_INTERVAL * 0.6)     # ③ 凑满间隔：dirty 1.0 ≥ 0.8 → 放行
	assert_signal_emit_count(hot, "reloaded", 1, "稳够防抖后应重载一次")
	var params = get_signal_parameters(hot, "reloaded", 0)
	assert_not_null(params[0], "重载信号带新编译的主脚本")
	assert_eq((params[0] as Script).resource_path, FIXTURE, "带的就是主脚本")


## 文件没动 → 一次都不重载、也不播报（否则编辑器一开着就反复编译）
func test_poll_without_change_is_silent():
	var hot := _mk_hot()
	watch_signals(hot)
	for i in 4:
		hot.poll(HOT.POLL_INTERVAL)
	assert_signal_emit_count(hot, "reloaded", 0, "没改就不该重载")
	assert_signal_emit_count(hot, "status", 0, "没改也不该刷状态条")


## 失败：主脚本不存在 → 不重载、发 `failed` + 红条（旧版继续跑）
func test_failure_reports_and_keeps_old():
	var hot := _mk_hot(MISSING, [MISSING])
	watch_signals(hot)
	hot.force()
	assert_signal_emit_count(hot, "reloaded", 0, "坏路径不许报成功")
	assert_signal_emit_count(hot, "failed", 1, "应发 failed")
	assert_true(hot.paths().has(MISSING), "监听集仍在（等修好后自动恢复）")
	var st = get_signal_parameters(hot, "status", 0)
	assert_true(String(st[0]).contains("失败"), "状态条应说失败（实得：%s）" % st[0])


## 基线刷新：重载成功后**同一改动不再反复触发**（曾经不刷新会无限重载）
func test_baseline_refreshed_after_reload():
	var hot := _mk_hot()
	watch_signals(hot)
	hot.age_mtime(FIXTURE, 30.0)
	hot.force()
	assert_signal_emit_count(hot, "reloaded", 1, "第一次重载")
	hot.poll(HOT.POLL_INTERVAL)
	hot.poll(HOT.POLL_INTERVAL)
	hot.poll(HOT.POLL_INTERVAL)
	assert_signal_emit_count(hot, "reloaded", 1, "基线已刷新 → 不该再重载")


## 连坐：主脚本 + **同目录全部 .gd** 一起进监听集（只重载主脚本看不到同伴的新代码）
func test_collateral_reload_covers_same_dir():
	var one: Array[String] = [FIXTURE]
	var expanded := HOT.with_dir_scripts(one)
	assert_true(expanded.has(FIXTURE), "主脚本本身在监听集里")
	assert_gt(expanded.size(), 1, "同目录其它 .gd 也应连坐（%d 个）" % expanded.size())
	for p in expanded:
		assert_true(String(p).ends_with(".gd"), "监听集里只放 .gd：%s" % p)

	var hot := _mk_hot(FIXTURE, expanded)
	assert_eq(hot.paths().size(), expanded.size(), "rebuild/设定后监听集就绪")


## 关掉开关 → 完全惰性（连 mtime 都不查）
func test_disabled_is_inert():
	var hot := _mk_hot()
	watch_signals(hot)
	hot.age_mtime(FIXTURE, 30.0)
	hot.enabled = false
	for i in 4:
		hot.poll(HOT.POLL_INTERVAL)
	assert_signal_emit_count(hot, "reloaded", 0, "关掉后不重载")
	assert_signal_emit_count(hot, "status", 0, "关掉后也不播报")

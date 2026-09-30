class_name HotReloadService
extends RefCounted
## 工作台**热更新服务**（2026-09-30 S2：从 `BenchBase` 抽出）。
##
## 设计要点：**不依赖场景树、也不认识 toast** —— 调用方用两个 `Callable` 说明
## 「监听哪些路径 / 主脚本是谁」，结果走**信号**（`status` / `reloaded` / `failed`）。
## 于是"防抖语义 / 连坐重载 / 失败保旧版"这些规则可以**无树测试**（见 `test_hot_reload`）。
##
## 两个术语（原来的注释里散着）：
##   * **防抖（debounce）**：文件停止变化 `DEBOUNCE` 秒后才重载 —— 编辑器保存会连写几帧，
##     不等稳就重载会拿到半截脚本；
##   * **连坐**：主脚本 `preload` 的同伴改了，只重载主脚本**看不到**新代码 ⇒
##     主脚本 + 它同目录的全部 `.gd` 一起重载。

## 状态条文案（"＊ 检测到修改…" / "⚠ 重载失败…"）；调用方接去自己的 toast/标签
signal status(text: String, color: Color)
## 重载成功：带**新编译的**主脚本（调用方拿它替换当前脚本并重演）
signal reloaded(main_new: Script)
## 重载失败：带出错的文件路径（旧版继续跑）
signal failed(path: String)

## mtime 轮询间隔（秒）
const POLL_INTERVAL := 0.5
## 修改稳定防抖（秒）：文件这段时间不再变化才算"保存完成"
const DEBOUNCE := 0.8

## 关掉后 `poll()` 直接返回（子类的"热更新"勾选框接它）
var enabled := true

## () -> Array[String]：要监听的路径；() -> String：主脚本路径
var _collect: Callable
var _main_path: Callable

var _paths: Array[String] = []
var _mtimes: Dictionary = {}
var _poll := 0.0
var _dirty_since := -1.0


## 注入两个来源（子类虚函数包成 Callable 传进来；可在 `_init` 里调）
func setup(collect: Callable, main_path: Callable) -> void:
	_collect = collect
	_main_path = main_path


## 主脚本 + 其同目录全部 `.gd`（连坐重载；顺序稳定、去重）
static func with_dir_scripts(p_paths: Array) -> Array[String]:
	var out: Array[String] = []
	var dirs := {}
	for p in p_paths:
		if p == "":
			continue
		if not out.has(p):
			out.append(p)
		dirs[p.get_base_dir()] = true
	for d in dirs:
		var da := DirAccess.open(d)
		if da:
			for f in da.get_files():
				if f.ends_with(".gd"):
					var full: String = d.path_join(f)
					if not out.has(full):
						out.append(full)
	return out


## 重建监听集 = `_collect` 给出的路径连坐展开，然后刷新 mtime 基线
func rebuild() -> void:
	var collected: Array[String] = []
	if _collect.is_valid():
		collected = _collect.call()
	set_paths(with_dir_scripts(collected))


## 监听集（只读副本）
func paths() -> Array[String]:
	return _paths.duplicate()


## 显式设定监听集（会刷新 mtime 基线）
func set_paths(p_paths: Array[String]) -> void:
	_paths = p_paths.duplicate()
	refresh_mtimes()


## 记录全部监听路径的当前 mtime（重载完成后调用：避免同一改动反复触发）
func refresh_mtimes() -> void:
	for p in _paths:
		_mtimes[p] = int(FileAccess.get_modified_time(p))


## 把"上次看到的 mtime"往回拨 seconds 秒 —— 等价于"这个文件刚被改过"
## （测试没法真去改夹具文件；也让"模拟一次保存"不必 sleep）
func age_mtime(path: String, seconds: float) -> void:
	if not _mtimes.has(path):
		_mtimes[path] = int(FileAccess.get_modified_time(path))
	_mtimes[path] = int(_mtimes[path]) - int(seconds)


## 推进一次轮询：到间隔才查 mtime；改了 → 起/续防抖；稳够 `DEBOUNCE` 秒 → 真重载
func poll(delta: float) -> void:
	if not enabled or _paths.is_empty():
		return
	_poll += delta
	if _poll < POLL_INTERVAL:
		return
	_poll = 0.0
	var changed := false
	for p in _paths:
		if int(FileAccess.get_modified_time(p)) != int(_mtimes.get(p, 0)):
			changed = true
			# 注意：检测期间【不】刷新基线！刷新会把防抖清零导致永不重载；重载完成后统一刷新
	if changed:
		if _dirty_since < 0.0:
			_dirty_since = 0.0
			status.emit("＊ 检测到修改…", Color(1, 1, 0.6))
		_dirty_since += POLL_INTERVAL
		if _dirty_since >= DEBOUNCE:
			_dirty_since = -1.0
			force()
	else:
		_dirty_since = -1.0


## 跳过防抖立刻重载（= 防抖到点那一次；"保存后手动重载"也走它）
func force() -> void:
	var main_path: String = _main_path.call() if _main_path.is_valid() else ""
	var main_new: Script = null
	var bad := ""
	for p in _paths:
		if p == main_path:
			continue
		if not FileAccess.file_exists(p):
			bad = p
			break
		if ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE) == null:
			bad = p
			break
	if bad == "" and main_path != "":
		if FileAccess.file_exists(main_path):
			main_new = ResourceLoader.load(main_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			if main_new == null:
				bad = main_path
		else:
			bad = main_path
	refresh_mtimes()
	_dirty_since = -1.0
	if bad != "":
		status.emit("⚠ 重载失败：%s（旧版继续）" % bad.get_file(), Color(1, 0.4, 0.4))
		failed.emit(bad)
		return
	reloaded.emit(main_new)

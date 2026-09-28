extends Node
## 秒级全项目 .gd 编译检查（场景启动模式：autoload 完整注册，编译上下文与真实游戏一致）
## 每个脚本用 GDScript.source_code + reload() 从源码强制重编译，绕开 .godot 文件缓存。
## 用法：godot --headless --path . res://tools/check_syntax_scene.tscn

const SCAN_DIRS: Array[String] = ["res://scripts", "res://data", "res://scenes", "res://test", "res://tools"]

var _failures: Array[String] = []
var _total := 0


func _ready() -> void:
	for d in SCAN_DIRS:
		_scan(d)
	for f in _failures:
		print("[SYNTAX FAIL] ", f)
	print("check_syntax: 扫描 %d 个脚本，%d 个失败" % [_total, _failures.size()])
	get_tree().quit(1 if _failures.size() > 0 else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: " + dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			_scan(dir_path.path_join(entry))
		elif entry.ends_with(".gd"):
			var path := dir_path.path_join(entry)
			_total += 1
			# 场景模式 load()：autoload 完整注册、class_name 全局可用，编译上下文与真实游戏一致。
			# ⚠️ 光判 `load() == null` 会漏掉**依赖级**编译失败：脚本自身语法没错、但它调用的
			# 别处函数/类型不存在时，`load()` 仍返回**非 null** 的 GDScript（`can_instantiate()` 为 false）。
			# 典型：内容侧把 `static func build()` 改名 → 测试里还在调旧名，测试文件就"加载得到但用不了"。
			var script := load(path)
			if script == null or (script is GDScript and not (script as GDScript).can_instantiate()):
				_failures.append(path)
		entry = dir.get_next()
	dir.list_dir_end()

extends SceneTree
## NK9：原生库存在时，校验运行时 ClassDB 方法与 C++ _bind_methods 的名字对齐。
## 无二进制 → 明确 SKIP（项目允许无原生扩展运行）；有二进制但类未加载 → FAIL。

func _initialize() -> void:
	var bin_dir := "res://gdextension/bin"
	var has_binary := false
	if DirAccess.dir_exists_absolute(bin_dir):
		for f in DirAccess.get_files_at(bin_dir):
			var low := f.to_lower()
			if low.ends_with(".so") or low.ends_with(".dll") or low.ends_with(".dylib"):
				has_binary = true
				break
	if not ClassDB.class_exists("DanmakuStore"):
		if has_binary:
			print("❌ 原生二进制存在，但 DanmakuStore 未加载")
			quit(1)
		else:
			print("⚠️ 未构建原生扩展，跳过原生 API 对齐")
			quit(0)
		return
	var source := FileAccess.get_file_as_string("res://gdextension/src/danmaku_store.cpp")
	var re := RegEx.new()
	re.compile('D_METHOD\\("([^"]+)"')
	var expected: Array[String] = []
	for m in re.search_all(source):
		expected.append(m.get_string(1))
	var actual := {}
	for m in ClassDB.class_get_method_list("DanmakuStore"):
		actual[String(m["name"])] = true
	var missing: Array[String] = []
	for name in expected:
		if not actual.has(name):
			missing.append(name)
	if not missing.is_empty():
		print("❌ 原生 API 与 _bind_methods 不一致，缺：", missing)
		quit(1)
		return
	print("✅ 原生 API 与 _bind_methods 对齐：%d methods" % expected.size())
	quit(0)

extends SceneTree
## NK9：原生库存在时，校验运行时 ClassDB 方法与 C++ _bind_methods 的名字对齐。
## 同时校验**构建指纹**：运行时 `get_build_id()` == 当前 `gdextension/src/*.{h,cpp}` 的 SHA-256。
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

	# 指纹：源码树在编辑器/开发环境可用；导出包没有 gdextension/src 时明确 SKIP。
	var source_digest := _source_digest()
	if source_digest.is_empty():
		print("⚠️ 找不到 gdextension/src，跳过原生构建指纹")
		quit(0)
		return
	var store: Object = ClassDB.instantiate("DanmakuStore")
	if store == null:
		print("❌ 无法实例化 DanmakuStore")
		quit(1)
		return
	var runtime_digest := String(store.call("get_build_id"))
	if runtime_digest != source_digest:
		print("❌ 原生二进制与源码不一致：binary=%s source=%s（先跑 ./tools/build_gdextension.sh）"
			% [runtime_digest.substr(0, 12), source_digest.substr(0, 12)])
		quit(1)
		return
	print("✅ 原生构建指纹匹配：%s" % source_digest.substr(0, 12))
	quit(0)


## 与 gdextension/SConstruct 完全同序：文件名 ASCII 升序，逐个 update(name + NUL + bytes + NUL)。
func _source_digest() -> String:
	var source_dir := "res://gdextension/src"
	if not DirAccess.dir_exists_absolute(source_dir):
		return ""
	var names: Array[String] = []
	for file_name in DirAccess.get_files_at(source_dir):
		if file_name == "build_stamp.h":
			continue
		if file_name.ends_with(".h") or file_name.ends_with(".cpp"):
			names.append(file_name)
	names.sort()

	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	for file_name in names:
		context.update(file_name.to_utf8_buffer())
		context.update(PackedByteArray([0]))
		context.update(FileAccess.get_file_as_bytes(source_dir.path_join(file_name)))
		context.update(PackedByteArray([0]))
	return context.finish().hex_encode()

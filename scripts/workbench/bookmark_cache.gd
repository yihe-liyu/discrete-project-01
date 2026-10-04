## 书签缓存 —— user://bookmarks/stage{id}.json
## 持久化两类书签：
##   auto   ：运行时收集的真实事件时刻（只读，脚本变了自动重收集）
##   manual ：人工打点（可编辑，永远保留）
## script_hash 校验：关卡脚本源码变化 → auto 失效（重收集），manual 保留
extends RefCounted
class_name BookmarkCache


## 缓存格式版本：书签策略变化（如只留整数时刻）时 +1，强制旧缓存重收集
const CACHE_VERSION := 5  # v5: script_hash 存字符串——大整数 JSON 精度丢失（>2^53）导致缓存永不命中

## 关卡内容哈希：主脚本 + 关卡目录下所有 .gd 文件文本聚合
## （改任何子脚本/敌人/Boss 逻辑都会使书签缓存失效重收集）
static func stage_content_hash(stage: StageData) -> int:
	var hash_value := CACHE_VERSION
	if stage and stage.create_script:
		hash_value = hash_value * 31 + stage.create_script.source_code.hash()
		var stage_dir: String = stage.create_script.resource_path.get_base_dir().get_base_dir()
		hash_value = _hash_dir_files(stage_dir, hash_value)
	return hash_value


static func _stable_dict_str(dict_data: Dictionary) -> String:
	var keys := dict_data.keys()
	keys.sort()
	var parts: Array = []
	for key in keys:
		parts.append("%s=%s" % [str(key), _stable_value_str(dict_data[key])])
	return "|".join(parts)


## 值稳定表示：Vector2/Color 显式格式化（避免默认 str 精度差异）
static func _stable_value_str(value: Variant) -> String:
	if value is Vector2:
		return "V2(%.6f,%.6f)" % [value.x, value.y]
	if value is Vector3:
		return "V3(%.6f,%.6f,%.6f)" % [value.x, value.y, value.z]
	if value is Color:
		return "C(%.6f,%.6f,%.6f,%.6f)" % [value.r, value.g, value.b, value.a]
	if typeof(value) == TYPE_FLOAT:
		return "F%.6f" % value
	if value is Dictionary:
		return _stable_dict_str(value)
	if value is Array:
		var parts: Array = []
		for element in value:
			parts.append(_stable_value_str(element))
		return "[" + ",".join(parts) + "]"
	return str(value)


static func _hash_dir_files(dir_path: String, hash_value: int) -> int:
	var dir_access := DirAccess.open(dir_path)
	if dir_access == null:
		return hash_value
	# 先收集再排序：目录遍历顺序不稳定 → 不排序则哈希每次不同 → 缓存永不命中
	var sub_dirs: Array[String] = []
	var files: Array[String] = []
	dir_access.list_dir_begin()
	var file_name := dir_access.get_next()
	while file_name != "":
		if dir_access.current_is_dir():
			sub_dirs.append(file_name)
		elif file_name.ends_with(".gd"):
			files.append(file_name)
		file_name = dir_access.get_next()
	dir_access.list_dir_end()
	files.sort()
	sub_dirs.sort()
	for fn in files:
		var fa := FileAccess.open(dir_path + "/" + fn, FileAccess.READ)
		if fa:
			hash_value = hash_value * 31 + fa.get_as_text().hash()
			fa.close()
	for sd in sub_dirs:
		hash_value = _hash_dir_files(dir_path + "/" + sd, hash_value)
	return hash_value


static func _path(stage_id: int) -> String:
	return "user://bookmarks/stage%d.json" % stage_id


## 是否有缓存文件（区分"首次"与"数据变化"：首次无文件，变化有但 hash 不匹配）
static func has_cache(stage_id: int) -> bool:
	return FileAccess.file_exists(_path(stage_id))


## 读缓存 → {ok, auto: [{t}], manual: [{t, label}]}
## ok=false 且 manual 非空 = 脚本变了（auto 待重收集，manual 保留）
static func load(stage_id: int, script_hash: int) -> Dictionary:
	var path := _path(stage_id)
	if not FileAccess.file_exists(path):
		return {"ok": false, "auto": [], "manual": []}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "auto": [], "manual": []}
	var data: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY or data.get("stage_id", -1) != stage_id:
		return {"ok": false, "auto": [], "manual": []}
	# script_hash 以字符串存储：哈希 ~8.6e18 超 2^53，JSON 数字往返会精度丢失
	# （v4 旧缓存是数字：str() 后不会匹配 → 视为脚本变更重收集一次，人工打点保留）
	if str(data.get("script_hash", 0)) != str(script_hash):
		# 脚本变了：auto 失效，人工打点保留
		return {"ok": false, "auto": [], "manual": data.get("manual", [])}
	return {
		"ok": true,
		"auto": data.get("auto", []),
		"manual": data.get("manual", []),
	}


static func save(stage_id: int, script_hash: int, auto: Array, manual: Array) -> void:
	DirAccess.make_dir_recursive_absolute("user://bookmarks")
	var file := FileAccess.open(_path(stage_id), FileAccess.WRITE)
	if file == null:
		push_warning("BookmarkCache: 无法写入 " + _path(stage_id))
		return
	file.store_string(JSON.stringify({
		"stage_id": stage_id,
		"script_hash": str(script_hash),  # 哈希 ~8.6e18 超 2^53：JSON 数字往返丢精度 → 存字符串
		"auto": auto,
		"manual": manual,
	}, "\t"))
	file.close()

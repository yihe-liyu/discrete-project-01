## 内容数据指纹：对 res://data/** 的源文件做稳定 SHA-256。
##
## 用途：Replay 头里的 content_hash 闸门 —— 内容改了（脚本 / .tres / 场景）就拒绝旧录像。
## 边界：只覆盖 data/** 的内容源文件；美术 / 音乐二进制不在这个指纹里。
class_name ContentFingerprint
extends RefCounted

const ROOT := "res://data"
const EXTENSIONS := ["gd", "tres", "tscn", "json"]


## 计算当前内容指纹（hex SHA-256）。路径排序后逐文件混入，跨扫描顺序稳定。
static func compute() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for path in _files(ROOT):
		ctx.update((path + "\n").to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(path))
	return ctx.finish().hex_encode()


static func _files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_files(dir_path.path_join(entry)))
		else:
			var ext := entry.get_extension().to_lower()
			if ext in EXTENSIONS:
				out.append(dir_path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

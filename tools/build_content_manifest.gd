extends Node
## 生成只读内容清单 JSON（V2-1）。
##
## 输出 user://content_manifest.json；manifest 是派生缓存，不是源数据。
## 用法：godot --headless --path . res://tools/build_content_manifest.tscn

const MANIFEST := preload("res://scripts/data/content_manifest.gd")
const OUT_PATH := "res://.godot/probe/content_manifest.json"


func _ready() -> void:
	var manifest: RefCounted = MANIFEST.new()
	var data: Dictionary = manifest.build()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_PATH.get_base_dir()))
	var file := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("无法写入 " + OUT_PATH)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	print("✅ 内容清单：%s（%d stages / %d bosses / %d phases / %d issues）" % [
		OUT_PATH, data.stages.size(), data.bosses.size(), data.phases.size(), data.issues.size()])
	get_tree().quit(0)

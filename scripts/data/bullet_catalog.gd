class_name BulletCatalog
extends RefCounted
## 弹型目录：扫 `data/bullets/*.tres`（`BulletDef` 内容资源），按 key（= 文件名）索引。
## **索引不手写**（R17：内容在 data/，机制在 scripts/）；未知 key **响亮告警**，不静默回退。
## 单一来源：`bullet_configs` 代码表已删除 —— 贴图引用（texture_key）+ 判定 + 朝向全部在 .tres 里。

const DIR := "res://data/bullets/"

static var _by_key: Dictionary = {}
static var _loaded: bool = false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_warning("BulletCatalog: 打不开 %s" % DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var key := file_name.get_basename()
			var bt := load(DIR + file_name) as BulletDef
			if bt == null:
				push_warning("BulletCatalog: %s 加载失败" % file_name)
			else:
				_by_key[key] = bt
		file_name = dir.get_next()
	dir.list_dir_end()


## 按 key 取弹型；未知 → 告警 + null（**不静默**）。
static func find(key: String) -> BulletDef:
	_ensure()
	if not _by_key.has(key):
		push_warning("BulletCatalog: 未知弹型 key '%s'（%s 下无 %s.tres）" % [key, DIR, key])
		return null
	return _by_key[key]


## 全部 key（已排序；工具/查看器遍历用）。
static func keys() -> Array:
	_ensure()
	var out: Array = _by_key.keys()
	out.sort()
	return out


## 全部弹型（工具/查看器遍历用）。
static func all() -> Array:
	_ensure()
	return _by_key.values()

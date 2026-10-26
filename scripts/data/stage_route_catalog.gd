## 难度路线目录：扫描 data/routes/*.tres，按 difficulty / route_id 取路线。
## 同一份 StageData 可被多条路线引用；这里只负责“路线数据”，不负责推进。
class_name StageRouteCatalog
extends RefCounted

const ROUTES_DIR := "res://data/routes"

static var _routes: Array[StageRoute] = []
static var _by_id: Dictionary = {}
static var _by_difficulty: Dictionary = {}
static var _is_loaded: bool = false


## 加载并校验所有路线；重复 route_id / 同难度多条路线会响亮报错。
static func load_routes() -> void:
	_routes.clear()
	_by_id.clear()
	_by_difficulty.clear()
	_is_loaded = true
	var dir := DirAccess.open(ROUTES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var route := ResourceLoader.load(ROUTES_DIR.path_join(entry)) as StageRoute
			if route == null:
				push_error("StageRouteCatalog: %s 不是 StageRoute" % entry)
			else:
				_add_route(route, entry)
		entry = dir.get_next()
	dir.list_dir_end()


static func _add_route(route: StageRoute, file_name: String) -> void:
	var errs := route.validate()
	if not errs.is_empty():
		for err in errs:
			push_error("StageRouteCatalog(%s): %s" % [file_name, err])
		return
	if _by_id.has(route.route_id):
		push_error("StageRouteCatalog: route_id '%s' 重复（%s）" % [route.route_id, file_name])
		return
	_routes.append(route)
	_by_id[route.route_id] = route
	if _by_difficulty.has(route.difficulty):
		push_warning("StageRouteCatalog: 难度 %s 有多条路线，route_for() 取第一条" % Difficulty.display_name(route.difficulty))
	else:
		_by_difficulty[route.difficulty] = route


static func _ensure_loaded() -> void:
	if not _is_loaded:
		load_routes()


## 全部路线（按加载顺序）。
static func all() -> Array[StageRoute]:
	_ensure_loaded()
	return _routes


## 按稳定 route_id 查找。
static func find(route_id: StringName) -> StageRoute:
	_ensure_loaded()
	return _by_id.get(route_id)


## 某难度的默认路线；没有 = null。
static func route_for(difficulty: int) -> StageRoute:
	_ensure_loaded()
	return _by_difficulty.get(difficulty)


## 重新扫描（内容重载 / 工具用）。
static func reload() -> void:
	_is_loaded = false
	load_routes()

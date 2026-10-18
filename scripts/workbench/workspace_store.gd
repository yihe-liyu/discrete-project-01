extends RefCounted
## 创作台工作区配置（D3：从 CreationStation 拆出的无树服务）。
##
## 只做：读/写 user://creation_station.cfg、schema 版本、v1→v2 迁移、坏数据降级、
## 未实例化试验台的数据保留。不碰节点/树。
##
## 配置形状：
##   [ws] version=2, slot=0..3
##   [bench0..2] data=Dictionary（BenchBase.snapshot()）

const CFG_PATH := "user://creation_station.cfg"
const VERSION := 2

var _slot: int = 1
var _loaded_version: int = 0
var _restores: Array = [{}, {}, {}]


## 读工作区；无文件/坏文件都回落到默认（slot=1，空工作区）。
func load(slot_count: int = 4) -> void:
	_slot = 1
	_loaded_version = 0
	_restores = [{}, {}, {}]
	var config_file := ConfigFile.new()
	if config_file.load(CFG_PATH) != OK:
		return
	_loaded_version = int(config_file.get_value("ws", "version", 1))
	if _loaded_version < 1:
		_loaded_version = 1
	_slot = clampi(int(config_file.get_value("ws", "slot", 1)), 0, slot_count - 1)
	for i in 3:
		var data = config_file.get_value("bench%d" % i, "data", {})
		_restores[i] = data if data is Dictionary else {}
	_migrate(_loaded_version)


## 写工作区；没实例化的台保留读到的旧数据，不被当前会话清空。
func save(current_slot: int, benches: Array) -> Error:
	if current_slot < 0:
		return ERR_UNCONFIGURED
	var config_file := ConfigFile.new()
	config_file.set_value("ws", "version", VERSION)
	config_file.set_value("ws", "slot", current_slot)
	for i in 3:
		var bench = benches[i] if i < benches.size() else null
		if bench != null:
			config_file.set_value("bench%d" % i, "data", bench.snapshot())
		elif not (_restores[i] as Dictionary).is_empty():
			config_file.set_value("bench%d" % i, "data", _restores[i])
	return config_file.save(CFG_PATH)


## 旧 schema → 当前 schema。v1→v2 目前只是信封补齐；以后字段迁移都加在这里。
func _migrate(_from_version: int) -> void:
	for i in 3:
		if not (_restores[i] is Dictionary):
			_restores[i] = {}


func version() -> int:
	return VERSION


## 本次读到的原始版本（0 = 没有配置文件；1 = 旧文件；2 = 当前）
func loaded_version() -> int:
	return _loaded_version


func slot() -> int:
	return _slot


## 某个试验台的恢复数据（只读副本）
func restore(slot_index: int) -> Dictionary:
	if slot_index < 1 or slot_index > 3:
		return {}
	return (_restores[slot_index - 1] as Dictionary).duplicate(true)


## 切走时把常驻台的最新快照写回内存（不落盘）
func put_restore(slot_index: int, data: Dictionary) -> void:
	if slot_index < 1 or slot_index > 3:
		return
	_restores[slot_index - 1] = data

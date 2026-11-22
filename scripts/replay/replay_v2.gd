## 薄回放格式 v2 —— 只存每 tick 输入 + 离散命令 + 状态哈希。
##
## [b]和旧 ReplayRecorder 的区别[/b][br]
## - 不存逐帧位置 / 弹幕 / RNG trace，不靠 force despawn / graze 修正。[br]
## - 回放必须重跑同一套确定性模拟；哈希对不上就是模拟出了问题。[br]
## - 旧 v1 JSON 不兼容：v2 自带 magic + 版本，加载时直接拒绝。[br]
## [br]
## [b]格式[/b][br]
## header：tick_rate / seed / sim_version / content_hash / metadata；[br]
## body：每 tick 1 字节 mask + 1 字节 command flags + 一个 32 位状态哈希。[br]
class_name ReplayV2
extends RefCounted

const FORMAT_VERSION := 2
const MAGIC := "TSR2"
## 离散命令位（与 PlayerInput.command_flags 对齐）。
const COMMAND_BOMB := 1
const COMMAND_MEMORY := 2

var tick_rate: int = 60
var rng_seed: int = 0
## 录制起点的完整宿主 RNG state；只存 seed 会从错误的流位置开始。
var rng_state: int = 0
var sim_version: String = ""
var content_hash: String = ""
var metadata: Dictionary = {}
## 录制起点的自机资源快照（跨面开局 / 中途起点必须恢复它，否则第一帧就不同）。
var start_resources: Dictionary = {}
## 每 tick 的输入位掩码。
var masks: PackedByteArray = PackedByteArray()
## 每 tick 的离散命令位标记。
var commands: PackedByteArray = PackedByteArray()
## 每 tick 的规范状态哈希（SimHash）。
var hashes: Array[int] = []


## 开一份新录制（清空缓冲）。
func begin(p_tick_rate: int = 60, p_seed: int = 0, p_sim_version: String = "") -> void:
	tick_rate = maxi(1, p_tick_rate)
	rng_seed = p_seed
	sim_version = p_sim_version
	content_hash = ""
	metadata = {}
	start_resources = {}
	masks = PackedByteArray()
	commands = PackedByteArray()
	hashes.clear()


## 录一个 tick；mask / command_flags / state_hash 必须一一对应。
func capture_tick(mask: int, command_flags: int, state_hash: int) -> void:
	masks.append(mask & 0xFF)
	commands.append(command_flags & 0xFF)
	hashes.append(state_hash)


func tick_count() -> int:
	return masks.size()


func mask_at(p_tick: int) -> int:
	if p_tick < 0 or p_tick >= masks.size():
		return 0
	return int(masks[p_tick])


func command_at(p_tick: int) -> int:
	if p_tick < 0 or p_tick >= commands.size():
		return 0
	return int(commands[p_tick])


func hash_at(p_tick: int) -> int:
	if p_tick < 0 or p_tick >= hashes.size():
		return 0
	return hashes[p_tick]


## JSON 序列化；旧 v1 没有 magic/version，不会被误读。
func to_dict() -> Dictionary:
	return {
		"magic": MAGIC,
		"version": FORMAT_VERSION,
		"tick_rate": tick_rate,
		"seed": str(rng_seed),
		"rng_state": str(rng_state),
		"sim_version": sim_version,
		"content_hash": content_hash,
		"metadata": metadata,
		"start_resources": start_resources,
		"masks_hex": masks.hex_encode(),
		"commands_hex": commands.hex_encode(),
		"hashes": hashes,
	}


## 从字典加载；magic / 版本 / 长度任一不对都拒绝。
func load_dict(data: Dictionary) -> bool:
	if str(data.get("magic", "")) != MAGIC:
		return false
	if int(data.get("version", 0)) != FORMAT_VERSION:
		return false
	tick_rate = maxi(1, int(data.get("tick_rate", 60)))
	rng_seed = int(str(data.get("seed", "0")))
	rng_state = int(str(data.get("rng_state", "0")))
	sim_version = str(data.get("sim_version", ""))
	content_hash = str(data.get("content_hash", ""))
	metadata = data.get("metadata", {})
	if metadata is not Dictionary:
		metadata = {}
	start_resources = data.get("start_resources", {})
	if start_resources is not Dictionary:
		start_resources = {}
	masks = (str(data.get("masks_hex", "")) as String).hex_decode()
	commands = (str(data.get("commands_hex", "")) as String).hex_decode()
	hashes.clear()
	var raw_hashes = data.get("hashes", [])
	if raw_hashes is Array:
		for h in raw_hashes:
			hashes.append(int(h))
	if commands.size() != masks.size():
		return false
	if not hashes.is_empty() and hashes.size() != masks.size():
		return false
	return true


## 存盘（user:// 或绝对路径）；返回是否成功。
func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ReplayV2: 无法写入 " + path)
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


## 读盘；坏文件 / 旧格式返回 false。
func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return false
	return load_dict(parsed)

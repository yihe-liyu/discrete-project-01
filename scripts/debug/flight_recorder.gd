## 运行时飞行记录仪：把一次排练里的离散事件与 0.25s 采样收成可导出的轨迹。
##
## 它不碰内容、不写文件，只在内存里保留最近一段记录；导出与离线分析都读同一份。
## 离散事件（spawn / phase / dialogue / player）进 [member events]；
## 连续状态（弹数 / 敌数 / HP）进 [member samples]，两者时间轴相同。
class_name FlightRecorder
extends RefCounted

## 离散事件上限（环形缓冲；超出丢最旧）。
const MAX_EVENTS: int = 2000
## 采样上限（0.25s 一条，约 16 分钟；超出丢最旧）。
const MAX_SAMPLES: int = 4000

## 离散事件（按时间追加；每条 = id / t / frame / kind / source / payload）。
var events: Array[Dictionary] = []
## 连续采样（按时间追加；每条 = t / bullets / enemies / ...）。
var samples: Array[Dictionary] = []
## 本段记录的元信息（stage / difficulty / character / seed）。
var meta: Dictionary = {}

var _next_event_id: int = 1


## 开始一段新记录：清空旧数据，写入元信息。
func begin(p_meta: Dictionary) -> void:
	clear()
	meta = p_meta.duplicate(true)


## 清空事件 / 采样 / 元信息，id 归 1。
func clear() -> void:
	events.clear()
	samples.clear()
	meta.clear()
	_next_event_id = 1


## 记一条离散事件；source 形如 res://data/...:96，抓不到传空串。
func record(kind: String, payload: Dictionary, source: String, t: float) -> Dictionary:
	var event: Dictionary = {
		"id": _next_event_id,
		"t": t,
		"frame": Engine.get_physics_frames(),
		"kind": kind,
		"source": source,
		"payload": payload.duplicate(true),
	}
	_next_event_id += 1
	events.append(event)
	while events.size() > MAX_EVENTS:
		events.pop_front()
	return event


## 记一条采样（t + snapshot 字段；只保留最近 MAX_SAMPLES 条）。
func sample(t: float, snapshot: Dictionary) -> void:
	var row: Dictionary = snapshot.duplicate(true)
	row["t"] = t
	samples.append(row)
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()


## 按 id 找事件；已被环形缓冲丢掉 = 空字典。
func event_by_id(event_id: int) -> Dictionary:
	for i in range(events.size() - 1, -1, -1):
		if int(events[i].get("id", 0)) == event_id:
			return events[i]
	return {}


## 导出结构（导出 / 复制 JSON 用）。
func to_dict() -> Dictionary:
	return {
		"version": 1,
		"meta": meta.duplicate(true),
		"events": events.duplicate(true),
		"samples": samples.duplicate(true),
	}


## 导出 JSON 文本。
func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")


## 从 get_stack() 里挑第一条落在 res://data/ 的调用点。
## 返回 res://data/...:line；没有 = 空串（不猜）。
static func pick_source(stack: Array) -> String:
	for frame in stack:
		if not frame is Dictionary:
			continue
		var source := String((frame as Dictionary).get("source", ""))
		if source.begins_with("res://data/"):
			return "%s:%d" % [source, int((frame as Dictionary).get("line", 0))]
	return ""

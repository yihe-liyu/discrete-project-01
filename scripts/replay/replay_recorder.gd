## ReplayRecorder —— Replay 录输入基础设施
## 每帧记录玩家输入位掩码 + RNG 种子，可序列化为 JSON（ReplaySession 负责录制/播放生命周期）
## 铁律：capture() 必须挂在 _physics_process（物理帧固定 60Hz，与渲染帧率设置无关）——
##   挂渲染帧会导致不同帧率下录制长度不同、回放错乱。Engine.max_fps 只限渲染，物理 tick 不变。
class_name ReplayRecorder
extends RefCounted

## 录制动作顺序（位掩码按此索引 —— 格式兼容性，勿改顺序）
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "shoot", "focus", "memory_release"]
const FORMAT_VERSION := 1

## 每帧输入位掩码
var frames: PackedByteArray = PackedByteArray()
## 录制起始 RNG 种子（勿叫 seed：会遮蔽内建 seed()）
var rng_seed: int = 0
## 录制开始时的完整 RNG state；只存 seed 会丢掉当前 state。
var rng_state: int = 0
## 是否正在录制
var recording := false
## 已录帧数
var duration_frames := 0
## 回放元数据（关卡 / 难度 / 角色 / 分数等；由录制方填写）
var metadata: Dictionary = {}
## 离散输入事件（bomb / memory_release）：{frame, action}。
## 不能只靠每帧位掩码：deathbomb 定格期间物理帧停止，bomb 事件必须单独记。
var events: Array[Dictionary] = []
## 逐帧状态采样（位置 / RNG / 分数 / 残机 / 雷）；用于定位回放首个分歧。
var samples: Array[Dictionary] = []
## 得分来源事件 {frame, amount, source}：追 score 分歧用。
var score_events: Array[Dictionary] = []
## 每次敌弹命中自机：frame / uid / type / pos。很小，常驻。
var hit_events: Array[Dictionary] = []
## 弹幕生成事件：frame / uid / type / p / faction / behavior。很小，常驻。
var spawn_events: Array[Dictionary] = []
## gameplay RNG 调用序列：frame / 入口名。用于定位 RNG 流错位。
var rng_calls: Array[Dictionary] = []
## 擦弹事件：frame / uid / roll 前后 state；定位 graze 清弹跨帧。
var graze_events: Array[Dictionary] = []


## 开始录制：重置缓冲 + 记录当前 RNG 种子
func start() -> void:
	frames = PackedByteArray()
	events.clear()
	samples.clear()
	score_events.clear()
	var rng_snapshot := RNG.snapshot_state()
	rng_seed = int(rng_snapshot.get("seed", 0))
	rng_state = int(rng_snapshot.get("state", 0))
	recording = true
	duration_frames = 0


## 每帧调用一次：采样当前输入为位掩码
func capture() -> void:
	if not recording:
		return
	frames.append(input_mask())
	duration_frames += 1


## 记录一次离散动作；frame = 当前已录物理帧数（定格中也可用）。
func capture_event(action: StringName) -> void:
	if not recording:
		return
	# 当前帧 sample 已写 = 事件发生在采样之后；否则会落在下一帧采样前。
	var after_sample := samples.size() >= duration_frames
	# capture_frame 在物理帧开头先 +1，但这一帧的 sample 在帧末才写。
	# before_sample 事件实际属于 sample(duration-1)，事件帧必须同步减一。
	var event_frame := duration_frames
	if not after_sample and duration_frames > 0:
		event_frame = duration_frames - 1
	events.append({
		"frame": event_frame,
		"action": String(action),
		"after_sample": after_sample,
	})


## 记录一次得分来源（敌人 / 道具 / 擦弹 / 符卡奖励）。
func capture_score(amount: int, source: StringName) -> void:
	if not recording:
		return
	score_events.append({"frame": duration_frames, "amount": amount, "source": String(source)})


## 记录一帧状态采样（与 frames 同序）。
func capture_sample(sample: Dictionary) -> void:
	if not recording:
		return
	samples.append(sample.duplicate(true))


## 停止录制
func stop() -> void:
	recording = false


## 当前输入 → 位掩码（ACTIONS[i] 按下则第 i 位置 1）
func input_mask() -> int:
	var mask := 0
	for i in ACTIONS.size():
		if Input.is_action_pressed(ACTIONS[i]):
			mask |= 1 << i
	return mask


## 某帧是否按下某动作（回放播放器用）
func is_action_pressed_at(frame: int, action: String) -> bool:
	var idx := ACTIONS.find(action)
	if idx < 0 or frame < 0 or frame >= frames.size():
		return false
	return (frames[frame] & (1 << idx)) != 0


## 序列化（JSON）
func to_dict() -> Dictionary:
	return {
		"version": FORMAT_VERSION,
		"actions": ACTIONS,
		"seed": str(rng_seed),
		"rng_state": str(rng_state),  # 字符串防 JSON int64 精度丢失（种子决定可复现性！）
		"duration": duration_frames,
		"frames_hex": frames.hex_encode(),
		"metadata": metadata,
		"events": events,
		"samples": samples,
		"score_events": score_events,
		"hits": hit_events,
		"spawns": spawn_events,
		"rng_calls": rng_calls,
		"graze_events": graze_events,
	}


## 存盘（user:// 或绝对路径）
func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ReplayRecorder: 无法写入 " + path)
		return false
	file.store_string(JSON.stringify(to_dict()))
	return true


## 从字典加载（版本/帧数校验；失败静默返回 false，由调用方决定日志）
func load_dict(data: Dictionary) -> bool:
	if data.get("version", 0) != FORMAT_VERSION:
		return false
	rng_seed = int(data.get("seed", "0"))  # 兼容字符串存储（JSON 键仍叫 seed）
	rng_state = int(data.get("rng_state", "0"))
	duration_frames = data.get("duration", 0)
	frames = (data.get("frames_hex", "") as String).hex_decode()
	if frames.size() != duration_frames:
		return false
	metadata = data.get("metadata", {})
	if metadata is not Dictionary:
		metadata = {}
	events.clear()
	var raw_events = data.get("events", [])
	if raw_events is Array:
		for e in raw_events:
			if e is Dictionary:
				events.append(e.duplicate(true))
	samples.clear()
	var raw_samples = data.get("samples", [])
	if raw_samples is Array:
		for sample in raw_samples:
			if sample is Dictionary:
				samples.append(sample.duplicate(true))
	score_events.clear()
	var raw_scores = data.get("score_events", [])
	if raw_scores is Array:
		for e in raw_scores:
			if e is Dictionary:
				score_events.append(e.duplicate(true))
	hit_events.clear()
	var raw_hits = data.get("hits", [])
	if raw_hits is Array:
		for e in raw_hits:
			if e is Dictionary:
				hit_events.append(e.duplicate(true))
	spawn_events.clear()
	var raw_spawns = data.get("spawns", [])
	if raw_spawns is Array:
		for e in raw_spawns:
			if e is Dictionary:
				spawn_events.append(e.duplicate(true))
	rng_calls.clear()
	var raw_rng = data.get("rng_calls", [])
	if raw_rng is Array:
		for e in raw_rng:
			if e is Dictionary:
				rng_calls.append(e.duplicate(true))
	graze_events.clear()
	var raw_graze = data.get("graze_events", [])
	if raw_graze is Array:
		for e in raw_graze:
			if e is Dictionary:
				graze_events.append(e.duplicate(true))
	return true


## 读取存档文件
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

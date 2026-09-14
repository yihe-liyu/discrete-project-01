## ReplayRecorder —— Replay 录输入基础设施
## 每帧记录玩家输入位掩码 + RNG 种子，可序列化为 JSON（回放播放器后续接入）
## ⚠️ 铁律：capture() 必须挂在 _physics_process（物理帧固定 60Hz，与渲染帧率设置无关）——
##   挂渲染帧会导致不同帧率下录制长度不同、回放错乱。Engine.max_fps 只限渲染，物理 tick 不变。
class_name ReplayRecorder
extends RefCounted

## 录制动作顺序（位掩码按此索引 —— 格式兼容性，勿改顺序）
const ACTIONS := ["move_left", "move_right", "move_up", "move_down", "shoot", "focus", "memory_release"]
const FORMAT_VERSION := 1

var frames: PackedByteArray = PackedByteArray()  ## 每帧输入位掩码
var rng_seed: int = 0                             ## 录制起始 RNG 种子（勿叫 seed：会遮蔽内建 seed()）
var recording := false                            ## 是否正在录制
var duration_frames := 0                          ## 已录帧数


## 开始录制：重置缓冲 + 记录当前 RNG 种子
func start() -> void:
	frames = PackedByteArray()
	rng_seed = RNG.get_seed()
	recording = true
	duration_frames = 0


## 每帧调用一次：采样当前输入为位掩码
func capture() -> void:
	if not recording:
		return
	frames.append(input_mask())
	duration_frames += 1


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
		"seed": str(rng_seed),  # 字符串防 JSON int64 精度丢失（种子决定可复现性！）
		"duration": duration_frames,
		"frames_hex": frames.hex_encode(),
	}


## 存盘（user:// 或绝对路径）
func save(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("ReplayRecorder: 无法写入 " + path)
		return false
	f.store_string(JSON.stringify(to_dict()))
	return true


## 从字典加载（版本/帧数校验；失败静默返回 false，由调用方决定日志）
func load_dict(d: Dictionary) -> bool:
	if d.get("version", 0) != FORMAT_VERSION:
		return false
	rng_seed = int(d.get("seed", "0"))  # 兼容字符串存储（JSON 键仍叫 seed）
	duration_frames = d.get("duration", 0)
	frames = (d.get("frames_hex", "") as String).hex_decode()
	if frames.size() != duration_frames:
		return false
	return true


## 读取存档文件
func load_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is not Dictionary:
		return false
	return load_dict(parsed)

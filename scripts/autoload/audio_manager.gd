extends Node
## 音频管理器 autoload
## **音量走总线**（`Master → BGM / SE / UI`，布局在 `res://default_bus_layout.tres`；缺总线响亮告警）。
## BGM **两路**（新曲满音量直入、旧曲淡出；不淡入）+ 关键时刻自动让位（duck）；SFX 16 路池 + 同帧去重 + 最小间隔节流。
## 统计计数器（`sfx_stats()`）给「先量再调」用 —— 见 `tools/audio_density_probe.tscn`。

# ── 声道 ──
## BGM **两路**（新的直入、旧的淡出 = 交叉；**新曲不淡入**，见 `BGM_FADE_IN`）；SFX 16 路池
var _bgm_players: Array[AudioStreamPlayer] = []
## 正在播的那一路（另一路留给旧曲淡出）
var _bgm_current: AudioStreamPlayer
## 刚被 `stop_bgm()` 停过（淡出中）—— 用来区分「同曲续播」与「同曲重开」
var _bgm_stopping: bool = false
## 每路的淡出 tween —— 复用同一路前先 kill（否则两条 tween 抢同一个 volume_db）
var _bgm_fades: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 16
const BGM_PLAYER_COUNT := 2
## 旧曲淡出 / 停止淡出的默认时长（秒）
const BGM_FADE := 0.6
## 新曲**淡入**时长（秒）。**0 = 不淡入**（作者 2026-10-10 拍板：换曲/重开都"干脆"地满音量直入）
## —— 想恢复"新曲渐入"就把它设成 0.6（旧曲淡出仍然照旧，交叉还在）。
const BGM_FADE_IN := 0.0
const SILENT_DB := -80.0

# ── 总线（布局 = res://default_bus_layout.tres）──
## 音量**一律走总线**（`AudioServer.set_bus_volume_db`）：改一下当场对所有在响的声音生效，
## 也能在总线上挂效果器（限幅/压缩）。per-player 的 `volume_db` 只留**均衡偏移**。
## ⚠️ 总线在布局文件里缺一条 → 音量**不会生效**（引擎静默回退 Master）⇒ `_require_bus` 响亮告警。
const BUS_MASTER := &"Master"
const BUS_BGM := &"BGM"
const BUS_SE := &"SE"
const BUS_UI := &"UI"
## 缺总线只告警一次（防每帧刷屏）
static var _warned_missing_buses: Dictionary = {}

## 每帧已播放的音效流，防止同帧重复播放
var _played_this_frame: Array[AudioStream] = []
## 各音效上次播放时间（秒），配合 min_interval 限制高频音效频率
var _last_played_at: Dictionary = {}
## 受保护音效：播放中不被池抢占（重要反馈，如玩家被击中）
var _protected_streams: Array = []

# ── 统计（B：密度护栏「先量再调」的仪表；也留给性能工具读）──
## 累计起了多少路声音
var sfx_played_total: int = 0
## 池满、**踢掉了正在响的一路**的次数 —— 听感上就是「被掐断」
var sfx_evicted_total: int = 0
## 其中踢到**受保护**音效的次数（>0 说明 16 路全被重要音占满，危险信号）
var sfx_evicted_protected_total: int = 0
## 本帧起了几路（每帧清零）
var sfx_started_this_frame: int = 0
## 被「同帧去重」挡掉的请求数
var sfx_deduped_total: int = 0
## 被「最小间隔节流」挡掉的请求数
var sfx_throttled_total: int = 0
## 单帧起声部数的历史峰值
var sfx_peak_voices_per_frame: int = 0
## 上一整秒起了多少路
var sfx_per_second: int = 0
## 密度压制量的峰值 / 均值（dB，<=0）—— 「护栏到底动了多少」的账
var density_cut_peak_db: float = 0.0
var _density_cut_sum: float = 0.0
var _density_samples: int = 0
var _sfx_second_start_ms: int = 0
var _sfx_count_this_second: int = 0

# ── 密度护栏（B：实测真实关卡 ≈22 路/秒、峰值 14/16 路同时在响）──
## 同时在响超过这个数**才开始**压制 —— 低于它 = 正常场面，一个数都不动
const DENSITY_KNEE := 8
## 每多一路压多少 dB
const DENSITY_DB_PER_VOICE := 0.75
## 压制上限（压过头会「整片变小」）
const DENSITY_MAX_CUT_DB := -3.0
## 声部数的**平滑**系数（每帧）——用瞬时值会「忽大忽小」（正是要治的病）
const DENSITY_SMOOTH := 0.12
## 高优先级：**永不**吃密度压制、也最后被池驱逐（回报音 / 宣言 / 菜单）
const SFX_PRIORITY_HIGH: Array[String] = [
	"player_die", "boss_die", "player_card", "get_card", "get_player",
	"ok", "cancel", "select", "pause",
]
## 密集持续音（实测主力）：池满时**先踢它们**
const SFX_PRIORITY_LOW: Array[String] = [
	"kira", "player_shoot", "msl", "lazer", "marisa_damage", "normal_damage",
]
## 平滑后的在响声部数（只有**新起**的声部吃它算出来的压制）
var _density_ema: float = 0.0

# ── 音量（线性 0..1；落到总线上）──
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volumes()
var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volumes()
var sfx_volume: float = 0.7:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		_apply_bus_volumes()
## BGM 总线的**动态**压低量（dB，<=0）—— 见 `duck_bgm`（D：符卡宣言/击破时音乐让位）
var _bgm_duck_db: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_init_players()
	_apply_bus_volumes()
	# 受保护音效：播放中不被池抢占（重要反馈，如玩家被击中）
	_protected_streams = [AssetRegistry.sounds["player_die"]]
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _process(_delta: float) -> void:
	_played_this_frame.clear()
	sfx_started_this_frame = 0
	_density_ema = lerpf(_density_ema, float(active_voice_count()), DENSITY_SMOOTH)
	var cut := density_cut_db()
	density_cut_peak_db = minf(density_cut_peak_db, cut)
	_density_cut_sum += cut
	_density_samples += 1
	var now_ms := Time.get_ticks_msec()
	if _sfx_second_start_ms == 0:
		_sfx_second_start_ms = now_ms
	if now_ms - _sfx_second_start_ms >= 1000:
		sfx_per_second = _sfx_count_this_second
		_sfx_count_this_second = 0
		_sfx_second_start_ms = now_ms


## 当前密度压制量（dB，<=0）。按**平滑后**的在响声部数算；低于 `DENSITY_KNEE` = 0。
## 只作用于**新起**的声部（已经在响的不动），否则会「泵」——那正是要治的病。
func density_cut_db() -> float:
	var over := _density_ema - float(DENSITY_KNEE)
	if over <= 0.0:
		return 0.0
	return maxf(DENSITY_MAX_CUT_DB, -DENSITY_DB_PER_VOICE * over)


## 统计快照（工具 / 探针 / 测试读它；`reset_sfx_stats()` 清零后再跑一段）。
func sfx_stats() -> Dictionary:
	return {
		"played": sfx_played_total,
		"evicted": sfx_evicted_total,
		"evicted_protected": sfx_evicted_protected_total,
		"deduped": sfx_deduped_total,
		"throttled": sfx_throttled_total,
		"per_second": sfx_per_second,
		"peak_per_frame": sfx_peak_voices_per_frame,
		"active_voices": active_voice_count(),
		"pool_size": SFX_POOL_SIZE,
		"density_cut": density_cut_db(),
		"density_cut_peak": density_cut_peak_db,
		"density_cut_avg": _density_cut_sum / float(_density_samples) if _density_samples > 0 else 0.0,
	}


## 目前在响的声部数（池里 playing 的路数）
func active_voice_count() -> int:
	var n := 0
	for player in _sfx_players:
		if player.playing:
			n += 1
	return n


## 清零统计（只清统计，不动正在播的声音）
func reset_sfx_stats() -> void:
	sfx_played_total = 0
	sfx_evicted_total = 0
	sfx_evicted_protected_total = 0
	sfx_started_this_frame = 0
	sfx_peak_voices_per_frame = 0
	sfx_deduped_total = 0
	sfx_throttled_total = 0
	sfx_per_second = 0
	density_cut_peak_db = 0.0
	_density_cut_sum = 0.0
	_density_samples = 0
	_density_ema = 0.0
	_sfx_count_this_second = 0
	_sfx_second_start_ms = 0


# ═══ 初始化 ═══

func _init_players() -> void:
	if _bgm_players.is_empty():
		var bgm_bus := _require_bus(BUS_BGM)
		for i in range(BGM_PLAYER_COUNT):
			var player := AudioStreamPlayer.new()
			player.bus = bgm_bus
			player.process_mode = PROCESS_MODE_ALWAYS
			player.volume_db = SILENT_DB
			add_child(player)
			_bgm_players.append(player)

	if _sfx_players.is_empty():
		var se_bus := _require_bus(BUS_SE)
		for i in range(SFX_POOL_SIZE):
			var player := AudioStreamPlayer.new()
			player.bus = se_bus
			add_child(player)
			_sfx_players.append(player)


# ═══ BGM ═══

## 实际切换了 BGM（用于 BGM 提示等 UI 跟随）
signal bgm_started(stream: AudioStream)

## 播 BGM（换曲：**新的满音量直入**、旧的淡出；同一首正在播则不动）。
func play_bgm(stream: AudioStream, _gap_unused: float = 0.0) -> void:
	_play_bgm_at(stream, 0.0)

## 从指定秒数播放 BGM（工作台续跑恢复音乐进度用）
func play_bgm_from(stream: AudioStream, from: float) -> void:
	_play_bgm_at(stream, maxf(from, 0.0))

func _play_bgm_at(stream: AudioStream, from: float) -> void:
	if _bgm_players.is_empty():
		_init_players()
	if stream == null:
		push_warning("AudioManager.play_bgm: stream 为 null —— 不切曲（BGM key 可能没解析到）")
		return
	# ① **同一首已经在某一路**（含正在淡出的那一路）→ 复用那一路。
	#    ⚠️ 绝不另起一路同曲：关卡重开是「stop_bgm()（淡出）→ 立刻 reload → 新场景又播同一首」，
	#    若新起一路，同一首歌会**自己叠自己**（两路不同播放位置 = 合唱/回声，作者报的「重开后音乐重叠」）。
	var existing := _find_bgm_player_with(stream)
	if existing != null:
		existing.stream_paused = false
		# 正在正常播（且不是刚被 stop）→ 不重头播：换场景时同曲**续播**
		if existing == _bgm_current and not _bgm_stopping:
			return
		_adopt_bgm(existing, stream, from)
		return

	var next := _pick_bgm_player()
	var prev := _bgm_current
	_bgm_current = next
	_bgm_stopping = false
	_stop_fade(next)
	next.stream = stream
	next.stream_paused = false
	next.volume_db = SILENT_DB
	next.play(from)
	_fade_bgm(next, 0.0, BGM_FADE_IN, false)   # BGM_FADE_IN = 0 ⇒ 当场满音量（不淡入）
	if prev and is_instance_valid(prev) and prev != next:
		_fade_bgm(prev, SILENT_DB, BGM_FADE, true)
	bgm_started.emit(stream)
	# 音乐解锁已由 AssetRegistry.get_bgm 统一处理（播放即听过）


## 停 BGM（默认淡出，不是硬切）；`fade` = 0 立即停
func stop_bgm(fade: float = BGM_FADE) -> void:
	for player in _bgm_players:
		if player.playing:
			_fade_bgm(player, SILENT_DB, maxf(fade, 0.0), true)
	_bgm_current = null
	_bgm_stopping = true   # 之后的 play_bgm(同一首) 走「复用那一路重头播」，不另起一路同曲


## 暂停当前 BGM（创作台整关预览切走时用；位置冻结，恢复后原处继续）。
func pause_bgm() -> void:
	for player in _bgm_players:
		if player.playing:
			player.stream_paused = true


## 恢复 BGM；只清 stream_paused，不重播/不抢别的曲。
func resume_bgm() -> void:
	for player in _bgm_players:
		if player.stream_paused:
			player.stream_paused = false


## 当前 BGM 是否被暂停（测试/宿主查询）
func bgm_paused() -> bool:
	return _bgm_current != null and is_instance_valid(_bgm_current) and _bgm_current.stream_paused


## 复用**已经在放这一首**的那一路（重开 / 快速来回切）：停掉它的淡入淡出、从头播，其余各路淡出。
## 保证「同一首永远只有一路在响」。
func _adopt_bgm(player: AudioStreamPlayer, stream: AudioStream, from: float) -> void:
	_bgm_current = player
	_bgm_stopping = false
	_stop_fade(player)
	player.stream = stream
	player.stream_paused = false
	player.volume_db = SILENT_DB
	player.play(from)
	_fade_bgm(player, 0.0, BGM_FADE_IN, false)   # 重开也是满音量直入（不淡入）
	for other in _bgm_players:
		if other != player and other.playing:
			_fade_bgm(other, SILENT_DB, BGM_FADE, true)
	bgm_started.emit(stream)


func _find_bgm_player_with(stream: AudioStream) -> AudioStreamPlayer:
	for player in _bgm_players:
		if player.playing and player.stream == stream:
			return player
	return null


## BGM 变速（工作台快进时音乐跟随游戏时间；1.0 = 正常）
func set_bgm_pitch(pitch: float) -> void:
	for player in _bgm_players:
		player.pitch_scale = maxf(pitch, 0.01)


# ═══ BGM 让位（duck）═══
# 关键时刻音响起时把 BGM 压下去一点再自动回落 —— 音乐不再和音效抢。

## 哪些音效响起时自动让位（按资源 key；语义 = "这一下比音乐重要"）
const BGM_DUCK_ON_SFX: Array[String] = ["player_card", "boss_die"]
const BGM_DUCK_DB := -6.0
## 压低保持（秒）；之后自动回落
const BGM_DUCK_HOLD := 0.9
## 起落时间（秒）——比武器的 crossfade 快，否则"让位"变成"抽气"
const BGM_DUCK_FADE := 0.12

var _bgm_duck_tween: Tween


## 让 BGM 让位（一般由 `play_sfx` 按 `BGM_DUCK_ON_SFX` 自动调；也可手动）
func duck_bgm(amount_db: float = BGM_DUCK_DB, hold: float = BGM_DUCK_HOLD) -> void:
	if _bgm_duck_tween and _bgm_duck_tween.is_valid():
		_bgm_duck_tween.kill()
	_bgm_duck_tween = create_tween()
	_bgm_duck_tween.set_trans(Tween.TRANS_SINE)
	_bgm_duck_tween.tween_method(_set_bgm_duck_db, _bgm_duck_db, amount_db, BGM_DUCK_FADE)
	_bgm_duck_tween.tween_interval(hold)
	_bgm_duck_tween.tween_method(_set_bgm_duck_db, amount_db, 0.0, BGM_DUCK_FADE)


func _set_bgm_duck_db(db: float) -> void:
	_bgm_duck_db = db
	_set_bus_volume(BUS_BGM, bgm_volume)


func _pick_bgm_player() -> AudioStreamPlayer:
	for player in _bgm_players:
		if player != _bgm_current and not player.playing:
			return player
	for player in _bgm_players:
		if player != _bgm_current:
			return player
	return _bgm_players[0]


func _fade_bgm(player: AudioStreamPlayer, to_db: float, duration: float, stop_after: bool) -> void:
	_stop_fade(player)
	if duration <= 0.0:
		player.volume_db = to_db
		if stop_after:
			player.stop()
		return
	var tween := player.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "volume_db", to_db, duration)
	if stop_after:
		tween.tween_callback(player.stop)
	_bgm_fades[player] = tween


func _stop_fade(player: AudioStreamPlayer) -> void:
	if _bgm_fades.has(player):
		var tween: Tween = _bgm_fades[player]
		if tween and tween.is_valid():
			tween.kill()
		_bgm_fades.erase(player)


# ═══ 总线音量 ═══

## 把所有音量落到总线上（唯一出口）。三个 setter + `_ready` 都走这里。
func _apply_bus_volumes() -> void:
	_set_bus_volume(BUS_MASTER, master_volume)
	_set_bus_volume(BUS_BGM, bgm_volume)
	_set_bus_volume(BUS_SE, sfx_volume)
	# UI 与 SE 共用一条滑杆（设置里没有第三条），但**独立总线**：SE 的密度护栏/限幅不该泵到菜单音
	_set_bus_volume(BUS_UI, sfx_volume)


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		_require_bus(bus_name)
		return
	AudioServer.set_bus_volume_db(idx, _to_db(linear) + _bus_offset_db(bus_name))


## 总线上的**动态**偏移（dB）：目前只有 BGM 的 duck（见 `duck_bgm`）。静态偏移请写进布局文件。
func _bus_offset_db(bus_name: StringName) -> float:
	return _bgm_duck_db if bus_name == BUS_BGM else 0.0


# ═══ SFX ═══

## 播一次音效，返回播放器（返回值通常不用）。
## 同帧同一流不重复；min_interval > 0 时限制该流最小播放间隔（秒，高频音效防挤兑用）
## bus 默认 `SE`；UI 音（菜单）传 `BUS_UI` —— 与 SE 分开，不被 SE 的密度护栏/限幅牵连。
func play_sfx(stream: AudioStream, volume_db: float = SFX_LEVEL_DB, min_interval: float = 0.0,
		bus: StringName = BUS_SE) -> void:
	if _sfx_players.is_empty():
		_init_players()

	# 同帧不重复
	if stream in _played_this_frame:
		sfx_deduped_total += 1
		return
	_played_this_frame.append(stream)

	# 最小间隔节流（跨帧限频）：命中/擦弹这类高频音效避免持续占满池
	if min_interval > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		var last: float = _last_played_at.get(stream, -INF)
		if now - last < min_interval:
			sfx_throttled_total += 1
			return
		_last_played_at[stream] = now

	var player := _pick_sfx_player()
	if not player:
		return

	var key := _key_of_stream(stream)
	# 密度压制：多声叠加时**新起**的密集音压一点（重要音不吃）
	var cut_db := 0.0 if SFX_PRIORITY_HIGH.has(key) else density_cut_db()
	player.set_meta("protected", stream in _protected_streams)
	player.stream = stream
	player.bus = bus
	# per-player 只剩**均衡偏移**：总电平/主音量/SE 音量都在总线上（改动当场生效，含在响的）
	player.volume_db = clampf(volume_db + _base_db(stream) + sfx_trim_db + cut_db, -80.0, 24.0)
	player.play()
	sfx_played_total += 1
	_sfx_count_this_second += 1
	sfx_started_this_frame += 1
	sfx_peak_voices_per_frame = maxi(sfx_peak_voices_per_frame, sfx_started_this_frame)
	if BGM_DUCK_ON_SFX.has(key):
		duck_bgm()


## UI 音效语义键 → 资源键（音效知识唯一 owner：调用方只喊 "nav/confirm/back"，不必知道资源键）
const UI_SFX_KEYS := {"nav": "select", "confirm": "ok", "back": "cancel"}

## 播放 UI 音效（按语义 kind，如 "nav"/"confirm"/"back"）—— 走独立 `UI` 总线
func play_ui_sfx(kind: String) -> void:
	var key: String = UI_SFX_KEYS.get(kind, "")
	if key == "":
		return
	play_sfx(AssetRegistry.sounds[key], SFX_LEVEL_DB, 0.0, BUS_UI)


## 需要节流的高频音（擦弹/命中）：总电平走默认，只传最小间隔
func play_sfx_throttled(stream: AudioStream, min_interval: float) -> void:
	play_sfx(stream, SFX_LEVEL_DB, min_interval)


## 每个音效的**基准音量**（dB）：由 `AssetRegistry.SFX_DB` 按 key 给出，首次用时反查成 stream → dB。
## 总电平现在有名字（`SFX_LEVEL_DB`）且是默认值 —— 调用点**不用再写**，均衡关系全由表决定（R17）。
static var _base_db_cache: Dictionary = {}
## stream → 资源 key 反查（「按 key 配置」的规则用，如 `BGM_DUCK_ON_SFX`）
static var _key_cache: Dictionary = {}


func _base_db(stream: AudioStream) -> float:
	if _base_db_cache.is_empty():
		for key in AssetRegistry.sounds:
			_base_db_cache[AssetRegistry.sounds[key]] = AssetRegistry.SFX_DB.get(key, 0.0)
	return _base_db_cache.get(stream, 0.0)


func _key_of_stream(stream: AudioStream) -> String:
	if _key_cache.is_empty():
		for key in AssetRegistry.sounds:
			_key_cache[AssetRegistry.sounds[key]] = String(key)
	return _key_cache.get(stream, "")


## 池满时「谁该被踢」的排序（越大越先踢）：密集持续音 2 > 一般 1 > 重要 0
func _eviction_rank(stream: AudioStream) -> int:
	var key := _key_of_stream(stream)
	if SFX_PRIORITY_LOW.has(key):
		return 2
	if SFX_PRIORITY_HIGH.has(key):
		return 0
	return 1


## 音效**总电平**（dB）。相对关系由 `AssetRegistry.SFX_DB` 决定，这里只管整体大小。
## 曾因 `lc.sfx()` 的 db 默认 0.0（满音量）误压到 -15.0；真凶修好后已回到原值 -12.0。
## ⚠️ 觉得**所有**音效整体偏大/偏小 → 动这一个数（3 dB ≈ 明显一档）；只嫌某一个吵 → 改 `SFX_DB` 里那一行。
## 调用点**不用再写**它 —— 不传就是它。
const SFX_LEVEL_DB := -12.0
## 弹幕音效的**最小间隔**（秒）。弹幕是"每颗子弹一次"的高频源，只靠同帧去重仍可到 ~60 次/秒 ——
## 同一个音连打就是机关枪，听感上"格外大"。节流后最多 ~12 次/秒。
## ⚠️ 还嫌吵就继续调大（0.15 ≈ 6.7 次/秒），或直接压 `SFX_DB` 里那个音。
const BULLET_SFX_MIN_INTERVAL := 0.08
## **额外**压低（dB，<=0）。给"某些场景该更安静"用（当前：符卡练习）。
## 正常流程保持 0.0 —— 不改动你已经调好的那套值。
var sfx_trim_db: float = 0.0


## 从池中挑一个可用的播放器。
## 优先空闲；全忙时先踢不受保护的（最老的），全被保护才踢最老——重要音效不被挤掉。
func _pick_sfx_player() -> AudioStreamPlayer:
	# 1) 有空闲 → 用它
	for player in _sfx_players:
		if not player.playing:
			return player

	# 2) 全忙 → 踢**最不重要**的（同级里踢最老的）：密集持续音先让位，回报音不被挤掉
	var victim: AudioStreamPlayer = null
	var victim_rank := -1
	var victim_tick := -INF
	for player in _sfx_players:
		if player.get_meta("protected", false):
			continue
		var rank := _eviction_rank(player.stream)
		var tick := player.get_playback_position()
		if rank > victim_rank or (rank == victim_rank and tick > victim_tick):
			victim = player
			victim_rank = rank
			victim_tick = tick
	if victim:
		victim.stop()
		sfx_evicted_total += 1
		return victim

	# 3) 全被保护（罕见：16 路全被保护音效占用）→ 踢最老
	var oldest := _sfx_players[0]
	var oldest_tick := oldest.get_playback_position()
	for i in range(1, _sfx_players.size()):
		var player := _sfx_players[i]
		var tick := player.get_playback_position()
		if tick > oldest_tick:
			oldest = player
			oldest_tick = tick
	oldest.stop()
	sfx_evicted_total += 1
	sfx_evicted_protected_total += 1
	return oldest


# ═══ 内部 ═══

func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80
	return linear_to_db(linear)


## 总线存在性守卫：**缺了就响亮告警**（引擎会静默回退 Master，音量/效果器全失效）。
## 返回总线名（存在）或 `Master`（缺失时的兜底）。
func _require_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	if not _warned_missing_buses.has(bus_name):
		_warned_missing_buses[bus_name] = true
		push_warning("AudioManager: 总线 '%s' 不存在（res://default_bus_layout.tres 缺这条）—— 该路音量与效果器不会生效，已回退 Master" % bus_name)
	return BUS_MASTER

func _on_game_state_changed(_old: int, new: int) -> void:
	var paused: bool = new == GameManager.AppState.PAUSED or new == GameManager.AppState.TRANSITIONING
	for player in _bgm_players:
		player.stream_paused = paused
	# SFX 在 tree.paused 下自动静音，无需额外处理

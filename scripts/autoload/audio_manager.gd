extends Node
## 音频管理器 autoload
## BGM 单路（无需 crossfade），SFX 16 路池 + 同帧去重 + 最小间隔节流

# ── 声道 ──
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE := 16

## 每帧已播放的音效流，防止同帧重复播放
var _played_this_frame: Array[AudioStream] = []
## 各音效上次播放时间（秒），配合 min_interval 限制高频音效频率
var _last_played_at: Dictionary = {}
## 受保护音效：播放中不被池抢占（重要反馈，如玩家被击中）
var _protected_streams: Array = []

# ── 音量 ──
var master_volume: float = 1.0:
	set(v):
		master_volume = clampf(v, 0.0, 1.0)
		_bgm_sync_volume()
var bgm_volume: float = 1.0:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		_bgm_sync_volume()
var sfx_volume: float = 0.7:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_init_players()
	# 受保护音效：播放中不被池抢占（重要反馈，如玩家被击中）
	_protected_streams = [AssetRegistry.sounds["player_die"]]
	GameManager.game_state_changed.connect(_on_game_state_changed)


func _process(_delta: float) -> void:
	_played_this_frame.clear()


# ═══ 初始化 ═══

func _init_players() -> void:
	if not _bgm_player:
		_bgm_player = AudioStreamPlayer.new()
		_bgm_player.bus = _find_bus("BGM")
		_bgm_player.process_mode = PROCESS_MODE_ALWAYS
		add_child(_bgm_player)

	if _sfx_players.is_empty():
		var sfx_bus := _find_bus("SFX")
		for i in range(SFX_POOL_SIZE):
			var player := AudioStreamPlayer.new()
			player.bus = sfx_bus
			add_child(player)
			_sfx_players.append(player)


# ═══ BGM ═══

## 实际切换了 BGM（用于 BGM 提示等 UI 跟随）
signal bgm_started(stream: AudioStream)

## 播 BGM（覆盖当前播放）。播放前无间隔、无渐弱。
func play_bgm(stream: AudioStream, _gap_unused: float = 0.0) -> void:
	_play_bgm_at(stream, 0.0)

## 从指定秒数播放 BGM（工作台续跑恢复音乐进度用）
func play_bgm_from(stream: AudioStream, from: float) -> void:
	_play_bgm_at(stream, maxf(from, 0.0))

func _play_bgm_at(stream: AudioStream, from: float) -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		_init_players()
	if _bgm_player.playing and _bgm_player.stream == stream:
		return

	_bgm_player.stop()
	_bgm_player.stream = stream
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)
	_bgm_player.play(from)
	bgm_started.emit(stream)
	# 音乐解锁已由 AssetRegistry.get_bgm 统一处理（播放即听过）


func stop_bgm() -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		return
	_bgm_player.stop()


## BGM 变速（工作台快进时音乐跟随游戏时间；1.0 = 正常）
func set_bgm_pitch(pitch: float) -> void:
	if _bgm_player and is_instance_valid(_bgm_player):
		_bgm_player.pitch_scale = maxf(pitch, 0.01)


# ═══ BGM 音量同步 ═══

func _bgm_sync_volume() -> void:
	if not _bgm_player or not is_instance_valid(_bgm_player):
		return
	_bgm_player.volume_db = _to_db(bgm_volume * master_volume)


# ═══ SFX ═══

## 播一次音效，返回播放器（返回值通常不用）。
## 同帧同一流不重复；min_interval > 0 时限制该流最小播放间隔（秒，高频音效防挤兑用）
func play_sfx(stream: AudioStream, volume_db: float = 0.0, min_interval: float = 0.0) -> void:
	if _sfx_players.is_empty():
		_init_players()

	# 同帧不重复
	if stream in _played_this_frame:
		return
	_played_this_frame.append(stream)

	# 最小间隔节流（跨帧限频）：命中/擦弹这类高频音效避免持续占满池
	if min_interval > 0.0:
		var now := Time.get_ticks_msec() / 1000.0
		var last: float = _last_played_at.get(stream, -INF)
		if now - last < min_interval:
			return
		_last_played_at[stream] = now

	var player := _pick_sfx_player()
	if not player:
		return

	player.set_meta("protected", stream in _protected_streams)
	player.stream = stream
	player.volume_db = clampf(volume_db + _to_db(sfx_volume), -80.0, 24.0)
	player.play()


## UI 音效语义键 → 资源键（音效知识唯一 owner：调用方只喊 "nav/confirm/back"，不必知道资源键）
const UI_SFX_KEYS := {"nav": "select", "confirm": "ok", "back": "cancel"}

## 播放 UI 音效（按语义 kind，如 "nav"/"confirm"/"back"）
func play_ui_sfx(kind: String) -> void:
	var key: String = UI_SFX_KEYS.get(kind, "")
	if key == "":
		return
	play_sfx(AssetRegistry.sounds[key])


## 从池中挑一个可用的播放器。
## 优先空闲；全忙时先踢不受保护的（最老的），全被保护才踢最老——重要音效不被挤掉。
func _pick_sfx_player() -> AudioStreamPlayer:
	# 1) 有空闲 → 用它
	for player in _sfx_players:
		if not player.playing:
			return player

	# 2) 全忙 → 先踢不受保护的（最早开始播放的那个）
	var oldest_free: AudioStreamPlayer = null
	var oldest_tick := -INF
	for player in _sfx_players:
		if player.get_meta("protected", false):
			continue
		var tick := player.get_playback_position()
		if tick > oldest_tick:
			oldest_free = player
			oldest_tick = tick
	if oldest_free:
		oldest_free.stop()
		return oldest_free

	# 3) 全被保护（罕见：16 路全被保护音效占用）→ 踢最老
	var oldest := _sfx_players[0]
	oldest_tick = oldest.get_playback_position()
	for i in range(1, _sfx_players.size()):
		var player := _sfx_players[i]
		var tick := player.get_playback_position()
		if tick > oldest_tick:
			oldest = player
			oldest_tick = tick
	oldest.stop()
	return oldest


# ═══ 内部 ═══

func _to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80
	return linear_to_db(linear)


func _find_bus(bus_name: String) -> StringName:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return StringName(bus_name)
	return &"Master"


func _on_game_state_changed(_old: int, new: int) -> void:
	if not _bgm_player:
		return
	_bgm_player.stream_paused = (new == GameManager.AppState.PAUSED or new == GameManager.AppState.TRANSITIONING)
	# SFX 在 tree.paused 下自动静音，无需额外处理

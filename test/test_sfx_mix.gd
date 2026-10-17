extends GutTest
## 音效均衡表（`AssetRegistry.SFX_DB`）：只锁**不变量**，不锁具体 dB
## （数值是作者会调的混音决定；锁死了每次调音量都要改测试）。


## 每个音效都要有基准音量 —— 漏一个就退回"完全由 wav 自身电平决定"的老问题
func test_every_sound_has_base_db():
	for key in AssetRegistry.sounds:
		assert_true(AssetRegistry.SFX_DB.has(key), "音效 %s 应在 SFX_DB 里有基准音量" % key)


## 表必须**中心化**（均值≈0）：调用点原有的 -12.0 才是总电平，表只表达相对关系
func test_table_is_centered():
	assert_gt(AssetRegistry.SFX_DB.size(), 0, "表不应为空")
	var total := 0.0
	for key in AssetRegistry.SFX_DB:
		total += AssetRegistry.SFX_DB[key]
	var mean: float = total / float(AssetRegistry.SFX_DB.size())
	assert_almost_eq(mean, 0.0, 0.5, "整表均值应≈0（中心化，否则总音量会被表整体推高/压低）")


## 基准音量不该离谱（±12 dB 以内 —— 超出说明某个音源电平异常，该去查源文件）
func test_base_db_within_sane_range():
	for key in AssetRegistry.SFX_DB:
		assert_between(AssetRegistry.SFX_DB[key], -12.0, 12.0, "%s 的基准音量应 ±12dB 内" % key)


# ═══ 音量总线（A：音量走总线，2026-10-10）═══
# 背景：布局文件里的总线**缺一条时引擎静默回退 Master**，音量/效果器全失效且不报错 ——
# 下面第一条就是「骨架在不在」的哨兵；其余锁「三段音量各自落到哪条总线」。


func test_buses_exist():
	for bus_name in [AudioManager.BUS_BGM, AudioManager.BUS_SE, AudioManager.BUS_UI]:
		assert_gt(AudioServer.get_bus_index(bus_name), 0,
			"总线 %s 应存在（res://default_bus_layout.tres）" % bus_name)


## 三段音量各自落到自己的总线。**主音量必须管到 SE** —— 它曾经只乘进 BGM（半死的旋钮）。
func test_volumes_land_on_their_buses():
	AudioManager.master_volume = 0.5
	AudioManager.bgm_volume = 0.5
	AudioManager.sfx_volume = 0.5
	assert_almost_eq(_bus_db(AudioManager.BUS_MASTER), linear_to_db(0.5), 0.01, "主音量 → Master 总线")
	assert_almost_eq(_bus_db(AudioManager.BUS_BGM), linear_to_db(0.5), 0.01, "BGM 音量 → BGM 总线")
	assert_almost_eq(_bus_db(AudioManager.BUS_SE), linear_to_db(0.5), 0.01, "SE 音量 → SE 总线")
	assert_almost_eq(_bus_db(AudioManager.BUS_UI), linear_to_db(0.5), 0.01, "UI 跟随 SE 滑杆")
	_restore_default_volumes()


## 滑杆拉到 0 必须是**静音**（不是 0 dB = 满音量）
func test_zero_volume_is_silence():
	AudioManager.sfx_volume = 0.0
	assert_almost_eq(_bus_db(AudioManager.BUS_SE), -80.0, 0.01, "SE 拉到 0 应静音")
	_restore_default_volumes()


## SE 播放器只留**均衡偏移**：滑杆不再写进 per-player —— 写进去 = 拖滑杆时对**已经在响**的声音无效
func test_sfx_player_carries_only_balance_offset():
	await get_tree().process_frame
	AudioManager.sfx_volume = 0.25
	AudioManager.play_sfx(AssetRegistry.sounds["item"])
	var player := _playing_on(AudioManager.BUS_SE)
	assert_not_null(player, "应有一路在 SE 总线上播")
	if player:
		var expected: float = AudioManager.SFX_LEVEL_DB + AssetRegistry.SFX_DB["item"] + AudioManager.density_cut_db()
		assert_almost_eq(player.volume_db, expected, 0.01, "per-player 只含总电平 + 均衡（+ 密度压制），不含滑杆")
	_restore_default_volumes()


## UI 音走**独立总线**：SE 上的密度护栏/限幅不该把菜单音一起泵掉
func test_ui_sfx_uses_ui_bus():
	await get_tree().process_frame
	AudioManager.play_ui_sfx("nav")
	var player := _playing_on(AudioManager.BUS_UI)
	assert_not_null(player, "UI 音应在 UI 总线上播")
	if player:
		assert_eq(player.stream, AssetRegistry.sounds["select"], "nav 语义键 → select 资源")
	_restore_default_volumes()


## 缺总线要**响亮**（引擎静默回退 Master，不告警就永远查不出来）
func test_missing_bus_warns_loudly():
	var idx := AudioServer.get_bus_index(AudioManager.BUS_SE)
	assert_gt(idx, 0, "前提：SE 总线存在")
	AudioServer.set_bus_name(idx, &"SE_TEMP")
	AudioManager.master_volume = 0.5   # 触发一次全量应用 → SE 找不到
	assert_push_warning("总线 'SE' 不存在")
	AudioServer.set_bus_name(idx, AudioManager.BUS_SE)
	_restore_default_volumes()


# ═══ 密度护栏（B：实测 ≈22 路/秒、峰值 14/16 路同时在响，2026-10-10）═══


## SE 总线必须挂**硬限幅**：14 路同时在响时不做峰值保护就是削波（听感 = 糊/破）
func test_se_bus_has_hard_limiter():
	var idx := AudioServer.get_bus_index(AudioManager.BUS_SE)
	assert_gt(AudioServer.get_bus_effect_count(idx), 0, "SE 总线应有效果器（硬限幅）")
	var found := false
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectHardLimiter:
			found = true
	assert_true(found, "SE 总线应挂 AudioEffectHardLimiter（防多声叠加削波）")


## 密度压制：空闲时为 0（正常场面一个数都不动），声部堆起来才压，散开后**自动归零**
func test_density_cut_rises_with_voices_and_recovers():
	_release_all_se_voices()
	await wait_seconds(0.6)   # 让平滑值落回 0
	assert_almost_eq(AudioManager.density_cut_db(), 0.0, 0.01, "空闲时不应压制")
	var streams := _play_distinct(12)
	assert_gt(streams.size(), 0, "应起了多路不同音")
	await wait_seconds(0.6)
	assert_lt(AudioManager.density_cut_db(), -0.01, "声部堆起来后应开始压制")
	assert_true(AudioManager.density_cut_db() >= AudioManager.DENSITY_MAX_CUT_DB - 0.01, "压制应有上限")
	_release_all_se_voices()
	await wait_seconds(0.9)
	assert_almost_eq(AudioManager.density_cut_db(), 0.0, 0.05, "散开后应自动归零")


## 池满时踢的是**最不重要**的，不是最老的：先起的**重要音**要活下来
## （旧策略「踢最老的」会把它掐掉 —— 这条就是那个行为的哨兵）
func test_pool_pressure_keeps_high_priority():
	_release_all_se_voices()
	await get_tree().process_frame
	var important: AudioStream = AssetRegistry.sounds["boss_die"]
	AudioManager.play_sfx(important)
	for i in 15:   # 补满 16 路（都是"一般"优先级 ≠ 重要音）
		await get_tree().process_frame
		AudioManager.play_sfx(_silent_stream(3.0))
	assert_eq(AudioManager.active_voice_count(), AudioManager.SFX_POOL_SIZE, "前提：池应被占满")
	await get_tree().process_frame
	AudioManager.play_sfx(AssetRegistry.sounds["kira"])   # 低优先级，必然触发一次驱逐
	assert_gt(AudioManager.sfx_stats()["evicted"], 0, "池满后应发生驱逐")
	assert_true(_stream_is_playing(important), "重要音（boss_die）不该被密度音挤掉")
	_release_all_se_voices()


## 关卡**重开**：`pause_menu` 的路径是「`stop_bgm()`（淡出）→ 立刻 reload → 新场景又播同一首」。
## 同一首**永远只允许一路在响** —— 否则同一首歌自己叠自己（作者报的「重开后音乐重叠」）。
func test_stop_then_play_same_stream_does_not_double():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE + 0.1)
	AudioManager.stop_bgm()      # 重开第一步：先停（默认淡出）
	AudioManager.play_bgm(a)     # 重开第二步：新场景马上又播同一首
	await wait_seconds(AudioManager.BGM_FADE * 0.3)
	assert_eq(_bgm_playing_streams().size(), 1, "同一首不能有两路同时在响（重开会自己叠自己）")
	AudioManager.stop_bgm(0.0)


## 正在淡出的那一首被重新叫起来 → 复用**同一路**（不是另起一路同曲）
func test_restarting_fading_stream_reuses_same_player():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE + 0.1)
	var player := _active_bgm()
	AudioManager.stop_bgm()
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE * 0.5)
	assert_eq(_active_bgm(), player, "同一首重开应复用原来那一路")
	AudioManager.stop_bgm(0.0)


## **不要淡入**：新曲一上来就是满音量（作者要"干脆"）—— 只有**旧曲**淡出
func test_bgm_starts_at_full_volume_without_fade_in():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await get_tree().process_frame
	var player := _active_bgm()
	assert_not_null(player, "刚起就应该在响")
	if player:
		assert_almost_eq(player.volume_db, 0.0, 0.01, "不要淡入：一上来就是满音量")
	AudioManager.stop_bgm(0.0)


## 重开同一首也是**满音量直入**（不是从 -80 dB 慢慢推上来）
func test_restart_same_stream_starts_at_full_volume():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await wait_seconds(0.2)
	AudioManager.stop_bgm()      # 淡出中
	AudioManager.play_bgm(a)     # 重开：复用那一路
	await get_tree().process_frame
	var player := _active_bgm()
	assert_not_null(player, "重开后应在响")
	if player:
		assert_almost_eq(player.volume_db, 0.0, 0.01, "重开也是满音量直入（不淡入）")
	AudioManager.stop_bgm(0.0)


# ── 测试辅助 ──

## 起 n 路互不相同的音（同帧去重按 stream 判重，所以每路都得是新实例）
func _play_distinct(count: int) -> Array[AudioStream]:
	var streams: Array[AudioStream] = []
	for i in count:
		var stream := _silent_stream(3.0)
		streams.append(stream)
		AudioManager.play_sfx(stream)
	return streams


func _release_all_se_voices() -> void:
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer and player.bus == AudioManager.BUS_SE:
			player.stop()


func _stream_is_playing(stream: AudioStream) -> bool:
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer and player.stream == stream:
			return player.playing
	return false


func _bus_db(bus_name: StringName) -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_name))


func _playing_on(bus_name: StringName) -> AudioStreamPlayer:
	for child in AudioManager.get_children():
		if child is AudioStreamPlayer and child.playing and child.bus == bus_name:
			return child
	return null


func _restore_default_volumes() -> void:
	AudioManager.master_volume = 1.0
	AudioManager.bgm_volume = 1.0
	AudioManager.sfx_volume = 0.7


# ═══ 动态混音（D：BGM duck + 交叉淡入淡出，2026-10-10）═══


## 让位是**有起落**的：压下去 → 保持 → **自动回落**（不会一直闷着）
func test_duck_lowers_bgm_then_releases():
	AudioManager.bgm_volume = 1.0
	# BGM 让位是**跨用例状态**（别的用例播过 boss_die/player_card 会留下余温）→ 先等它散掉
	await wait_seconds(AudioManager.BGM_DUCK_HOLD + AudioManager.BGM_DUCK_FADE * 2.0 + 0.2)
	var base := _bus_db(AudioManager.BUS_BGM)
	AudioManager.duck_bgm()
	await wait_seconds(AudioManager.BGM_DUCK_FADE + 0.1)
	assert_almost_eq(_bus_db(AudioManager.BUS_BGM), base + AudioManager.BGM_DUCK_DB, 0.6, "让位期间应压低")
	await wait_seconds(AudioManager.BGM_DUCK_HOLD + AudioManager.BGM_DUCK_FADE + 0.2)
	assert_almost_eq(_bus_db(AudioManager.BUS_BGM), base, 0.1, "保持结束后应**自动回落**到原音量")


## 关键时刻音（符卡宣言/Boss 全破）**自动**触发让位 —— 调用点不必知道 duck 的存在
func test_critical_sfx_triggers_duck():
	AudioManager.bgm_volume = 1.0
	await get_tree().process_frame
	AudioManager.play_sfx(AssetRegistry.sounds["player_card"])
	await wait_seconds(AudioManager.BGM_DUCK_FADE + 0.1)
	assert_lt(_bus_db(AudioManager.BUS_BGM), -1.0, "宣言音响起时 BGM 应让位")
	await wait_seconds(AudioManager.BGM_DUCK_HOLD + AudioManager.BGM_DUCK_FADE + 0.2)
	assert_almost_eq(_bus_db(AudioManager.BUS_BGM), 0.0, 0.1, "让位结束应回落")


## 换曲 = **交叉**淡入淡出：两路同时在响（新的进、旧的退），结束后只剩新那首
func test_bgm_change_crossfades():
	await _reset_bgm()
	var a := _silent_stream()
	var b := _silent_stream()
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE + 0.1)
	assert_eq(_bgm_playing_streams(), [a] as Array[AudioStream], "第一首应在播")
	AudioManager.play_bgm(b)
	await wait_seconds(AudioManager.BGM_FADE * 0.4)   # 交叉进行中
	var during := _bgm_playing_streams()
	assert_true(during.has(a), "交叉中旧那首还在淡出（不是硬切）")
	assert_true(during.has(b), "交叉中新那首已经进来")
	await wait_seconds(AudioManager.BGM_FADE + 0.2)
	var after := _bgm_playing_streams()
	assert_eq(after.size(), 1, "交叉淡出结束后应只剩一路在响")
	assert_eq(after[0], b, "剩下的应是新那首")
	AudioManager.stop_bgm(0.0)


## 同一首**正在响**时不重头播（换场景同曲续播）；停掉之后再播才重头
func test_same_stream_does_not_restart():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE + 0.1)
	var player := _active_bgm()
	watch_signals(AudioManager)
	AudioManager.play_bgm(a)
	assert_signal_not_emitted(AudioManager, "bgm_started", "同一首正在响 → 不应重发 bgm_started")
	assert_eq(_active_bgm(), player, "同一首应仍在原来那一路（没有重头播）")
	AudioManager.stop_bgm(0.0)
	await get_tree().process_frame
	assert_false(player.playing, "stop_bgm(0) 应立即停（工作台重跑靠这个）")


## 停止默认是**淡出**，`fade = 0` 才是立即停
func test_stop_bgm_fades_by_default():
	await _reset_bgm()
	var a := _silent_stream(20.0)
	AudioManager.play_bgm(a)
	await wait_seconds(AudioManager.BGM_FADE + 0.1)
	var player := _active_bgm()
	AudioManager.stop_bgm()
	assert_true(player.playing, "淡出期间还在响（不是硬切）")
	await wait_seconds(AudioManager.BGM_FADE + 0.2)
	assert_false(player.playing, "淡出结束应停")


## 当前**在响**的 BGM 路（音量不为静音的那一路）
func _active_bgm() -> AudioStreamPlayer:
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer and player.bus == AudioManager.BUS_BGM \
				and player.playing and player.volume_db > AudioManager.SILENT_DB:
			return player
	return null


func _bgm_playing_streams() -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for player in AudioManager.get_children():
		if player is AudioStreamPlayer and player.bus == AudioManager.BUS_BGM and player.playing:
			out.append(player.stream)
	return out


## 每个 BGM 用例先清场：BGM 是 autoload 的**跨用例状态**，不清就会互相串
func _reset_bgm() -> void:
	AudioManager.stop_bgm(0.0)
	await get_tree().process_frame


## 自建静音流：测试不绑内容（BGM 素材换了/删了不该让它红）
func _silent_stream(seconds: float = 3.0) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(int(44100 * seconds) * 2)
	wav.data = bytes
	return wav

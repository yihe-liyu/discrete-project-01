## 全项目资源注册表：内容槽的代码侧索引表，改一处全局生效。
##
## 不是 autoload；调用方统一用 [code]AssetRegistry.xxx[/code]。
## 表内的 [code]res://[/code] 与中文 key 属于内容槽引用，按基线「命名边界契约」豁免。
##
## 退役条件：随图集/数据化逐表迁到 [code]data/*.tres[/code]；迁完一表移除一表豁免。
## 当前仅余 [code]enemy_visuals[/code] / [code]sounds[/code] / [code]BGM_PATHS[/code] / [code]LASER_TEXTURE[/code]。
class_name AssetRegistry

## 敌人外观：id -> 场景；[code]EnemyData[/code] / 创作台外观清单从这里取。
const enemy_visuals := {
	"blue_little_fairy":  preload("res://data/enemy_visual/blue_little_fairy.tscn"),
	"red_little_fairy":  preload("res://data/enemy_visual/red_little_fairy.tscn"),
	"green_little_fairy":  preload("res://data/enemy_visual/green_little_fairy.tscn"),
	"yellow_little_fairy":  preload("res://data/enemy_visual/yellow_little_fairy.tscn"),
	"red_middle_fairy":  preload("res://data/enemy_visual/red_middle_fairy.tscn"),
	"blue_middle_fairy":  preload("res://data/enemy_visual/blue_middle_fairy.tscn"),
	"red_big_fairy":  preload("res://data/enemy_visual/red_big_fairy.tscn"),
	"blue_big_fairy":  preload("res://data/enemy_visual/blue_big_fairy.tscn"),
	"white_huge_fairy":  preload("res://data/enemy_visual/white_huge_fairy.tscn"),
	"red_yin_yang_jade":  preload("res://data/enemy_visual/red_yin_yang_jade.tscn"),
	"green_yin_yang_jade":  preload("res://data/enemy_visual/green_yin_yang_jade.tscn"),
	"blue_yin_yang_jade":  preload("res://data/enemy_visual/blue_yin_yang_jade.tscn"),
	"purple_yin_yang_jade":  preload("res://data/enemy_visual/purple_yin_yang_jade.tscn"),
	"death":  preload("res://data/enemy_visual/death_effect.tscn"),
}


## 激光贴图（碰撞由激光系统自行处理，这里只提供贴图）。
## 弹型的贴图/判定/朝向已迁到 [code]data/bullets/*.tres[/code]（[code]BulletCatalog[/code] 读取）；
## 本表不再承载弹型内容。
const LASER_TEXTURE := preload("res://assets/Textures/bullet/laser.png")

## 音效均衡表（dB，已中心化：整表均值约 0）。
## 来源：量各 wav 的 RMS，向 -20 dBFS 对齐后减去均值；总电平由 [code]AudioManager.SFX_LEVEL_DB[/code] 控制。
## RMS 只负责拉平源文件之间约 13 dB 的差异；短促/高频音的听感偏差仍需手调。
## 觉得哪个音不对，只改这里，不用动播放代码。
## 新加音效时先用 [code]python3 tools/sfx_db_baseline.py[/code] 算起点。
const SFX_DB := {
	"cancel": +1.4,   ## 手调：菜单返回音，同上
	"card": -0.3,
	## 符卡干净收取的回报音（作者素材）。起点 = RMS 基准(+3.9)，作者反馈偏小 → +3 dB
	"get_card": +6.9,
	## 拿到完整残机的回报音（作者素材）。起点 = RMS 基准(+0.4)：素材 RMS −13.1 dBFS，
	## 比 get_card 的源还响 ~3.5 dB ⇒ 几乎不用补（取基准 ⇒ 与 item/graze 的有效 RMS 相同）
	"get_player": +0.4,
	"enemy_die": +2.6,
	"boss_die": -3.0,   ## 专用素材（作者提供）。RMS 基准 -4.4，随整表居中抬到与其余音效同档
	"graze": +5.5,
	"item": +5.3,
	"kira": -4.6,   ## 手调（作者反馈两次）：弹幕每颗子弹都发它，密度+高频 ⇒ 必须比 RMS 值再低一截
	"lazer": -3.3,
	"marisa_damage": -0.6,   ## 手调（作者反馈两次）：魔理沙子机弹的命中音（focus 弹专属 key），最多 20 次/秒（节流 0.05）
 ## ⇒ 压 7 dB（相对 RMS 基准 −7.9），与 kira 同档：高频持续音必须比 RMS 值再低一截
	"msl": -5.3,   ## 手调（作者反馈两次）：魔理沙子机（focus）的发射音，~12 次/秒的持续音 ⇒ 同样压 7 dB（相对基准 −7.9）
	"normal_damage": -3.3,
	"ok": +4.3,
	"pause": +4.3,
	"player_card": +3.3,   ## 手调：Bomb 宣言是关键时刻音，该亮出来
	"player_die": -3.3,
	"player_shoot": -4.4,   ## 手调：自机射击是持续音，连打时疲劳；作者两次反馈偏大
	"select": -0.3,   ## 手调：菜单导航音。短促点击，RMS 高估了它的响度 ⇒ 表里被压过头，作者反馈偏小
	"shoot": +2.0,   ## 手调：作者要求更突出
}


## 音效 key -> AudioStream；key 必须与 [code]SFX_DB[/code] 对应。
const sounds := {
	"shoot":        preload("res://assets/Sound/shoot.wav"),
	"player_shoot": preload("res://assets/Sound/player_shoot.wav"),
	"kira":         preload("res://assets/Sound/kira.wav"),
	"enemy_die":    preload("res://assets/Sound/enemy_die.wav"),
	"player_die":   preload("res://assets/Sound/player_die.wav"),
	"graze":        preload("res://assets/Sound/graze.wav"),
	"item":         preload("res://assets/Sound/item.wav"),
	"card":         preload("res://assets/Sound/card.wav"),
	## 符卡干净收取（正常流程）的回报音 —— 见 [code]Boss.CAPTURE_SFX[/code]
	"get_card":     preload("res://assets/Sound/get_card.wav"),
	## 拿到完整残机（碎片集满 5 片 / 吃到整命道具）的回报音 —— 见 [code]Item.EXTEND_SFX[/code]
	"get_player":   preload("res://assets/Sound/get_player.wav"),
	"player_card":  preload("res://assets/Sound/player_card.wav"),
	# ── UI ──
	"select":       preload("res://assets/Sound/select.wav"),
	"ok":           preload("res://assets/Sound/ok.wav"),
	"cancel":       preload("res://assets/Sound/cancel.wav"),
	"pause":        preload("res://assets/Sound/pause.wav"),

	"lazer":          preload("res://assets/Sound/lazer.wav"),
	"marisa_damage":  preload("res://assets/Sound/marisa_damage.wav"),
	"msl":            preload("res://assets/Sound/msl.wav"),
	"normal_damage":  preload("res://assets/Sound/normal_damage.wav"),
	# Boss 全破（[code]Boss.play_defeat[/code]）。专用素材；[code]BossData.defeat_sfx[/code] 可按 Boss 换 key。
	"boss_die":       preload("res://assets/Sound/boss_die.wav"),
}

## BGM key -> 路径；按需 [code]load[/code]（不要 preload 大文件）。
## 音乐室与游戏内播放共用此表；[code]MusicRecord[/code] 只存 [code]bgm_key[/code]。
const BGM_PATHS := {
	# 音乐室曲目（与 music_registry.tres 的 bgm_key 对应）
	"music_1":  "res://assets/Music/THq01_01.无缘故之回.mp3",
	"music_2":  "res://assets/Music/THq01_02.夜间漫步.mp3",
	"music_3":  "res://assets/Music/THq01_03.洞窟蝙蝠.mp3",
	"music_4":  "res://assets/Music/THq01_04.又一次瞥向日食.mp3",
	"music_7":  "res://assets/Music/THq01_07.就在那里的不思议宇宙.mp3",
	"music_10": "res://assets/Music/THq01_10.寂寥记忆界.mp3",
	"music_12": "res://assets/Music/THq01_12.不尽记忆的天空.mp3",
	"music_16": "res://assets/Music/THq01_16.忘不了，与生俱来的未来.mp3",
	"music_17": "res://assets/Music/THq01_17.朝夕之阳，在远在洋.mp3",
	"music_18": "res://assets/Music/THq01_18.以空为核，抽丝剥茧.mp3",
	# 游戏内场景 BGM（语义 key，可指向音乐室曲目）
	"menu":        "res://assets/Music/THq01_01.无缘故之回.mp3",
	"stage1":      "res://assets/Music/THq01_02.夜间漫步.mp3",
	"stage1_boss": "res://assets/Music/THq01_03.洞窟蝙蝠.mp3",
	"stage2":      "res://assets/Music/THq01_04.又一次瞥向日食.mp3",
	"stage3B":     "res://assets/Music/THq01_07.就在那里的不思议宇宙.mp3",
	"stage4":      "res://assets/Music/THq01_10.寂寥记忆界.mp3",
	"stage5":      "res://assets/Music/THq01_12.不尽记忆的天空.mp3",
	"stage6B_boss":"res://assets/Music/THq01_16.忘不了，与生俱来的未来.mp3",
	"stageEX":     "res://assets/Music/THq01_17.朝夕之阳，在远在洋.mp3",
	"stageEX_boss":"res://assets/Music/THq01_18.以空为核，抽丝剥茧.mp3",
}

## 音乐室出厂目录（只读）。
const MUSIC_REGISTRY_PATH := "res://data/registry/music_registry.tres"
## 运行期解锁档；导出包 [code]res://[/code] 只读，写入一律走 [code]user://[/code]。
const MUSIC_REGISTRY_USER_PATH := "user://music_registry.tres"


## 载入出厂目录并叠加 [code]user://[/code] 解锁状态；新增曲目不会因旧档消失。
## 出厂/用户档缺失或不可用时返回可用的出厂表。
static func load_music_registry() -> MusicRegistry:
	var registry: MusicRegistry = null
	if ResourceLoader.exists(MUSIC_REGISTRY_PATH):
		registry = ResourceLoader.load(MUSIC_REGISTRY_PATH)
	if registry == null:
		registry = MusicRegistry.new()
	if not FileAccess.file_exists(MUSIC_REGISTRY_USER_PATH):
		return registry
	var override: MusicRegistry = ResourceLoader.load(MUSIC_REGISTRY_USER_PATH)
	if override == null:
		return registry
	for record in registry.records:
		var override_record: MusicRecord = override.get_by_id(record.music_id)
		if override_record != null:
			record.is_unlocked = override_record.is_unlocked
	return registry


## 保存解锁状态到 [code]user://[/code]；失败会报错，不静默丢进度。
static func save_music_registry(registry: MusicRegistry) -> void:
	var err := ResourceSaver.save(registry, MUSIC_REGISTRY_USER_PATH)
	if err != OK:
		push_error("AssetRegistry.save_music_registry: 保存失败（%s）：%s"
			% [error_string(err), MUSIC_REGISTRY_USER_PATH])

static var _bgm_cache: Dictionary = {}
# BGM 路径 -> 曲名（首次 get_bgm_title 时建一次；曲名不随解锁状态变化）
static var _bgm_titles: Dictionary = {}
static var _bgm_titles_ready: bool = false
# 未知 / 加载失败的 BGM key：只告警一次，避免调用方每帧刷屏
static var _bgm_missing: Dictionary = {}

## 按 key 取 BGM；首次 [code]load[/code] 后按 key 缓存。
## 播放视为听过，顺带解锁音乐室同路径曲目；未知/加载失败只告警一次并返回 null。
static func get_bgm(key: String) -> AudioStream:
	if _bgm_cache.has(key):
		return _bgm_cache[key]
	var path: String = BGM_PATHS.get(key, "")
	if path.is_empty():
		_warn_missing_bgm(key, "未知 BGM key")
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		_warn_missing_bgm(key, "BGM 加载失败：" + path)
		return null
	_bgm_cache[key] = stream
	_unlock_music_by_key(key)
	return stream


## 由 stream 的资源路径反查曲名；首次建 path -> title 缓存，之后 O(1)。
## 同一文件的不同 key（[code]stage1[/code] / [code]music_2[/code]）返回同一曲名。
static func get_bgm_title(stream: AudioStream) -> String:
	if stream == null:
		return ""
	var path: String = stream.resource_path
	if path.is_empty():
		return ""
	_ensure_bgm_titles()
	return _bgm_titles.get(path, "")


# 首次需要曲名时建 path -> title 映射；之后 O(1)。
static func _ensure_bgm_titles() -> void:
	if _bgm_titles_ready:
		return
	var registry: MusicRegistry = load_music_registry()
	if registry == null:
		return
	_bgm_titles_ready = true
	for record in registry.records:
		var path: String = BGM_PATHS.get(record.bgm_key, "")
		if not path.is_empty() and not _bgm_titles.has(path):
			_bgm_titles[path] = record.title


static func _warn_missing_bgm(key: String, reason: String) -> void:
	if _bgm_missing.has(key):
		return
	_bgm_missing[key] = true
	push_warning("AssetRegistry.get_bgm: %s（key='%s'）" % [reason, key])


## 播放 BGM 视为听过，解锁音乐室同路径曲目（幂等，仅首次解锁写盘）。
static func _unlock_music_by_key(bgm_key: String) -> void:
	var registry: MusicRegistry = load_music_registry()
	if not registry:
		return
	var path: String = BGM_PATHS.get(bgm_key, "")
	if path.is_empty():
		return
	var changed := false
	for r in registry.records:
		if r.is_unlocked:
			continue
 # 该曲目的注册器路径 == 当前播放路径 → 听过
		if BGM_PATHS.get(r.bgm_key, "") == path:
			r.is_unlocked = true
			changed = true
	if changed:
		save_music_registry(registry)

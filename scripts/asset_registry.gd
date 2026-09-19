## AssetRegistry — 全项目资源注册表（**内容槽的代码侧索引表**），改一处全局生效。
## 不再是 autoload（R9）—— 改 `class_name` 静态表（R8）；调用方 `AssetRegistry.xxx` 语法不变。
## **契约**：本表的 `res://` 与中文 key 属内容槽引用，按基线「命名边界契约」**明确豁免**（非机制标识符）。
## **退役条件**：随 S13 图集 + 数据化（F7：打包 + `AtlasLayout` + `BulletType` `.tres`）逐表迁 `data/*.tres`（R17）；迁完一表移除一表豁免。
class_name AssetRegistry

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

const FOG_TEXTURE: Texture2D = preload("res://assets/Textures/bullet/弹雾.png")

const bullet_configs := {
	# 微型弹
	"点弹":   {"tex": preload("res://assets/Textures/bullet/点弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	"点棱弹":   {"tex": preload("res://assets/Textures/bullet/点棱弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	"菌弹":   {"tex": preload("res://assets/Textures/bullet/菌弹.png"),   "hitbox": {"circle": 4.0, "offset": {"x": 0, "y": 0}}},
	# 小型弹
	"小玉":   {"tex": preload("res://assets/Textures/bullet/小玉.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"星弹":   {"tex": preload("res://assets/Textures/bullet/星弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"枪弹":   {"tex": preload("res://assets/Textures/bullet/枪弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"棱弹":   {"tex": preload("res://assets/Textures/bullet/棱弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"滴弹":   {"tex": preload("res://assets/Textures/bullet/滴弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"环玉":   {"tex": preload("res://assets/Textures/bullet/环玉.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"符札":   {"tex": preload("res://assets/Textures/bullet/符札.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"米弹":   {"tex": preload("res://assets/Textures/bullet/米弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"苦无":   {"tex": preload("res://assets/Textures/bullet/苦无.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"长菌弹":   {"tex": preload("res://assets/Textures/bullet/长菌弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	"鳞弹":   {"tex": preload("res://assets/Textures/bullet/鳞弹.png"),   "hitbox": {"circle": 6.0, "offset": {"x": 0, "y": 0}}},
	# 中型弹
	"小光玉": {"tex": preload("res://assets/Textures/bullet/小光玉.png"), "hitbox": {"circle": 12.0, "offset": {"x": 0, "y": 0}}},

	# 自机弹
	"reimu_main":     {"tex": preload("res://assets/Textures/player/reimu_main_bullet.png"),    "hitbox": {"rect": {"w": 48, "h": 24}, "offset": {"x": 0, "y": 0}}},
	"reimu_opt1":     {"tex": preload("res://assets/Textures/player/reimu_option_bullet1.png"), "hitbox": {"circle": 12.0, "offset": {"x": 0, "y": 0}}},
	"reimu_opt2":     {"tex": preload("res://assets/Textures/player/reimu_option_bullet2.png"), "hitbox": {"rect": {"w": 120, "h": 24}, "offset": {"x": 0, "y": 0}}},
	"marisa_main":    {"tex": preload("res://assets/Textures/player/marisa_main_bullet.png"),   "hitbox": {"rect": {"w": 48, "h": 24}, "offset": {"x": 0, "y": 0}}},
	"marisa_opt1":    {"tex": preload("res://assets/Textures/player/marisa_option_bullet1.png"), "hitbox": {"rect": {"w": 32, "h": 32}, "offset": {"x": 0, "y": 0}}},
	"marisa_opt2":    {"tex": preload("res://assets/Textures/player/marisa_option_bullet2.png"), "hitbox": {"rect": {"w": 48, "h": 24}, "offset": {"x": 0, "y": 0}}},
	"reimu_bomb01":   {"tex": preload("res://assets/Textures/player/reimu_bomb01.png"), "hitbox": {"circle": 45.0, "offset": {"x": 0, "y": 0}}},
	# 激光贴图（碰撞由激光系统自行处理，这里只提供贴图）
	"laser":    {"tex": preload("res://assets/Textures/bullet/laser.png"), "hitbox": {"circle": 0.0, "offset": {"x": 0, "y": 0}}},
}

const sounds := {
	"shoot":        preload("res://assets/Sound/shoot.wav"),
	"player_shoot": preload("res://assets/Sound/player_shoot.wav"),
	"kira":         preload("res://assets/Sound/kira.wav"),
	"enemy_die":    preload("res://assets/Sound/enemy_die.wav"),
	"player_die":   preload("res://assets/Sound/player_die.wav"),
	"graze":        preload("res://assets/Sound/graze.wav"),
	"item":         preload("res://assets/Sound/item.wav"),
	"card":         preload("res://assets/Sound/card.wav"),
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
}

## BGM 资源表 —— 按需加载（load 而非 preload，避免启动即解码大文件）
## 路径唯一来源：音乐室（music_registry.tres）与游戏内播放共用此表；
## MusicRecord 只存 bgm_key 引用（展示数据），不再存路径
const BGM_PATHS := {
	# 音乐室曲目（与 music_registry.tres 的 bgm_key 对应）
	"music_1":  "res://assets/Music/THq01_01.无缘故之回.mp3",
	"music_2":  "res://assets/Music/THq01_02.夜间漫步.mp3",
	"music_3":  "res://assets/Music/THq01_03.洞窟蝙蝠.mp3",
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
	"stage3B":     "res://assets/Music/THq01_07.就在那里的不思议宇宙.mp3",
	"stage4":      "res://assets/Music/THq01_10.寂寥记忆界.mp3",
	"stage5":      "res://assets/Music/THq01_12.不尽记忆的天空.mp3",
	"stage6B_boss":"res://assets/Music/THq01_16.忘不了，与生俱来的未来.mp3",
	"stageEX":     "res://assets/Music/THq01_17.朝夕之阳，在远在洋.mp3",
	"stageEX_boss":"res://assets/Music/THq01_18.以空为核，抽丝剥茧.mp3",
}

const MUSIC_REGISTRY_PATH := "res://data/registry/music_registry.tres"   # 出厂默认（只读）
## 运行期解锁档（R14：导出包 res:// 只读，运行期写入一律 user://）
const MUSIC_REGISTRY_USER_PATH := "user://music_registry.tres"


## 加载音乐注册表：以出厂目录为基准，叠加 user:// 的解锁状态
## （新增曲目不会因旧解锁档而消失）。无 user:// 档时 = 出厂目录。
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


## 保存解锁状态到 user://（R14）
static func save_music_registry(registry: MusicRegistry) -> void:
	ResourceSaver.save(registry, MUSIC_REGISTRY_USER_PATH)

static var _bgm_cache: Dictionary = {}

## 按需加载 BGM（带缓存，首次访问后复用）；播放视为听过 → 顺带解锁音乐室对应曲目
static func get_bgm(key: String) -> AudioStream:
	if _bgm_cache.has(key):
		return _bgm_cache[key]
	var path: String = BGM_PATHS.get(key, "")
	if path.is_empty():
		push_warning("AssetRegistry.get_bgm: 未知 BGM key '%s'" % key)
		return null
	var stream: AudioStream = load(path)
	_bgm_cache[key] = stream
	_unlock_music_by_key(key)
	return stream


## BGM 曲名（BGM 提示 UI 用）：由 stream 的资源路径反查音乐室记录
## 游戏语义 key（stage1）与音乐室 key（music_2）指向同一文件 → 按路径关联取同一曲名
static func get_bgm_title(stream: AudioStream) -> String:
	if stream == null:
		return ""
	var path: String = stream.resource_path
	if path.is_empty():
		return ""
	var registry: MusicRegistry = load_music_registry()
	if registry == null:
		return ""
	for r in registry.records:
		if BGM_PATHS.get(r.bgm_key, "") == path:
			return r.title
	return ""


## 播放 BGM 视为听过 → 解锁音乐室对应曲目（幂等，仅首次解锁写盘）
## 按路径关联：游戏 key（stage1）与音乐室 key（music_2）指向同一文件时视为同一曲
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

static func get_bullet_tex(key: String) -> Texture2D:
	var cfg: Dictionary = bullet_configs.get(key, {})
	return cfg.get("tex")

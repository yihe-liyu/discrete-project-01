## AssetRegistry — 全项目资源注册表（**内容槽的代码侧索引表**），改一处全局生效。
## 不再是 autoload（R9）—— 改 `class_name` 静态表（R8）；调用方 `AssetRegistry.xxx` 语法不变。
## **契约**：本表的 `res://` 与中文 key 属内容槽引用，按基线「命名边界契约」**明确豁免**（非机制标识符）。
## **退役条件**：随 S13 图集 + 数据化（F7：打包 + `AtlasLayout` + `BulletType` `.tres`）逐表迁 `data/*.tres`（R17）；迁完一表移除一表豁免。
## **F7 进度（2026-09-20）**：A = 弹幕贴图全部进图集（`data/atlas/bullet_shapes.tres` + `assets/Textures/bullet/bullet.png`）；
## ② = 弹型内容表从代码 `bullet_configs` 迁到 `data/bullets/*.tres`（`BulletCatalog` 读取）→ **`bullet_configs` 表已退役**。
## 本表仅余 `enemy_visuals` / `sounds` / `BGM_PATHS` / `LASER_TEXTURE`（内容槽引用豁免范围相应收窄）。
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


## 激光贴图（碰撞由激光系统自行处理，这里只提供贴图）。
## 弹幕的**贴图引用 / 判定 / 朝向**已迁到 `data/bullets/*.tres`（`BulletCatalog` 读取）：
## 见 `scripts/data/bullet_catalog.gd` + `scripts/data/bullet_type.gd`；本表不再承载弹型内容。
const LASER_TEXTURE := preload("res://assets/Textures/bullet/laser.png")

## 音效**均衡表**（dB，已中心化：整表均值 ≈ 0）。
## 来源：量各 wav 的 RMS，向 -20 dBFS 对齐后减去均值 —— 所以**总电平**（`AudioManager.SFX_LEVEL_DB`）不受影响，
## 这里只表达**相对**关系（谁该响一点、谁该轻一点）。
## ⚠️ 觉得哪个音不对，**只改这里**就行，不用去动播放代码。
## 定位：**RMS 只是起点，耳朵才是终局** —— 它负责把源文件之间 ~13 dB 的电平差拉平；
## 短促/高频音的听感偏差（`kira` 偏响、菜单点击偏小）RMS 无法建模，只能手调（下面标 `## 手调` 的就是）。
## 新加音效时用 `python3 tools/sfx_db_baseline.py` 算起点，并看哪些是手调过的。
const SFX_DB := {
	"cancel": +1.4,   ## 手调：菜单返回音，同上
	"card": -0.3,
	"enemy_die": +2.6,
	"boss_die": -3.0,   ## 专用素材（作者提供）。RMS 基准 -4.4，随整表居中抬到与其余音效同档
	"graze": +5.5,
	"item": +5.3,
	"kira": -4.6,   ## 手调（作者反馈两次）：弹幕每颗子弹都发它，密度+高频 ⇒ 必须比 RMS 值再低一截
	"lazer": -3.3,
	"marisa_damage": -0.6,   ## 手调（作者反馈两次）：**魔理沙子机弹的命中音**（focus 弹专属 key），最多 20 次/秒（节流 0.05）
	                         ## ⇒ 压 7 dB（相对 RMS 基准 −7.9），与 kira 同档：高频持续音必须比 RMS 值再低一截
	"msl": -5.3,   ## 手调（作者反馈两次）：**魔理沙子机（focus）的发射音**，~12 次/秒的持续音 ⇒ 同样压 7 dB（相对基准 −7.9）
	"normal_damage": -3.3,
	"ok": +4.3,
	"pause": +4.3,
	"player_card": +3.3,   ## 手调：Bomb 宣言是关键时刻音，该亮出来
	"player_die": -3.3,
	"player_shoot": -4.4,   ## 手调：自机射击是持续音，连打时疲劳；作者两次反馈偏大
	"select": -0.3,   ## 手调：菜单导航音。短促点击，RMS 高估了它的响度 ⇒ 表里被压过头，作者反馈偏小
	"shoot": +2.0,   ## 手调：作者要求更突出
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
	# Boss 全破（`Boss.play_defeat`）。专用素材；`BossData.defeat_sfx` 可按 Boss 换 key。
	"boss_die":       preload("res://assets/Sound/boss_die.wav"),
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

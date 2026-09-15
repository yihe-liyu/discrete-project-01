# MusicRecord.gd — 单首音乐的播放记录
extends Resource
class_name MusicRecord

## 音乐编号（NO.xx）
@export var music_id: int = 0
## 曲名
@export var title: String = ""
## 评语
@export_multiline var comment: String = ""
## 资源注册器 BGM key（AssetRegistry.BGM_PATHS，如 "music_1"）；播放走 AssetRegistry.get_bgm
@export var bgm_key: String = ""
## 是否已解锁（在游戏中播放过一次）
@export var is_unlocked: bool = false

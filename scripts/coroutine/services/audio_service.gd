## 音频服务 —— 协程中通过 ctx.audio 访问
class_name AudioService
extends RefCounted

## 总开关：false 时所有音频调用静默 no-op。
var is_active: bool = true

## 播 BGM；is_active=false 时 no-op。
func play_bgm(stream: AudioStream, gap: float = 0.0) -> void:
	if not is_active: return
	AudioManager.play_bgm(stream, gap)

## 停 BGM；is_active=false 时 no-op。
func stop_bgm() -> void:
	if not is_active: return
	AudioManager.stop_bgm()

## 播音效；is_active=false 时 no-op。
func play_sfx(stream: AudioStream, volume_db: float = AudioManager.SFX_LEVEL_DB) -> void:
	if not is_active: return
	AudioManager.play_sfx(stream, volume_db)

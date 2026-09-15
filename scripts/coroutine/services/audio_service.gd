class_name AudioService
## 音频服务 —— 协程中通过 ctx.audio 访问
extends RefCounted

var is_active: bool = true

func play_bgm(stream: AudioStream, gap: float = 0.0) -> void:
	if not is_active: return
	AudioManager.play_bgm(stream, gap)

func stop_bgm() -> void:
	if not is_active: return
	AudioManager.stop_bgm()

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not is_active: return
	AudioManager.play_sfx(stream, volume_db)

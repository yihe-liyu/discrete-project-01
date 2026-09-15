# MusicRegistry.gd — 音乐注册表
extends Resource
class_name MusicRegistry

## 全音乐记录
@export var records: Array[MusicRecord] = []


func get_by_id(music_id: int) -> MusicRecord:
	for r in records:
		if r.music_id == music_id:
			return r
	return null


func get_unlocked() -> Array[MusicRecord]:
	var result: Array[MusicRecord] = []
	for r in records:
		if r.is_unlocked:
			result.append(r)
	return result


func unlock(music_id: int) -> void:
	var r := get_by_id(music_id)
	if r:
		r.is_unlocked = true


func is_unlocked(music_id: int) -> bool:
	var r := get_by_id(music_id)
	return r != null and r.is_unlocked


## 通过 BGM key 解锁（返回是否实际解锁，幂等）
func unlock_by_bgm_key(bgm_key: String) -> bool:
	var did_change := false
	for r in records:
		if r.bgm_key == bgm_key and not r.is_unlocked:
			r.is_unlocked = true
			did_change = true
	return did_change

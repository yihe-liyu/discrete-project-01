# MusicRegistry.gd — 音乐注册表
## 音乐注册表：MusicRecord 集合 + 按编号 / BGM key 查询与解锁。
extends Resource
class_name MusicRegistry

## 全音乐记录
@export var records: Array[MusicRecord] = []


## 按编号取音乐记录；不存在 = null。
func get_by_id(music_id: int) -> MusicRecord:
	for record in records:
		if record.music_id == music_id:
			return record
	return null


## 所有已解锁的音乐记录。
func get_unlocked() -> Array[MusicRecord]:
	var result: Array[MusicRecord] = []
	for record in records:
		if record.is_unlocked:
			result.append(record)
	return result


## 按编号解锁；记录不存在时 no-op。
func unlock(music_id: int) -> void:
	var record := get_by_id(music_id)
	if record:
		record.is_unlocked = true


## 是否已解锁；记录不存在 = false。
func is_unlocked(music_id: int) -> bool:
	var record := get_by_id(music_id)
	return record != null and record.is_unlocked


## 通过 BGM key 解锁（返回是否实际解锁，幂等）
func unlock_by_bgm_key(bgm_key: String) -> bool:
	var did_change := false
	for record in records:
		if record.bgm_key == bgm_key and not record.is_unlocked:
			record.is_unlocked = true
			did_change = true
	return did_change

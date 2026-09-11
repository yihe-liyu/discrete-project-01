## KernelBulletPhysics（Track A / S3b）—— 把原项目 BulletPhysics 的规则移植到内核 SoA 池。
##
## 边界：本文件是**宿主桥接层**（可引用 GameState / RNG / AudioManager / HitEffectPool 等宿主全局）；
## 几何唯一实现归内核（query_circle / hit_test），本层只做"规则"（命中 / 擦弹 / 伤害 / 特效）。
## 当前覆盖 S3b：敌弹 ↔ 自机（命中 + 擦弹双阈值 + 记忆随机清弹），与旧
## BulletPhysics._resolve_enemy_bullets_near_player 1:1。
## S3c 再补：自机弹 ↔ 敌人（damage 侧表 + 记忆加成 + 音效/特效）+ bomb + 死亡清弹 + out_grace。
class_name KernelBulletPhysics
extends RefCounted

const _CLEAR_EFFECT = preload("res://scenes/effect/enemy_bullet_clear.tscn")

## 命中音效音量表（key → dB；未列出的默认 -14）：与旧 BulletPhysics.HIT_SFX_VOLUME 一致。
const HIT_SFX_VOLUME := {
	"marisa_damage": -10.0,
}

var backend: KernelBulletBackend


func setup(p_backend: KernelBulletBackend) -> void:
	backend = p_backend


## 每帧碰撞派发（由 BulletManager._physics_process 在内核积分之后调用）。
func process() -> void:
	if backend == null or backend.system == null:
		return
	_player_bullets_vs_enemies()
	_enemy_bullets_vs_player()


## 敌弹 ↔ 自机：命中 → miss + 回收；否则擦弹（每弹只计一次）+ 记忆随机清弹。
func _enemy_bullets_vs_player() -> void:
	var player: Player = GameState.player
	if not is_instance_valid(player) or player.is_invincible:
		return
	var sys := backend.system
	# 查询半径 = 擦弹半径（覆盖命中 + 擦弹两阈值；query 内部已按弹半径外扩）
	var ids: PackedInt32Array = CollisionResolver.overlap_ids(
		sys, player.global_position, player.graze_radius, BulletType.Faction.ENEMY)
	# 倒序：despawn 是 swap-with-last，正序会让后续 id 错位 / 漏回收
	for k in range(ids.size() - 1, -1, -1):
		var id: int = ids[k]
		if sys.hit_test(id, player.global_position, player.hitbox_radius):
			player.miss()
			sys.despawn(id)
		elif not sys.is_grazed(id) and sys.hit_test(id, player.global_position, player.graze_radius):
			sys.mark_grazed(id)
			_on_graze()
			if GameState.memory_value >= 50.0:
				var chance := remap(GameState.memory_value, 50.0, 100.0, 0.05, 0.30)
				if RNG.randf() < chance:
					HitEffectPool.play(_CLEAR_EFFECT, sys.get_position(id), Vector2.ZERO, sys.get_color(id))
					sys.despawn(id)


## 自机弹 ↔ 敌人：与旧 BulletPhysics._player_vs_enemies 1:1（伤害走后端 damage 侧表，内核无 damage）。
func _player_bullets_vs_enemies() -> void:
	var sys := backend.system
	var enemies: Array = GameState.get_active_enemies()
	if enemies.is_empty():
		return
	# 倒序：despawn 是 swap-with-last，正序会让后续 id 错位 / 漏回收
	for i in range(sys.get_active_count() - 1, -1, -1):
		var bt: BulletType = sys.get_type(i)
		if bt == null or bt.faction != BulletType.Faction.PLAYER:
			continue
		var bonus: float = _memory_bonus()
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			if enemy is Boss:
				var phase: PhaseData = (enemy as Boss).current_phase()
				if not phase or phase.is_timeout_only:
					continue   # 时符 / 未开战：弹穿过
			if not sys.hit_test(i, enemy.global_position, enemy.hitbox_radius):
				continue
			var ti: int = sys.get_type_indices()[i]
			enemy.take_damage(backend.damage_for_index(ti) * bonus)
			GameState.add_memory(GameState.MEMORY_HIT_BY_BULLET)
			_play_hit_sfx(ti, enemy)
			_spawn_hit_fx(sys, i, bt)
			sys.despawn(i)
			break


## 记忆 <50 时的伤害加成（与旧 BulletPhysics 同式）。
func _memory_bonus() -> float:
	if GameState.memory_value < 50.0:
		return 1.0 + remap(GameState.memory_value, 0.0, 50.0, 0.15, 0.05)
	return 1.0


## 命中音效规则（与旧 BulletPhysics 1:1）：专属 key 任何敌人命中都播；默认仅 Boss 残血播。
func _play_hit_sfx(ti: int, enemy) -> void:
	var key: String = backend.hit_sfx_for_index(ti)
	if key == "":
		if enemy is Boss and (enemy as Boss).is_low_hp():
			AudioManager.play_sfx(AssetRegistry.sounds["normal_damage"], -14.0, 0.05)
		return
	var sfx: AudioStream = AssetRegistry.sounds.get(key, null)
	if sfx == null:
		push_warning("KernelBulletPhysics: 未知命中音效 key '%s'（回退 normal_damage）" % key)
		sfx = AssetRegistry.sounds["normal_damage"]
	AudioManager.play_sfx(sfx, HIT_SFX_VOLUME.get(key, -14.0), 0.05)


## 命中特效：场景在 BulletType.hit_fx，颜色取该弹当前色（与旧 _spawn_effect 1:1）。
func _spawn_hit_fx(sys: BulletSystem, id: int, bt: BulletType) -> void:
	if bt.hit_fx == null:
		return
	HitEffectPool.play(bt.hit_fx, sys.get_position(id), sys.get_velocity(id), sys.get_color(id))


## 擦弹结算：与旧 BulletPhysics.on_graze 1:1。
func _on_graze() -> void:
	GameState.graze_count += 1
	GameState.add_score(10)
	GameState.add_memory(GameState.MEMORY_GRAZE)
	AudioManager.play_sfx(AssetRegistry.sounds["graze"], -2.0, 0.03)

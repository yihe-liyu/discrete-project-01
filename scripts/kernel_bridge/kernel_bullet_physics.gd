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

var backend: KernelBulletBackend


func setup(p_backend: KernelBulletBackend) -> void:
	backend = p_backend


## 每帧碰撞派发（由 BulletManager._physics_process 在内核积分之后调用）。
func process() -> void:
	if backend == null or backend.system == null:
		return
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


## 擦弹结算：与旧 BulletPhysics.on_graze 1:1。
func _on_graze() -> void:
	GameState.graze_count += 1
	GameState.add_score(10)
	GameState.add_memory(GameState.MEMORY_GRAZE)
	AudioManager.play_sfx(AssetRegistry.sounds["graze"], -2.0, 0.03)

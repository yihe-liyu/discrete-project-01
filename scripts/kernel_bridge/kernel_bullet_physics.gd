## KernelBulletPhysics（Track A / S3b）—— 把原项目 BulletPhysics 的规则移植到内核 SoA 池。
##
## 边界：本文件是**宿主桥接层**（可引用 RNG / AudioManager 等宿主全局）；
## 几何唯一实现归内核（query_circle / hit_test），本层只做"规则"（命中 / 擦弹 / 伤害 / 特效）。
## 覆盖：S3b 敌弹 ↔ 自机（命中 + 擦弹双阈值 + 记忆随机清弹）；S3c 自机弹 ↔ 敌人
## （damage 侧表 + 记忆加成 + 音效/特效）；S3d 死亡清弹扫掠（sweep_enemy_bullets）。
## 待补：bomb（X）+ 出界宽限（out_grace）。
class_name KernelBulletPhysics
extends RefCounted

const _CLEAR_EFFECT = preload("res://scenes/effect/enemy_bullet_clear.tscn")

## 命中音效音量表（key → dB；未列出的默认 -14）：与旧 BulletPhysics.HIT_SFX_VOLUME 一致。
const HIT_SFX_VOLUME := {
	"marisa_damage": -10.0,
}

var backend: KernelBulletBackend
## W2：组合根注入的特效层（空则静默）
var fx: FxPool
## W4b-3b：实体注册表（自机 / 敌机 / Boss；BulletManager 注入）
var refs: EntityRegistry


func setup(p_backend: KernelBulletBackend) -> void:
	backend = p_backend


## 当前自机的单局资源（经注册表取）；无自机 = null
func _player_res() -> PlayerResources:
	return refs.get_player_resources() if refs != null else null


## 消弹特效（同色）：未注入特效层时静默。
func _play_clear(pos: Vector2, tint: Color) -> void:
	if fx:
		fx.play(_CLEAR_EFFECT, pos, Vector2.ZERO, tint)


## 每帧碰撞派发（由 BulletManager._physics_process 在内核积分之后调用）。
func process() -> void:
	if backend == null or backend.system == null:
		return
	_player_bullets_vs_enemies()
	_enemy_bullets_vs_player()


## 敌弹 ↔ 自机：命中 → miss + 回收；否则擦弹（每弹只计一次）+ 记忆随机清弹。
func _enemy_bullets_vs_player() -> void:
	var p = refs.player if refs else null
	var player: Player = p if is_instance_valid(p) else null
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
			on_graze()
			var res := _player_res()
			if res != null and res.memory_value >= 50.0:
				var chance := remap(res.memory_value, 50.0, 100.0, 0.05, 0.30)
				if RNG.randf() < chance:
					_play_clear(sys.get_position(id), sys.get_color(id))
					sys.despawn(id)


## 自机弹 ↔ 敌人：与旧 BulletPhysics._player_vs_enemies 1:1（伤害走后端 damage 侧表，内核无 damage）。
func _player_bullets_vs_enemies() -> void:
	var sys := backend.system
	var enemies: Array = refs.get_active_enemies() if refs else []
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
			var res := _player_res()
			if res != null:
				res.add_memory(PlayerResources.MEMORY_HIT_BY_BULLET)
			_play_hit_sfx(ti, enemy)
			_spawn_hit_fx(sys, i, bt)
			sys.despawn(i)
			break


## 死亡清弹圈的一帧扫掠：清 center/radius 内的敌弹，逐弹播消散特效 + on_clear。
## 与旧 DeathClear 的逐弹循环 1:1（颜色取内核该弹当前色；不做出生雾过滤——旧池 is_ready
## 在 bind() 末尾无条件置真，雾中弹同样参与消弹）。
## 供 BulletManager 以 DeathClear 的每帧回调形式驱动（Track A / S3d）。
func sweep_enemy_bullets(center: Vector2, radius: float, on_clear: Callable = Callable()) -> void:
	var sys := backend.system
	if sys == null:
		return
	var r2: float = radius * radius
	# 倒序：despawn 是 swap-with-last，正序会让后续 id 错位 / 漏回收
	for i in range(sys.get_active_count() - 1, -1, -1):
		var bt: BulletType = sys.get_type(i)
		if bt == null or bt.faction != BulletType.Faction.ENEMY:
			continue
		var pos: Vector2 = sys.get_position(i)
		if pos.distance_squared_to(center) > r2:
			continue
		if on_clear.is_valid():
			on_clear.call(pos)
		_play_clear(pos, sys.get_color(i))
		sys.despawn(i)


## 记忆 <50 时的伤害加成（与旧 BulletPhysics 同式）。
func _memory_bonus() -> float:
	var res := _player_res()
	if res != null and res.memory_value < 50.0:
		return 1.0 + remap(res.memory_value, 0.0, 50.0, 0.15, 0.05)
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
	if bt.hit_fx == null or fx == null:
		return
	fx.play(bt.hit_fx, sys.get_position(id), sys.get_velocity(id), sys.get_color(id))


## 擦弹结算：与旧 BulletPhysics.on_graze 1:1。
func on_graze() -> void:
	var res := _player_res()
	if res != null:
		res.graze_count += 1
		res.add_score(10)
		res.add_memory(PlayerResources.MEMORY_GRAZE)
	AudioManager.play_sfx(AssetRegistry.sounds["graze"], -2.0, 0.03)

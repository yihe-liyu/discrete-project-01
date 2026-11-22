## 确定性状态指纹 —— 把一 tick 的规范玩法状态压成一个 32 位 FNV-1a 哈希。
##
## [b]用途[/b][br]
## - 回放 / 双跑测试：同 tick 比对，首个不一致直接暴露；不靠零散告警。
## - 只做检测，不做修正；不可逆，不是状态快照。[br]
## [br]
## [b]规范[/b][br]
## - 浮点位置先量化到 1/1000 像素（[constant POS_SCALE]），避免末位噪声误报。[br]
## - 活跃弹按稳定 uid 排序后再混入，池行序 / swap-remove 不影响结果。[br]
## - 不遍历 Dictionary、不对 float 直接哈希。[br]
## [br]
## [b]边界[/b][br]
## - 当前覆盖：tick / 冻结态 / RNG seed+state / 自机位置与资源 / Boss 阶段状态 /
##   活跃弹 uid+type+量化位置。道具、激光、敌机列表暂未纳入，后续按需扩展。[br]
## - 32 位哈希有碰撞概率；用于逐 tick 报警足够，不能当证明。
class_name SimHash
extends RefCounted

## 位置量化：1/1000 像素。
const POS_SCALE := 1000.0
## FNV-1a 32 位参数。
const MASK := 0xFFFFFFFF
const OFFSET := 2166136261
const PRIME := 16777619


## 当前 tick 的规范状态哈希。
static func of(registry: EntityRegistry, system: KernelNativeSystem, tick: int,
		items: ItemPool = null, lasers: Array = []) -> int:
	var h := OFFSET
	h = mix(h, tick)
	h = mix(h, 1 if SimClock.is_frozen() else 0)

	var rng := RNG.snapshot_state()
	h = mix64(h, int(str(rng.get("seed", "0"))))
	h = mix64(h, int(str(rng.get("state", "0"))))

	var player: Node2D = registry.player if registry != null else null
	if is_instance_valid(player):
		h = mix_vec2(h, player.global_position)
		var actor := player as PlayerBase
		var res: PlayerResources = actor.resources if actor != null else null
		if res != null:
			h = mix(h, res.current_score)
			h = mix(h, res.lives)
			h = mix(h, res.bomb_count)
			h = mix(h, res.power_raw)
			h = mix(h, res.graze_count)
			h = mix(h, res.life_fragments)
			h = mix(h, res.bomb_fragments)
			h = mix(h, roundi(res.memory_value * POS_SCALE))
		else:
			h = mix(h, -1)
		if actor is Player:
			h = mix(h, 1 if (actor as Player).is_invincible else 0)
	else:
		h = mix(h, -1)

	var boss: Boss = registry.get_boss() if registry != null else null
	if is_instance_valid(boss):
		var phase: PhaseData = boss.current_phase()
		h = mix(h, phase.uid if phase != null else -1)
		h = mix(h, boss.hp)
		h = mix(h, boss.get_elapsed_ticks())
		h = mix(h, boss.get_open_reduce_ticks())
	else:
		h = mix(h, -1)

	var enemies: Array = registry.get_active_enemies() if registry != null else []
	h = mix(h, enemies.size())
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		h = mix(h, enemy.hp)
		h = mix_vec2(h, enemy.global_position)

	if items != null:
		var item_list := items.active_items()
		h = mix(h, item_list.size())
		for item in item_list:
			h = mix(h, int(item.item_type))
			h = mix_vec2(h, item.global_position)
	else:
		h = mix(h, -1)

	h = mix(h, lasers.size())
	for beam in lasers:
		if beam == null or not is_instance_valid(beam):
			continue
		h = mix(h, int(beam.phase))
		h = mix(h, roundi(float(beam.age) * POS_SCALE))
		h = mix(h, roundi(float(beam.head_dist) * POS_SCALE))
		h = mix(h, roundi(float(beam.tail_dist) * POS_SCALE))

	if system != null:
		var entries: Array[Dictionary] = []
		for id in system.get_active_count():
			var pos: Vector2 = system.get_position(id)
			entries.append({
				"uid": system.get_uid(id),
				"type": system.get_type_index(id),
				"x": pos.x,
				"y": pos.y,
			})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["uid"]) < int(b["uid"]))
		h = mix(h, entries.size())
		for e in entries:
			h = mix(h, int(e["uid"]))
			h = mix(h, int(e["type"]))
			h = mix_vec2(h, Vector2(float(e["x"]), float(e["y"])))
	else:
		h = mix(h, -1)

	return h


## 混入一个整数（低 32 位；负数按位模式处理）。
static func mix(h: int, value: int) -> int:
	h = (h ^ (value & MASK)) & MASK
	h = (h * PRIME) & MASK
	return h


## 混入 64 位整数（seed / state 不会被截成低 32 位）。
static func mix64(h: int, value: int) -> int:
	h = mix(h, value & MASK)
	h = mix(h, (value >> 32) & MASK)
	return h


## 混入量化后的 Vector2。
static func mix_vec2(h: int, p: Vector2) -> int:
	h = mix(h, roundi(p.x * POS_SCALE))
	h = mix(h, roundi(p.y * POS_SCALE))
	return h

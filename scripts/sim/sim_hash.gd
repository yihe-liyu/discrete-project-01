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


## 分项状态哈希（诊断用）：每个子系统独立一个 32 位 hash。
## 总 hash 的算法不变；分项只用于定位“首个不一致来自哪里”。
static func fields(registry: EntityRegistry, system: KernelNativeSystem, tick: int,
		items: ItemPool = null, lasers: Array = []) -> Dictionary:
	var out: Dictionary = {}
	out["tick"] = mix(mix(OFFSET, tick), 1 if SimClock.is_frozen() else 0)

	var rng := RNG.snapshot_state()
	var rh := OFFSET
	rh = mix64(rh, int(str(rng.get("seed", "0"))))
	rh = mix64(rh, int(str(rng.get("state", "0"))))
	out["rng"] = rh

	var ph := OFFSET
	var res_hash := OFFSET
	var player: Node2D = registry.player if registry != null else null
	if is_instance_valid(player):
		ph = mix_vec2(ph, player.global_position)
		var actor := player as PlayerBase
		var res: PlayerResources = actor.resources if actor != null else null
		if res != null:
			res_hash = mix(res_hash, res.current_score)
			res_hash = mix(res_hash, res.lives)
			res_hash = mix(res_hash, res.bomb_count)
			res_hash = mix(res_hash, res.power_raw)
			res_hash = mix(res_hash, res.graze_count)
			res_hash = mix(res_hash, res.life_fragments)
			res_hash = mix(res_hash, res.bomb_fragments)
			res_hash = mix(res_hash, roundi(res.memory_value * POS_SCALE))
		else:
			res_hash = mix(res_hash, -1)
		if actor is Player:
			ph = mix(ph, 1 if (actor as Player).is_invincible else 0)
	else:
		ph = mix(ph, -1)
		res_hash = mix(res_hash, -1)
	out["player"] = ph
	out["resources"] = res_hash

	var boss_phase := OFFSET
	var boss_hp := OFFSET
	var boss_time := OFFSET
	var boss_pos := OFFSET
	var boss: Boss = registry.get_boss() if registry != null else null
	if is_instance_valid(boss):
		var phase: PhaseData = boss.current_phase()
		boss_phase = mix(boss_phase, phase.uid if phase != null else -1)
		boss_hp = mix(boss_hp, boss.hp)
		boss_time = mix(boss_time, boss.get_elapsed_ticks())
		boss_time = mix(boss_time, boss.get_open_reduce_ticks())
		boss_pos = mix_vec2(boss_pos, boss.global_position)
	else:
		boss_phase = mix(boss_phase, -1)
		boss_hp = mix(boss_hp, -1)
		boss_time = mix(boss_time, -1)
		boss_pos = mix(boss_pos, -1)
	out["boss_phase"] = boss_phase
	out["boss_hp"] = boss_hp
	out["boss_time"] = boss_time
	out["boss_pos"] = boss_pos

	var eh := OFFSET
	var enemies: Array = registry.get_active_enemies() if registry != null else []
	eh = mix(eh, enemies.size())
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			eh = mix(eh, enemy.hp)
			eh = mix_vec2(eh, enemy.global_position)
	out["enemies"] = eh

	var ih := OFFSET
	if items != null:
		var item_list := items.active_items()
		ih = mix(ih, item_list.size())
		for item in item_list:
			ih = mix(ih, int(item.item_type))
			ih = mix_vec2(ih, item.global_position)
	else:
		ih = mix(ih, -1)
	out["items"] = ih

	var lh := OFFSET
	lh = mix(lh, lasers.size())
	for beam in lasers:
		if beam != null and is_instance_valid(beam):
			lh = mix(lh, int(beam.phase))
			lh = mix(lh, roundi(float(beam.age) * POS_SCALE))
			lh = mix(lh, roundi(float(beam.head_dist) * POS_SCALE))
			lh = mix(lh, roundi(float(beam.tail_dist) * POS_SCALE))
	out["lasers"] = lh

	var uh := OFFSET
	if system != null:
		var entries: Array[Dictionary] = []
		for id in system.get_active_count():
			var pos: Vector2 = system.get_position(id)
			entries.append({"uid": system.get_uid(id), "type": system.get_type_index(id), "x": pos.x, "y": pos.y})
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["uid"]) < int(b["uid"]))
		uh = mix(uh, entries.size())
		for e in entries:
			uh = mix(uh, int(e["uid"]))
			uh = mix(uh, int(e["type"]))
			uh = mix_vec2(uh, Vector2(float(e["x"]), float(e["y"])))
	else:
		uh = mix(uh, -1)
	out["bullets"] = uh

	return out


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


## 人类可读的规范状态快照（只在调试分歧时用；不参与正常哈希）。
static func describe(registry: EntityRegistry, system: KernelNativeSystem, tick: int,
		items: ItemPool = null, lasers: Array = []) -> String:
	var lines: Array[String] = ["tick=%d" % tick]
	var player: Node2D = registry.player if registry != null else null
	if is_instance_valid(player):
		var actor := player as PlayerBase
		var res: PlayerResources = actor.resources if actor != null else null
		lines.append("player pos=(%.3f,%.3f) score=%d lives=%d bombs=%d power=%d graze=%d mem=%.2f inv=%s" % [
			player.global_position.x, player.global_position.y,
			res.current_score if res != null else -1,
			res.lives if res != null else -1,
			res.bomb_count if res != null else -1,
			res.power_raw if res != null else -1,
			res.graze_count if res != null else -1,
			res.memory_value if res != null else -1.0,
			str((actor as Player).is_invincible) if actor is Player else "?",
		])
	var boss: Boss = registry.get_boss() if registry != null else null
	if is_instance_valid(boss):
		var phase := boss.current_phase()
		lines.append("boss uid=%d hp=%d elapsed=%d reduce=%d pos=(%.3f,%.3f)" % [
			phase.uid if phase != null else -1, boss.hp, boss.get_elapsed_ticks(),
			boss.get_open_reduce_ticks(), boss.global_position.x, boss.global_position.y,
		])
	var enemies: Array = registry.get_active_enemies() if registry != null else []
	lines.append("enemies=%d" % enemies.size())
	for enemy in enemies:
		if is_instance_valid(enemy):
			lines.append("  enemy hp=%d pos=(%.3f,%.3f)" % [
				enemy.hp, enemy.global_position.x, enemy.global_position.y])
	if system != null:
		lines.append("bullets=%d" % system.get_active_count())
		for id in mini(system.get_active_count(), 8):
			var p := system.get_position(id)
			lines.append("  bullet uid=%d type=%d pos=(%.3f,%.3f)" % [
				system.get_uid(id), system.get_type_index(id), p.x, p.y])
	if items != null:
		var item_list := items.active_items()
		lines.append("items=%d" % item_list.size())
		for item in item_list:
			lines.append("  item type=%d pos=(%.3f,%.3f)" % [
				int(item.item_type), item.global_position.x, item.global_position.y])
	lines.append("lasers=%d" % lasers.size())
	var rng := RNG.snapshot_state()
	lines.append("rng seed=%s state=%s" % [str(rng.get("seed", 0)), str(rng.get("state", 0))])
	return "\n".join(lines)

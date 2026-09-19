class_name BulletMultiMesh
extends Node2D
## BulletMultiMesh — 用 MultiMeshInstance2D 批量渲染子弹
## 所有子弹合并为 1 次 draw call（按纹理 × 阵营 × tint_mode 分组）
## 数据源：KernelBulletHost 的内核 SoA 快照（backend.system）；set_backend() 注入后生效。


## 宿主阵营常量（顺序与内核 BulletType.Faction 不同，渲染时显式映射）
const _FACTION_PLAYER := 0
const _FACTION_ENEMY := 1
const _FACTION_BOMB := 2

## 是否启用 MultiMesh 批渲染
@export var is_enabled: bool = true

## 内核后端（唯一数据源）。
var backend: KernelBulletHost

var _groups: Dictionary = {}  # key → {mmi, mm, mesh}

## 渲染同步走原生 DanmakuRenderBridge（分组 + 旋转 + fade + 填充）；L3.5-4f 起扩展为必需。
var _bridge = null
var _type_table_count: int = -1
var _fx_table_count: int = -1


func _ready():
	set_process(is_enabled)


func _process(_delta):
	if not is_enabled:
		return
	_sync()


## 注入内核后端；null = 无可渲染数据源（不画）。
func set_backend(b: KernelBulletHost) -> void:
	backend = b
	_type_table_count = -1   # 后端换 → 类型表失效
	_fx_table_count = -1


## 数据源：内核 SoA 快照。
func _sync():
	if backend != null and backend.system != null:
		_sync_kernel()


## 直接读内核 SoA 快照（唯一数据源）。
## 朝向/颜色语义对齐旧路径（Bullet.bind：rotation = 方向角、modulate = tint，scale = ONE）。
func _sync_kernel():
	if _render_bridge() != null:
		_sync_native()
	else:
		_hide_all()


## 原生渲染同步器（存在则用）。
func _render_bridge():
	if _bridge == null and ClassDB.class_exists("DanmakuRenderBridge"):
		_bridge = ClassDB.instantiate("DanmakuRenderBridge")
	return _bridge


## N4-real：分组 + 旋转 + fade + 填充全在原生；这里只按组取/建 MultiMesh（O(groups)）。
## 弹与特效（出生雾 / 消弹消散）分两路：桥按行 fx_type/相位拆流，这里分别建组。
func _sync_native() -> void:
	var system := backend.system
	var count: int = system.get_active_count()
	if count == 0:
		_hide_all()
		return
	var registry := system.get_type_registry()
	var fx_registry := system.get_fx_registry()
	if registry.size() != _type_table_count or fx_registry.size() != _fx_table_count:
		_type_table_count = registry.size()
		_fx_table_count = fx_registry.size()
		_build_type_table(registry, fx_registry)
	var positions := system.get_positions()
	var velocities := system.get_velocities()
	var render_rots := system.get_render_rots()
	var colors := system.get_colors()
	var type_indices := system.get_type_indices()
	var factions := system.get_factions()
	var fx_phases := system.get_fx_phases()
	var fx_type_indices := system.get_fx_type_indices()
	var fade := PackedFloat32Array([
		system.get_render_fade(BulletType.Kind.POINT),
		system.get_render_fade(BulletType.Kind.LASER),
	])
	var groups: Dictionary = _bridge.group(count, positions, velocities, colors, type_indices, factions, fade, render_rots, fx_phases, fx_type_indices)
	var seen := {}
	# ── 弹批次 ──
	var keys: PackedInt64Array = groups["keys"]
	var starts: PackedInt32Array = groups["starts"]
	var rows: PackedInt32Array = groups["rows"]
	var rots: PackedFloat32Array = groups["rots"]
	var alphas: PackedFloat32Array = groups["alphas"]
	for gi in keys.size():
		var key: int = keys[gi]
		var s0: int = starts[gi]
		var n: int = starts[gi + 1] - s0
		var rep: int = rows[s0]
		var ti: int = type_indices[rep]
		var tex: Texture2D = backend.texture_for_index(ti)
		var host_faction := _host_faction(factions[rep])
		var tint_mode: int = registry[ti].tint_mode
		var eg = _get_or_create_group(key, tex, tint_mode, _z_for_faction(host_faction), n)
		_show_group(eg, n)
		_bridge.fill(eg.mm, positions, colors, rows, rots, alphas, s0, n)
		seen[key] = true
	# ── 特效批次（出生雾 / 消弹消散；带缩放与 alpha 淡出）──
	var fx_keys: PackedInt64Array = groups["fx_keys"]
	var fx_starts: PackedInt32Array = groups["fx_starts"]
	var fx_rows: PackedInt32Array = groups["fx_rows"]
	var fx_rots: PackedFloat32Array = groups["fx_rots"]
	var fx_alphas: PackedFloat32Array = groups["fx_alphas"]
	var fx_scales: PackedFloat32Array = groups["fx_scales"]
	for gi in fx_keys.size():
		var fkey: int = fx_keys[gi]
		var fs0: int = fx_starts[gi]
		var fcount: int = fx_starts[gi + 1] - fs0
		var frep: int = fx_rows[fs0]
		var fi: int = fx_type_indices[frep]
		var ftex: Texture2D = backend.fx_texture_for_index(fi)
		var fx_tint: int = fx_registry[fi].tint_mode
		var eg = _get_or_create_group(fkey, ftex, fx_tint, LayerConfig.EFFECT, fcount)
		_show_group(eg, fcount)
		_bridge.fill_fx(eg.mm, positions, colors, fx_rows, fx_rots, fx_alphas, fx_scales, fs0, fcount)
		seen[fkey] = true
	for gkey in _groups:
		if not seen.has(gkey):
			_hide_group(gkey)


## 类型表：纹理句柄 + tint / kind / follow_dir / dir_offset（类型数变化时重建）；
## 同步构建特效表（纹理句柄 + 时长 + 缩放 + alpha 淡出）。
func _build_type_table(registry: Array[BulletType], fx_registry: Array[EffectType]) -> void:
	var n := registry.size()
	var tex_key := PackedInt64Array()
	var tint := PackedInt32Array()
	var kind := PackedInt32Array()
	var follow := PackedByteArray()
	var dir_off := PackedFloat32Array()
	tex_key.resize(n)
	tint.resize(n)
	kind.resize(n)
	follow.resize(n)
	dir_off.resize(n)
	for ti in n:
		var tex: Texture2D = backend.texture_for_index(ti)
		if tex == null:
			tex_key[ti] = -1
			continue
		var kb: int = tex.get_rid().get_id()
		if tex is AtlasTexture:
			kb = kb * 31 + hash((tex as AtlasTexture).region)
		tex_key[ti] = kb
		var bt: BulletType = registry[ti]
		tint[ti] = bt.tint_mode
		kind[ti] = bt.kind
		follow[ti] = 1 if bt.follow_dir else 0
		dir_off[ti] = bt.dir_offset
	_bridge.set_type_table(tex_key, tint, kind, follow, dir_off)

	var fxn := fx_registry.size()
	var fx_tex_key := PackedInt64Array()
	var fx_duration := PackedFloat32Array()
	var fx_scale_from := PackedFloat32Array()
	var fx_scale_to := PackedFloat32Array()
	var fx_alpha_from := PackedFloat32Array()
	var fx_alpha_to := PackedFloat32Array()
	var fx_tint := PackedInt32Array()
	fx_tex_key.resize(fxn)
	fx_duration.resize(fxn)
	fx_scale_from.resize(fxn)
	fx_scale_to.resize(fxn)
	fx_alpha_from.resize(fxn)
	fx_alpha_to.resize(fxn)
	fx_tint.resize(fxn)
	for fi in fxn:
		var fx: EffectType = fx_registry[fi]
		var ftex: Texture2D = backend.fx_texture_for_index(fi)
		if ftex == null:
			fx_tex_key[fi] = -1
			continue
		var fk: int = ftex.get_rid().get_id()
		if ftex is AtlasTexture:
			fk = fk * 31 + hash((ftex as AtlasTexture).region)
		fx_tex_key[fi] = fk
		fx_duration[fi] = fx.duration
		fx_scale_from[fi] = fx.scale_from
		fx_scale_to[fi] = fx.scale_to
		fx_alpha_from[fi] = fx.alpha_from
		fx_alpha_to[fi] = fx.alpha_to
		fx_tint[fi] = fx.tint_mode
	_bridge.set_fx_table(fx_tex_key, fx_duration, fx_scale_from, fx_scale_to, fx_alpha_from, fx_alpha_to, fx_tint)


## 分组键（两路共用）：纹理 RID + region + 阵营 + tint_mode → 唯一 int（避免每帧拼字符串）。
func _group_key(tex: Texture2D, faction: int, tint_mode: int) -> int:
	var key: int = tex.get_rid().get_id()
	if tex is AtlasTexture:
		key = key * 31 + hash((tex as AtlasTexture).region)
	key = key * 16 + faction * 2 + tint_mode
	return key


## 内核阵营 → 宿主 Bullet 阵营常量：两枚枚举顺序不同（内核 ENEMY=0/PLAYER=1，宿主 PLAYER=0/ENEMY=1），必须显式映射。
func _host_faction(kernel_faction: int) -> int:
	match kernel_faction:
		BulletType.Faction.ENEMY:
			return _FACTION_ENEMY
		BulletType.Faction.PLAYER:
			return _FACTION_PLAYER
		_:
			return _FACTION_BOMB


## 宿主阵营 → z 层。
func _z_for_faction(host_faction: int) -> int:
	match host_faction:
		_FACTION_ENEMY:
			return LayerConfig.ENEMY_BULLET
		_FACTION_PLAYER:
			return LayerConfig.PLAYER_BULLET
		_:
			return LayerConfig.BOMB


func _hide_all() -> void:
	for key in _groups:
		_hide_group(key)


func _hide_group(key: int) -> void:
	_groups[key].mmi.visible = false
	_groups[key].mm.visible_instance_count = 0


func clear():
	for grp in _groups.values():
		if is_instance_valid(grp.mmi):
			grp.mmi.queue_free()
	_groups.clear()


## 本帧组可见 + 实例容量（只增不减，几何增长）。
func _show_group(eg: Dictionary, n: int) -> void:
	var mm: MultiMesh = eg.mm
	if mm.instance_count < n:
		mm.instance_count = max(n * 2, 2048)
	mm.visible_instance_count = n
	eg.mmi.visible = true


func _get_or_create_group(key: int, tex: Texture2D, tint_mode: int, p_z_index: int, min_size: int) -> Dictionary:
	if _groups.has(key):
		var existing = _groups[key]
		if existing.mm.instance_count < min_size:
			existing.mm.instance_count = max(min_size * 2, 2048)  # 只增不减，几何增长
		return existing

	# ── 处理 AtlasTexture → 用图集 + UV 偏移 ──
	var use_tex: Texture2D = tex
	var use_region := Vector4(0.0, 0.0, 1.0, 1.0)
	if tex is AtlasTexture:
		var atex = tex as AtlasTexture
		use_tex = atex.atlas
		var atlas_size = atex.atlas.get_size()
		var r = atex.region
		use_region = Vector4(
			r.position.x / atlas_size.x,
			r.position.y / atlas_size.y,
			r.size.x / atlas_size.x,
			r.size.y / atlas_size.y
		)

	# ── 创建 MultiMesh ──
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.instance_count = max(min_size, 2048)  # 预分配大缓冲：之后子弹数在容量内增减不再重分配 GPU 缓冲
	mm.visible_instance_count = 0  # 初始不绘制，由 _sync 按实际子弹数设置

	# ── 创建 2D 四边形网格 ──
	# 尺寸匹配纹理像素大小
	var tex_size: Vector2 = use_tex.get_size()
	var quad_w: float = tex_size.x
	var quad_h: float = tex_size.y
	if tex is AtlasTexture:
		var r = (tex as AtlasTexture).region
		quad_w = r.size.x
		quad_h = r.size.y

	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(quad_w, quad_h)

	# ── 材质（用 shader 文件，不要运行时拼字符串）──
	var shader: Shader = preload("res://gdshader/bullet_batch.gdshader")
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tex", use_tex)
	mat.set_shader_parameter("region", use_region)
	mat.set_shader_parameter("tint_mode", tint_mode)
	mm.mesh = mesh

	# ── MultiMeshInstance2D ──
	var mmi: MultiMeshInstance2D = MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.material = mat
	mmi.z_index = p_z_index
	add_child(mmi)

	var entry: Dictionary = {mmi = mmi, mm = mm, mesh = mesh}
	_groups[key] = entry
	return entry

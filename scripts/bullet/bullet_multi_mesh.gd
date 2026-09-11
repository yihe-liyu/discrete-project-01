# BulletMultiMesh — 用 MultiMeshInstance2D 批量渲染子弹
# 所有子弹合并为 1 次 draw call（按纹理 × 阵营 × tint_mode 分组）
# 数据源两路（Track A / S2，Strangler）：
#   ① 旧：遍历 BulletManager.active_bullets（Bullet 节点）
#   ② 新：读 KernelBulletBackend 的内核 SoA 快照（backend.system）
# set_backend() 注入后自动走新路径；两路**共用同一分组键**，批次数才可比对。
extends Node2D
class_name BulletMultiMesh

## 是否启用 MultiMesh 批渲染
@export var enabled: bool = true

## 内核后端（Track A / S2）；注入后 _sync 改走内核快照路径。
var backend: KernelBulletBackend

var _groups: Dictionary = {}  # key → {mmi, mm, mesh}


## 注入内核后端；null = 回到遍历 Bullet 节点的旧路径。
func set_backend(b: KernelBulletBackend) -> void:
	backend = b


func _ready():
	set_process(enabled)


func _process(_delta):
	if not enabled:
		return
	_sync()


## 数据源分派：有内核后端 → 内核快照；否则旧路径。
func _sync():
	if backend != null and backend.system != null:
		_sync_kernel()
	else:
		_sync_nodes()


## 旧路径：遍历 Bullet 节点。
func _sync_nodes():
	var bulbs := BulletManager.active_bullets
	if bulbs.is_empty():
		_hide_all()
		return
	var active_groups: Dictionary = {}
	for bullet in bulbs:
		if not is_instance_valid(bullet) or bullet.is_queued_for_deletion() or not bullet.visible or not bullet.is_ready:
			continue
		var tex = bullet.batch_texture()
		if not tex:
			continue
		var key := _group_key(tex, bullet.faction, bullet.tint_mode)
		if not active_groups.has(key):
			active_groups[key] = {tex = tex, faction = bullet.faction, tint_mode = bullet.tint_mode, bullets = []}
		active_groups[key].bullets.append(bullet)
	for key in active_groups:
		var g = active_groups[key]
		var bullets: Array = g.bullets
		var eg = _get_or_create_group(key, g.tex, g.faction, g.tint_mode, bullets.size())
		var mm: MultiMesh = eg.mm
		# 缓冲只增不减：超过预分配容量才 grow（几何增长，罕见），避免每帧 grow/shrink 重分配 GPU 缓冲
		if mm.instance_count < bullets.size():
			mm.instance_count = max(bullets.size() * 2, 2048)
		mm.visible_instance_count = bullets.size()
		eg.mmi.visible = true
		for i in bullets.size():
			var b = bullets[i]
			var t = Transform2D(b.rotation, b.scale, 0.0, b.global_position)
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, b.sprite.modulate)
	for key in _groups:
		if not active_groups.has(key):
			_hide_group(key)


## 新路径（S2）：直接读内核 SoA 快照，不再遍历 Bullet 节点。
## 朝向/颜色语义对齐旧路径（Bullet.bind：rotation = 方向角、modulate = tint，scale = ONE）。
func _sync_kernel():
	var sys := backend.system
	var count: int = sys.get_active_count()
	if count == 0:
		_hide_all()
		return
	var positions := sys.get_positions()
	var velocities := sys.get_velocities()
	var colors := sys.get_colors()
	var type_indices := sys.get_type_indices()
	var factions := sys.get_factions()
	var registry := sys.get_type_registry()
	var active_groups: Dictionary = {}
	for i in count:
		var ti: int = type_indices[i]
		if ti < 0:
			continue   # 纯特效行：本批不画（与旧路径"无贴图不进组"同语义）
		var tex: Texture2D = backend.texture_for_index(ti)
		if tex == null:
			continue
		var bt: BulletType = registry[ti]
		var host_faction := _host_faction(factions[i])
		var key := _group_key(tex, host_faction, bt.tint_mode)
		if not active_groups.has(key):
			active_groups[key] = {tex = tex, faction = host_faction, tint_mode = bt.tint_mode, rows = []}
		active_groups[key].rows.append(i)
	for key in active_groups:
		var g = active_groups[key]
		var rows: Array = g.rows
		var eg = _get_or_create_group(key, g.tex, g.faction, g.tint_mode, rows.size())
		var mm: MultiMesh = eg.mm
		if mm.instance_count < rows.size():
			mm.instance_count = max(rows.size() * 2, 2048)
		mm.visible_instance_count = rows.size()
		eg.mmi.visible = true
		for s in rows.size():
			var r: int = rows[s]
			var bt: BulletType = registry[type_indices[r]]
			var rot: float = bt.rotation_for(velocities[r])
			mm.set_instance_transform_2d(s, Transform2D(rot, Vector2.ONE, 0.0, positions[r]))
			mm.set_instance_color(s, colors[r])
	for key in _groups:
		if not active_groups.has(key):
			_hide_group(key)


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
			return Bullet.FACTION_ENEMY
		BulletType.Faction.PLAYER:
			return Bullet.FACTION_PLAYER
		_:
			return Bullet.FACTION_BOMB


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


func _get_or_create_group(key: int, tex: Texture2D, faction: int, tint_mode: int, min_size: int) -> Dictionary:
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
	match faction:
		Bullet.FACTION_ENEMY:
			mmi.z_index = LayerConfig.ENEMY_BULLET
		Bullet.FACTION_PLAYER:
			mmi.z_index = LayerConfig.PLAYER_BULLET
		Bullet.FACTION_BOMB:
			mmi.z_index = LayerConfig.BOMB
	add_child(mmi)

	var entry: Dictionary = {mmi = mmi, mm = mm, mesh = mesh}
	_groups[key] = entry
	return entry

## 游戏 HUD —— Score / HiScore / Power / MaxPoint / Graze
extends CanvasLayer
class_name GameUI

## 单局资源（组合根注入；过渡期与全局资源同一实例）
var resources: PlayerResources

## 入场动画完成时发射，供 GameScene 等待
signal entry_finished()

## 入场动画：每个元素的间隔时间（秒）
const ENTRY_INTERVAL: float = 0.03
## 入场动画：单个元素滑入持续时间（秒）
const ENTRY_DURATION: float = 0.25

var _hi_score_num: Node2D
var _score_num: Node2D
var _power_num: Node2D
var _max_point_num: Node2D
var _graze_num: Node2D
var _memory_num: Node2D
var _memory_rect: ColorRect
var _shader_time: float = 0.0

const FRAME_DEFAULT := preload("res://assets/Textures/front/false_front.png")
const FRAME_LATE := preload("res://assets/Textures/front/false_front_2.png")
const FRAME_EX := preload("res://assets/Textures/front/true_front.png")
const _LIFE_TEX := preload("res://assets/Textures/front/life.png")
const _SPELL_TEX := preload("res://assets/Textures/front/spell.png")

# 残机 & Bomb 碎片
var _life_fragments: Array[Sprite2D] = []
var _bomb_fragments: Array[Sprite2D] = []

## 记录所有入场元素，按顺序播放
var _entry_queue: Array[Node] = []

## 游戏框（Front）的交叉淡入层：新框在上面淡入，结束后写回 _front 再隐藏。
@onready var _front: Sprite2D = $"Front"
var _front_next: Sprite2D
var _front_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时水面动画不冻
	_setup_front_crossfade()
	var tex := preload("res://assets/Textures/ascii/ascii.png")

	# Title Logo → 先入队但单独处理
	var title := $"Title"
	_entry_queue.push_front(title)

	# 难度 UI → 入队，单独处理入场动画
	var diff := $"Difficulty"
	_entry_queue.append(diff)

	# 文字标签先入队（先出现）
	_entry_queue.append($HighScore)
	_entry_queue.append($Score)
	_entry_queue.append($Player)
	_entry_queue.append($Bomb)
	_entry_queue.append($Power)
	_entry_queue.append($Point)
	_entry_queue.append($Graze)
	_entry_queue.append($MemoryValue)

	_hi_score_num = _make_number_sprite("HiScoreNumber",  $HighScore.position + Vector2(102, 0), tex, 10)
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 124), 450.0, Color(0.685, 0.685, 0.685, 0.5))
	_score_num    = _make_number_sprite("ScoreNumber",    $Score.position     + Vector2(102, 0), tex, 10)
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 180), 450.0, Color(1.0, 1.0, 1.0, 0.5))
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 274), 450.0, Color(0.961, 0.825, 0.963, 0.502))
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 344), 450.0, Color(0.735, 1.0, 0.732, 0.502))
	_power_num    = _make_number_sprite("PowerNumber",    $Power.position     + Vector2(78, 0), tex, 10)
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 396), 450.0, Color(1.0, 0.805, 0.704, 0.502))
	_max_point_num= _make_number_sprite("MaxPointNumber", $Point.position     + Vector2(102, 0), tex)
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 452), 450.0, Color(0.689, 0.933, 1.0, 0.502))
	_graze_num    = _make_number_sprite("GrazeNumber",    $Graze.position     + Vector2(102, 0), tex)
	_add_separator(Vector2(GameConfig.FIELD_RIGHT, 508), 450.0, Color(0.685, 0.685, 0.685, 0.5))

	_memory_rect = $Memory/OutlineRect
	_entry_queue.append(_memory_rect)
	_memory_num = _make_number_sprite_on("MemoryNumber", $Memory, Vector2(980, 608), tex, 6)

	# 设置难度标签贴图
	_update_difficulty_texture()

	# 碎片图标
	_fragment_init()

	# 颜色
	_hi_score_num.modulate  = Color(0.735, 0.735, 0.735)
	_power_num.modulate     = Color(1.0, 0.498, 0.165, 1.0)
	_max_point_num.modulate = Color(0.502, 0.898, 1.0, 1.0)
	_graze_num.modulate     = Color(0.735, 0.735, 0.735)
	_memory_num.modulate    = Color(0.592, 0.549, 1.0, 1.0)

	# 对齐：不带前导零的用左对齐
	_max_point_num.is_left_align = true
	_graze_num.is_left_align     = true
	_memory_num.pct_index     = 13
	_memory_num.minus_index   = 12
	_memory_num.char_count    = 14
	_memory_num.z_index       = LayerConfig.UI_TOP

	# 路线切面 / 回放切面会整场景重建 HUD；不要再播一遍入场动画，
	# 直接显示最终状态，避免“切关后 HUD 重新加载”的观感。
	if SaveData.is_route_transition:
		_show_entry_immediately()
	else:
		_play_entry_animation()


## 建交叉淡入用的第二张游戏框：放在 Front 后面、HUD 前面，保证淡入期间不会盖住 HUD 文字。
func _setup_front_crossfade() -> void:
	_front_next = Sprite2D.new()
	_front_next.name = "FrontNext"
	_front_next.z_index = _front.z_index
	_front_next.centered = _front.centered
	_front_next.offset = _front.offset
	_front_next.position = _front.position
	_front_next.scale = _front.scale
	_front_next.flip_h = _front.flip_h
	_front_next.flip_v = _front.flip_v
	_front_next.visible = false
	_front_next.modulate.a = 0.0
	add_child(_front_next)
	# Front 是当前框；FrontNext 紧随其后，再后面才是各 HUD 节点。
	move_child(_front_next, _front.get_index() + 1)


## HUD 全部 CanvasItem 的基准 modulate 缓存：淡出时不能破坏各元素原本的颜色/透明度。
var _hud_alpha_base: Dictionary = {}


## 让整个 HUD 以统一 alpha 淡入淡出（包含嵌套 Memory 层）。
func set_hud_alpha(mult: float) -> void:
	if _hud_alpha_base.is_empty():
		_cache_hud_alpha(self)
	for node in _hud_alpha_base:
		var item := node as CanvasItem
		if not is_instance_valid(item):
			continue
		var base: Color = _hud_alpha_base[node]
		item.modulate = Color(base.r, base.g, base.b, base.a * mult)
	if is_equal_approx(mult, 1.0):
		_hud_alpha_base.clear()


func _cache_hud_alpha(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasItem:
			_hud_alpha_base[child] = (child as CanvasItem).modulate
		_cache_hud_alpha(child)


## 统一 HUD 显隐：Memory 是嵌套 CanvasLayer，必须单独同步，否则外层隐藏后它还会留在主菜单。
func set_hud_visible(value: bool) -> void:
	visible = value
	var memory := get_node_or_null("Memory")
	if memory is CanvasLayer:
		(memory as CanvasLayer).visible = value


## 按“面数”选框：Stage 4/5/6 使用 false_front_2，EX（stage_no=7）使用 true_front，其余 false_front。
static func frame_texture_for_stage(stage_no: int) -> Texture2D:
	if stage_no == 7:
		return FRAME_EX
	return FRAME_LATE if stage_no >= 4 and stage_no <= 6 else FRAME_DEFAULT


## 按面数切框（同一套 crossfade）。
func set_stage_frame(stage_no: int, fade_time: float = 0.35) -> void:
	set_frame_texture(frame_texture_for_stage(stage_no), fade_time)


## 运行时换游戏框：新纹理淡入，淡入结束再写回 Front。
## [param fade_time] <= 0 时立即切换；动画可在暂停中继续。
func set_frame_texture(texture: Texture2D, fade_time: float = 0.25) -> void:
	if texture == null:
		return
	if _front_next == null:
		_setup_front_crossfade()
	if _front_tween:
		_front_tween.kill()
		_front_tween = null
	# 若上一次淡入还在中途，先把它的目标提交，避免连续换框时闪回旧图。
	if _front_next.visible:
		_front.texture = _front_next.texture
		_front_next.visible = false
		_front_next.modulate.a = 0.0
	if texture == _front.texture:
		return
	if fade_time <= 0.0:
		_front.texture = texture
		return
	_front_next.texture = texture
	_front_next.modulate.a = 0.0
	_front_next.visible = true
	_front_tween = create_tween()
	_front_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_front_tween.tween_property(_front_next, "modulate:a", 1.0, fade_time)
	_front_tween.tween_callback(func():
		_front.texture = texture
		_front.modulate.a = 1.0
		_front_next.visible = false
		_front_next.modulate.a = 0.0)


## 当前游戏框纹理（读取用；切换请走 set_frame_texture）。
func get_frame_texture() -> Texture2D:
	return _front.texture if _front else null


## 跳过入场：把所有元素直接置到最终状态（切面时用）。
func _show_entry_immediately() -> void:
	var title := $"Title"
	var title_mat := ShaderMaterial.new()
	title_mat.shader = preload("res://gdshader/logo_entrance.gdshader")
	title_mat.set_shader_parameter("progress", 1.0)
	title_mat.set_shader_parameter("alpha_mult", 1.0)
	title.material = title_mat
	title.modulate.a = 1.0

	var diff := $"Difficulty"
	diff.position = Vector2(1056, 64)
	diff.scale = Vector2(1, 1)
	diff.modulate.a = 1.0

	for node: Node in _entry_queue:
		if node is UISeparator:
			node.progress = 1.0
			node.modulate.a = 1.0
		elif node.name in ["MemoryValue", "MemoryNumber"]:
			node.modulate.a = 1.0
		elif node == _memory_rect:
			if node.material is ShaderMaterial:
				node.material = node.material.duplicate()
				node.material.set_shader_parameter("alpha_mult", 1.0)
			node.modulate.a = 1.0
		elif node.has_meta("is_fragment"):
			node.modulate.a = 1.0
		elif node.name not in ["Title", "Difficulty"]:
			node.modulate.a = 1.0
	entry_finished.emit()


## 将所有 HUD 元素依次从右侧滑入
func _play_entry_animation() -> void:
	for i in _entry_queue.size():
		var node := _entry_queue[i]
		_reset_entry_node(node)

		var tw := create_tween()
		tw.tween_interval(i * ENTRY_INTERVAL)
		tw.tween_callback(_play_entry_tween.bind(node))

	# 所有入场动画完成后通知 GameScene
	var total := _entry_queue.size() * ENTRY_INTERVAL + 1.5
	var done := create_tween()
	done.tween_interval(total + 0.1)
	done.tween_callback(func(): entry_finished.emit())


## 将入场节点设为初始隐藏状态
func _reset_entry_node(node: Node) -> void:
	if node.name == "Title":
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://gdshader/logo_entrance.gdshader")
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("alpha_mult", 0.0)
		node.material = mat
		node.modulate.a = 1.0
	elif node is UISeparator:
		node.progress = 0.0
		node.modulate.a = 0.0
	elif node.name == "Difficulty":
		node.position = Vector2(GameConfig.FIELD_CENTER_X, GameConfig.FIELD_CENTER_Y)
		node.scale = Vector2(0.01, 0.01)
		node.modulate.a = 0.0
	elif node.name in ["MemoryValue", "MemoryNumber"]:
		node.modulate.a = 0.0
	elif node == _memory_rect:
		node.material = node.material.duplicate()
		node.material.set_shader_parameter("alpha_mult", 0.0)
	elif node.has_meta("is_fragment"):
		pass  # 碎片用 frag_init 已初始化
	else:
		node.position.x += 30
		node.modulate.a = 0.0


## 播放单个节点的入场动画
func _play_entry_tween(node: Node) -> void:
	if not is_instance_valid(node):
		return

	if node.name == "Title":
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node.material, "shader_parameter/progress", 1.0, 1.5)
		tween.tween_property(node.material, "shader_parameter/alpha_mult", 1.0, 0.8)

	elif node.name == "Difficulty":
		node.modulate.a = 1.0
		var pop := create_tween().set_parallel(true)
		pop.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop.tween_property(node, "scale", Vector2(3, 3), 0.4)
		pop.tween_callback(_play_diff_move.bind(node)).set_delay(0.5)

	elif node is UISeparator:
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "progress", 1.0, ENTRY_DURATION)
		tween.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)

	elif node.name in ["MemoryValue", "MemoryNumber"]:
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)

	elif node == _memory_rect:
		var tween := create_tween()
		tween.tween_property(node.material, "shader_parameter/alpha_mult", 1.0, ENTRY_DURATION * 0.7)

	elif node.has_meta("is_fragment"):
		var tween := create_tween()
		tween.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)

	else:
		# 普通标签：左滑 + 渐显
		var tween := create_tween().set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(node, "position:x", node.position.x - 30, ENTRY_DURATION)
		tween.tween_property(node, "modulate:a", 1.0, ENTRY_DURATION * 0.7)


## 难度入场第二阶段：弹跳后移动到右上角并缩回
func _play_diff_move(node: Node) -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", Vector2(1056, 64), 0.5)
	tween.tween_property(node, "scale", Vector2(1, 1), 0.5)


func _make_number_sprite_on(p_name: String, parent: Node, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := _make_number_sprite(p_name, pos, tex, dcount)
	remove_child(ns)
	parent.add_child(ns)
	ns.z_index = LayerConfig.UI_NORMAL  # 同层内靠到最上（UI 内部相对）
	return ns


## 初始化残机 / Bomb 碎片图标
## 贴图要求：横排 6 帧等宽，帧数 = 碎片数
func _fragment_init() -> void:
	var life_tex := preload("res://assets/Textures/front/life.png")
	var spell_tex := preload("res://assets/Textures/front/spell.png")

	_life_fragments.resize(8)
	_bomb_fragments.resize(8)

	# 残机碎片：在 Player 标签右侧
	for i in 8:
		var sprite := Sprite2D.new()
		sprite.texture = _make_fragment_region(life_tex, 5)
		sprite.position = Vector2(1018 + i * 32, 232)
		sprite.z_index = LayerConfig.UI_TOP
		sprite.modulate.a = 0.0
		sprite.set_meta("is_fragment", true)
		add_child(sprite)
		_life_fragments[i] = sprite
		_entry_queue.append(sprite)

	# Spell 碎片：在 Bomb 标签右侧
	for i in 8:
		var sprite := Sprite2D.new()
		sprite.texture = _make_fragment_region(spell_tex, 5)
		sprite.position = Vector2(1018 + i * 32, 304)
		sprite.z_index = LayerConfig.UI_TOP
		sprite.modulate.a = 0.0
		sprite.set_meta("is_fragment", true)
		add_child(sprite)
		_bomb_fragments[i] = sprite
		_entry_queue.append(sprite)


## 从 6 帧横排贴图中切出第 index 帧
func _make_fragment_region(tex: Texture2D, index: int) -> AtlasTexture:
	var frame_w := tex.get_width() / 6.0
	var height := tex.get_height()
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(index * frame_w, 0, frame_w, height)
	at.filter_clip = true
	return at


func _update_fragments() -> void:
	if resources == null:
		return
	var fw_life := _LIFE_TEX.get_width() / 6.0
	var fw_spell := _SPELL_TEX.get_width() / 6.0
	var life_h := _LIFE_TEX.get_height()
	var spell_h := _SPELL_TEX.get_height()

	for i in 8:
		# 残机：前 lives 个完整，下一个可能显示碎片，其余空
		if i < resources.lives:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(5 * fw_life, 0, fw_life, life_h)  # 帧 5=完整
		elif i == resources.lives and resources.life_fragments > 0:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(resources.life_fragments * fw_life, 0, fw_life, life_h)
		else:
			_life_fragments[i].visible = true
			var at := _life_fragments[i].texture as AtlasTexture
			at.region = Rect2(0, 0, fw_life, life_h)  # 帧 0=空

		# Bomb
		if i < resources.bomb_count:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(5 * fw_spell, 0, fw_spell, spell_h)
		elif i == resources.bomb_count and resources.bomb_fragments > 0:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(resources.bomb_fragments * fw_spell, 0, fw_spell, spell_h)
		else:
			_bomb_fragments[i].visible = true
			var at := _bomb_fragments[i].texture as AtlasTexture
			at.region = Rect2(0, 0, fw_spell, spell_h)


## 各难度的贴图切片（Easy/Normal/Hard/Lunatic/Extra），在 Inspector 中拖入
@export var difficulty_textures: Array[Texture2D]


## 根据 selected_difficulty 切换难度标签贴图
func _update_difficulty_texture() -> void:
	var diff := $"Difficulty"
	if not diff:
		return
	var idx := clampi(SaveData.selected_difficulty, 0, difficulty_textures.size() - 1)
	if idx < difficulty_textures.size() and difficulty_textures[idx]:
		diff.texture = difficulty_textures[idx]


func _add_separator(pos: Vector2, length: float, col: Color) -> void:
	var sep := UISeparator.new()
	sep.position = pos
	sep.line_length = length
	sep.line_color = col
	sep.line_width = 4
	sep.fade_ratio = 0.25
	sep.z_index = LayerConfig.UI_TOP
	add_child(sep)
	_entry_queue.append(sep)


func _make_number_sprite(p_name: String, pos: Vector2, tex: Texture2D = null, dcount: int = 8) -> Node2D:
	var ns := NumberSprite.new()
	ns.name = p_name
	ns.position = pos
	ns.z_index = LayerConfig.UI_TOP
	ns.digit_count = dcount
	ns.digit_texture = tex
	ns.char_count = 14   # 贴图: 0-9 . / - %
	ns.dot_index = 10    # 10='.'
	ns.slash_index = 11  # 11='/'
	ns.minus_index = -1  # 普通不用 '-'
	ns.pct_index = -1    # 普通不用 '%'
	add_child(ns)
	_entry_queue.append(ns)
	return ns


func _process(_delta: float) -> void:
	if resources == null:
		return
	_hi_score_num.value = SaveData.get_high_score(0)
	_score_num.value    = resources.current_score
	_max_point_num.value= resources.max_point
	_graze_num.value    = resources.graze_count
	_memory_num.show_text("%d%%" % int(resources.memory_value))

	if resources != null:
		_power_num.show_text(resources.get_power_display() + "/4.00")

	_update_fragments()

	# 同步 memory → shader
	if _memory_rect and _memory_rect.material is ShaderMaterial:
		_memory_rect.material.set_shader_parameter("memory", float(resources.memory_value))
		_shader_time += _delta * smoothstep(-100.0, 200.0, resources.memory_value) * 10.0
		_memory_rect.material.set_shader_parameter("shader_time", _shader_time)

class_name BenchBase
extends Control
## 组合台（弹幕/敌人/阶段）公共基类 —— 场地/幽灵/坐标归一/面板脚手架/字段助手
## 术语：行为（脚本）/ 外形（外观）/ 数值（字段）——"魂/壳" 已弃用
## 三台结构一致：只写各自的"行为/外形/数值"专属逻辑，公共骨架在此一处。

const RIG_COMMON := preload("res://scripts/workbench/bench_common.gd")
const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")

## 创作台嵌入时页面在页签横栏下方（standalone 为 0）：场地局部 + 偏移 = 游戏坐标
var _world_offset := Vector2.ZERO

var _field: Control
var _ghost: Player
## 关卡运行时（W3b-2：组合台自备，门面已移除）
var _stage_runtime: StageRuntime
## W4c：本台的弹幕世界（组合台自持；standalone 也能跑）
var _bullets: BulletManager


# ═══ 创作台工作区接口（子类覆写；CreationStation 统一调用，R6 公开虚函数）═══

## 序列化当前工作区（存入 user:// 配置）
func snapshot() -> Dictionary:
	return {}

## 恢复工作区
func restore(_data: Dictionary) -> void:
	pass

## 从目录条目装配本台
func preset_from_entry(_entry) -> void:
	pass


## 建本台的弹幕世界（幂等）：standalone 工作台无 autoload，需自建
func ensure_bullet_world() -> BulletManager:
	if _bullets != null:
		return _bullets
	_bullets = BulletManager.new()
	_bullets.name = "BulletManager"
	add_child(_bullets)
	return _bullets


## 建组合台的关卡运行时（幂等）：生成目标 = BenchWorld。_ready 里调用。
func ensure_stage_runtime() -> StageRuntime:
	if _stage_runtime != null:
		return _stage_runtime
	var bench_world := Node2D.new()
	bench_world.name = "BenchWorld"
	add_child(bench_world)
	_stage_runtime = StageRuntime.new()
	_stage_runtime.name = "StageRuntime"
	_stage_runtime.world = bench_world
	add_child(_stage_runtime)
	return _stage_runtime


## 场地 + 幽灵（鼠标跟随 = 自机狙目标）搭建；返回场地
func build_world() -> Control:
	ensure_stage_runtime()  # 保证本台有关卡运行时（子弹台不显式建：幽灵/注册表注入依赖它）
	_bullets = ensure_bullet_world()
	_bullets.fx_parent = _stage_runtime.world
	_stage_runtime.bullets = _bullets
	RIG_COMMON.add_stage_bg(self)
	# 场地：直接子节点绝对定位；(0,0) 起、832x928 → 局部坐标=游戏坐标
	_field = Control.new()
	_field.position = Vector2.ZERO
	_field.size = Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_BOTTOM)
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.gui_input.connect(_on_field_input)
	_field.draw.connect(_on_field_draw)
	add_child(_field)
	_ghost = PLAYER_SCENE.instantiate()
	_ghost.set_script(GHOST)
	_ghost.name = "GhostPlayer"
	_ghost.set("mode", 1)  # GhostPlayer.Mode.MOUSE（AUTO=0/MOUSE=1/STATIC=2；静态类型 Player 无 mode，用 set 动态写）
	_ghost.player_data = REIMU_DATA  # 必须：Player._ready 会应用角色数据
	_ghost.position = Vector2(GameConfig.FIELD_CENTER_X, 620.0)
	_ghost.z_index = 30
	_field.add_child(_ghost)
	# 幽灵（自机）→ 关卡实体注册表；注册表 → 内核弹幕后端
	_stage_runtime.refs.bind_player(_ghost)
	_bullets.inject_world_refs(_stage_runtime.refs)
	return _field


## 创作台嵌入时记录页面偏移（standalone 为 0）。deferred：等布局就绪再取（首台 _ready 时 add_child 未布局完）。
func sync_world_offset() -> void:
	call_deferred("_sync_world_offset_now")

func _sync_world_offset_now() -> void:
	_world_offset = get_global_rect().position


## 场地局部坐标 → 游戏坐标（点击/子弹落点用）
func to_game(p: Vector2) -> Vector2:
	return p + _world_offset


## 游戏坐标 → 场地局部坐标（绘制用）
func from_game(p: Vector2) -> Vector2:
	return p - _world_offset


## 面板脚手架：右锚金边卡片 + 内部纵向滚动 → 返回内容 VBox
func build_panel_scroll() -> VBoxContainer:
	var panel: PanelContainer = RIG_COMMON.make_panel()
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return box



## 字段标签（默认 LABEL_SIZE）
func _label(text: String, font_size: int = RIG_COMMON.LABEL_SIZE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 换行：不撑宽（面板 432 内）
	return l


## 提示行（左键=… · 鼠标=自机 等）
func _hint(text: String) -> Label:
	return _label(text, RIG_COMMON.HINT_SIZE)


## 场地左键（含坐标换算）→ 子类 _on_click；并重绘。
## 需要更多手势（如弹幕台右键指向）的子类覆写本函数。
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_click(to_game((event as InputEventMouseButton).position))
		_field.queue_redraw()


## 子类实现：左键点击（game_pos 为游戏坐标）
func _on_click(_game_pos: Vector2) -> void:
	pass


## 场地绘制：金框 + 子类标记（子弹台整函数覆写；敌人/阶段用基类 + _draw_marker）
func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP - _world_offset.y,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	_draw_marker()


## 子类实现：在游戏坐标画标记（基类已画金框；用 from_game() 转场地局部）
func _draw_marker() -> void:
	pass

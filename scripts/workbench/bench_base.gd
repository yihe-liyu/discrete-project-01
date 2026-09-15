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
var _player: Player
## 关卡运行时（组合台自备，门面已移除）
var _stage_runtime: StageRuntime
## 本台的弹幕世界（组合台自持；standalone 也能跑）
var _bullet_manager: BulletManager


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

# ═══ 热更新管线（公共；子类只提供监听路径 + 重载后动作）═══
## mtime 轮询间隔 + 修改稳定防抖（保存后不再变化才算完成）
const HOT_POLL_INTERVAL := 0.5
const HOT_DEBOUNCE := 0.8

## 右下角浮动状态条（子类 _ready 建好）
var _toast: Control
var _watch_paths: Array[String] = []
var _watch_mtimes: Dictionary = {}
var _hot_enabled := true
var _hot_poll := 0.0
var _hot_dirty_since := -1.0


## 子类覆写：要监听的脚本路径（主脚本 + 同目录全部 .gd，连坐重载）
func _collect_watch_paths() -> Array[String]:
	return []


## 子类覆写：热重载后要替换的主脚本路径；无主脚本返回 ""
func _main_watch_path() -> String:
	return ""


## 子类覆写：热重载成功后的动作（重建面板 / 重演）
func _on_hot_reloaded(_main_new: Script) -> void:
	pass


func _on_hot_toggled(on: bool) -> void:
	_hot_enabled = on
	_toast.show_msg("热更新：开" if on else "热更新：关", Color(0.5, 0.95, 0.6) if on else Color(1, 1, 1, 0.6))


## 主脚本 + 其同目录全部 .gd（A preload B 时只重载 B 无效 → 连坐）
func _with_dir_scripts(paths: Array) -> Array[String]:
	var out: Array[String] = []
	var dirs := {}
	for p in paths:
		if p == "":
			continue
		if not out.has(p):
			out.append(p)
		dirs[p.get_base_dir()] = true
	for d in dirs:
		var da := DirAccess.open(d)
		if da:
			for f in da.get_files():
				if f.ends_with(".gd"):
					var full: String = d.path_join(f)
					if not out.has(full):
						out.append(full)
	return out


## 重建监听集（子类切脚本时调用）
func _rebuild_watch() -> void:
	_watch_paths = _collect_watch_paths()
	_refresh_watch_mtimes()


## 重载完成后刷新监听基线（避免同一改动反复触发）
func _refresh_watch_mtimes() -> void:
	for p in _watch_paths:
		_watch_mtimes[p] = int(FileAccess.get_modified_time(p))


func _process_hot_reload(delta: float) -> void:
	if not _hot_enabled or _watch_paths.is_empty():
		return
	_hot_poll += delta
	if _hot_poll < HOT_POLL_INTERVAL:
		return
	_hot_poll = 0.0
	var changed := false
	for p in _watch_paths:
		var mt := int(FileAccess.get_modified_time(p))
		if mt != int(_watch_mtimes.get(p, 0)):
			changed = true
			# 注意：检测期间【不】更新基线！更新会把防抖清零导致永不重载；重载完成后统一刷新
	if changed:
		if _hot_dirty_since < 0.0:
			_hot_dirty_since = 0.0
			_toast.show_msg("＊ 检测到修改…", Color(1, 1, 0.6))
		_hot_dirty_since += HOT_POLL_INTERVAL
		if _hot_dirty_since >= HOT_DEBOUNCE:
			_hot_dirty_since = -1.0
			_do_hot_reload()
	else:
		_hot_dirty_since = -1.0


## 连坐重载 + 成功后回调子类；解析失败 → 旧版继续 + 红条
func _do_hot_reload() -> void:
	var main_path := _main_watch_path()
	var main_new: Script = null
	var failed := ""
	for p in _watch_paths:
		if p == main_path:
			continue
		if not FileAccess.file_exists(p):
			failed = p
			break
		var s: Script = ResourceLoader.load(p, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
		if s == null:
			failed = p
			break
	if failed == "" and main_path != "":
		if FileAccess.file_exists(main_path):
			main_new = ResourceLoader.load(main_path, "GDScript", ResourceLoader.CACHE_MODE_REPLACE)
			if main_new == null:
				failed = main_path
		else:
			failed = main_path
	if failed != "":
		_toast.show_msg("⚠ 重载失败：%s（旧版继续）" % failed.get_file(), Color(1, 0.4, 0.4))
		_refresh_watch_mtimes()
		_hot_dirty_since = -1.0
		return
	_refresh_watch_mtimes()
	_hot_dirty_since = -1.0
	_on_hot_reloaded(main_new)


## 建本台的弹幕世界（幂等）：standalone 工作台无 autoload，需自建
func ensure_bullet_world() -> BulletManager:
	if _bullet_manager != null:
		return _bullet_manager
	_bullet_manager = BulletManager.new()
	_bullet_manager.name = "BulletManager"
	add_child(_bullet_manager)
	return _bullet_manager


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
	_bullet_manager = ensure_bullet_world()
	_bullet_manager.fx_parent = _stage_runtime.world
	_stage_runtime.bullet_manager = _bullet_manager
	_bullet_manager.inject_stage_runtime(_stage_runtime)   # 共享子弹 ctx 显式绑本台 stage
	RIG_COMMON.add_stage_bg(self)
	# 场地：直接子节点绝对定位；(0,0) 起、832x928 → 局部坐标=游戏坐标
	_field = Control.new()
	_field.position = Vector2.ZERO
	_field.size = Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_BOTTOM)
	_field.mouse_filter = Control.MOUSE_FILTER_STOP
	_field.gui_input.connect(_on_field_input)
	_field.draw.connect(_on_field_draw)
	add_child(_field)
	_player = PLAYER_SCENE.instantiate()
	_player.set_script(GHOST)
	_player.name = "GhostPlayer"
	_player.set("mode", 1)  # GhostPlayer.Mode.MOUSE（AUTO=0/MOUSE=1/STATIC=2；静态类型 Player 无 mode，用 set 动态写）
	_player.player_data = REIMU_DATA  # 必须：Player._ready 会应用角色数据
	_player.position = Vector2(GameConfig.FIELD_CENTER_X, 620.0)
	_player.z_index = LayerConfig.GHOST_PLAYER
	_field.add_child(_player)
	# 幽灵（自机）→ 关卡实体注册表；注册表 → 内核弹幕后端
	_stage_runtime.entity_registry.bind_player(_player)
	_bullet_manager.inject_entity_registry(_stage_runtime.entity_registry)
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

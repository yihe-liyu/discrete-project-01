class_name BenchBase
extends Control
## 组合台（弹幕/敌人/阶段）公共基类 —— 场地/幽灵/坐标归一/面板脚手架/字段助手
## 术语：行为（脚本）/ 外形（外观）/ 数值（字段）——"魂/壳" 已弃用
## 三台结构一致：只写各自的"行为/外形/数值"专属逻辑，公共骨架在此一处。

const RIG_COMMON := preload("res://scripts/workbench/bench_common.gd")
const GHOST := preload("res://scripts/workbench/ghost_player.gd")
const REIMU_DATA := preload("res://data/player_data/reimu_data.tres")
## 幽灵自机：组合台用鼠标跟随（自机狙随手走），起点在场地偏下（与真游戏自机带一致）
const GHOST_MOUSE := 1     # GhostPlayer.Mode.MOUSE（静态类型 Player 无 mode，用 set 动态写）
const GHOST_START_Y := 620.0

## 坐标约定：场地局部坐标 = 游戏坐标（工作台里所有游戏内容都是本 Control 的子节点，天然同一空间）。

var _field: Control
var _player: Player
## 关卡运行时（组合台自备，门面已移除）
var _stage_runtime: StageRuntime
## 本台的弹幕世界（组合台自持；standalone 也能跑）
var _bullet_manager: BulletManager

# ── 三台共用的工作区状态（原先 bullet/enemy 各写一份、phase 又抄两处；2026-09-30 上移）──
## 内容目录（`ContentCatalog.scan()`）；三台同一份扫描
const CATALOG := preload("res://scripts/data/content_catalog.gd")
var _catalog: Variant
## 当前"行为脚本"（发射/生成用它；热重载后替换）。不关心脚本的台子留空。
var _cur_script: Script = null
var _cur_script_path: String = ""
## 参数字段面板（脚本 var → 可调控件）；不建面板的台子留空
var _param_panel: VBoxContainer = null
## 右下角状态条文案（热更新结果等）；三台都指向 `_toast.label`
var _reload_status: Label = null


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

# ═══ 热更新（实现全在 `HotReloadService`；本类只做接线 + 转发）═══
## 右下角浮动状态条（子类 _ready 建好）
var _toast: Control
## 热更新服务（无树；两个来源是下面两个子类虚函数的 Callable）
var _hot_reload_service: HotReloadService


func _init() -> void:
	_hot_reload_service = HotReloadService.new()
	_hot_reload_service.setup(_collect_watch_paths, _main_watch_path)
	_hot_reload_service.status.connect(_on_hot_status)
	_hot_reload_service.reloaded.connect(_on_hot_reloaded)


## 子类覆写：要监听的脚本路径（主脚本 + 同目录全部 .gd，连坐重载）
func _collect_watch_paths() -> Array[String]:
	return []


## 子类覆写：热重载后要替换的主脚本路径；无主脚本返回 ""
func _main_watch_path() -> String:
	return ""


## 子类覆写：热重载成功后的动作（重建面板 / 重演）
func _on_hot_reloaded(_main_new: Script) -> void:
	pass


## 管线播报 → 状态条（子类没建 toast 时静默）
func _on_hot_status(text: String, color: Color) -> void:
	if _toast != null:
		_toast.show_msg(text, color)


func _on_hot_toggled(on: bool) -> void:
	_hot_reload_service.enabled = on
	_on_hot_status("热更新：开" if on else "热更新：关",
			Color(0.5, 0.95, 0.6) if on else Color(1, 1, 1, 0.6))


## 主脚本 + 其同目录全部 .gd（连坐；实现见服务，这里保留旧名给子类调）
func _with_dir_scripts(paths: Array) -> Array[String]:
	return HotReloadService.with_dir_scripts(paths)


## 重建监听集（子类切脚本时调用）
func _rebuild_watch() -> void:
	_hot_reload_service.rebuild()


## 推进一次热更新轮询（子类 `_process` 调）
func _process_hot_reload(delta: float) -> void:
	_hot_reload_service.poll(delta)


## 跳过防抖立刻重载
func _do_hot_reload() -> void:
	_hot_reload_service.force()


func ensure_bullet_world() -> BulletManager:
	if _bullet_manager == null:
		# top_level：游戏世界原点 = 画布原点（全局坐标 = 游戏坐标），不叠工作台页签偏移
		_bullet_manager = StageHost.make_bullet_world(self, true)
	return _bullet_manager


## 建组合台的关卡运行时（幂等）：生成目标 = BenchWorld。_ready 里调用。
func ensure_stage_runtime() -> StageRuntime:
	if _stage_runtime != null:
		return _stage_runtime
	var bench_world := Node2D.new()
	bench_world.name = "BenchWorld"
	bench_world.top_level = true   # 同 BulletManager：游戏坐标 = 画布坐标
	add_child(bench_world)
	_stage_runtime = StageRuntime.new()
	_stage_runtime.name = "StageRuntime"
	_stage_runtime.world = bench_world
	add_child(_stage_runtime)
	return _stage_runtime


## 场地 + 幽灵（鼠标跟随 = 自机狙目标）搭建；返回场地
## 装配顺序照旧（子弹世界 → 垫底暗色 → 场地）：场地金框画在子弹之上，是刻意的观感。
func build_world() -> Control:
	ensure_stage_runtime()  # 保证本台有关卡运行时（子弹台不显式建：幽灵/注册表注入依赖它）
	ensure_bullet_world()
	RIG_COMMON.add_stage_bg(self)
	_field = _make_field()
	_player = StageHost.make_player(_field, GHOST, "GhostPlayer", REIMU_DATA)
	_player.set("mode", GHOST_MOUSE)  # 静态类型 Player 无 mode，用 set 动态写
	_player.position = Vector2(GameConfig.FIELD_CENTER_X, GHOST_START_Y)
	_player.z_index = LayerConfig.GHOST_PLAYER
	# 与真游戏/工作台同一条 StageHost 接线（fx_parent / 运行时认领 / 共享 ctx / 注册表 / 内核后端）
	StageHost.wire(_stage_runtime, _bullet_manager, _player, _stage_runtime.world)
	return _field


## 场地：直接子节点绝对定位；(0,0) 起、832x928 → 局部坐标 = 游戏坐标
func _make_field() -> Control:
	var field := Control.new()
	field.position = Vector2.ZERO
	field.size = Vector2(GameConfig.FIELD_RIGHT, GameConfig.FIELD_BOTTOM)
	field.top_level = true          # 场地也在画布坐标（与子弹/Boss 同一空间）
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.gui_input.connect(_on_field_input)
	field.draw.connect(_on_field_draw)
	add_child(field)
	return field




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


## 场地左键 → 子类 _on_click（参数即游戏坐标）；并重绘。
## 需要更多手势（如弹幕台右键指向）的子类覆写本函数。
func _on_field_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_click((event as InputEventMouseButton).position)
		_field.queue_redraw()


## 子类实现：左键点击（game_pos 为游戏坐标）
func _on_click(_game_pos: Vector2) -> void:
	pass


## 场地绘制：金框 + 子类标记（子弹台整函数覆写；敌人/阶段用基类 + _draw_marker）
func _on_field_draw() -> void:
	var field := Rect2(GameConfig.FIELD_LEFT, GameConfig.FIELD_TOP,
		GameConfig.FIELD_RIGHT - GameConfig.FIELD_LEFT, GameConfig.FIELD_BOTTOM - GameConfig.FIELD_TOP)
	_field.draw_rect(field, Color(0.62, 0.52, 0.28, 0.5), false, 2.0)
	_draw_marker()


## 子类实现：在游戏坐标画标记（基类已画金框；坐标即场地局部）
func _draw_marker() -> void:
	pass


# ═══ 公开接缝（创作台 / 测试走这里；R6：外部不碰 _私有）═══
# ⚠️ 这些方法**不是**为测试新开的旁路 —— 用户操作走的就是同一条实现：
#    `load_script()` = 用户在脚本下拉里选一条；`force_hot_reload()` = 防抖到点那一次。

## 子类覆写：本台"行为脚本"在目录里的角色（"bullet" / "enemy" / "" = 没有脚本概念）
func _catalog_role() -> String:
	return ""


## 子类覆写：本台的"行为脚本"下拉（没有就返回 null）
func _script_selector() -> OptionButton:
	return null


## 子类覆写：本台的"主选择器"（用于 selected_index()；没有就返回 null）
func _primary_selector() -> OptionButton:
	return null


## 按路径装载"行为脚本"：等价于用户在下拉里选中它 ——
## 在目录里 → 同步下拉并走同一条实现；不在目录里（测试夹具脚本）→ 直接记录 + load。
## 都会重建监听集与参数面板。
func load_script(path: String) -> void:
	var idx := _selector_index_of(path)
	var sel := _script_selector()
	if sel != null and idx >= 0:
		sel.selected = idx
		_set_current_script()
	else:
		_cur_script_path = path
		# 路径不存在 → **保留旧脚本**（与"热更新失败时旧版继续"同一口径），失败交给管线去报
		if ResourceLoader.exists(path):
			_cur_script = load(path)
		_rebuild_watch()
	if _param_panel != null:
		_param_panel.rebuild(_cur_script)


## 该路径在下拉里的下标（0 = "（无）"占位；不在目录里 → -1）
func _selector_index_of(path: String) -> int:
	var role := _catalog_role()
	if role == "" or _catalog == null:
		return -1
	var entries: Array = _catalog.by_role(role)
	for i in entries.size():
		if entries[i].path == path:
			return i + 1
	return -1


## 由下拉当前项推出"行为脚本"路径 → 记录 + load + 重建监听集（用户选脚本走这条）
func _set_current_script() -> void:
	var sel := _script_selector()
	var idx: int = sel.selected if sel != null else 0
	if idx <= 0:
		_cur_script = null
		_cur_script_path = ""
	else:
		var entries: Array = _catalog.by_role(_catalog_role())
		_cur_script_path = entries[idx - 1].path
		_cur_script = load(_cur_script_path)
	_rebuild_watch()


## 当前"行为脚本"（无 → null）
func current_script() -> Script:
	return _cur_script


## 当前"行为脚本"路径（无 → 空串）
func current_script_path() -> String:
	return _cur_script_path


## 参数字段面板（没建面板的台子 → null）
func param_panel() -> VBoxContainer:
	return _param_panel


## 右下角状态条文案（热更新"检测到修改 / 已重载 / 失败"都在这；测试断言它的内容）
func reload_status_text() -> String:
	return _reload_status.text if _reload_status != null else ""


## 正在监听（会被连坐重载）的脚本路径
func watch_paths() -> Array[String]:
	return _hot_reload_service.paths()


## 显式设定监听集（会重建 mtime 基线）；测试/创作台想固定监听目标时用
func set_watch_paths(paths: Array[String]) -> void:
	_hot_reload_service.set_paths(paths)


## 把"上次看到的 mtime"往回拨 seconds 秒 —— 等价于"这个文件刚被改过"（测试没法真去改夹具文件）
func age_watch_mtime(path: String, seconds: float) -> void:
	_hot_reload_service.age_mtime(path, seconds)


## 推进一次热更新轮询（运行时每帧由 `_process` 调；测试手动步进）
func poll_hot_reload(delta: float) -> void:
	_hot_reload_service.poll(delta)


## 跳过防抖立刻重载（= 防抖到点那一次）
func force_hot_reload() -> void:
	_hot_reload_service.force()


## 热更新开关（关掉后 `poll_hot_reload` 直接返回）
func set_hot_enabled(on: bool) -> void:
	_hot_reload_service.enabled = on


## 内容目录（三台同一份扫描结果）
func catalog() -> ContentCatalog:
	return _catalog as ContentCatalog


## 主选择器当前下标（-1 = 没有选择器）
func selected_index() -> int:
	var sel := _primary_selector()
	return sel.selected if sel != null else -1


## 本台的关卡运行时（坐标/注册表/开演都从它走）
func stage_runtime() -> StageRuntime:
	return _stage_runtime


## 本台的弹幕世界（画布坐标，`top_level`）
func bullet_manager() -> BulletManager:
	return _bullet_manager


## 本台的场地（画布坐标，`top_level`；原点 = 画布原点）
## 名字不叫 `field()`：基类/子类里 `var field` 是个常见局部名，会触发"遮蔽成员"警告（warnings-as-errors）
func playfield() -> Control:
	return _field

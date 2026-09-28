extends Control
## **对话预览**（独立场景，不进关卡）：把 `data/dialogue/**` 里任意一段构建函数直接播出来。
## 解决"战后对话要打完整关才看得到"的痛点。
##
## 三种用法（优先级：命令行 > `@export` > 默认）：
##   ① **编辑器里**：打开本场景 → 右侧面板选「脚本 / 段落」→ 直接 F5（或改 `@export` 后 F5 即播）
##   ② **命令行**：`--script=` / `--func=` / `--list` / `--dry` / `--shot=`（见下）
##   ③ **窗口内**：下拉换段（换脚本自动刷新段落列表）、`▶ 播放`、R 重播、Q 退出
##
##   godot --headless --path . scenes/ui/dialogue_preview.tscn -- --list
##   godot --headless --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后 --dry
##   godot --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后
##   godot --path . scenes/ui/dialogue_preview.tscn -- --func=战斗后 --shot=/tmp/dlg.png
##
## 构建函数识别：`static` + 零参数 + 返回 `DialogueSteps`（元数据判据，不靠命名约定）。

const BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
const DEFAULT_SCRIPT := "res://data/dialogue/stage/stage01_dialogue.gd"
const DIALOGUE_DIR := "res://data/dialogue"

## 编辑器里直接选（命令行 `--script=` / `--func=` 会覆盖它们；都空 → 默认脚本的第一个构建函数）
@export var dialogue_script: String = ""
@export var dialogue_func: String = ""
## 进场景即播（**默认关**：进来先看清面板、挑好段，再按「▶ 播放」/ R）。
## 命令行给了 `--script=` / `--func=` / `--shot=` 时例外 —— 那本就是"现在就播"的请求，自动化不受影响。
@export var auto_play: bool = false

@onready var _script_picker: OptionButton = $Panel/VBox/ScriptPicker
@onready var _func_picker: OptionButton = $Panel/VBox/FuncPicker
@onready var _play_button: Button = $Panel/VBox/PlayButton
@onready var _info: Label = $Panel/VBox/Info

var _paths: Array[String] = []      ## 扫描到的对话脚本（脚本下拉的数据）
var _path: String = ""
var _func_name: String = ""
var _box: CanvasLayer


func _ready() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	if args.has("list"):
		_print_catalog()
		get_tree().quit(0)
		return

	_reload_scripts()
	# 优先级：命令行 > @export > 默认（两者都空时 `_select` 自己兜底）
	if not _select(String(args.get("script", dialogue_script)), String(args.get("func", dialogue_func))):
		get_tree().quit(1)
		return

	# 干跑：不开窗，打印整段（无头可用）
	if args.has("dry"):
		print("=== %s.%s（干跑）===" % [_path.get_file(), _func_name])
		print(DialogueDryRun.format(DialogueDryRun.play(_build_steps().steps)))
		get_tree().quit(0)
		return

	_wire_pickers()
	# `--shot` 只负责"截图当前状态"，不构成"要播"（播不播看 auto_play / --script / --func）
	var wants_playback: bool = auto_play or args.has("script") or args.has("func")
	if wants_playback:
		_play_current()
	else:
		_show_idle()

	# `--shot=<path>`：等首句稳定后截图并退出（给"看一眼/自动化检查"用）
	if args.has("shot"):
		await get_tree().create_timer(float(args.get("shot-delay", 1.0))).timeout
		var image := get_viewport().get_texture().get_image()
		image.save_png(String(args["shot"]))
		print("已截图：%s" % args["shot"])
		get_tree().quit(0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_Q:
				get_tree().quit(0)
			KEY_R:
				_play_current()


# ═══ 播放 ═══

func _play_current() -> void:
	var steps := _build_steps()
	if steps == null:
		return
	# 终端同步打一份文本：改台词/挑段时不用盯着窗口读
	print("=== %s.%s ===" % [_path.get_file(), _func_name])
	print(DialogueDryRun.format(DialogueDryRun.play(steps.steps)))
	_start_playback(steps.steps)
	_info.text = _info_text()


func _start_playback(p_steps: Array) -> void:
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_box = BOX_SCENE.instantiate()
	add_child(_box)
	_box.finished.connect(func(): _info.text = _info_text() + "\n播完了")
	_box.play_steps(p_steps)


## **换段只是"选好"**：停掉当前演出、提示按 ▶ / R —— 不自动播（与 `auto_play` 默认关一致）
func _show_idle() -> void:
	if _box != null and is_instance_valid(_box):
		_box.queue_free()
	_box = null
	_info.text = _info_text() + "\n（未播放）选好段落 → 「▶ 播放」或 R"


func _build_steps() -> DialogueSteps:
	var script: GDScript = load(_path)
	var steps = script.call(StringName(_func_name))
	if steps == null:
		push_error("DialoguePreview: %s.%s() 返回 null（构建函数要 static 且返回 DialogueSteps）" % [_path, _func_name])
	return steps


func _info_text() -> String:
	return "%s · %s\nZ/Enter 下一句 · X 跳过（长按关闭）\nR 重播 · Q 退出 · 下拉换段" % [
		_path.get_file(), _func_name]


# ═══ 下拉 / 选择 ═══

func _wire_pickers() -> void:
	_script_picker.item_selected.connect(_on_script_picked)
	_func_picker.item_selected.connect(_on_func_picked)
	_play_button.pressed.connect(_play_current)


## 换脚本：刷新段落列表并**只选中**它第一个构建函数（不播 —— 要播按 ▶ / R）
func _on_script_picked(p_index: int) -> void:
	if _select(String(_script_picker.get_item_metadata(p_index)), ""):
		_show_idle()


## 换段落：只选中（不播）
func _on_func_picked(p_index: int) -> void:
	if _select(_path, String(_func_picker.get_item_metadata(p_index))):
		_show_idle()


## 扫描 `data/dialogue/**` 填脚本下拉
func _reload_scripts() -> void:
	_paths = _scan_scripts(DIALOGUE_DIR)
	_script_picker.clear()
	for path in _paths:
		var index := _script_picker.item_count
		_script_picker.add_item(path.get_file())
		_script_picker.set_item_metadata(index, path)


## 选定「脚本 + 构建函数」：同步两个下拉，写 `_path`/`_func_name`；失败返回 false
func _select(p_path: String, p_func: String) -> bool:
	var path := p_path
	if path.is_empty():
		path = _paths[0] if not _paths.is_empty() else DEFAULT_SCRIPT
	if path.begins_with("data/"):
		path = "res://" + path              # 允许写相对路径，好看
	if not ResourceLoader.exists(path):
		push_error("DialoguePreview: 找不到脚本 %s" % path)
		return false
	var builders := _builders_of(load(path))
	if builders.is_empty():
		push_error("DialoguePreview: %s 里没有构建函数（static + 零参数 + 返回 DialogueSteps）" % path)
		return false
	var func_name := p_func
	if not builders.has(func_name):
		if not func_name.is_empty():
			push_warning("DialoguePreview: %s 里没有 %s，改用第一个（%s）" % [path.get_file(), func_name, builders[0]])
		func_name = builders[0]
	_path = path
	_func_name = func_name
	_sync_pickers(builders)
	return true


## 让两个下拉显示当前选择（程序 `select()` 不会触发 `item_selected`，无回环）
func _sync_pickers(p_builders: Array[String]) -> void:
	var script_index := -1
	for i in _script_picker.item_count:
		if String(_script_picker.get_item_metadata(i)) == _path:
			script_index = i
			break
	if script_index < 0:                    # 命令行给的脚本不在扫描目录里 → 临时加一项
		script_index = _script_picker.item_count
		_script_picker.add_item(_path.get_file())
		_script_picker.set_item_metadata(script_index, _path)
	_script_picker.select(script_index)

	_func_picker.clear()
	for i in p_builders.size():
		_func_picker.add_item(p_builders[i])
		_func_picker.set_item_metadata(i, p_builders[i])
		if p_builders[i] == _func_name:
			_func_picker.select(i)


# ═══ 参数 / 目录扫描 / 构建函数识别 ═══

## 解析 `--key=value` / `--flag`（Godot 的 `--` 之后是 user args）
func _parse_args(p_args: PackedStringArray) -> Dictionary:
	var out := {}
	for raw in p_args:
		var text := String(raw)
		if text.begins_with("--"):
			text = text.substr(2)
		var eq := text.find("=")
		if eq >= 0:
			out[text.substr(0, eq)] = text.substr(eq + 1)
		else:
			out[text] = true
	return out


## 构建函数识别：static + 零参数 + 返回 DialogueSteps（看元数据，不靠命名）
static func _builders_of(p_script: GDScript) -> Array[String]:
	var out: Array[String] = []
	for method in p_script.get_script_method_list():
		if not (int(method.flags) & METHOD_FLAG_STATIC):
			continue
		if not (method.args as Array).is_empty():
			continue
		if String(method.get("return", {}).get("class_name", "")) != "DialogueSteps":
			continue
		out.append(String(method.name))
	out.sort()
	return out


func _print_catalog() -> void:
	print("=== 对话脚本目录（data/dialogue/**）===")
	for path in _scan_scripts(DIALOGUE_DIR):
		print("%s" % path)
		for builder in _builders_of(load(path)):
			print("    · %s" % builder)
	print("\n干跑：-- --script=<路径> --func=<函数> --dry")


func _scan_scripts(p_dir: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(p_dir)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full := p_dir.path_join(entry)
		if dir.current_is_dir() and not entry.begins_with("."):
			out.append_array(_scan_scripts(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out

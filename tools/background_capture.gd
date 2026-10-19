extends Node
## 3D 背景「可对比截图 + 渲染耗时」工具（2026-10-02 重建 BG8；原版随 `54d7758` 删除，`git show bfe853f` 可取回）
##
## **为什么要有它**：背景是**真 3D SubViewport**（每帧一整条 3D 管线 + 天空/glow + 全屏氛围 pass），
## 但"它到底花多少 ms"全项目没人量过；而「地平线分界线 / 黑远地面」这类问题**光靠眼睛调不出来** ——
## 2026-08-10 那批画面改动就是因为没有可量化对比，最后整体回退（`17e928e`）。
## 本工具交付两样：① 同种子同帧号的**可对比截图**；② 官方测量接口的**每帧 CPU/GPU ms**。
##
## 用法（⚠️ 必须真实渲染后端；`--headless` 下数字全是假的）：
##   godot --path . res://tools/background_capture.tscn --fixed-fps 60 -- \
##         --out res://.godot/probe/bg_shots --shots 180,540 --stage 1
##
## `--fixed-fps 60` **必须**：它把模拟时间与真实时间解耦 ⇒ 同一帧号 = 同一画面状态。
## 参数（都在 `--` 之后，`--key value` 成对）：
##   `--stage <id>`    抓**哪一面**（默认 1）。走 `StageCatalog.find()`（带目录扫描兜底）；
##                     缺面 / 该面没配 `background_scene` / 背景根不是 `StageBackground` ⇒ 直接退出并报错
##   `--out <目录>`    输出目录（默认 `res://.godot/probe/bg_shots`，git 忽略）
##   `--shots 180,540` 在第 N 帧各存一张图 + 打一行数字（默认 180=3s / 540=9s；1s = 60 帧）
##   `--until 600`     跑到第 N 帧退出（默认 = 最大 shot + 60）
##   `--shrink 2`      背景视口按 1/N 分辨率渲染（1/2 ⇒ 1/4 像素；**默认 2 = 出厂口径**）
##   `--seed <整数>`   固定 RNG 种子，默认 = 项目唯一来源 `BenchCommon.FIXED_SEED`
##                     （树是 `DecorManager.batch_spawn` **随机**撒的：不固定种子，两次跑的画面不可比）
##   `--no-srgb`       不做线性→sRGB 修正（默认做：视口纹理是线性的，直接存 PNG 会偏暗）
##
## 出图文件名带 **stage**：`bg_s<stage>_f<帧>_<宽>x<高>.png` —— 同一目录跑多面不会互相覆盖。

const BENCH_COMMON := preload("res://scripts/workbench/bench_common.gd")
const CAMERA_HOME := preload("res://scripts/background/background_camera_home.gd")

## 抓哪一面（`--stage` 覆盖）
const DEFAULT_STAGE_ID := 1
## 与 `game_scene.tscn` 的 SubViewport 同规格（BG7 已把工作台统一到此值）
const FIELD_SIZE := Vector2i(800, 928)
## 相机姿态唯一来源：scripts/background/background_camera_home.gd
const CAM_POS := CAMERA_HOME.POSITION
const CAM_ROT_DEG := CAMERA_HOME.ROTATION_DEGREES
const CAM_FOV := CAMERA_HOME.FOV
## 真实耗时的滚动平均窗口（帧）
const AVG_WINDOW := 60

var _vp: SubViewport
var _bg: StageBackground
var _win_rid: RID
var _out_dir := "res://.godot/probe/bg_shots"
var _shot_frames: Array[int] = [180, 540]
var _until_frame := -1
## 默认 **2 = 出厂口径**（`stretch_shrink = 2`）；用 1 量出来的像素量是出厂的 4 倍，别混着比
var _shrink := 2
var _seed: int = BENCH_COMMON.FIXED_SEED
var _srgb := true
var _frame := 0
var _last_usec := 0
var _real_ms: Array[float] = []
var _stage_id := DEFAULT_STAGE_ID
var _stage_name := ""


func _ready() -> void:
	_parse_args()
	var made := DirAccess.make_dir_recursive_absolute(_out_dir)
	if made != OK and made != ERR_ALREADY_EXISTS:
		push_error("建不出输出目录 %s（err=%d）" % [_out_dir, made])
		get_tree().quit(1)
		return

	# 抓哪一面：走 `StageCatalog.find()`（它带目录扫描兜底）。缺面 / 缺背景一律**响亮退出** ——
	# 否则会拿一个空视口的数字当结论（这工具的用途就是"别靠眼睛"）。
	var stage_data: StageData = StageCatalog.find(_stage_id)
	if stage_data == null:
		push_error("找不到关卡 stage_id=%d" % _stage_id)
		get_tree().quit(1)
		return
	if stage_data.background_scene == null:
		push_error("关卡 %s（id=%d）没配 background_scene" % [StageCatalog.display_name_of(_stage_id), _stage_id])
		get_tree().quit(1)
		return
	_stage_name = StageCatalog.display_name_of(_stage_id)

	# 种子必须**早于**任何 batch_spawn：树的位置/尺寸都走 RNG
	RNG.set_seed(_seed)

	_vp = SubViewport.new()
	_vp.own_world_3d = true   # BG12-fix：各自持有 World3D（否则同 world 的第二个 WorldEnvironment 被静默忽略）
	_vp.name = "CaptureViewport"
	_vp.size = Vector2i(
		int(round(float(FIELD_SIZE.x) / float(_shrink))),
		int(round(float(FIELD_SIZE.y) / float(_shrink))))
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = CAM_POS
	cam.rotation_degrees = CAM_ROT_DEG
	cam.fov = CAM_FOV
	_vp.add_child(cam)

	_bg = stage_data.background_scene.instantiate() as StageBackground
	if _bg == null:
		push_error("关卡 %s 的背景**根节点**必须挂 StageBackground（抄背景时最容易把内容脚本挂到根上）" % _stage_name)
		get_tree().quit(1)
		return
	_vp.add_child(_bg)

	# 与 `StageRuntime.load_stage()` 启动背景协程的方式**一致**（别自创接线）：
	# 引擎的规则 = 「背景**直接子节点**里所有 `CoroutineScript` 都 start」。这里照抄同一条 ——
	# **不按节点名找**（节点名是作者的自由：BGA3 之后那个脚本会从 `Decor` 改名成 `Stage`）。
	# ctx.stage 提供 current_background → `ctx.decor` 才拿得到 DecorManager。
	var runtime := StageRuntime.new()
	runtime.name = "CaptureStageRuntime"
	add_child(runtime)
	runtime.current_background = _bg
	var started := 0
	for child in _bg.get_children():
		if child is CoroutineScript:
			var ctx := StageContext.new(child)
			ctx.stage = runtime
			child.start(ctx)
			started += 1
	if started == 0:
		push_error("背景 %s 里没有 `CoroutineScript` 直接子节点 —— 演出不会跑" % _stage_name)
		get_tree().quit(1)
		return

	_win_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp.get_viewport_rid(), true)
	RenderingServer.viewport_set_measure_render_time(_win_rid, true)
	_last_usec = Time.get_ticks_usec()

	print("═══ 背景截图 / 测量 ｜ %s（id=%d）｜ 视口 %dx%d（shrink=%d）｜ 种子 %d ｜ 帧 1..%d ｜ 出图 %s ═══"
		% [_stage_name, _stage_id, _vp.size.x, _vp.size.y, _shrink, _seed, _until_frame, _out_dir])
	print("适配器：%s ｜ %s" % [RenderingServer.get_video_adapter_name(), Engine.get_version_info().string])
	print("提示：`--fixed-fps 60` ⇒ 帧号 = 模拟时间 × 60；真实 ms/帧 是滚动 %d 帧均值" % AVG_WINDOW)


func _process(_delta: float) -> void:
	_frame += 1
	var now := Time.get_ticks_usec()
	_real_ms.append(float(now - _last_usec) / 1000.0)
	_last_usec = now
	if _real_ms.size() > AVG_WINDOW:
		_real_ms.pop_front()

	if _shot_frames.has(_frame):
		_shot(_frame)
	if _frame >= _until_frame:
		_row(_frame)
		print("═══ 跑完 %d 帧（模拟 %.1fs）═══" % [_frame, float(_frame) / 60.0])
		get_tree().quit()


func _shot(frame: int) -> void:
	var tex := _vp.get_texture()
	var img: Image = tex.get_image() if tex else null
	if img == null:
		# 响亮退出，别留空指针堆栈：`--headless`（dummy 渲染器）取不到视口图像，
		# 而这工具的所有数字/出图都要求**真实渲染后端** —— 静默继续等于拿假数据当结论。
		push_error("背景视口取不到图像（多半是 --headless / dummy 渲染器）—— 本工具需要真实渲染后端")
		get_tree().quit(1)
		return
	if _srgb:
		# 视口纹理是**线性**空间：直接存 PNG 会偏暗（原版工具的注释就在说这件事）
		img.linear_to_srgb()
	# 文件名带 stage：同一 `--out` 跑多面时不会互相覆盖（静默丢图比报错更坏）
	var file_name := "bg_s%d_f%04d_%dx%d.png" % [_stage_id, frame, _vp.size.x, _vp.size.y]
	var path := "%s/%s" % [_out_dir, file_name]
	var err := img.save_png(path)
	_row(frame)
	print("     ↳ 截图 %s（err=%d，模拟 %.1fs）" % [path, err, float(frame) / 60.0])


## 一行数字：真实帧耗时 + 背景视口 + 主视口（官方口径：全部视口渲染时间相加才是整帧）
func _row(frame: int) -> void:
	var sum := 0.0
	for ms in _real_ms:
		sum += ms
	var avg_real := sum / maxf(float(_real_ms.size()), 1.0)
	print("帧 %-5d 模拟 %5.1fs ｜ 真实 %6.2f ms/帧（%5.1f FPS）｜ 背景视口 CPU %6.2f / GPU %6.2f ms ｜ 主视口 CPU %6.2f / GPU %6.2f ms"
		% [frame, float(frame) / 60.0, avg_real, 1000.0 / maxf(avg_real, 0.001),
			RenderingServer.viewport_get_measured_render_time_cpu(_vp.get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_gpu(_vp.get_viewport_rid()),
			RenderingServer.viewport_get_measured_render_time_cpu(_win_rid),
			RenderingServer.viewport_get_measured_render_time_gpu(_win_rid)])


func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key: String = args[i]
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match key:
			"--stage":
				_stage_id = maxi(value.to_int(), 1)
				i += 2
			"--out":
				if value != "":
					_out_dir = value
				i += 2
			"--shots":
				_shot_frames = _parse_int_list(value)
				i += 2
			"--until":
				_until_frame = maxi(value.to_int(), 1)
				i += 2
			"--shrink":
				_shrink = maxi(value.to_int(), 1)
				i += 2
			"--seed":
				_seed = value.to_int()
				i += 2
			"--no-srgb":
				_srgb = false
				i += 1
			_:
				i += 1
	if _until_frame < 0:
		_until_frame = _shot_frames.max() + 60


func _parse_int_list(text: String) -> Array[int]:
	var out: Array[int] = []
	var pieces := text.split(",", false)
	for piece in pieces:
		var trimmed := piece.strip_edges()
		if trimmed.is_valid_int():
			out.append(trimmed.to_int())
	if out.is_empty():
		out.append(180)
	out.sort()
	return out

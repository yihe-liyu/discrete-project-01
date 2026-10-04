extends GutTest
## 背景环境接线（`StageBackground` / `BackgroundEnvPreset`）。
##
## 背景：初始环境**唯一来源 = 预设 .tres**（`stage01_env.tres`；`stage01_decor.gd` 的头注释也是这么写的）。
## 但内容脚本 `stage01_decor.gd` 挂在 **`Decor` 子节点**上，而 Godot 里**子节点 `_ready` 先于父节点**
## ⇒ 它 `_ready()` 里那句 `apply_env_preset()` 执行时，父节点还没找到 `WorldEnvironment`，
## 旧实现 `if not world_environment: return` **静默返回** —— **练习模式**（只 `_load_background`、
## 不走 `load_stage` ⇒ 内容脚本的 `start()` 不跑）于是拿场景内联环境，**改预设它不变**。
## 2026-10-02 用哨兵值实测确认过（预设改 0.99 → 实例化后仍是 0.3），见 `BEST_PRACTICES_LOG`。

const BG_PRESET := preload("res://data/stages/stage01/background/stage01_env.tres")


## 回归：**父节点 `_ready` 之前**调用 `apply_env_preset()` 也必须生效（靠 `_env_node()` 懒查找）。
func test_apply_env_preset_works_before_parent_ready():
	var bg := StageBackground.new()
	var env_node := WorldEnvironment.new()
	# ⚠️ 故意**不** add_child(bg) 到树上：这样父节点 `_ready` 不会跑，
	#    正是内容脚本在自己 `_ready` 里调用那一刻的状态。
	bg.add_child(env_node)
	bg.apply_env_preset(BG_PRESET)
	assert_not_null(env_node.environment, "父节点未 `_ready` 时预设也必须生效（懒查找 WorldEnvironment）")
	if env_node.environment != null and BG_PRESET.environment != null:
		assert_almost_eq(env_node.environment.fog_density, BG_PRESET.environment.fog_density, 0.0001,
			"生效的环境应来自预设（fog_density 应与预设一致）")
	bg.free()


## 回归：`build_environment()` 每次都必须是**全新实例** —— 否则重跑/多背景共享同一 Environment，
## 上一轮 tween 改过的雾色残留 ⇒「越重跑越暗」。
func test_env_preset_builds_fresh_environment_each_time():
	var first := BG_PRESET.build_environment()
	var second := BG_PRESET.build_environment()
	assert_not_null(first, "预设应能构建环境")
	assert_not_null(second, "预设应能构建环境")
	assert_ne(first, second, "两次构建必须是两个独立实例（防重跑共享污染）")
	# 改一份不许影响另一份
	first.fog_density = 0.99
	assert_ne(second.fog_density, first.fog_density, "改一份不许串到另一份")


## 回归（BG2/BG3）：预设必须带**真天球**，且 `fog_sky_affect` 必须**够大**（让雾也糊天球）。
## 历史：预设一度只有雾（`background_mode = BG_CLEAR_COLOR`、`sky = null`）⇒ 天是平坦清屏色，
## `stage_background.gd::_sky_material()` 恒返回 null，地平线联动**静默 no-op**。
## ⚠️ `fog_sky_affect` 的方向**两次都翻过**，最终实测定案：
##   **0.0**（作者 2026-08 的原值）⇒ 天球整条不受雾 ⇒ 相机上移/雾变薄后，地面平面**远缘**处出现
##     「暗天花板 + 锯齿树线」硬边：t=15s 实测行均值跳变 **Δ=0.078**（y=67）；
##   **1.0** ⇒ 同帧 Δ=**0.005**（边消失）。关键：洗白**与雾量成正比** ⇒ 雾薄时（density 0.02）
##     天球照样看得见（≈98% 不被洗），所以**该按"雾最薄那一刻"定，而不是按开局最浓的 0.3 定**。
func test_preset_sky_is_fogged_like_the_scene():
	var env := BG_PRESET.build_environment()
	assert_not_null(env, "预设应能构建环境")
	if env == null:
		return
	assert_eq(env.background_mode, Environment.BG_SKY, "天必须是天球（BG_SKY），不是清屏色")
	assert_not_null(env.sky, "预设必须带 Sky（否则没有渐变天、地平线联动也无从生效）")
	if env.sky != null:
		assert_true(env.sky.sky_material is ProceduralSkyMaterial, "天球材质应是 ProceduralSkyMaterial")
	assert_gt(env.fog_sky_affect, 0.3,
		"fog_sky_affect 必须够大：0.0 时天球整条不受雾 ⇒ t=15s 地面平面远缘出现 Δ=0.078 的硬边（1.0 时为 0.005）")


## 回归（BG2）：`tween_env_fog()` 必须**真的**把天球地平线色跟着雾色走 —— 以前预设没 sky，
## 这段联动是静默 no-op（写着"改雾色不露地平线"，实际什么都没做）。
func test_tween_env_fog_drives_sky_horizon():
	var bg := StageBackground.new()
	var env_node := WorldEnvironment.new()
	bg.add_child(env_node)
	add_child_autofree(bg)      # 入树：create_tween() 需要树，_ready 才能找到 WorldEnvironment
	await wait_frames(1)
	bg.apply_env_preset(BG_PRESET)
	var sky_mat: ProceduralSkyMaterial = null
	if bg.world_environment != null and bg.world_environment.environment != null \
			and bg.world_environment.environment.sky != null:
		sky_mat = bg.world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	assert_not_null(sky_mat, "预设的天球材质应可用（否则联动无从生效）")
	if sky_mat == null:
		return
	bg.tween_env_fog(Color.RED, 0.05, 0.05)
	await wait_physics_frames(12)
	assert_almost_eq(sky_mat.ground_horizon_color.r, Color.RED.r, 0.02, "地平线色应跟着雾色走")
	assert_almost_eq(sky_mat.ground_bottom_color.r, Color.RED.darkened(0.25).r, 0.02,
		"地面底色 = 雾色暗化 25%")


## 回归（BG2 性能，2026-10-02 实测）：`Sky.radiance_size` 必须**压低**。
## 背景**全是 unshaded 材质**（地面 shader / 树 / Sprite3D 太阳）⇒ 没有任何材质消费天球的辐照/反射，
## 而 `radiance_size` 默认 256px，且天球颜色被 `tween_env_fog` **每帧**改 ⇒ 引擎每帧重算 6 面立方图。
## 实测（llvmpipe，800×928）：256 → 背景视口 GPU **44.8 ms**（21.5 FPS）；32 → **8.9 ms**（76.4 FPS，
## 等于**完全没天球**的 8.92 ms）；而两者**画面差 0.00000**（radiance 只喂环境光/反射，全 unshaded 用不到）。
func test_sky_radiance_is_cheap():
	var env := BG_PRESET.build_environment()
	assert_not_null(env, "预设应能构建环境")
	if env == null or env.sky == null:
		return
	assert_lt(env.sky.radiance_size, 2,
		"radiance_size 必须低（0/1 = 32/64px）：默认 3 = 256px 时每帧重算立方图，实测 8.9 → 44.8 ms")




## 回归（2026-10-02）：雾色**不许是亮灰** —— `Color.DARK_GRAY` 是 CSS `darkgray` (#A9A9A9，
## 亮度 0.663)，名字骗人；雾色偏亮会把**远处洗亮**（实测"远/近" = 1.15 ⇒ 发灰、不真实；
## 换成冷灰 (0.25,0.27,0.30) 后 = 1.02）。另外：**雾量 ≥0.05 基本饱和，雾色才是主导旋钮**。
func test_preset_fog_color_is_not_washed_out():
	var env := BG_PRESET.build_environment()
	assert_not_null(env, "预设应能构建环境")
	if env == null:
		return
	var lum := 0.2126 * env.fog_light_color.r + 0.7152 * env.fog_light_color.g + 0.0722 * env.fog_light_color.b
	assert_lt(lum, 0.45, "雾色亮度必须 < 0.45（0.663 = CSS darkgray ⇒ 把远处洗亮）")
	assert_gt(lum, 0.05, "也别黑到没有空气感")


## 回归（BG6）：相机必须按**类型**找，**不能按名字** —— 旧实现只认 `Camera3D` 这个名字，
## 一改名就**静默**掉进 `_own_camera()` 兜底（多出一台相机、注入的那台被无视）。
func test_background_finds_camera_by_type_not_name():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	cam.name = "主相机"      # 故意不叫 Camera3D
	host.add_child(cam)
	var bg := StageBackground.new()
	host.add_child(bg)       # 入树触发 _ready → _find_camera
	await wait_frames(1)
	assert_eq(bg.camera, cam, "应按类型找到那台相机（而不是只认名字 Camera3D）")
	var cam_count := 0
	for c in host.get_children():
		if c is Camera3D:
			cam_count += 1
	assert_eq(cam_count, 1, "不许自建第二台相机（按名字找的旧实现改名后会多出一台）")


## 回归（P1-B3）：背景的 `DecorManager` 必须是**场景声明的子节点**
## （`StageBackground.get_decor_manager()` 按类型解析）—— 旧实现 `StageContext.get_decor()`
## 按名字 `get_node_or_null("DecorManager")` 找、找不到再运行时 `add_child` 动态建：
## 行为绑在节点名上，还在内容脚本里偷偷改场景树。
func test_stage01_background_declares_decor_manager():
	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	add_child_autofree(bg)
	var mgr := bg.get_decor_manager()
	assert_not_null(mgr, "背景场景必须声明 DecorManager 子节点（否则 ctx.decor 为 null）")
	if mgr != null:
		assert_eq(mgr.get_parent(), bg, "声明的 DecorManager 应是背景子节点（随背景存亡）")
		assert_eq(bg.get_decor_manager(), mgr, "二次访问返回同一实例（懒解析缓存）")


## 回归（BG12-fix）：两个宿主的**背景视口必须 `own_world_3d = true`**。
## 实测（2026-10-02 探针）：`false` 时背景视口**与根视口共享同一个 World3D**，而一个 World3D 只有一份生效的
## Environment ⇒ 后进的 `WorldEnvironment` **被静默忽略**（塞红雾无效）。⇒ 各自持有世界才不会被抢。
func test_background_viewports_own_their_world():
	var hosts := {
		"res://scenes/game_scene.tscn": "Background/SubViewportContainer/SubViewport",
		"res://scenes/workbench.tscn": "BgContainer/BgViewport",
	}
	for path in hosts.keys():
		var packed: PackedScene = load(path) as PackedScene
		assert_not_null(packed, "场景应能加载：" + str(path))
		if packed == null:
			continue
		var host: Node = packed.instantiate()
		var vp := host.get_node_or_null(hosts[path]) as SubViewport
		assert_not_null(vp, "%s 里应能找到背景 SubViewport（%s）" % [path, hosts[path]])
		if vp != null:
			assert_true(vp.own_world_3d,
				"%s 的背景视口必须 own_world_3d = true（否则它与根视口共享 World3D，环境会被同 world 的另一个 WorldEnvironment 抢）" % path)
		host.free()

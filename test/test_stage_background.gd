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


## 相机复位要**回初始姿态**，不只是 fov：旧实现只写回 `fov = 90` ⇒
## 相机动词跑过之后的重跑**不会回正**（位置/朝向一路漂）。
func test_reset_camera_restores_pose_not_only_fov():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 6)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 90.0
	host.add_child(cam)
	var bg := StageBackground.new()
	host.add_child(bg)                 # 入树 ⇒ `_ready` 抓"初始姿态"
	await wait_frames(1)

	cam.position = Vector3(0, 30, 3)   # 模拟演出跑过（pan + rotate + zoom）
	cam.rotation_degrees = Vector3(0, 0, 0)
	cam.fov = 68.0
	bg.reset_camera()

	assert_eq(cam.transform.origin, Vector3(0, 10, 6), "位置要回初始（旧实现只复位 fov）")
	assert_eq(cam.rotation_degrees, Vector3(-30, 0, 0), "朝向要回初始")
	assert_eq(cam.fov, 90.0, "fov 要回初始")


## 环境**不由内容脚本负责**：背景场景声明 `env_preset` 后，**入树即有环境**
## （旧实现靠内容子节点的 `_ready` 调 `apply_env_preset` ⇒ 练习模式 / 内容脚本缺失时就没有环境）。
func test_ready_applies_declared_env_preset():
	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	assert_not_null(bg.env_preset, "本场景应在 .tscn 里声明 env_preset（环境唯一来源）")
	if bg.env_preset == null:
		bg.free()
		return
	add_child_autofree(bg)
	await wait_frames(1)
	assert_not_null(bg.world_environment, "场景应有 WorldEnvironment")
	if bg.world_environment == null:
		return
	assert_not_null(bg.world_environment.environment,
		"入树后环境必须已被应用（不再依赖内容脚本的 _ready）")


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


## BGT5：工作台切走时背景视口必须停渲染（`render_target_update_mode` 与 process_mode 无关，
## 不显式关掉的话 3D 管线在后台照跑；游戏里实测暂停省 ≈8.7 ms/帧）。
func test_workbench_bg_viewport_stops_when_suspended():
	var wb: Node = load("res://scenes/workbench.tscn").instantiate()
	add_child_autofree(wb)
	await get_tree().process_frame
	var viewport := wb.get_node_or_null("BgContainer/BgViewport") as SubViewport
	assert_not_null(viewport, "工作台应有背景 SubViewport")
	if viewport == null:
		return
	assert_eq(viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS,
		"运行中背景视口应持续渲染")
	wb.suspend_preview()
	assert_eq(viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED,
		"切走/暂停后背景视口应停渲染")
	wb.resume_preview()
	assert_eq(viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS,
		"恢复后背景视口应重新渲染")


# ═══ 蒙眼雾：可见部分场景声明 + 不再摸父节点（2026-10-04 BGA/B）═══

## 蒙眼雾的**可见部分**必须在场景里声明，参数唯一来源 = **材质**。
## 旧实现 `new()` 出 CanvasLayer/ColorRect/材质 + 12 个 `@export` + `_apply_params()` 镜像
## ⇒ 同一个值三份默认（shader 文件 / `@export` / `.tscn`），改 shader 里的数字是静默 no-op；
## 且编辑器里看不见/点不到这层雾。
func test_fog_layer_and_params_are_scene_declared():
	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	add_child_autofree(bg)
	await wait_frames(1)
	var layer := bg.get_node_or_null("FogFX/FogLayer") as CanvasLayer
	var rect := bg.get_node_or_null("FogFX/FogLayer/FogRect") as ColorRect
	assert_not_null(layer, "FogLayer 必须场景声明（不再 new()）—— 否则编辑器里看不见")
	assert_not_null(rect, "FogRect 必须场景声明")
	if rect == null:
		return
	assert_true(layer.visible, "**声明即显示**（练习模式也开黑雾 —— 2026-10-04 作者拍板）")
	var mat := rect.material as ShaderMaterial
	assert_not_null(mat, "FogRect 应挂 ShaderMaterial")
	if mat == null:
		return
	# 真值（原先是 FogFX 节点上的 @export 覆盖，现搬进材质 ⇒ 只剩这一处）
	assert_almost_eq(mat.get_shader_parameter("fog_dark"), 0.8, 0.001, "fog_dark 真值应在材质里")
	assert_almost_eq(mat.get_shader_parameter("ring_strength"), 0.5, 0.001, "ring_strength 真值应在材质里")
	assert_almost_eq(mat.get_shader_parameter("ring_radius"), 0.08, 0.001, "ring_radius 真值应在材质里")


## 雾材质必须**每实例独立**：旧实现是 `ShaderMaterial.new()`（天然独立），而 `.tscn` 的
## `[sub_resource]` **默认跨实例共享** ⇒ 必须 `resource_local_to_scene = true`，
## 否则两个背景实例同时存在时 `sun_pos` 互相覆盖（雾跟错相机）。
## ⚠️ 这正是本项目已踩过的「Environment 是场景 SubResource、多实例共享 ⇒ 越重跑越暗」同款。
func test_fog_material_is_per_instance():
	var packed: PackedScene = preload("res://data/stages/stage01/background/stage01_background.tscn")
	var a: Node = packed.instantiate()
	var b: Node = packed.instantiate()
	add_child_autofree(a)
	add_child_autofree(b)
	var ma := (a.get_node("FogFX/FogLayer/FogRect") as ColorRect).material as ShaderMaterial
	var mb := (b.get_node("FogFX/FogLayer/FogRect") as ColorRect).material as ShaderMaterial
	assert_not_null(ma, "实例 a 应有雾材质")
	assert_not_null(mb, "实例 b 应有雾材质")
	assert_ne(ma, mb, "两个实例的雾材质必须各自独立（sub_resource 默认共享 ⇒ 需 resource_local_to_scene）")


## BGA9：地面材质同理 —— `BackgroundPlane._process` 每帧写 `uv_offset`，
## 工作台 + 游戏同时跑时共享材质会互相串 ⇒ 必须每实例独立。
func test_ground_material_is_per_instance():
	for path in [
		"res://data/stages/stage01/background/stage01_background.tscn",
		"res://data/stages/stage02/background/stage02_background.tscn",
	]:
		var packed: PackedScene = load(path)
		assert_not_null(packed, "场景应能加载：" + path)
		if packed == null:
			continue
		var a: Node = packed.instantiate()
		var b: Node = packed.instantiate()
		add_child_autofree(a)
		add_child_autofree(b)
		var mesh_a := (a.get_node("Ground") as MeshInstance3D).mesh as PlaneMesh
		var mesh_b := (b.get_node("Ground") as MeshInstance3D).mesh as PlaneMesh
		assert_not_null(mesh_a, "%s 的 Ground 应是 PlaneMesh" % path)
		assert_not_null(mesh_b, "%s 的 Ground 应是 PlaneMesh" % path)
		if mesh_a == null or mesh_b == null:
			continue
		var ma := mesh_a.material as ShaderMaterial
		var mb := mesh_b.material as ShaderMaterial
		assert_not_null(ma, "%s 实例 a 应有地面材质" % path)
		assert_not_null(mb, "%s 实例 b 应有地面材质" % path)
		assert_ne(ma, mb, "%s 两个实例的地面材质必须各自独立（需 resource_local_to_scene）" % path)


## 太阳的可见部分必须场景声明，**且圆盘纹理来自场景**（不是运行时 `load()`）。
## 否则编辑器里是个"无纹理的 Sprite3D" = **什么都不画**，连"把太阳拖进画面"都做不到 ——
## 而 2026-10-04 实测太阳圆心在画面顶边**外 7 像素**（屏幕像素 640, -7.3），正需要能在编辑器里调位置。
func test_sun_sprite_is_scene_declared_with_texture():
	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	add_child_autofree(bg)
	await wait_frames(1)
	var sun := bg.get_node_or_null("Sun") as BackgroundSun
	var sprite := bg.get_node_or_null("Sun/SunSprite") as Sprite3D
	assert_not_null(sun, "场景应有 Sun 节点")
	assert_not_null(sprite, "SunSprite 必须场景声明（旧实现是 setup() 里 new()）")
	if sun == null or sprite == null:
		return
	assert_not_null(sprite.texture, "圆盘纹理必须来自场景 ⇒ 编辑器里才看得见（裸 Image 资源做不到）")
	assert_eq(sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "太阳要 billboard")
	assert_eq(sun.position, Vector3(0, 100, -320), "位置应由**节点 transform** 决定（不再是 @export sun_position）")
	assert_true(sprite.visible, "**声明即显示**：不需要任何人调 setup()（练习模式也要它）")


## 回归（2026-10-04 作者实测「二面道中看不见太阳和黑雾」）：
## **宿主自动接线** —— 背景场景一入树，雾就该拿到相机并把太阳投影到屏幕，
## **完全不需要内容脚本调用**。旧设计要靠内容脚本 `setup()`，忘一次就隐形/不跟相机且零报错。
func test_host_auto_binds_fog_without_any_content_call():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 6)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 90.0
	host.add_child(cam)                      # 相机是背景的**兄弟**（宿主按类型找得到）

	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	var rect := bg.get_node("FogFX/FogLayer/FogRect") as ColorRect
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("sun_pos", Vector2(-1, -1))   # 哨兵：确认宿主真的写了它
	host.add_child(bg)                       # 入树 ⇒ `_ready` ⇒ `_resolve_showcase()` 接线
	await wait_frames(1)

	var fog := bg.get_node("FogFX") as ScreenFogFX
	assert_eq(fog.camera, cam, "宿主应把（按类型找到的）相机接进雾里")
	assert_ne(mat.get_shader_parameter("sun_pos"), Vector2(-1, -1),
		"入树后太阳屏幕位置就该被算出来（**没有任何内容脚本调用**）")
	assert_true((fog.get_node("FogLayer") as CanvasLayer).visible, "雾层应可见（声明即显示）")
	assert_true((bg.get_node("Sun/SunSprite") as Sprite3D).visible, "太阳也应可见（声明即显示）")


## 回归：`bind()` **不需要**自己的父节点是 `StageBackground`（注入而非摸爹）。
## 旧实现靠 `get_parent() as StageBackground` 拿相机 ⇒ 把 FogFX 挪个层级/嵌套一层就**静默拿到 null**，
## 于是雾不再跟相机（太阳位置不更新）且**零报错** —— 与 stage02 那次崩溃同款脆弱，只是发生在引擎组件里。
func test_fog_bind_does_not_need_background_parent():
	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	add_child_autofree(bg)
	await wait_frames(1)
	var fog: ScreenFogFX = bg.get_node("FogFX")
	assert_not_null(fog, "场景里应有 FogFX")
	if fog == null:
		return

	# 挪到**任意**父节点下（故意不是 StageBackground）
	var plain := Node3D.new()
	add_child_autofree(plain)
	bg.remove_child(fog)
	plain.add_child(fog)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 6)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	plain.add_child(cam)
	var sun := Node3D.new()
	sun.position = Vector3(0, 100, -320)
	plain.add_child(sun)

	var rect := fog.get_node_or_null("FogLayer/FogRect") as ColorRect
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("sun_pos", Vector2(-1, -1))   # 哨兵：确认 bind 真的写了它
	fog.bind(cam, sun)

	assert_true((fog.get_node("FogLayer") as CanvasLayer).visible, "雾层声明即显示（与父节点是谁无关）")
	assert_not_null(mat.get_shader_parameter("noise_tex"), "噪声纹理来自场景（材质里，不靠运行时读盘）")
	assert_ne(mat.get_shader_parameter("sun_pos"), Vector2(-1, -1),
		"太阳屏幕位置应被投影写入（旧实现此时静默不动：拿不到相机）")


## 回归（2026-10-04 作者实测「一改太阳的 y 坐标，黑雾的对准就不准了」）：
## 雾的太阳对准必须跟**画出来的那个 sprite**（`SunSprite`），**不是** `Sun` 节点 ——
## 作者在编辑器里拖的正是 sprite，而它带自己的局部位移（stage02 里就有一段）。
func test_fog_aligns_to_the_drawn_sprite_not_the_sun_node():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 6)
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 90.0
	host.add_child(cam)

	var bg: StageBackground = preload("res://data/stages/stage01/background/stage01_background.tscn").instantiate()
	var sprite := bg.get_node("Sun/SunSprite") as Sprite3D
	var sun_node := bg.get_node("Sun") as Node3D
	sprite.position = Vector3(0, -60, 200)     # 模拟作者把太阳往下拖
	host.add_child(bg)                          # 入树 ⇒ 宿主接线
	await wait_frames(1)

	var mat := (bg.get_node("FogFX/FogLayer/FogRect") as ColorRect).material as ShaderMaterial
	var vp: Vector2 = bg.get_viewport().get_visible_rect().size
	var want: Vector2 = cam.unproject_position(sprite.global_position) / vp
	var wrong: Vector2 = cam.unproject_position(sun_node.global_position) / vp
	assert_gt(absf(want.y - wrong.y), 0.02, "本用例的前提：sprite 与节点的投影确实差得够远")
	var got: Vector2 = mat.get_shader_parameter("sun_pos")
	assert_almost_eq(got.y, want.y, 0.001,
		"对准必须跟 `SunSprite`（作者拖的就是它），不是 `Sun` 节点")




## 相机**初始姿态**可由背景自己声明（`override_camera_home` + 三个值）。
## 语义关键：它在**抓 home 之前**应用 ⇒ `reset_camera()` 复位到**声明的**那套，
## **不是**宿主相机的原姿态（否则"重跑回正"会把构图带回别的关的样子）。
func test_camera_home_override_applies_and_is_the_reset_target():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 10, 6)          # 宿主相机：故意与下面声明的不同
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.fov = 90.0
	host.add_child(cam)

	var bg := StageBackground.new()
	bg.override_camera_home = true
	bg.camera_home_position = Vector3(0, 20, -3)
	bg.camera_home_rotation_degrees = Vector3(-22, 0, 0)
	bg.camera_home_fov = 68.0
	host.add_child(bg)                        # 入树 ⇒ `_ready` 应用 + 抓 home
	await wait_frames(1)

	assert_eq(cam.transform.origin, Vector3(0, 20, -3), "入树后相机应被摆成声明的初始姿态")
	assert_almost_eq(cam.rotation_degrees.x, -22.0, 0.01, "朝向也应是声明的")
	assert_eq(cam.fov, 68.0, "fov 也应是声明的")

	cam.position = Vector3(9, 9, 9)           # 模拟演出跑过（pan/rotate/zoom）
	cam.rotation_degrees = Vector3.ZERO
	cam.fov = 120.0
	bg.reset_camera()
	assert_eq(cam.transform.origin, Vector3(0, 20, -3), "reset 必须回**声明的**初始姿态（不是宿主原姿态）")
	assert_almost_eq(cam.rotation_degrees.x, -22.0, 0.01, "reset 后朝向也应是声明的")
	assert_eq(cam.fov, 68.0, "reset 后 fov 也应是声明的")


# ═══ 相机动词：绝对 / 相对 + 目标记忆（2026-10-04 作者实测「Y 没回到 0」）═══

## (b) 相对动词从**上一条指令的目标**累加，**不是**从 `camera.transform.origin`（实时值）。
## 反例（旧 `pan_camera`）：两条重叠的相对移动会以"飞行途中的位置"为基准 ⇒ 漂移、丢段。
func test_relative_camera_moves_accumulate_from_target_not_live_value():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	host.add_child(cam)
	var bg := StageBackground.new()
	host.add_child(bg)
	await wait_frames(1)

	bg.set_camera_position(Vector3.ZERO, 0.001)
	bg.move_camera_by(Vector3(5, 0, 0), 0.5)     # 立刻
	bg.move_camera_by(Vector3(0, 7, 0), 0.5)     # **不等第一条跑完** —— 旧实现会在这里丢掉 +5
	await wait_physics_frames(45)

	assert_almost_eq(bg.get_camera_offset().x, 5.0, 0.02, "第二条相对移动必须从**目标**累加（+5 不能丢）")
	assert_almost_eq(bg.get_camera_offset().y, 7.0, 0.02, "第二条自己那段也要到位")


## 作者实况：4 条 Y 增量 −10/+25/−30/+15 **和 = 0**，本意是"转过去再转回来"
## ⇒ 用**相对**动词后必须回到 Y = 0（旧名 `rotate_camera` 是**绝对**，最后一条 +15° 就是终态）。
func test_relative_yaw_deltas_summing_to_zero_return_to_zero():
	var host := Node.new()
	add_child_autofree(host)
	var cam := Camera3D.new()
	host.add_child(cam)
	var bg := StageBackground.new()
	host.add_child(bg)
	await wait_frames(1)

	for deg in [-10.0, 25.0, -30.0, 15.0]:
		bg.rotate_camera_by(Vector3(0, deg_to_rad(deg), 0), 0.2)
	await wait_physics_frames(30)

	assert_almost_eq(rad_to_deg(cam.rotation.y), 0.0, 0.5,
		"增量序列和为 0 ⇒ 必须转回正前方（这正是作者要的「最后回到 0」）")

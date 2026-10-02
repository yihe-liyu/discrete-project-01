# Stage01 道中背景 — 画面效果优化清单

> 状态：**部分已实施** —— 第一批（E+G 氛围 pass / C 地面距离雾 / D3 树融雾）+ 性能优化已落，见文末「已完成」；**§A–§I 中未打 ✅ 的仍是待做**。
> 范围：仅背景 SubViewport（弹幕/UI 不受影响）
> 2026-08-10 记录
>
> **本文怎么读**：**§0 是改动前基线（历史快照，别当现状）** · **§A–§I 是待做清单（做了就打 ✅ 或移进文末）** · **文末「已完成」是记录（只增不改）**。
> 逐条状态权威仍在基线 S 表（S13 背景/图集线）。

---

## 0. 当前视觉构成（基线）

- **天空**：`ProceduralSkyMaterial` 纯色渐变（暗蓝灰→灰白地平线），**无云**
- **太阳**：规则亮圆盘 Sprite3D（HDR 发射 ×4 + additive glow），屏幕雾遮成日食，**无日冕光线**
- **地面**：256×256 平面 + 草纹平铺滚动（`background_plane.gdshader` 仅 8 行 unshaded），**无距离雾/无层次**
- **树**：橡树 MultiMesh 纸片（scissor，billboard=false），**统一色调、无风、远处不虚化**
- **蒙眼雾**：全屏 CanvasLayer 噪点云斑（`screen_fog.gdshader`），太阳处高斯加浓，**单层均匀平移**
- **环境**：fog 0.15→0.04、glow additive 0.8、相机 6s 上移+旋转、地面 10s 加速 1→7×

游戏本体是 2D 玩法，但背景是**真 3D SubViewport**（真相机/真 3D 物体）→ 所有 3D 挂件都有正确视差。

---

## A. 天空加云

- **效果**：日食暗云压境，太阳周围一圈亮、远处乌云堆叠
- **做法**：
  - 简易版：3D 里放 2~3 个大 Sprite3D 云片（暗灰半透明，复用 `_make_cloud_texture`），挂太阳附近高空慢漂移
  - 进阶版：自定义 `shader_type sky` 画 fbm 云层（注意与屏幕雾配合）
- **成本**：低~中 ｜ **风险**：低

## B. 日冕光线

- **效果**：黑盘边缘一圈细亮环 + 向外辐射的冠状光线，微微闪烁
- **做法**：`sun_sprite.gdshader` 对 [黑盘半径, 光晕半径] 区域加角度噪声辐射纹（`ray = noise(atan(uv)*freq + TIME) * exp(-dist)`）；屏幕雾 `sun_mask` 同步加一圈细亮环呼应
- **成本**：低~中 ｜ **风险**：低

## C. 地面层次

- **效果**：近清远朦（距离雾）、地平线渐隐变暗、平铺重复感减轻
- **做法**：改 `background_plane.gdshader`：fragment 用 `VIEW` 算距离→混入雾色；`uv += 值噪声(uv*频率+TIME*滚速)*幅度` 打破平铺；整体压暗一档
- **成本**：低 ｜ **风险**：低（别把草全糊没）

## D. 树的风与色调

- **效果**：每棵颜色微差（深浅绿/枯黄）、微风轻摆、远处融进雾
- **做法**：
  - D1 色调差异（**不用写 shader**）：`MultiMesh.use_colors = true` + `set_instance_color` 随机 tint，材质开 `vertex_color_use_as_albedo`
  - D2 风摆：橡树材质换自定义 shader（unshaded+alpha_scissor），顶点 `sin(TIME + 实例相位 + 高度)` 横摆（相位用 custom_data 或 INSTANCE_ID hash）
  - D3 远处雾化：同 shader 按距离混入雾色（scissor 不能淡 alpha，用颜色融雾）
- **成本**：中 ｜ **风险**：低~中（风摆别过头）

## E. 蒙眼雾升级（特色效果，最值得打磨）

- **效果**（全在 `screen_fog.gdshader`）：
  1. 双层噪声：两档频率/流向/速度叠加 → 有机漂移（现在是均匀平移像贴纸）
  2. 边缘渐晕：四角更暗（蒙眼/头罩真实感）
  3. 太阳处：高斯 mask 改不规则羽化边缘（噪声扰动半径）+ 漏光亮环
  4. 色调分层：雾色暗蓝灰基础上加明暗斑块
  5. 呼吸感：`fog_dark` 极慢 TIME 微调
- **成本**：低（纯 shader 调参）｜ **风险**：低，参数多需多次试看

## F. 大气尘埃粒子

- **效果**：暗空漂浮细尘，被太阳漏光点亮（STG 氛围神器）
- **做法**：背景 3D 场景加 `CPUParticles3D`（或 GPU）：大盒子发射域、极小圆点、additive、慢速漂移+微旋；粒子集中太阳方向更亮；数量 200~400
- **成本**：低 ｜ **风险**：极低

## G. 全局调色

- **效果**：暗部压黑带冷蓝、亮部（太阳）提暖、降饱和提对比 → 统一"伪日食蒙眼"压抑感
- **做法**：背景 SubViewport 最上层全屏 ColorRect + canvas_item 调色 shader（lift/gamma/gain）；**建议与 E 合并成一个全屏 pass**（雾+调色+vignette 一个 shader）
- **成本**：低（技术），需调色审美 ｜ **风险**：低~中（调过头画面脏）

## H. 漏光光柱（真 3D，三档）

- **效果**：日食边缘漏光在暗空气里形成可见光柱/光束
- **H1 光锥 mesh（推荐先试）**：太阳→地面光路挂 3~5 个 additive 半透明锥/梯形 mesh（真 3D），不同角度透明度，缓慢旋转 → 相机移动有正确视差
- **H2 Godot 真体积雾**：4.7.1 支持 `FogVolume` + `Environment.volumetric_fog_enabled` + 低能量 DirectionalLight（现在 `setup_sun` 是 0 能量无光照）→ 真实散射。768×896 低分辨率 SubViewport 里跑，**需实测帧率**
- **H3 屏幕空间 raymarch（不推荐）**：全屏向太阳方向步进采样。除非 H2 性能翻车才考虑
- **成本**：低（H1）/ 中高（H2）/ 高（H3）｜ **风险**：H2 需确认性能

## I. 远山剪影（东方风道中经典元素）

- **效果**：地平线 1~2 层深蓝灰远山剪影，随相机平移产生视差
- **做法**：3D 放几个大暗色山形 mesh（或噪声边缘 billboard 剪影），挂太阳下方地平线，随相机 z 滚动（复用 `BackgroundPlane` 思路）
- **成本**：低 ｜ **风险**：极低

---

## 推荐分批

```
第一批（shader 快赢）：E+G 合并氛围 pass  +  C 地面距离雾 ✅
第二批（3D 氛围）：F 尘埃粒子 + I 远山剪影 + H1 光锥
第三批（打磨）：B 日冕 + D 树风摆/色调 + A 云
彩蛋（试性能）：H2 真体积雾
```

## 验证流程 + 测量基线

- ✅ 截图/测量工具 **已按现架构重建（2026-10-02）**：`tools/background_capture.tscn`（原版随 `54d7758` 删除；重建版按 `StageRuntime` + `StageContext` 接线，与 `load_stage` 启动背景协程的方式一致）。
  用法：`godot --path . res://tools/background_capture.tscn --fixed-fps 60 -- --out res://.godot/probe/bg_shots --shots 180,540`
  （`--fixed-fps 60` 把模拟时间与真实时间解耦 ⇒ 同帧号 = 同画面；`--seed` 默认取 `BenchCommon.FIXED_SEED`，
  因为树是 `DecorManager.batch_spawn` **随机**撒的，**不固定种子两次跑的画面不可比**）。
  它同时打印官方测量接口的每帧数字（`RenderingServer.viewport_get_measured_render_time_cpu/gpu`）。
- **测量基线（2026-10-02 · 软件 Vulkan/llvmpipe，绝对数不代表真实 GPU；比值与"谁是瓶颈"可看）**：

  | 档 | 背景视口 | 背景视口 GPU | 真实 ms/帧 | FPS |
  |---|---|---|---|---|
  | 现状 `--shrink 1` | 800×928 | **11.8 ~ 14.5 ms** | 17.8 ~ 18.2 | 55 ~ 56 |
  | `--shrink 2` | 400×464 | **7.3 ~ 7.6 ms** | 12.9 ~ 14.4 | 70 ~ 77 |

  ⇒ 背景视口是**主开销**（主视口只 0.4 ~ 1.7 ms）；`stretch_shrink = 2` 一档就把它的 GPU 时间砍掉 ≈40%。
- 📏 **空视口的代价（推翻"无背景也在白跑"的直觉）**：**空的** 800×928 `UPDATE_ALWAYS` 视口实测只花
  **GPU 0.28 ms / CPU 0.04 ms**（`disable_3d` 再省 0.05 ms，`UPDATE_DISABLED` 基本无差别）——
  没有 3D 对象就只剩一次 clear + 一次全屏合成 ⇒ **「无背景的关卡关掉视口」不值得做**（≈0.3 ms）。
- 📏 **`stretch_shrink` 机制实测**（`stretch = true` 时**容器驱动** `SubViewport.size`）：
  `shrink=1` → 800×928；`2` → 400×464；`3` → **266×309**（整数**截断**）；`stretch = false` 时**不生效**；
  且 `stretch = true` 时**手改 `SubViewport.size` 会被容器立刻覆盖**（官方那句"别再手改"的实证）。
  容器矩形不变 ⇒ 暂停模糊（`_add_blur` 用 container.position/size）与震屏（`bind_layer` 只做位移）都不受影响。
- ✅ **蒙眼雾 = 故事设定（作者 2026-10-02 拍板，保留）**：实拍 3s（`bg_f0180`）/ 9s（`bg_f0540`）两档，
  画面**几乎全是蒙眼雾**（草地在画面底部才隐约可见）；`stage01_decor.gd` 只 tween **环境雾**（0.3 → 0.02），
  `ScreenFogFX.fog_dark` 保持 **0.8** —— 这是**有意**的，**别去动 `fog_dark`**。
- 📏 **由此得到的成本结论**（同种子同帧号，把 `--shrink 2` 的图放大到同尺寸**逐像素**比）：
  降分辨率**几乎无损** —— 平均亮度差 **0.43%（3s）/ 0.69%（9s）**、最大差 0.027 / 0.050，
  而背景视口 GPU 时间省 **≈40%**。⇒ 3D 只是"雾后面的底色"，**分辨率该省**（见 `TODO_TEMP` 的 BG5）。
- 改前/改后截图在 `~/Desktop/bg_before/`、`~/Desktop/bg_after/`，对比图 `~/Desktop/compare_t3s.png` / `compare_t9s.png`
- 注意 6s 相机上移后、10s 加速后的画面都要看（动态效果看视频/实机）

---

## 已完成

### 画面优化（第一批 + 地平线/树墙修复，2026-08-10）

- ✅ **E+G**：`screen_fog.gdshader` 合并为全屏不透明氛围 pass —— 调色 + 双层噪声蒙眼雾 + 太阳不规则羽化浓雾 + 渐晕 + 日食漏光亮环 + 呼吸感
- ✅ **C**：`background_plane.gdshader` 距离雾 + 平铺扰动；后续修：`fog_disabled` 摆脱环境黑雾、距离改为 vertex 插值（**fragment 的 VIEW 内置在本项目环境返回 0**，需传 cam_pos uniform）、远缘带渐变到天球色（0.29,0.32,0.35）→ 水平线无缝
- ✅ **D3**：`decor_fade.gdshader` 新 shader —— 树按距离融进雾色/天球色，远处树海不再是硬剪影墙；SCISSOR 层改用此 shader，cam_pos 每帧同步
- ✅ 地面平面加深 256→340 盖住树带、tiling.y 6→8 保持密度
- ✅ 新增 `tools/background_capture`：背景截图工具（视口线性→sRGB 修正后存 PNG）——**后随 3D 背景重构删除（`54d7758`），见「验证流程」的说明**

### 性能优化（2026-08-10）

- ✅ `decor_manager.gd`：逐实例更新 → 节点整体平移（O(n)→O(1)）；砍每帧排序/数组分配；死亡槽位复用池；分块扩容
- ✅ 修复：`Transform3D.scaled()` 连 origin 一起缩放的 bug
- ✅ 新增 `test/test_decor_manager.gd`（6 个回归测试）

### 工具链（2026-10-02）

- ✅ 按现架构**重建** `tools/background_capture`（原版随 `54d7758` 删除；旧版引用的 `StageManager` 已不存在，重建版改走 `StageRuntime` + `StageContext`）：同种子**可对比截图** + 官方接口**渲染耗时测量**；首份测量基线见「验证流程 + 测量基线」。
- ✅ 同一次测量拍到的「画面几乎全是蒙眼雾」经作者确认为**故事设定**（保留，不动 `fog_dark`）；由此测得「降分辨率几乎无损」（平均差 0.43~0.69%、省 ≈40% GPU）—— 见「验证流程 + 测量基线」。

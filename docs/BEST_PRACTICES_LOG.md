# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件是**滚动日志**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> - **反复踩的坑 / 铁律** → 蒸馏进 `BEST_PRACTICES_BASELINE.md`（改动前必读）。
> - **正文只留最近 2 天**（且不少于 12 条）→ 更早的按**月**归档到 `docs/archive/LOG_<YYYY-MM>.md`
>   （**不删任何东西**；归档内文**时间正序**，越往下越新）。
> - **顶部索引**由工具生成，列**全部**条目（新→旧）：留在正文的直接往下读，归档的给文件链接。
> - 找旧事：先扫索引，或 `grep -n "关键词" docs/BEST_PRACTICES_LOG.md docs/archive/*.md`
>
> 维护：`python3 tools/log_archive.py --check`（体检格式/体积）· `--dry-run`（看会搬走什么）·
> `--index`（只重建索引）· `--archive [--days=7 --keep-min=20]`（归档 + 重建索引）。

---

## 模板（每条可复制）

### YYYY-MM-DD — 子系统名 / 改动名
- **目标**：一句话说明要改什么。
- **为什么**：为什么这样改才算符合最佳实践（对应哪篇文档哪一条）。
- **对照旧项目**：旧版 file.gd:line 哪里不好，我这次刻意没抄什么。
- **新落点**：新文件:行号。
- **验收**：./tools/verify.sh / 对应 GUT 测试结果。

---


## 索引

> 共 54 条（本文件留最近 54 条，其余在 `docs/archive/`；本段由 `tools/log_archive.py` 生成，手改会被覆盖）。

- 2026-10-19 — 把「卡摩瑞一非」迁到 ring（保留旧路径 A/B）
- 2026-10-19 — Pattern spike：BulletPattern / PatternParams / ring
- 2026-10-19 — 拆 `spell_practice_menu`：770 → 348 + Data / ListView
- 2026-10-19 — P1 前五步：R2 对话注入 / BGA9 / 内容 lint / 死代码分诊 / 白盒接缝
- 2026-10-19 — P0 整洁包：C++ 弃用警告 / 行尾空格 / 死常量
- 2026-10-19 — 存档可靠性：版本号 / 原子写 / .bak 回退 / 读档校验
- 2026-10-19 — 原生库构建指纹：`get_build_id()` + verify 重算源码哈希
- 2026-10-19 — BGT5 + BGA12：工作台背景视口停渲染 + 相机初值唯一来源
- 2026-10-18 — D6 修正：canvas_transform + bench UI CanvasLayer
- 2026-10-18 — D6：1600 布局 + 384 常驻左栏
- 2026-10-18 — D3 第五批：PreviewPlayback / PreviewBookmarks
- 2026-10-18 — D3 第四批：PreviewStageLoader
- 2026-10-18 — NK5/10：删 overlap_pairs + 跨语言常量门禁
- 2026-10-18 — NK7：逐弹 type_index 访问器
- 2026-10-18 — NK8：dt clamp + cull 边界统一
- 2026-10-18 — NK4/9：program 入参 fail-closed + 原生 API 对齐
- 2026-10-18 — NK1/2/3：逐弹 id 守卫 + dead 去重
- 2026-10-18 — DSL1/7：DirSpec eval_phase + emit_speed_rel
- 2026-10-18 — DSL10/12：纯编译器 + 宿主表分离 + DirSpec
- 2026-10-18 — DSL2 契约测试 + DSL9 缓存形状守卫
- 2026-10-18 — 页签字号 16→20（16px 宋体密笔画糊成别的字）
- 2026-10-18 — Ghost 活动范围/初始点与真自机对齐
- 2026-10-18 — Workbench 与游戏场地同坐标（顶栏 36→32）
- 2026-10-18 — 创作台页签对齐 + 快捷键
- 2026-10-18 — 预览暂停：BulletManager 显式 PAUSABLE
- 2026-10-18 — 命中框错位：叠加 BulletManager 全局偏移
- 2026-10-18 — D3 第三批：CreationStation 节点化 + WorkspaceStore
- 2026-10-18 — D3 第二批：PreviewUI 拆出，Workbench 523
- 2026-10-18 — D3 第一批：Workbench 拆出 6 个预览服务
- 2026-10-18 — 预览协程卡死：常驻视图不再 remove/re-add
- 2026-10-18 — 预览冻结修复：雾 shader 本地时间 + 递归 CanvasLayer
- 2026-10-18 — 创作台 Phase 2：整关预览保活 / 配置 v2 / 页面协议
- 2026-10-17 — 直射页 UI 紧凑化（对齐拼装页初始弹）
- 2026-10-17 — 弹幕台直射页清理：去掉空行为脚本/参数/热更新
- 2026-10-17 — F10 拼装页补“初始弹”编辑
- 2026-10-17 — F10 模板选择器：emit / emit_variant 的 A/B 替换弹
- 2026-10-17 — F10c：删掉 9 个 bullet preset，内容改手写原语
- 2026-10-17 — F10b：弹幕台拼装页 + 描述符目录组 + 代码生成
- 2026-10-17 — 创作台 Phase 1：全局目录抽屉 + 公开接缝
- 2026-10-17 — F10a：拼装器模型 + 现有内容 golden
- 2026-10-17 — verify 提速：GUT 并行分片（~60s → 18.8s）
- 2026-10-17 — DSL 静默坑：编译期 fail-closed + 四处响亮
- 2026-10-10 — 音量管理补骨架：**真总线 + SE 密度护栏 + BGM 让位/交叉淡入**
- 2026-10-10 — 补齐 10 个缺失弹型：**重建版的弹型资源在 git 里没丢**
- 2026-10-04 — 清场要看得见：敌人**击破特效** + 弹幕**消弹特效**
- 2026-10-04 — 补「即时清弹」内容动词：`ctx.bullets.clear_enemy_bullets()`
- 2026-10-04 — 敌人回收**动词化**：`ctx.enemies.despawn` / `despawn_all`
- 2026-10-04 — Miss 的雷：从「+2 补偿」改为「−2、下限 3」
- 2026-10-04 — 关卡练习：第 2 面起**满火力**起步
- 2026-10-04 — 修「关卡练习菜单的黑幕没有了」（我的回归）+ 扫同款
- 2026-10-04 — 相机动词改名 + 目标记忆（作者实测「摄像机的 y 角度最后没回到 0」）
- 2026-10-04 — 相机初始姿态改由**背景自己声明**（`override_camera_home`）
- 2026-10-04 — 修「一改太阳 y，黑雾的太阳对准就不准」（投影的是节点，画的是 sprite）
- 2026-10-04 — 废止「记得调用才显示」：背景演出层改**宿主自动接线**（练习模式也开黑雾）

## 记录

### 2026-10-19 — 把「卡摩瑞一非」迁到 ring（保留旧路径 A/B）

- **迁移点**：`卡摩瑞一非` 的 `开花()` 原本 `shoot_spread(开花弹, 个数, TAU, 随机角度, ...)`；现在走 `RingPattern.fire()`。
- **模板路径**：`PatternParams.template`（运行时注入，不进 `.tres`）——旧 `BulletData` 自带 `lifecycle`（`accel_heading` / 撞墙 emit 反弹 / despawn），ring 只 `duplicate()` 后改本次 `speed/count`，不把 lifecycle 重写成参数。
- **A/B 开关**：脚本里 `const USE_RING := true`；`false` 走旧 `shoot_spread` 路径，方便对比手感（确认后删）。
- **为什么选这一张**：它是 stage01 第一张非符，环弹参数干净（15~30 发 / TAU / 随机基准角），迁移后方向和速度语义与 `shoot_spread` 一致。
- **验收**：`test_pattern_ring` 6/6（含 template 路径）；stage01 headless 60s 无脚本错误；全量 **859 用例 / 7911 断言**；verify 七步全绿。

### 2026-10-19 — Pattern spike：BulletPattern / PatternParams / ring

- **目标**：验证“高层 pattern 用代码、手感参数用 `.tres`、具体 pattern 不进全局类表”的路线。
- **全局类只加 2 个**：`BulletPattern`（基类，`fire()`）与 `PatternParams`（Resource：`bullet_def` / `count` / `speed` / `spread` / `interval` / `duration` / `aim` / `color` / `enemy` / `blend` / `extra`）。
- **具体 pattern 不写 `class_name`**：`data/patterns/ring.gd` 继承 `BulletPattern`，由内容 preload；`PatternParams` 的 `.tres` 预设只引用 `BulletDef`（`data/bullets/*.tres`），不复制外观。
- **Ring**：`spread_directions()` 纯函数（整圈 / 扇形 / 单发）+ `fire()` 通过 `ctx.bullets.shoot_directions()` 发射；每波建 `BulletData`，只改自己这一发的速度，不污染共享资源。
- **测试**：`test_pattern_ring` 6 例 / 39 断言 —— 类型/默认值/方向/预设加载/真实 `BulletManager` 发射 6 发/null ctx 容错。
- **未做**：continuous pattern 的 `PatternHandle`、PatternCatalog、composer 接线（先验证再扩展）。
- **验收**：`test_pattern_ring` 6/6；`verify.sh` 七步全绿。

### 2026-10-19 — 拆 `spell_practice_menu`：770 → 348 + Data / ListView

- **动机**：770 行的菜单同时做“记录 → 数据”、“三级列表渲染/滚动/高亮”、“输入/启动/返回状态”，是 P1 清单里最大的单体之一。
- **拆法**：
  - `SpellPracticeData`（231 行，RefCounted）：从 `spell_book` 生成 `stages/phases/diff_entries`，解析 Boss 配置、收取进度、`first_unlocked_index()`；不碰树、不碰 UI。
  - `SpellPracticeListView`（370 行，RefCounted）：三级列表构建、二级窗口开窗/滚动提示、高亮/脉冲/压暗、`get_highlighted_item`；只吃 Data + 选中项。
  - `spell_practice_menu.gd`（348 行）：生命周期、人物切换、层级/索引、输入、返回状态还原、开始练习；保留 `_stages/_phases/_diff_entries` 只读转发和 `_build_*` 包装，测试/Probe 调用面不变。
- **顺手**：`diff_entries` 现在由 Data 一次性生成（含 `record` / `card_name`），View 不再自己查 `BossCatalog`；`SpellPracticeMenuProbe` 只改 `set_phases/set_stages` 的落点。
- **验收**：`test_spell_practice_menu` 20/20；白盒仍 **327/327**；`verify.sh` 七步全绿；853 用例 / 7872 断言。

### 2026-10-19 — P1 前五步：R2 对话注入 / BGA9 / 内容 lint / 死代码分诊 / 白盒接缝

- **R2 对话**：`DialogueService.play_steps()` 不再 `get_tree().current_scene.add_child(box)`，改挂组合根注入的 `ctx.stage`（对话框自身是 `CanvasLayer`，层级由 `box.layer=40` 决定）。新增回归：对话框 parent == 注入的 StageRuntime。
- **BGA9**：两个背景的 `Mat_Ground` 与承载它的 `PlaneMesh` 都加 `resource_local_to_scene = true`。⚠️ 只给材质加**不够**（PlaneMesh 仍跨实例共享）；测试同时断言材质与 mesh 每实例独立，覆盖 stage01/02。
- **BGA5 + BGA7**：新增 `check_structure.sh` ⑥：`data/**/*.gd` 的非注释行不得出现 `get_parent()` / `create_tween()`；临时探针验证会报 2 条。清理 11 个内容脚本（stage01 enemy01~04、stage02 enemy01/02、3 个 boss_move、2 个 stage 脚本），机制收口为 `ctx.enemies.move_to` / `ctx.boss.move_to`/`move_path` / `ctx.stage.show_logo`。
- **死代码分诊**：删除 7 个确认无引用的私有函数（`_group_key` / `_time_to_pixel_x` / `_pulse_on_diff` / `_fade_content_in` / `_fade_all_out` / `_life_frame` / `_do_hot_reload`）；新增 `tools/report_dead_code.py`（只报告不判红），当前剩 37 个**公开**零引用声明，保留为内容/工作台 API。
- **白盒接缝**：`SpellPracticeMenu` 新增 `probe()`（返回独立的 `SpellPracticeMenuProbe`，集中读写内部状态），`test_spell_practice_menu` 的 135 处 `._` 全部改走 Probe；全仓白盒 **462 → 327**，预算同步收紧到 327。
- **验收**：`verify.sh` 七步全绿；**853 用例 / 7872 断言**；stage01 headless 50s 无脚本错误。

### 2026-10-19 — P0 整洁包：C++ 弃用警告 / 行尾空格 / 死常量

- **范围**：只做“确认无引用”的安全清理，不动公开内容 API、不拆文件。
- **C++**：3 处 `ABS` → `Math::abs`（godot-cpp 4.7 已弃用 `ABS`），debug/release 重编 **0 warnings**。
- **空白/注释**：清掉 4 处行尾空格；`layer_config.gd` 的 `SPELL_PORTRAIT` 合并重复的 `##` 注释（旧注释把“符卡背景”的说明挂到了立绘上）。
- **死常量**：删除 `FRONT_UP` / `FRONT_DOWN` / `MIN_MARGIN`（`player.gd`）、`DIFF_ITEM_SIZE`（`character_screen.gd`）；同步去掉 `game_config.gd` 注释里对 `MIN_MARGIN` 的引用。`DEFAULT_CENTER_Y` **保留**（`test_workbench_align` 用它断言默认起点）。
- **死函数只报告不删**：整仓有 46 个生产函数在声明处之外无引用，其中一部分是留给内容脚本的公开动词；先记录，不在 P0 里批量删。
- **指纹**：源码变化后原生构建指纹从 `0322b13bdb12` → `cc64cfa470a1`（verify 会自动比对）。
- **验收**：`verify.sh` 七步全绿；851 用例 / 7857 断言。

### 2026-10-19 — 存档可靠性：版本号 / 原子写 / .bak 回退 / 读档校验

- **起因**：`SaveManager` 只有 60 行，直接 `ConfigFile.save(SAVE_PATH)`；写到一半崩溃会同时毁掉设置和高分，主档损坏时下次保存又会直接覆盖。
- **改法**：
  - `meta/version = 1`；读档时对已知设置做类型/范围收敛（音量 0..1、`max_fps` 白名单），高分只留「非负整数 id + 非负整数分」。
  - 写盘改为 **tmp → 轮换 `.bak` → 提交**；任何一步失败都保留原正式档，并 `push_warning` + 返回 `false`（`get_last_save_error()` 可查）。
  - 主档损坏/空文件 → 回退 `.bak`，坏档隔离成 `.corrupt`（避免下一次保存把好备份轮换掉）；`load()` 先清空内存字典，二次 load 不再叠旧数据。
  - `save_path` 可覆盖（测试用独立 `user://` 档）；`clear_player_data()` 在全新档上不再凭空创建文件。
- **踩坑**：`ConfigFile.load("not a config file")` 返回 **OK**（只是没有任何段）⇒ 不能只看返回值，必须检查 `meta/settings/high_scores` 至少存在一段，否则会把空档当成好档、绕过 `.bak`。
- **回归**：`test_clear_data` 从 3 例扩到 9 例 —— 往返/版本、原子写+备份、坏主档回退、二次 load 清旧状态、非法值收敛、写失败返回 false。
- **验收**：全量 **851 用例 / 7857 断言**；`verify.sh` 七步全绿。

### 2026-10-19 — 原生库构建指纹：`get_build_id()` + verify 重算源码哈希

- **问题**：NK9 只比对 `D_METHOD` 名字；C++ 实现改了、方法名没变，旧 `.so` 仍然全绿 —— "库 = 源码"是巧合，不是保证。
- **改法**：
  - `gdextension/SConstruct` 构建时对 `src/*.{h,cpp}`（排除生成的 `build_stamp.h`）按「文件名升序 + 文件名 + NUL + 内容 + NUL」算 SHA-256，写入 `build_stamp.h`；该文件 gitignore。
  - C++ 新增 `get_build_id()`（`D_METHOD` 自动进入 NK9 的 API 对齐）。
  - `tools/check_native_api.gd` 用同一算法重算源码指纹，与运行时值比对；`verify.sh` 打印匹配结果，源码改了没重编 → 直接红。
- **反向验证**：临时往 `danmaku_store.h` 追加一行注释，检查立刻报 `binary=0322b13bdb12 source=95fc9a677de4`；恢复后重新匹配。
- **验收**：debug + release 重编；原生 API **60 methods**；指纹先为 `0322b13bdb12`，P0 清理后更新为 `cc64cfa470a1`。

### 2026-10-19 — BGT5 + BGA12：工作台背景视口停渲染 + 相机初值唯一来源

- **BGT5**：`SubViewport.render_target_update_mode` 与 `process_mode` 无关 —— 暂停/切走/无背景时 3D 管线仍会跑。`Workbench._sync_bg_viewport()` 在 `_apply_playback_runtime` / `_load_stage` / `suspend_preview` / `resume_preview` 收口：暂停（逐帧推进那一瞬除外）、切走、无背景 → `UPDATE_DISABLED`，恢复 → `UPDATE_ALWAYS`。回归 `test_workbench_bg_viewport_stops_when_suspended`（21 例背景套件）。
- **BGA12**：新增 `BackgroundCameraHome`（POSITION / ROTATION_DEGREES / FOV）作为唯一来源；`StageBackground` 的 `camera_home_*` 默认值、`_own_camera()`、`tools/background_capture.gd` 全部引用它；两个宿主场景的冗余 `Camera3D` 节点删除（背景入树时自建，未开 `override_camera_home` 的默认姿态不变）。
- **顺带**：CI Godot 4.7.1 → 4.7.2（与本地一致）；`TEST_INDEX` 开头「118 个测试文件」→ 119；基线 R2 残余只剩 `dialogue_service.gd:20`（`item_service` / `player` 已不再摸 `current_scene`）。
- **验收**：全量 **851 用例 / 7857 断言**；`verify.sh` 七步全绿。

### 2026-10-18 — D6 修正：canvas_transform + bench UI CanvasLayer

- 根因：bench 的场地/BulletManager 是 `top_level`，只把 Content 右移不会带动它们；左栏因此盖住场地、右面板却跟着 Content 走了。
- 修法：创作台改用 **viewport `canvas_transform.origin.x`** 整体平移游戏画布（top_level 也生效）；UI 用 CanvasLayer 不跟着走。
- 三个 bench 的右面板统一挂到 `BenchBase.add_panel_to_layer()` 的 CanvasLayer(1)，嵌入时 top+36/bottom−36 让出顶栏；hitbox/Stage logo 设 `follow_viewport_enabled=true`。
- 离开创作台重置 canvas_transform / content_scale；1600 实拍场地 384..1152、右面板 1160..1592，1280 自动收起为 0..832 / 840..1272。
- Timeline / phase 倒计时属于 CanvasLayer，不吃 canvas_transform ⇒ 单独 `set_view_offset_x` 跟场地左移；右面板保持右锚定。
- 1600 目录常驻且隐藏关闭按钮：关闭只会留空白，画布仍需 320 偏移；1280 才显示「目录」按钮作为覆盖抽屉。
- 目录从屏幕 x=0 起，已不在场地黑底上；抽屉改用不透明深色侧栏底（0.025），不再让 32% 半透明黑盖默认灰底发灰。
- 全量 832 / 7746，verify 七步全绿。

### 2026-10-18 — D6：1600 布局 + 384 常驻左栏

- 创作台默认 1600×960：左侧目录 384 常驻（贴住场地金框），内容 1280（场地 832 + 右面板 440）；1280 自动收起为覆盖抽屉。
- `content_scale_size` 同步 1600/1280；离开创作台恢复 1280（游戏/工作台 standalone 不受影响）。
- 三台 bench 与 Workbench 在嵌入时不再把窗口改回 1280（BenchBase `_embedded` / Workbench `_embedded`）。
- 窗口宽度用 `_process` 轮询兜底（`size_changed` 在 viewport stretch 下可能不触发）。
- 左栏复用 CatalogDrawer/CanvasLayer(3)，宽 320；内容右移，页签横栏保持全宽避免遮挡测试点击。
- 实拍 `creation_1600.png` / `creation_1280.png`；全量 832 / 7742，verify 七步全绿。

### 2026-10-18 — D3 第五批：PreviewPlayback / PreviewBookmarks

- `preview_playback.gd`（75）：Playback → 引擎/音频/播放条投影、快进轮询、逐帧、跳转。
- `preview_bookmarks.gd`（44）：书签 open / 保存 / 时间轴刷新 / 来源文案。
- Workbench 483 → 439；`_process` 只调两个服务，`_current_time`/`_jump_to`/`_apply_playback_runtime` 变薄委托。
- 至此 D3 共 10 个预览服务；Workbench 只剩装配、选项回调、公开接缝。
- 全量 832 / 7742，verify 七步全绿。

### 2026-10-18 — D3 第四批：PreviewStageLoader

- `preview_stage_loader.gd`（96）接管：停旧关 → 清 World → 旧背景离树/释放 → RNG/自机复位 → 新背景实例化 → `StageRuntime.load_stage` → 时间轴/书签刷新。
- 背景实例由 loader 持有，Workbench 通过 `background()` 读取；不再在各处维护 `_background`。
- Workbench 523 → 483；`_restart`/选项回调只剩“调 loader + 日志”。
- 全量 832 / 7742，verify 七步全绿。

### 2026-10-18 — NK5/10：删 overlap_pairs + 跨语言常量门禁

- NK5：删除生产零调用的原生 `overlap_pairs`、绑定、测试文件与 TEST_INDEX 行；主路径保持 `query_circle + hit_test`，不再有“文档说主路径用它”的歧义。
- NK10：`fill_multimesh` 确认仍被 `tools/bench_native.gd` 使用（不是死 API），保留并在头文件标注 benchmark-only；`check_structure.sh` 新增 ⑤ 跨语言常量门禁，`OPS_ARGS/ARGS` 与 `SLOT_STRIDE/MAX_SLOTS` 不一致会红。
- 原生 API 对齐数 60→59；全量 844 / 7820，verify 七步全绿。

### 2026-10-18 — NK7：逐弹 type_index 访问器

- 原生新增 `get_type_index(id)`（越界 -1，走 NK1 guard）；`KernelNativeSystem.get_type_index` 单行读取。
- `KernelBulletHost._sync_host_tables` 不再每次 spawn 拉整张 `_type_index` 只为读一个元素，per-spawn O(N) 拷贝改为 O(1)。
- 原生 API 对齐数 59→60；全量 847 / 7844，verify 七步全绿。

### 2026-10-18 — NK8：dt clamp + cull 边界统一

- 原生 `MAX_DT = 0.4s`：`integrate` / `behavior_tick` / `behavior_batch` / `integrate_batch` 统一 clamp 到 `[0, 0.4]`；1s 级断点不再一步穿透/漏剔除。
- `integrate_batch` 的 cull 右/下边界改为 `>=`，与 `integrate` 的 `Rect2.has_point`（右/下开区间）一致。
- 测试：1s 大 dt 只积分 0.4s、负 dt 不倒放、batch 右边界 x==x1 判死/内侧存活；全量 847 / 7840，verify 七步全绿。

### 2026-10-18 — NK4/9：program 入参 fail-closed + 原生 API 对齐

- NK4：`register_program` 在写任何表前校验 phase_count / 五个并行数组长度 / ops*OPS_ARGS 参数长度 / move/until/action opcode 白名单 / rotate、position、state 的 slot 操作数；失败返回 -1，不产生半个 program。
- NK9：新增 `tools/check_native_api.gd`；verify 的启动步骤在有原生二进制时校验 ClassDB 方法名与 C++ `_bind_methods` 的 `D_METHOD` 对齐（当前 59 个），无二进制明确 SKIP。
- 测试：`test_native_guards` 增加到 3 用例（坏 phase_count / 短 args / 未知 opcode / 越界 slot + 拒绝后合法注册仍成功）。
- 全量 845 / 7836，verify 七步全绿（含原生 API 59 methods）。

### 2026-10-18 — NK1/2/3：逐弹 id 守卫 + dead 去重

- NK1：原生 `DanmakuStore` 增加 `_valid(id)`；约 20 个逐弹 getter/setter（life/fx/timer/velocity/position/forward/type/faction/color/hitbox/hit_test/grazed/program）越界时返回安全默认或 no-op，release 下不再有 vector[] UB。
- NK2：`BulletManager.bullet_global_position()` 补 `id >= active_count` 上界并修掉“已回收返回 ZERO”的假注释。
- NK3：`_run_behavior_pass()` 末尾对 `_tick_dead` sort+unique；重复 despawn 不再二次 swap-remove 误删无辜弹，`behavior_batch` 的 dead 输出也去重。
- 新增 `test_native_guards`（2 用例/43 断言）；全量 844 / 7830，verify 七步全绿。

### 2026-10-18 — DSL1/7：DirSpec eval_phase + emit_speed_rel

- DSL1：`DirSpec` 从字典工厂升级为带 `eval_phase`（WORLD/TARGET/EMITTER/WALL）的类型；`heading()` 是世界角，`world_heading()` 是 emit/on_end_heading 的显式世界角；builder 对裸 heading 报错，防止“以为会跟随发射者”。
- 编译/参考解释器/工作台统一 normalize DirSpec；旧 Dictionary 仍兼容（工作台生成 `world_heading` 代码）。
- DSL7：`emit_speed_rel(spawn, dir, speed, spread)` 把逐发 ±spread 倍率放进宿主表；纯 program 只保留 base speed，KernelNativeSystem / 参考解释器在事件落地时求值。
- 测试：eval_phase、世界角守卫（emit / on_end_heading）、speed spec 边界；全量 842 / 7787，verify 七步全绿。

### 2026-10-18 — DSL10/12：纯编译器 + 宿主表分离 + DirSpec

- `bullet_lifecycle.gd` 733→453 行；编译/opcode/args 拆到 `LifecycleCompiler`（314 行），方向词汇/构造器拆到 `DirSpec`（61 行），spawn/Callable/sfx 拆到 `LifecycleHostTable`（47 行）。
- `compile_program()` 只产出 ops/args/phase 索引，不含宿主对象；`host_table()` 只产出 action/sfx；`compile()` 保留合并兼容入口。
- action local id 在编译器里按 EMIT/EMIT_VARIANT/CALL 共用 actions、SFX 独立 sfx 的纯结构分配；宿主表按同序遍历，天然对齐。
- `KernelNativeSystem._program_data` 只存纯 program；新增 `_program_host_tables` 同下标；事件路由查宿主表。content_signature = 纯 program 结构 + 宿主身份，保留模板身份隔离。
- 全量 840 / 7776，verify 七步全绿。

### 2026-10-18 — DSL2 契约测试 + DSL9 缓存形状守卫

- DSL2：新增原生契约测试——`on_end_heading` 必须先于后续 `emit(forward(...))` 执行，整圈发射共享新朝向；用固定 1.0 rad 断言绝对方向，random_dir 走同一 heading 路径。
- DSL9：`LifecycleCatalog.cache_key()` 在签名上混入 phase_count/slots；`get_lifecycle()` 命中后校验形状，不一致则重建。
- `KernelNativeSystem` 的 program 缓存改为同款复合键；命中时 `_program_matches()` 校验 pid 对应 program 的 phase/slots，不一致丢弃重登记，不再静默复用错误 pid。
- 测试：缓存键区分 phase、模拟脏缓存不回错、污染 program 不命旧 pid；全量 838 / 7767，verify 七步全绿。

### 2026-10-18 — 页签字号 16→20（16px 宋体密笔画糊成别的字）

- 现象：顶栏「整关预览 / 弹幕台」在 16px 思源宋体下，整/幕/预的笔画挤成一团，看起来像「幕关预览 / 弹合台」。
- 修法：页签字号 16→20；给页签单独压掉上下 content margin（0），让 20px 仍正好落在 32px 顶栏内；全局 Button 样式不动。
- 现在 Bar/Tab 高度正好 32，Workbench 场地仍 32..928；全量 834 / 7758，verify 七步全绿。

### 2026-10-18 — Ghost 活动范围/初始点与真自机对齐

- 真自机 clamp：`x 88..808 / y 64..896`，初始 `(448, 840)`；之前 ghost auto 路径中心 620、鼠标范围 44..868，初始 620。
- 把自机边界/初始点收进 `GameConfig`（`PLAYER_MIN/MAX_X/Y`、`PLAYER_START`），Player clamp 与 ghost 共用。
- GhostPlayer：默认中心 840、y 振幅 40；鼠标/auto 都 clamp 到同一范围；BenchBase 起点改 840；画框参考线改 840。
- 测试钉住 `GhostPlayer.player_bounds() == Rect2(88,64,720,832)` 与默认 y=840。
- 全量 834 / 7758，verify 七步全绿。

### 2026-10-18 — Workbench 与游戏场地同坐标（顶栏 36→32）

- 之前 Workbench 嵌入后场地 y=36..932（+4），因为顶栏 36、stage_shift 只上移 FIELD_TOP=32；整体上移 4 会裁掉顶边。
- 把创作台顶栏 36→32（Root margin / HeaderBg / HeaderLine / 页签 / CatalogHeader / CatalogDrawer / bench 面板让位），内容区从 y=32 开始。
- 现在 Workbench World/画框/场地都是 **x 64..832 / y 32..928**，与真游戏完全一致；高度 896 完整可见。
- 全量 833 / 7755，verify 七步全绿。

### 2026-10-18 — 创作台页签对齐 + 快捷键

- 1600 下页签从内容区 384 开始，不再悬在目录上；左侧顶部显示「内容目录」；1280 恢复全宽页签。
- `1–4` 直达四台，`Ctrl+Tab` 循环（Shift 反向），`Alt+←` 返回上一个台；历史栈 20，输入框聚焦时不抢数字键。
- `handle_shortcut()` 作为用户键盘与测试共用的公开接缝；测试钉住直达/循环/返回。
- 页签真实点击测试改到 1280 全宽下跑，避免 GUT 输出面板截走右侧点击。
- 全量 833 / 7755，verify 七步全绿。

### 2026-10-18 — 预览暂停：BulletManager 显式 PAUSABLE

- 根因：Workbench 根是 PROCESS_MODE_ALWAYS；BulletManager 作为子节点 INHERIT 后也 ALWAYS，`tree.paused` 时敌人（World PAUSABLE）停了、弹幕还在跑。
- 修法：PreviewStageWorld 建出 BulletManager 后显式 `process_mode = PAUSABLE`；内核积分/碰撞都挂在它的 `_physics_process`，因此一起冻结。
- 测试：断言预览 BulletManager 必须是 PAUSABLE；全量 832 / 7747，verify 七步全绿。

### 2026-10-18 — 命中框错位：叠加 BulletManager 全局偏移

- 根因：`HitboxOverlay` 直接画内核局部坐标 `positions[i]`，而子弹贴图吃 `BulletManager` 的 Node2D 变换；嵌进创作台后 manager 有页面 y 偏移，命中框整体偏上。
- 修法：`bullet_center_for()` 统一走 `BulletManager.to_global(local_pos)` 再叠加 `hitbox_offset`；测试钉住 y+36 时中心必须 +36。
- 顺手修节点化暴露的问题：`CatalogPanel.show_descriptors` 加 `@export`，并提供 `set_show_descriptors()` 在运行中重建描述符组（原先场景属性不生效）。
- 全量 832 / 7742，verify 七步全绿。

### 2026-10-18 — D3 第三批：CreationStation 节点化 + WorkspaceStore

- `creation_station.tscn` 现在声明：顶栏底板/金线、4 个页签按钮、目录按钮、CatalogLayer(3)/Root/Drawer/CatalogPanel；脚本只接信号、套主题、修正 CatalogPanel 宽度。
- 配置/迁移抽成无树 `workspace_store.gd`（84）：v1→v2、坏数据降级、slot 钳制、未实例化台数据保留；CreationStation 只委托。
- `creation_station.gd` 390 → 274；动态页面（Workbench/三台）仍按页签创建，不做节点化。
- 全量 832 / 7741，verify 七步全绿。

### 2026-10-18 — D3 第二批：PreviewUI 拆出，Workbench 523

- `PreviewUI`（191）接过关卡/难度选择、播放条、状态条、书签面板、事件日志、目录、页签及信号接线。
- Workbench 598 → 523；UI 装配不再和关卡/播放/书签状态混在一个方法里。
- 剩余：`_load_stage` / `_restart` / 播放/书签接线仍在 Workbench（下一批再拆 StageLoader）。
- 命名契约修正：`PreviewUI._stage_data`；全量 832 / 7741，verify 七步全绿。

### 2026-10-18 — D3 第一批：Workbench 拆出 6 个预览服务

- `workbench.gd` 786 → 598（低于基线旧值 611），一行行为没改，只搬职责。
- 新服务：
  - `preview_suspender.gd`（111）：process 子树 / CanvasLayer / BGM / 全局 paused+time_scale
  - `preview_layout.gd`（71）：嵌入创作台的 World/右栏/背景/计时器坐标归一
  - `preview_input.gd`（74）：快捷键 → 意图翻译
  - `preview_stage_world.gd`（54）：BulletManager / Player / HitboxOverlay 构造
  - `preview_phase_timer.gd`（40）：Boss 符卡倒计时
  - `preview_debug_tools.gd`（56）：Ctrl+G 强制击破 / phase uid 冲突扫描
- 剩余在 Workbench：UI 装配、关卡加载/重跑、播放/书签接线、公开接缝；继续拆时按这个边界走。
- 全量 832 / 7741，verify 七步全绿。

### 2026-10-18 — 预览协程卡死：常驻视图不再 remove/re-add

- 根因：`CreationStation._on_slot()` 每次切页都把常驻 Workbench `remove_child` 再 `add_child`；`remove_child` 触发整棵子树 `_exit_tree`，`CoroutineRunner._exit_tree()` 直接 `stop()`，背景/敌人/关卡协程全被停掉，重新入树不会自动重启。
- 修法：已挂在 `$Root/Content` 下的常驻视图不再脱离场景树，只切 `visible` / `process_mode`；只有首次或异常父节点才重新挂。
- 回归：等 stage01 第一波敌人后反复切页，验关卡 / 背景 / 敌人三个 CoroutineRunner 的 `is_running` 与 `game_time` 都继续推进；另保留递归 CanvasLayer、雾本地时间修复。
- **补充（同一根因的第二层）**：`$World`/背景显式 `process_mode=PAUSABLE`，根节点 `DISABLED` 压不住 ⇒ 冻结时必须递归快照/禁用整棵 Workbench 子树，恢复时逐个还原。测试切走后真等 0.3s，关卡/敌人/背景三个时钟都不前进。
- 全量 832 / 7741，verify 七步全绿。

### 2026-10-18 — 预览冻结修复：雾 shader 本地时间 + 递归 CanvasLayer

- **背景雾**：`screen_fog.gdshader` 原来用全局 `TIME`，节点冻结时 shader 时间照走，恢复会跳；改成 `time` uniform，由 `ScreenFogFX._process(delta)` 推进。
- **stage logo**：内容脚本把 logo 放在自己 `add_child()` 的 `CanvasLayer(layer=32)` 里；`CanvasLayer` 不随父 Control `visible` 隐藏 → 旧实现只隐藏 Workbench 直接子层，logo 会叠到别的台。改为递归收集/恢复整棵 Workbench 下的 CanvasLayer。
- **Tween**：实测 `TWEEN_PAUSE_BOUND` 会跟随绑定节点的 `process_mode`；Workbench disabled 后背景相机/滚动/logo tween 已经暂停。不要显式暂停全局 Tween —— 会误伤 AudioManager 的 duck tween（串行测试 -6dB 卡住），已撤。
- 测试：递归 CanvasLayer 隐藏/恢复；全量 832 / 7724，verify 七步全绿。

### 2026-10-18 — 创作台 Phase 2：整关预览保活 / 配置 v2 / 页面协议

- **整关预览保活**：切走 `suspend_preview()`（冻结 process + 暂停 BGM + 解全局 paused/time_scale），切回 `resume_preview()`（恢复 process + BGM + Playback 投影）；不再 `queue_free`，时间/关卡/书签保留。
- **配置 v2**：`ws.version=2`；v1 旧文件照读并写回 v2；`benchN.data` 非 Dictionary 降级为空；槽位越界钳制。
- **页面协议**：`CreationStation` 不再用 `has_method/call`；三台统一 `pause_view/resume_view/clear_runtime`，整关统一 `suspend_preview/resume_preview/preview_suspended/current_time`。
- **试验台保留**：仅首次从配置恢复；切走时把最新快照写回内存，切回不被旧快照覆盖。
- 测试：预览冻结/时间不归零、v1 迁移、坏数据降级；全量 832 / 7724，verify 七步全绿。

### 2026-10-17 — 直射页 UI 紧凑化（对齐拼装页初始弹）

- 直射页外观从 4 组“标签 + 全宽控件”收成一行：贴图 / 色块 / 加色 / 速度。
- 难度改成一行；初始弹区标题与拼装页统一为“初始弹（发射的这颗）”。
- 方向保留一行 + 角度提示；操作四键（发射/连发/清场/换种子）从 2×2 收成一行，并提升为直射/拼装共用的顶部操作栏；间隔/统计同样共用。
- 无行为脚本时旧的空区块仍隐藏；直射页现在和拼装页的初始弹编辑同风格。
- 全量 830 / 7699；verify 七步全绿。

### 2026-10-17 — 弹幕台直射页清理：去掉空行为脚本/参数/热更新

- 直射页只保留：模式 / 难度 / 初始弹（外形）/ 方向 / 操作 / 统计。
- b 线后 `bullet` 角色为空 ⇒ 旧“行为脚本 / 参数 / 热更新”区块默认隐藏；旧逻辑仍保留给兼容夹具/测试。
- “外形”正名为“初始弹（外形）”；顶部提示“弹道形状在拼装页编辑”。
- 直射 ↔ 拼装切换时先同步 shell 外观再刷新初始弹面板；不再弹“热更新：开”的死提示。
- 全量 830 / 7699；verify 七步全绿。

### 2026-10-17 — F10 拼装页补“初始弹”编辑

- 拼装页顶部新增“初始弹（发射的这颗）”：贴图 / 染色 / 加色 / 速度 / 方向（8 方位 + 自选）。
- 初始弹编辑写回 bench 的 `BulletShell`，并同步直射页控件；切回直射不会被旧值覆盖。
- 与 A/B 替换弹模板区分：初始弹是发射的这颗，A/B 是 `emit` / `emit_variant` 的替换弹。
- 测试：`set_base_spec` 回写 bench；全量 830 / 7699。

### 2026-10-17 — F10 模板选择器：emit / emit_variant 的 A/B 替换弹

- 拼装页加 A/B 两个模板槽：贴图（当前贴图 / BulletCatalog key）、染色、加色、速度。
- `emit` 选“当前 / A / B”；`emit_variant` 分别选 A/B；预览真的用两个不同 BulletData。
- 代码生成按槽位输出 `_spawn` / `_spawn_a` / `_spawn_b` 占位；快照把模板存成贴图/色/加色/速度，不塞实例。
- `ComposerPanel.preview_lifecycle` 不再把所有 spawn 覆盖成当前弹；模板编辑会同步引用该槽的 action。
- 测试：codegen A/B、emit_variant 默认 A/B、快照恢复；全量 830 / 7698。

### 2026-10-17 — F10c：删掉 9 个 bullet preset，内容改手写原语

- **7 处生产调用迁移**：enemy01/02/03 的 world_accel、enemy04 的 radial_accel、reimu 的 homing、marisa 的 world_accel + marisa_laser。
- **删除** `BulletLifecycle` 的 9 个 typed preset（bounce/curve/world_accel/accel/homing/radial_accel/avoid_player/laser_follow/marisa_laser）。
- **LifecycleCatalog 收口**：只剩 `{lifecycle: BulletLifecycle}` 兼容入口；旧 `{move: ...}` 名一律 null，KernelNativeSystem 的旧 anchor 分支也删了。
- **测试**：`test_lifecycle_presets` 改名 `test_lifecycle_compositions`，用手写原语组合保留逐帧 parity；其余 native/signature/model/tool 调用改 `FIX` 夹具。
- **文档**：DANMAKU_API §3.8 / CONTENT_GUIDE §六 / README 不再教 preset，改成“组合配方 + 拼装器”。
- **验证**：全量 829 / 7692；verify 七步全绿。

### 2026-10-17 — F10b：弹幕台拼装页 + 描述符目录组 + 代码生成

- **入口**：弹幕台「模式：直射 / 拼装」；全局目录「弹道描述符（33）」组放在最前，双击 Move/Until/Action → 切拼装页并加入当前相位。
- **拼装页**：难度（4 个 composer 各存一档）· Move/Until/Action 下拉 · 相位树（+相位/删除/上移/下移）· 参数表单（数值/向量/目标/相位落点/key/dir 编辑器）· 代码框（`_spawn` 占位）· 复制 / 预览发射。
- **代码**：`BulletComposer.to_code()` 从同一份 spec 生成 `var lc := BulletLifecycle.new()` … `data.trajectory(lc)`，不执行字符串。
- **边界**：仍只拼 trajectory，不拼 `_tick` / 波次；预设没删（内容迁移后再删，见 TODO）。
- **测试**：`test_bullet_rig` 加拼装模式/代码/预览；`test_creation_station` 加描述符组路由；`test_bullet_composer_golden` 加 to_code。全量 **829 / 7713**。
- **截图后补**：`spawn` 说明占满剩余宽（不再竖排）；`dir` 编辑器拆两行（kind/target + angle/p/spread），不再溢出 432 面板。截图放 `docs/screenshots/`。

### 2026-10-17 — 创作台 Phase 1：全局目录抽屉 + 公开接缝

- **审查**：目录只活在整关预览右面板「目录」页签，切到三台就消失；`CreationStation` 还 `get("_bullet_manager")` / `get("_stage_runtime")` / `wb.get("_catalog")` 私摸；顶部 4 页签 + 整关 3 页签两套导航。
- **改法**：`Workbench` 补 `catalog_panel()` / `bullet_manager()` / `stage_runtime()`；创作台改走公开方法；顶栏加「目录」抽屉（CanvasLayer(3)，四页签可开；双击路由后自动关）；整关预览仍保留自己的目录页签（standalone 用）。
- **测试**：`test_creation_station` 5 → 7：每页签可开/关目录 + 从弹幕台打开目录双击敌人条目路由；全量 826 / 7691。
- **截图后补**：`CatalogPanel.filter_row` 之前加到根节点、被 EXPAND 的 box 挤到最底部 → 改入 box（搜索/筛选回到顶部）；嵌入预览隐藏内部“目录”页签（避免左右双目录）；右面板延迟到布局完成后同步偏移（不再压在页签栏下）；目录按钮改为 `目录 ▾ / 目录 ▴`。
- **再补（顶栏接缝）**：顶栏加 36px 深色底板 + 底金线；嵌入时舞台只上移 `FIELD_TOP`，不再把 32px 的场地顶边裁到页面外 —— 场地顶/左/右金边形成完整框，页签与内容有明确接缝。
- **未做**：整关预览保活、1600 常驻左栏、`PreviewBench extends BenchBase` —— 留 Phase 2/3。

### 2026-10-17 — F10a：拼装器模型 + 现有内容 golden

- **背景**：F10 不做“预设下拉”；预设是结果，原语才是产品。先证明 `BulletComposer` 能容纳现有弹幕，再谈 UI。
- **新增**：`descriptor_catalog.gd`（Move/Until/Action/Dir 元数据 + apply）、`bullet_composer.gd`（线性相位模型 + `to_lifecycle` + 校验）。
- **golden**：卡摩瑞一符 / 二符 / 道中一非 / 哆来咪三符（Easy / Lunatic）+ `world_accel` / `radial_accel` / `homing` / `marisa_laser` / stage02 双相位；与真实内容 `compile()` 的 ops/args/phase/actions 逐字段一致。
- **结果**：10 用例 / 604 断言；全量 824 / 7666。
- **结论**：9/6/8/7 词汇无缺口；难度变体、表达式、emit 循环由 spec/UI 层承载；下一步才是弹幕台拼装页 + 代码生成。

### 2026-10-17 — verify 提速：GUT 并行分片（~60s → 18.8s）

- **症状**：`./tools/verify.sh` 约 60s，其中 GUT 串行 54s；日常改一行等一分钟。
- **改法**：新增 `test/run_tests_sharded.sh`，把 118 个 `test/test_*.gd` 分成 `min(nproc,8)` 片，
  每片一个 Godot 进程；`test_sfx_mix` / `test_stage_background` 两个慢文件各占一片；每片仍走
  `run_tests.sh`（`user://` 隔离 + `Failed to load` / pending 门禁）。
- **覆盖**：每个文件恰好进一片；合计 814 用例 / 7062 断言，与串行一致。
- **入口**：`verify.sh` 默认并行分片；`--serial` 串行；`--fast` 只跑 4 个冒烟文件（~6s，不全量）；
  `--shards=N` 指定片数。CI 2 核时自动退回串行（<3 片）。
- **实测**：`verify.sh` 60s → **18.8s**；GUT 54s → **15.0s**（14 核 / 8 片）。
- **验证失败传播**：临时塞一个失败测试 → runner exit=1 且打印失败分片日志（探针已删）。

### 2026-10-17 — DSL 静默坑：编译期 fail-closed + 四处响亮

- **目标**：把内容作者最容易踩的“不报错但没效果”变成编译期可见。
- **改法**：
  - `.every()` / `.every_ticks()` 写在 `until_*` 前：`_set_until` 保留修饰键 + 测试（DSL3）。
  - 未知 Move / Until / Action / target / dir：`push_error` + `_compile_failed` → 返回“下一帧 despawn”的兜底 program；不再静默编成 op 0（DSL4）。
  - `radial_accel` 的 `sfx_db` 默认改 `AudioManager.SFX_LEVEL_DB` + dB 断言（DSL6）。
  - `anchor_base` 失效锚点告警一次；`on_end_call` 未注册 hook 告警一次（DSL8）。
  - never 相位上的 `on_end` / 非最后相位 never → `push_warning`（DSL13，区分 despawn / emit）。
  - `BasePage._fade_overlay_in/out` 默认改 `OVERLAY_FADE_IN/OUT`（BGA14，旧 `-1.0` = 瞬间完成）。
  - `CONTENT_GUIDE` §三补敌人回收三条路径（F11）。
- **验证**：`./tools/verify.sh` 七步全绿；GUT 814 用例 / 7062 断言。
- **教训**：未知 op 不能“默认成 0”；编译期 `push_error` + 立即回收，比运行时静默错行为便宜。

### 2026-10-10 — 音量管理补骨架：**真总线 + SE 密度护栏 + BGM 让位/交叉淡入**

- **作者报**：「音效的音量管理还是不怎么好」——"还是"说明前面那几轮（`SFX_DB` 均衡表 / 逐流 `min_interval` / `sfx_trim_db` 练习压低）只是**在调数值**，没治结构。
- **实测三处硬伤（探针 `AudioServer` 直读，不是读代码猜的）**：
  1. **总线是假的**：`bus_count = 1`（只有 Master），而 `ProjectSettings` 指的 `res://default_bus_layout.tres` **文件不存在** —— `_find_bus("BGM"/"SFX")` 每次静默回退 Master，所以「BGM/SE 总线」只是两个字符串（挂不了效果器、也没有总线级音量）。
  2. **主音量是半死的旋钮**：`play_sfx` 的算式缺 `master_volume`（只有 BGM 乘了），而且它**没有 UI、不进存档** → 恒等于 1.0。「BGM 滑杆 = BGM×主音量，SE 滑杆 = SE×0 dB」两条路口径都不一样。
  3. **多声叠加没有护栏**：16 路池 + 同帧去重 + 每条流各自的 `min_interval`（`0.05` / `0.03` 写死在调用点），**不同流会叠加**；池满就踢「最老的」= 掐断正在响的声音。
- **A · 真总线**：新增 `default_bus_layout.tres`（`Master → BGM / SE / UI`，用引擎 `generate_bus_layout()` 生成而不是手写格式）；音量**一律走总线**（`AudioServer.set_bus_volume_db`），per-player 只剩均衡偏移 ⇒ 改滑杆当场对所有在响的声音生效；**缺总线响亮告警**（`_require_bus`，只报一次）；`master_volume` 补上对 SE 的作用 + 选项菜单加「主音量」+ 进存档。
  - UI 音独立一条总线（与 SE 共用同一根滑杆）：SE 的密度护栏/限幅不该泵到菜单音。
- **B · 先量再调**：新增 `tools/audio_density_probe.tscn`（跑真实关卡，量每秒起声部数 / 单帧峰值 / 同时在响 / 驱逐 / 去重与节流挡掉多少 / **密度压制动了多少**）。
  - **实测（stage01，按住射击 25s）**：**545 路 / 25s ≈ 21.8 路/秒**，单帧最多 3 路，**同时在响峰值 14 / 16**，驱逐 **0** 次，同帧去重挡掉 93 次。
  - 两个反直觉的结论：① 密度主力是**自机自己的射击音**（~20/s），不是敌弹；② **池根本没满过** ⇒ "踢最老的"不是当下的病根，**响度总和**才是。
  - 据此落三道护栏：**SE 总线挂 `AudioEffectHardLimiter`（ceiling −1 dB，14 路叠加必削波）**；**密度压制** `density_cut_db()`（按**平滑后**的在响声部数，knee 8、每路 0.75 dB、上限 −3 dB，**只压新起的密集音**，正在响的不动 ⇒ 不引入"泵"，重要音不吃）；**优先级驱逐**（池满时踢「最不重要且最老」，而不是「最老」）。
  - 复测：密度与驱逐不变（护栏不丢音），**压制峰值 −3.00 dB / 均值 −0.09 dB** —— 它只在拥挤的瞬间出手，平时一个数都不动。
  - 探针的**诚实边界**：headless 里自机不会躲弹，差不多 35~60s 就 Game Over（75s 那轮实测在 **35.2s** 被"整棵树 paused"截断）⇒ 探针 `process_mode = ALWAYS` + paused 检测，**报告后退出而不是挂死**（第一版就是这么挂到 `timeout 300` 的）；想看 Boss 战的数字得再加「不死」开关。
- **D · 动态混音**：BGM 两路（**新曲满音量直入、旧曲淡出** —— 作者随后拍板"不要淡入"，见 `BGM_FADE_IN`；换曲不再硬切；同一首正在响仍不重头播，工作台重跑照旧）、`stop_bgm` 默认淡出（`fade=0` 才立即停）；**BGM 让位** —— `BGM_DUCK_ON_SFX`（`player_card` / `boss_die`）响起时 BGM 自动压 6 dB、保持 0.9s 再自动回落，调用点不必知道 duck 存在。
- **为什么这样分**：A 是骨架（后面两个都要踩在总线上）、B 治"叠加"（治并发，不是继续压 dB）、D 治"互相抢"（音乐让位给人声/关键音）。**没有动任何已调好的 `SFX_DB` 数值**。
- **⚠️ 同日回归（我造的，作者当场发现）**：作者报「关卡重开后音乐播放会重叠」。
  - 根因：`pause_menu` 的重开是「`stop_bgm()`（**我新改成淡出**）→ 立刻 reload → 新场景又播**同一首**」；
    而 `_play_bgm_at` 判「同一首正在响」用的是 `volume_db > SILENT_DB` —— 淡出中的那一路**不算数**，
    于是它另起一路同曲：**同一首歌自己叠自己**（两路播放位置差 ~0.3s = 合唱/回声）。
  - 修法：新增 `_bgm_stopping` 标记 + `_find_bgm_player_with(stream)` + `_adopt_bgm()` —— **同一首永远只有一路**：
    正在正常播（且不是刚被停）→ 续播；正在淡出 / 被叫起重开 → **复用那一路**从头播，其余各路淡出。
  - 教训：**「淡出」是一种状态**，不能用「音量是否 > −80」反推 —— 状态要用状态变量记，别拿观测量猜。
  - 回归测试先红后绿：`[2] expected to equal [1]`（两路同曲在响）→ 修后 `19/19` 全绿。
- **同日追加（作者拍板）**：**不要淡入** —— 新曲（含重开同一首）**满音量直入**，只有旧曲淡出。
  落成常量 `BGM_FADE_IN := 0.0`（改回 0.6 就恢复渐入），`_play_bgm_at` / `_adopt_bgm` 两处共用。
  新增 2 条回归（刚起就是 0 dB / 重开也是 0 dB），先红（`−79.97 expected to equal 0.0`）后绿 ⇒ `21/21`。
- **验证**：`test_sfx_mix.gd` 从 3 条扩到 21 条（总线存在 / 三段音量各自落地 / 主音量管 SE / 0 = 静音 / per-player 只剩偏移 / UI 独立总线 / 缺总线告警 / 限幅在 SE 上 / 压制随声部起伏且自动归零 / 池满保重要音 / 让位有起落且自动回落 / 关键音自动让位 / 交叉淡入淡出 / 同曲不重播 / 停止淡出 / **重开同一首只允许一路在响**）—— 全量 **802 用例 / 7040 断言**、`./tools/verify.sh` 七步全绿。
  - ⚠️ 用例耗时 +12s（让位/淡出要等真实时间），全量 41s → **53.8s**；这是"测真实时间行为"的代价，没拿 `Engine.time_scale` 取巧。

### 2026-10-10 — 补齐 10 个缺失弹型：**重建版的弹型资源在 git 里没丢**

- **作者报**：「bulletdef 资源数量不对 😭，我之前有个重建版里面的弹幕是全的，但是没有全部拿到主项目来」。
- **实测缺口**：`data/bullets/*.tres` 只有 **23** 个（16 敌弹 + 7 自机），而 `assets/Textures/bullet/` 有 **26** 张敌弹贴图、`data/atlas/bullet_shapes.tres` 有这些格 —— **素材与图集都在，只有数据没来**：
  `光玉 / 刀弹 / 大星弹 / 大玉 / 心弹 / 椭弹 / 火弹 / 矩弹 / 箭弹 / 蝶弹`（正好 10 个，2026-09-20 迁移那次只搬了旧 `bullet_configs` 表里有的 16 个）。
- **重建版在哪**：目录 `1-st-touhou-star-rebuild/` **已被删除**（盘上 / 回收站 / DSH 会话备份都没有），但它的提交**就在本仓库的对象库里**——`git log --all -- '*大玉*'` 命中 `0901249`（2026-09-10，重建版把工程放在仓库根的那一版），`data/bullets/*.tres` 27 个文件（26 敌弹 + `fx_cancel`）一个不少。
  - **教训**：「那个版本没了」先别认命 —— `git log --all -- <特征名>` / `git fsck --lost-found` 常常还在；**内容在 git 里，删的只是工作区**。
- **改动**：`git show 0901249:data/bullets/<名>.tres` 逐个取回，按主项目资源类转写（`BulletType` → `BulletDef`，只留 `id` / `texture_key` / `hitbox_radius` / `hitbox_offset`），判定值**照抄重建版**（如 `大玉` 36 / `光玉` 28 / `矩弹` 20 / `箭弹` 6 + offset x+20）；`follow_dir` 用默认 true —— 与主项目既有 `中玉` / `小光玉` 一致。
  - 注：重建版对**已有的 16 个**给的值与主项目现值**不同**（主项目沿用的是更早的 `bullet_configs`）。作者拍板「**全部对齐重建版**」，同批改掉其中 8 个：`点弹` 4→5、`菌弹` 4→5、`小玉` 6→8、`环玉` 6→8、`苦无` 6→5、`小光玉` 12→16、`星弹` 补 offset x−1、`滴弹` 6→5 补 offset x+4（其余 8 个本就同值）。
  - 连带：`test_bullet_shell.gd` 那条钉死的「小玉判定 6.0」改 8.0 —— 断言口径从「engine 现行为」改成「内容资源 `data/bullets/小玉.tres`」，**钉数据不钉代码**。
- **为什么加测试**：光靠人眼看「数量不对」正是本条发生的原因。新增哨兵 `test_data_validity.test_enemy_bullet_textures_have_defs`：
  **`assets/Textures/bullet/` 下每张弹贴图都必须有同名 `data/bullets/<名>.tres`**；白名单 = 不是弹的四张（图集本体 `bullet`、`laser`、出生雾 `弹雾`、消弹特效 `消弹`）。
- **验证（红→绿）**：先写哨兵跑 → 红且**恰好点出那 10 个名字**（`["光玉","刀弹","大星弹","大玉","心弹","椭弹","火弹","矩弹","箭弹","蝶弹"]`）；补资源后同条转绿。全量 GUT **784 用例 / 6996 断言**；`./tools/verify.sh` 七步全绿。
- **文档同步**：`docs/DANMAKU_API.md` §7.1 弹型表（哨兵按它比对 `data/bullets/*.tres`）、`docs/TEST_INDEX.md`（E 层 4/25）、README 徽章。

### 2026-10-04 — 清场要看得见：敌人**击破特效** + 弹幕**消弹特效**

- **需求（作者）**：「敌人清场要有击破特效，弹幕清场要有消弹特效」。
- **弹幕侧**：我先前包的 `BulletManager.clear_bullets()` 是**裸清**（`system.clear()`：无特效、无事件）。
  而**同一份代码里早有带特效那条路**：`sweep_enemy_bullets(center, radius, on_clear, inside)` 会
  **先收集 `(pos, tint)` → 逐颗 `despawn` → 逐颗 `play_clear_fx`**（同色提亮 1.5×，与死亡清弹圈 / `clear_fx()` **同一套**），
  且**只清 ENEMY 阵营** ✓ ⇒ 新增 `BulletManager.clear_enemy_bullets_with_fx()` = **一次罩住全场的 sweep**
  （圆心 `GameConfig.SCREEN_CENTER`、半径取**场地对角线** ≈1600 ⇒ 比 cull 范围只大不小），`ctx.bullets.clear_enemy_bullets()` 改走它。
  **零原生改动**（不必动 C++ / 不必重编扩展）✓。分工保留：`clear_bullets()` 仍是关卡收尾的裸清（`StageRuntime` 在用）。
- **敌人侧**：`EnemyService` 新增 **`despawn_clear(enemy)`** = `despawn()` + `ctx.effects.play_hit_effect(death_effect, 位置)`
  —— 正好对应子弹那边的 `despawn()` / `despawn_clear()` 之分（静默 vs 看得见）；
  **`despawn_all()` 改为逐只播击破特效**（"清场"本来就是可见事件）；没配 `death_effect` ⇒ 只回收、不报错。
  **仍不算战果**：不掉道具 / 不计分 / 不发 `enemy_killed` / 不播死亡音效（那些是 `die()`）。
- **中途发现的两件事（都直接影响测试写法，值得记）**：
  1. **内核把"纯特效行"和弹放在同一个 store**（特效行 `_type_index = -1`）⇒ **`active_count()` 是"弹 + 特效"的总数**，
     不能当弹数用。`sweep_enemy_bullets` 自己就用 `get_type(i) == null` 区分 ✓ 照抄同一条判据 ⇒ 测试改成「数真弹 + 数特效行」。
  2. **`ctx.effects` 的 getter 每次访问都重刷** `fx_pool = stage.fx_pool`（"每取一次保持最新"）⇒
     **直接往服务里注入特效池会被覆盖**，注入点是 **`stage`**（`StageRuntime.fx_pool`）。测试已按这条改（顺带 `autofree(rt)` 消掉一个孤儿）。
- **回归测试（4 条，都反向验证过会红）**：
  - 弹幕：2 颗弹 ⇒ 清空 + **恰好 2 条消弹特效**（退回裸清 ⇒ 报 `0 vs 2`）；
  - 敌人 `despawn_clear` ⇒ **恰好 1 次**击破特效（位置 = 敌人位置、用它的 `death_effect`）**且仍不发 `enemy_killed`**；
  - 敌人 `despawn_all` ⇒ 2 只杂兵 = 2 次特效、**假 Boss 不播**；
  - 敌人没配 `death_effect` ⇒ 只回收不报错。
- **⚠️ 自查披露（同一个坑第二次，教训升级）**：反向验证后的还原脚本，我用 `'play_hit_effect' not in t` 当守卫 ——
  而那个词**也出现在文档注释里** ⇒ 守卫误判、**敌人那处一度没还原**（是随后跑全量前检查文件状态才发现的）。
  上一轮（README 徽章的 `base_texture = ExtResource` 撞 `texture = ExtResource`）已经踩过同款。
  ⇒ 教训升级为：**还原 / 存在性判据一律用「带缩进的整行代码」，绝不用裸词。**
- **验收**：`./tools/verify.sh` 七步；GUT **118 脚本 / 783 用例 / 6973 断言**全绿。

### 2026-10-04 — 补「即时清弹」内容动词：`ctx.bullets.clear_enemy_bullets()`

- **起因**：作者问「有弹幕清场动词么」。查清**四个层级**：

| 层级 | 动词 | 有动画 | 内容够得着 |
|---|---|---|---|
| 单颗弹 | `BulletLifecycle.despawn()` / `despawn_clear()` | 否 | ✅ |
| 清激光 | `ctx.bullets.clear_all_lasers()` | 否 | ✅ |
| 圈内清弹 | `ctx.bullets.death_clear(...)` | ✅ **膨胀圈** | ✅ |
| **即时全屏** | ❌ **缺** | — | 底层有、内容够不着 |
| 全清（含特效池 / MultiMesh） | `BulletManager.clear_all()` | 否 | ✗ 引擎级 |
| 工具级清场 + 回收内核表 | `BulletManager.reset_world()` | 否 | ✗ 注释写明"**仅工具 / 工作台**用" |

- **缺口的证据**：底层 `clear_bullets()`（只清内核弹 + 炸弹）**存在**，但调用者只有 `stage_runtime.gd:89`（关卡收尾）；
  `clear_enemy_bullets_in_circle/shape` 只有**炸弹**在用（`kernel_bomb.gd:98` / `kernel_mist_bomb.gd:125`）⇒
  内容想"此刻清屏"只能写 `ctx.bullets.bullet_manager.clear_bullets()`，**绕过服务层** —— 与敌人回收**同一个病**。
- **改法（作者选"只加全屏那条"）**：`BulletService.clear_enemy_bullets()` → 直转 `BulletManager.clear_bullets()`。
  - **纯清除**：不给分 / 不给道具（与 `clear_all_lasers()` 一致；要"炸弹式计分清弹"走炸弹那条路）。
  - **只清敌弹**：不动激光（用 `clear_all_lasers()`）、不动特效池（那是 `clear_all()`，内容别碰）。
  - 与 `death_clear()` 的分工写进注释：那个有半径上限 + 分帧扫 + `on_clear`，适合"死亡 / 炸弹的可见冲击"。
- **测试**：**新建 `test/test_bullet_service.gd`** —— `ctx.bullets` 原本**没有专用测试文件**
  （`shoot_spread` / `death_clear` / `clear_all_lasers` 都只有间接覆盖）。两条：
  - 即时全屏 ⇒ 当帧一颗不剩（与距离无关）；
  - **与膨胀圈的语义差**：`death_clear(ZERO, 100, 1s, 30)` 当帧清不到 300px 外的弹，而本动词清得掉。
  - **反向验证**：把本动词临时写成 `start_death_clear(...)` ⇒ **两条断言红**（`2 expected to equal 0`）——
    正是它要防的那种混淆。
- **验收**：`./tools/verify.sh` 七步；GUT **118 脚本 / 781 用例 / 6963 断言**全绿。

### 2026-10-04 — 敌人回收**动词化**：`ctx.enemies.despawn` / `despawn_all`

- **起因**：作者问「敌人的回收怎么调用」。查下来**没有动词**（`StageRuntime`/`StageDirector`/`StageObjects` 全无），
  文档也**一个字没写**，而子弹那边有整套（`DANMAKU_API.md` 的 `despawn()` / `out_grace` + `BULLET_PIPELINE §5 回收`）
  ⇒ 内容只能裸调 `target.queue_free()`（`fly_away.gd` / `enemy04.gd` 两处）。
- **加的两个动词**（落在已有的 `EnemyService` = `ctx.enemies`，与 `spawn()` 对称）：
  - `despawn(enemy) -> bool` —— **静默**：不掉道具、不计分、不发 `enemy_killed`、不播死亡特效
    （对齐子弹 `despawn()` 的口径；"被打死"走 `Enemy.die()`）。
  - `despawn_all() -> int` —— 只收杂兵、**不动 Boss**（`Boss` 是 `Area2D` 的**兄弟类**不是 `Enemy` 子类 ⇒ 天然筛掉），返回数量。
    与 `EntityRegistry.clear()` 的分工：那个是"拆关卡"语义（连 Boss 一起释放 + 清空名单）。
- **实现中途被测试顶出两个真问题（都改了）**：
  1. **签名从 `Enemy` 改成 `Node2D`**：原设计收 `Enemy` ⇒ 内容得写 `target as Enemy`，而 `as` 在**不是** Enemy 时
     **静默变 null**，我的报错会说"敌人为空/已释放"——**误诊**了真正的原因。现在收 `Node2D`
     （= `CoroutineScript.target` 的静态类型 ⇒ 内容直传 `despawn(target)`），类型不对时**响亮报出它到底是什么**。
     ⇒ 教训：**内容侧静态类型是基类时，用 `as` 换"类型安全"会换来更差的诊断**。
  2. **`test_enemy04_move.gd` 原本用 `cs.start(null, tgt)`**（null ctx）⇒ 内容改走 `ctx.enemies` 后当场炸
     `Invalid access to property or key 'enemies' on a base object of type 'Nil'`。真游戏里 `spawn_enemy_data`
     **保证 ctx 非空** ⇒ 那个 null 只是"这条测试恰好只跑到移动"的巧合；已改为提供 ctx + 用真 `Enemy` 当 target。
     ⚠️ **这条只有跑全量才抓到**（单跑该文件是绿的）—— 又一次证明门禁必须跑全量。
- **内容已改走动词**：`data/stages/stage01/enemy/{fly_away,enemy04}.gd` 的裸 `target.queue_free()` → `ctx.enemies.despawn(target)`。
- **回归测试**（`test_ctx_services` +4，**都反向验证过会红**）：
  - 静默 ⇒ 把回收临时写成 `die()` 时，报 `Expected ... to NOT emit signal [enemy_killed]`；
  - **类型守卫** ⇒ 去掉守卫时，3 条断言红（返回 true / 无 push_error / 假 Boss 真被回收了）；
  - 容错（空与已释放**响亮**+false；重复回收静默 false）；
  - 批量（只收杂兵、跳过 Boss 位、返回数量）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 779 用例 / 6958 断言**全绿。

### 2026-10-04 — Miss 的雷：从「+2 补偿」改为「−2、下限 3」

- **需求（作者）**：「miss 后改为减少 2 个 bomb，减少后如果不足 3 个 bomb 则设置为 3 个 bomb」。
- **这是改既有口径**：原先 miss 是**补偿 +2 个雷**（`Player.MISS_BOMB_GAIN = 2` → `PlayerResources.add_bombs()`，
  到 `MAX_BOMBS` 封顶；当时的理由写作"作者要求：不撒掉落物、雷碎片不动"）。现在改成**惩罚**：
  扣 `MISS_BOMB_PENALTY`(2)，再抬到下限 `MISS_BOMB_FLOOR`(3)。
- **⚠️ 明确记下这条副作用（作者口径，非 bug）**：规则是"**先扣、再把不足的抬到下限**"，**不是**"扣不动" ⇒
  `bomb < 3` 时中弹**反而净增**（1 → 3）。写进代码注释 + 基线文档 + 测试断言三处，
  免得以后有人当 bug"修掉"。
- **落点**：
  - `PlayerResources`：两个常量 + `on_miss_bomb_penalty()`（`changed.emit()` 让 HUD 刷新）；
  - `Player._apply_miss()`：`add_bombs(MISS_BOMB_GAIN)` → `on_miss_bomb_penalty()`；删掉 `MISS_BOMB_GAIN`（全仓已无引用）；
  - **雷碎片那条线不动** ✓（与原口径一致）。
- **同批更新的既有断言与文档**（旧口径散在多处，漏一处就是"文档在骗人"）：
  - `test_player.gd`：两条 `+MISS_BOMB_GAIN` 断言改成"扣 2 / 下限 3 / 满仓不越界"，
    并把两处过时措辞（"不补"、"不发补偿"）改成"不做雷惩罚"；
  - `test_player_resources.gd`：新增纯规则单测（与 `on_miss_power_penalty` 的测法对称）；
  - `docs/BASELINE_EVIDENCE.md`：miss 管线描述改写 + 那条"2026-09-28 补雷补偿"的历史注记改成
    "→ **2026-10-04 改为雷惩罚**"（保留历史，不篡改）。
- **回归测试（反向验证过会红）**：把下限拿掉（`maxi(..., 0)`）⇒ 两个测试文件共 **5 条**断言红，
  报 `2 / 0 / 1 expected to equal 3`。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 775 用例 / 6942 断言**全绿。

### 2026-10-04 — 关卡练习：第 2 面起**满火力**起步

- **需求（作者）**：「让关卡练习除了第一面的其他面都设置火力为满」。
- **现状**：`PlayerResources.reset_practice()`（= **符卡练习**）本来就 `power_raw = 300`（4.00）；
  而**关卡练习**走的是 `reset_all()`（`power_raw = 0` = 1.00）⇒ 练后面几面得从 1.00 攒起，练不到该面的弹幕。
- **改法**：
  - `PlayerResources`：抽出 `const MAX_POWER_RAW := 300`（原先写死 3 处），新增 `set_max_power()`
    （**必须 `changed.emit()`** —— 它是在 `reset_all()` **之后**单独调的，HUD 等不到下一次 reset）；
  - `SaveData`：`const PRACTICE_FULL_POWER_FROM_STAGE := 2` + `practice_starts_at_full_power()`（纯判定）
    + `apply_stage_practice_power(registry)`。⚠️ 判定比的是**面序号**（`StageCatalog.stage_no_of`）而不是 `stage_id`
    —— 3B 面 id=4、EX 面 id=9，"是不是第一面"要按面序号判（`stage_catalog.gd` 专门警告过别混用两套编号）。
  - `StageRuntime.load_stage()`：**紧跟在 `SaveData.reset_all()` 之后**调用它。
- **⚠️ 踩到的坑（第一次接错了位置）**：我最初把调用放在 `game_scene._ready()` 的 `reset_all()` 之后，
  端到端测试报 **`0 expected to equal 300`** —— 因为 `_start_normal_game()` → **`load_stage()` 内部还会
  `SaveData.reset_all()` 一次**，把满火力**冲掉**了。⇒ 落点改到**那次复位之后**（单点、且不吃调用顺序）。
  教训：**"复位"只有一个权威点时，规则要贴在它旁边**，否则会被下一次复位悄悄擦掉。
- **回归测试（3 条，端到端那条反向验证过会红）**：
  - `test_practice_full_power_rule`（纯判定：面 1 不拉满 / 面 2 起拉满 / **普通流程**不拉满）；
  - `test_stage_practice_stage_two_starts_at_full_power`（真场景 ⇒ `power_raw == MAX_POWER_RAW`；
    撤掉落点 ⇒ 报 `0 vs 300`）；
  - `test_stage_practice_stage_one_keeps_normal_power`（第 1 面例外 ⇒ 仍是 0）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 774 用例 / 6937 断言**全绿。

### 2026-10-04 — 修「关卡练习菜单的黑幕没有了」（我的回归）+ 扫同款

- **症状（作者实测）**：关卡练习菜单的黑幕不见了。
- **根因（我的回归）**：`BasePage._create_overlay()` 会按名字**复用**场景里的 `Overlay` 并把它的
  `modulate.a` **归 0**；HEAD 的 `on_enter()` 会把 `Overlay.modulate.a` 拉回 1（黑幕可见），
  而我重写时改成"整页 `self.modulate` 淡入"、**再没碰过 `Overlay.modulate`** ⇒ 有效 alpha = `0.55 × 0` = **0**。
- **修法**：`on_enter()` 调 **`_fade_overlay_in(0.35)`**（BasePage 自带动词）；遮罩**颜色**归场景
  （`Overlay.color`），代码里那句写死的 `0.55` 删掉 —— 颜色不该有两个来源。
- **⚠️ 顺带修了一句假文档**：`is_auto_overlay` 的注释写着"设为 true 则 on_enter 时**自动淡入**暗色遮罩"，
  但代码**只创建 + 归零、不会淡入** ⇒ 子类不调 `_fade_overlay_in()` 就是黑幕不可见。
  这句承诺很可能就是原作者和我都只写 `self.modulate` 的原因。已改成实话，并注明
  `_fade_overlay_in(duration)` 的默认 `-1.0` **不是** `OVERLAY_FADE_IN`（调用要显式传时长）。
- **扫同款（`extends BasePage` × 5）—— 我的扫描错了两次，值得记**：
  1. 先用正则判"有没有碰 `overlay.modulate`"⇒ **假阳性 `replay_menu`**（它用的变量名是 `ov`，
     而它 `tween_property(ov, "modulate:a", 1.0, 0.5)` 本来就是对的）；
  2. 只查脚本、**漏了场景级 `is_auto_overlay = false`** ⇒ **假阳性 `spell_practice_menu`**
     （它明确关掉了自动遮罩、自己管，从来没坏）。
  ⇒ **最终靠"跑起来量有效 alpha"才定案**（测试的前提断言当场把假阳性顶了出来）。
  教训：**可机械判定的东西不一定适合用正则判**；能跑出数值的就跑数值。
- **回归测试（两条，都反向验证过会红）**：
  - `test_stage_practice_menu::test_overlay_curtain_is_restored_after_enter` —— 去掉 `_fade_overlay_in()`
    ⇒ 报 **`0.0 expected to equal 0.55`**（正是作者看到的"黑幕没有了"）；
  - `test_spell_practice_menu::test_overlay_curtain_stays_visible_with_self_managed_overlay` ——
    守"本场景自己管遮罩"这条：**若有人把 `is_auto_overlay` 打开却不补 `_fade_overlay_in()`，它会红**。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 771 用例 / 6928 断言**全绿。

### 2026-10-04 — 相机动词改名 + 目标记忆（作者实测「摄像机的 y 角度最后没回到 0」）

- **症状**：作者的 `stage02_decor.gd` 里 4 条 Y 旋转（−10/+25/−30/+15，**和 = 0**）跑完后 Y 停在 **+15°**。
- **根因（一对动词两种语义、名字看不出来）**：旧 `rotate_camera` 是**绝对**（`tween_property(camera, "rotation", target_rot)` = 设成它）、
  旧 `pan_camera` 是**相对**（`camera.transform.origin + offset`）。作者按 `pan_camera` 的心智模型写 Y **增量** ⇒ 期望回 0，
  实际"最后一条赢" ⇒ +15°。顺带三个坑：
  1. `rotate_camera` 的注释写着"Euler 角度, **度**"，而它 tween 的是 `camera.rotation`（**弧度**）⇒ **注释是错的**（作者写 `deg_to_rad()` 反而是对的）；
  2. 这些动词各自 `create_tween()`、**不杀旧 tween** ⇒ 重叠时同一属性两条 tween 同时写（谁赢看创建顺序）；
  3. `pan_camera` 读的是**实时** `transform.origin` ⇒ 重叠时以"飞行途中的位置"为基准 ⇒ 漂移。
- **改法（作者选 a+b）**：
  - **(a) 名字自解释**：`rotate_camera` → `set_camera_rotation`（绝对）· `pan_camera` → `move_camera_by`（相对）·
    `move_camera` → `set_camera_position`（绝对）· `tween_env_fov` → `tween_camera_fov`（它 tween 的是**相机 fov**，旧名里的 "env" 是错的）；
    **新增** `rotate_camera_by(delta)`（相对旋转）⇒ 能写"转过去再转回来"。
  - **(b) 目标记忆 + 杀旧 tween**：内部保存"上一条指令的**目标**"（pos/rot/fov），相对动词从**目标**累加（**不是**实时值）；
    每个属性只留一条活动 tween，新指令先 `kill()` 旧的；`reset_camera()` 杀光 tween 并把目标也拉回初始姿态。
    ⚠️ **不改变单条调用的画面**（作者那种不重叠的写法结果一致）⇒ 已冻结的画面线不受影响。
- **作者的脚本按其本意转写**：4 条 `rotate_camera` → `rotate_camera_by`（他只提 Y，但 pitch 也一起成了增量：
  终态 **−15° 俯视**，而不是原来的 **+10° 抬头**）—— 脚本里已写明，想改终态只动最后一行的数。
- **回归测试（两条，都反向验证过会红）**：
  - `test_relative_camera_moves_accumulate_from_target_not_live_value`：两条重叠的相对移动，第二条不得丢掉第一段（退成读实时值 ⇒ 报 `0.0 vs 5.0`）；
  - `test_relative_yaw_deltas_summing_to_zero_return_to_zero`：**把作者的 bug 原样编码** —— Y 增量 −10/+25/−30/+15 ⇒ 必须回到 0
    （退成读实时值 ⇒ 报 **`15.0 expected to equal 0.0`**，正是他的现象）。
- **📌 顺带发现（记进 TODO）**：命名仍轻微不一致 —— `set_camera_position`/`set_camera_rotation` 是**动画**（带 duration），
  而 `set_camera_fov` 是**瞬时**（无 duration）；同一个 `set_` 前缀两种行为。
- **📌 一个教训**：`ctx` 在内容脚本里是**无类型**的 ⇒ 调**不存在**的动词**语法检查抓不到**，只会在运行时报错。
  本次改名是靠**全仓 grep + 测试**兜住的（不是靠门禁）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 769 用例 / 6921 断言**全绿。

### 2026-10-04 — 相机初始姿态改由**背景自己声明**（`override_camera_home`）

- **起因**：作者问「3D 摄像头的初始值能设置吗」。查明现状：
  - `StageBackground._find_camera()` **只看父节点的子节点**（宿主 SubViewport 里那台）⇒ **背景场景里放自己的 `Camera3D` 会被完全无视**；
  - 初始姿态有**四个来源**：`game_scene.tscn` / `workbench.tscn` 的相机、抓图工具的 `CAM_POS`/`CAM_ROT_DEG`/`CAM_FOV` 常量、以及 `_own_camera()` 里写死的一组字面量 —— **同一组 `(0,10,6)`/`(−30,0,0)`/`90` 抄了四遍**（正是 `check_structure.sh` 规则③「唯一来源常量」要防的漂移）。
- **改法（作者选方案 1）**：`StageBackground` 新增 `@export override_camera_home` + `camera_home_position`/`camera_home_rotation_degrees`/`camera_home_fov`，
  在 `_ready` 里**抓 home 之前**应用到解析到的那台相机 ⇒ `reset_camera()` 天然复位到**声明的**那套。
  两个背景场景都已打开它（值 = 今天的默认 ⇒ **零视觉变化**），于是"每面自己的初始构图"变成**场景里可改的三个数**。
  - 不建第二台相机、不碰 `Camera3D.current`、与宿主那台不冲突 ⇒ 没有"渲染用一台、逻辑动另一台"的错配风险。
- **降险事实（grep 过全仓）**：只有 `screen_fog_fx.gd` 读这台相机（做太阳投影），`game_scene.gd` **零处引用**
  ⇒ 3D 相机纯粹是"背景的画法"，**不影响弹幕 / 判定 / 坐标**。
- **回归测试**：`test_camera_home_override_applies_and_is_the_reset_target` —— 宿主相机故意摆成别的姿态，
  断言入树后是**声明的**姿态、且演出跑过（pan/rotate/zoom）后 `reset_camera()` 回的也是**声明的**。
  反向验证：去掉 `_apply_camera_home_override()` ⇒ 报 `(0,10,6)` vs 期望 `(0,20,-3)`、`−30` vs `−22`、`90` vs `68`。
- **顺带**：抓图工具在 `--headless`（dummy 渲染器）下原先是 `linear_to_srgb` 的**空指针堆栈**；
  现在改成**响亮报错 + 退出**（"本工具需要真实渲染后端"）—— 它每次冒烟测试都在污染输出，而静默继续等于拿假数据当结论。
- **遗留（记进 TODO）**：那组相机值仍写在 4 处；两个背景开了 override 之后，**宿主那两台已冗余**（只剩"没开 override 的场景"用得到）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 767 用例 / 6918 断言**全绿。

### 2026-10-04 — 修「一改太阳 y，黑雾的太阳对准就不准」（投影的是节点，画的是 sprite）

- **症状（作者实测）**：「我一改太阳的 y 坐标，黑雾的太阳的对准就不准了」。
- **根因**：`ScreenFogFX._update_sun_pos()` 投影的是 **`Sun` 节点**的 `global_position`，而**看得见、拖得动的是它的子节点 `SunSprite`** —— `SunSprite` 带自己的局部位移（stage02 里就有一段）⇒ 两者不是同一个点，**偏移越大、错得越远**。旧实现**恰好**只在"`SunSprite` 位移为零"时对齐。
- **修法**：
  - `BackgroundSun` 新增 `drawn_position()` = **`sprite.global_position`**（没有 sprite 才回落 `global_position`）——
    把"我到底画在哪儿"这件事留给太阳组件自己回答；
  - `ScreenFogFX` 投影时优先用它。**改 `Sun` 的 y 或改 `SunSprite` 的 y 都会对齐**。
- **实测（探针 `.godot/probe/sun_align.gd`）**：两个背景的"雾 `sun_pos` vs sprite 归一化位置"误差 **0.00 px**。
  反向验证：把投影退回 `Sun` 节点 ⇒ 报 `sun_pos.y = -0.0076` vs 期望 `0.0273`（错位 **≈34 px**），正是作者看到的现象。
- **顺带（给作者的量程表）**：`Sun` 在 `z=-500`、`SunSprite` 位移清零时，`Sun.y` → 屏幕归一化 y：
  `0→0.224`、`40→0.170`、`60→0.141`、`80→0.111`、**`87→0.100`**、`100→0.079`、`120→0.046`、`160→-0.027`（出框）。
  ⚠️ 作者当时的 `Sun.y=100` **加** `SunSprite.y=+106` = 全局 206 ⇒ 归一化 **-0.121（顶边外 116 px）** ——
  也就是说**只要把 sprite 位移清零、`Sun.y` 保持 100，太阳就进画面了**（距顶边 7.9%）。
- **回归测试**：`test_fog_aligns_to_the_drawn_sprite_not_the_sun_node` —— 给 `SunSprite` 一个明显的局部位移，
  断言雾写入的 `sun_pos` 等于 **sprite** 的投影、且与 `Sun` 节点的投影差得够远（用例前提自检，防空转）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 766 用例 / 6912 断言**全绿。

### 2026-10-04 — 废止「记得调用才显示」：背景演出层改**宿主自动接线**（练习模式也开黑雾）

- **起因**：作者问「为什么二面道中**现在**看不见太阳和黑雾」。查明是**我上一轮的设计造的坑**：两个组件在 `_ready()` 里藏起来、只由 `setup()` 显示 ⇒ **场景里声明了、脚本忘了调 = 永远隐形 + 零报错**。作者其实**已经把节点都摆好了**（`Sun`/`SunSprite`/`FogFX`/`FogLayer`/`FogRect`，材质/纹理/`resource_local_to_scene` 都齐，连 `SunSprite` 的局部位移都在编辑器里调过），只是 `stage02_decor.gd` 没调 `setup()`。
- **作者拍板**：**练习模式也开黑雾** ⇒ 「藏起来等 `setup()`」这个机制**连存在理由都没了** ⇒ 整条废止。结果是**删 API**而不是加 API。
- **改法**：
  1. **声明即显示**：`BackgroundSun` 删 `_ready` 隐藏与 `setup()`（`_ready` 只留"缺 `SunSprite` 就响亮"）；`ScreenFogFX` 同样删隐藏，`setup(sun, camera)` → **`bind(camera, sun)`**。
  2. **宿主接线**：`StageBackground._resolve_showcase()` 在 `_ready` 里**按类型**（不按名字 —— 同 `DecorManager`/`WorldEnvironment`）找 `ScreenFogFX`/`BackgroundSun`，并 `fog.bind(camera, sun)` ⇒ **内容脚本一个调用都不需要，也就没有"忘"的机会**。
  3. 两个内容脚本删掉 `setup()` 调用与随之无用的局部变量。
  4. **练习模式一行都不用改**：它走 `_load_background(PracticeSession.background)`（**不调 `load_stage`**），背景一入树就显示 ⇒ 练习自然有黑雾 + 太阳。
- **顺带一个安心结论**：雾层在**背景 SubViewport 内** ⇒ 只压暗背景、**不挡弹幕/自机**（"草地隐约可见"就是这么来的）⇒ 练习模式开它不影响可玩性。
- **回归测试**（`test_stage_background` 16 例）：
  - 新增 `test_host_auto_binds_fog_without_any_content_call` —— 背景入树后 `fog.camera` 已接上、`sun_pos` 已算出、雾层与太阳都可见，**全程零内容调用**。反向验证：去掉 `_resolve_showcase()` ⇒ 报相机为 `<null>` 且 `sun_pos` 停在哨兵。
  - `test_fog_setup_...` → 改名 `test_fog_bind_does_not_need_background_parent`（**注入而非摸爹**这条不变量仍在）。
  - 两条断言从"未 setup 前不显示"翻成"**声明即显示**"；其中一条我**漏翻了** —— 测试立刻报 15/16（`未 setup 前不显示`），补齐后 16/16。
- **教训**：**别把"显示"绑在"记得调用"上**。默认方向应是"声明了就看得见"，要例外就**显式**关（而不是靠漏调）。
- **验收**：`./tools/verify.sh` 七步；GUT **117 脚本 / 765 用例 / 6910 断言**全绿；抓图工具 `--stage 1` / `--stage 2` 都跑通。

# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件是**滚动日志**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> - **反复踩的坑 / 铁律** → 已蒸馏进 `BEST_PRACTICES_BASELINE.md`（改动前必读）；本文件只留**近期**条目。
> - **历史条目** → 归档在 `docs/archive/`（可检索，不作日常阅读）。

---

## 模板（每条可复制）

### YYYY-MM-DD — 子系统名 / 改动名
- **目标**：一句话说明要改什么。
- **为什么**：为什么这样改才算符合最佳实践（对应哪篇文档哪一条）。
- **对照旧项目**：旧版 file.gd:line 哪里不好，我这次刻意没抄什么。
- **新落点**：新文件:行号。
- **验收**：./tools/verify.sh / 对应 GUT 测试结果。

---

## 记录

### 2026-09-20 — 创作台清场回收内核注册表（program/弹型不再随重开演积累）

- **背景**：原生 `DanmakuStore` 的 program 表**只增不减**；而 `content_signature` 把 emit 模板 `BulletData` 的**实例 id** 算进签名（保证动作表指向正确模板）。创作台反复「开演」每次重建内容脚本 → 新 BulletData 实例 → 新签名 → program / 弹型表持续增长。普通游戏换 scene 会重建 BulletManager，天然重置，不受影响。
- **做法**（原位重置，不重建节点、保持接线）：
  - `KernelNativeSystem.reset_registries()`：丢 `_accel` 重建原生 store，清 `_program_data` / `_program_anchors` / `_sig_to_program` / `_type_registry` / `_fx_registry` / `_catalog`。
  - `KernelBulletHost.reset_registries()`：清**纹理句柄表**（与弹型表按下标对齐，必须同清，否则索引错位）+ 端口缓存/探测；转发 system。
  - `BulletManager.reset_world()`：`clear_all()` + host 重置。
- **接线**：三个试验台的 `_clear_all`、`bullet_bench._on_hot_reloaded`、整关预览 `_load_stage`、创作台 `_clear_view`（切页）→ `reset_world()`。
- **不做**：内容侧把 emit 模板改 `static`（旧 non01 的招）—— 修工具层更通用；内容保持实例语义（同发逐改速度的模板必须实例）。
- **验证**：新增 `test/test_kernel_reset.gd`：重置后 program / 弹型 / 活跃弹清零，且重置后可继续注册。
- **验收**：`./tools/verify.sh` 全绿：**323 scripts / 503 tests / 502 pass + 1 pending / 4949 asserts**。

### 2026-09-20 — 退役 `non_mid_flee` 预置（内容已内联）

- **背景**：`non_mid01_shoot.gd` 把「逃开自机 → 近 Boss 散圈」内联成两相位 builder，`non_mid_flee_hook.gd` 随之删除；`BulletLifecycle.non_mid_flee` 预置只剩测试在用 → 一并退役（它是最后一个用 `on_end_call` 的内容预置）。
- **改动**：
  - `bullet_lifecycle.gd` 删 `static func non_mid_flee`；`lifecycle_catalog.gd` 删 `&"non_mid_flee"` 分支 + 只服务它的 `_hook_of`（`hook`/`on_flee_burst` 兼容层）。
  - 测试：`test_lifecycle_catalog` 去掉该 move；`test_lifecycle_hooks` 的签名用例改用 `on_end_call` 直构；`test_native_executor::test_native_non_mid_flee` → `test_native_flee_then_burst`（用原语拼同构，保留原生覆盖）；`test_lifecycle_presets` 删该 parity 及 oracle `test/reference/behavior/non_mid_flee_behavior.gd`。
  - 文档：`CONTENT_GUIDE` / `LIFECYCLE_MODEL` / `DANMAKU_API` 的 preset 表/行删除，preset 计数 10→9。
- **保留**：`on_end_call` / `LifecycleHooks` / `A_CALL` 原语仍在（通用逃逸口，由 `test_lifecycle_hooks` + `test_lifecycle_primitives::action:on_end_call` 覆盖）。
- **验收**：`./tools/verify.sh` 全绿：**322 scripts / 501 tests / 500 pass + 1 pending / 4934 asserts**。

### 2026-09-20 — F1 一键解锁所有符卡练习（调试）

- **目标**：主菜单按 `debug_toggle`（F1）一键把名册里的所有阶段（符卡 + 非符）灌进符卡簿 → 符卡练习页全解锁。
- **背景**：`main_menu.gd:193` 原来只 `remove_meta("is_locked")`（视觉解锁），`debug_fill_spells` 已删、只剩 TODO —— 页面点进去是空的。
- **改动**：
  - `SpellBookManager.debug_unlock_all_spells()`：遍历 `BossCatalog.all()` 的 stage × Boss × 难度 × 角色，为**每个阶段**补一条空白记录（`get_or_create`，不记 attempts / 不覆盖成绩）；幂等，返回新建条数。
  - `SpellRecordBook.prune_empty()` 由「无 uid / 统计即清」改为「**主键无效才清**」（`stage<1` 或 `phase_index<0`）——否则零统计的非符记录会被当幽灵删掉、落不了盘。
  - `SaveData.debug_unlock_all_spells()` 薄包装；`main_menu.gd` 的 `debug_toggle` 调它 → `_refresh_spell_lock()` + 打印新增条数。
- **验证**：新增 `test/test_spell_book_debug.gd`（独立 manager，不碰全局簿）：断言符卡+非符都收、幂等、`prune_empty` 保留有主键的零统计记录 / 清理无主键空壳、以及最终 Boss 第 1 槽的难度专属符卡 × 2 角色都有记录且 uid 对得上。
- **验收**：`./tools/verify.sh` 全绿：**98 scripts / 502 tests / 501 pass + 1 pending / 4938 asserts**。

### 2026-09-20 — BossHandle.phase 按当前难度取阶段

- **背景**：上一条把 `BossCatalog` 的身份解析改成「按槽位」；但 `BossHandle.phase(index)` 仍硬取 `data.phases_normal[index]`。stage01 的内容走 `phases_for_difficulty()`（直连），所以线上没暴露；一旦有内容改用 `BossHandle.phase`，Easy/Hard/Lunatic 就会串成 Normal 的卡。
- **改动**：`scripts/coroutine/director/boss_handle.gd` 的 `phase()` 改为 `data.phases_for_difficulty(SaveData.selected_difficulty)`；越界告警带上难度名（`BossData.difficulty_name`），与 `stage01.gd` / `boss_ui.gd` 的取法一致。
- **验证**：`test/test_stage_director.gd` 新增 `test_phase_uses_current_difficulty`：注册真 Boss，4 个难度各断言 `phase(1)` 进的是该难度的第 1 槽（`_stage_id=0` 避免污染符卡簿）。
- **验收**：`./tools/verify.sh` 全绿：**97 scripts / 499 tests / 498 pass + 1 pending / 4889 asserts**。

### 2026-09-20 — 阶段身份按「槽位」解析（难度专属符卡不解锁）

- **症状**：Easy/Hard/Lunatic 打到最终 Boss 的符卡（spell001/003/004）后，符卡练习里不出现、连 attempts 也不记；只有 Normal（spell002）正常。
- **根因**：`BossData` 各难度列**同形、同槽可换卡**（`kamorui_final.tres`：Easy=non01+spell001 … Lunatic=non01+spell004），`stage01.gd:219` 用 `phases_for_difficulty()` 取阶段；但 `BossCatalog.phase_canonical_index` 只在 `stage_phase_order()`（**只摊 phases_normal**）里按**对象身份** `find(phase)` → 难度专属那张返回 -1 → `resolve_identity` 返回 null → `Boss.start_phase` 的 `if _phase_identity:` 跳过 `RecordService.record_phase_start`（不解锁 / 不记 attempts）→ 练习菜单（从 `book.records` 建表）永远看不到。
- **改动**：`phase_canonical_index` 从「按对象身份 find Normal」改为「**按槽位**」：遍历该面各 Boss，在它的 5 个难度列里找 phase 的下标（新 `_phase_offset`），canonical = 前面 Boss 的 `phases_normal.size()` 累加 + 槽位。`phases_normal` 仍是「形状权威」（长度/槽位），`phase_at` 语义不变。
- **落点**：`scripts/data/boss_catalog.gd`（`phase_canonical_index` + `_phase_offset`）。
- **验证**：`test/test_boss_catalog.gd` 新增 `test_difficulty_specific_spells_resolve_by_slot`：对 4 个难度各槽断言 `phase_canonical_index >= 0`、`resolve_identity` 非 null 且 `phase_index`/`difficulty` 正确、`phase_at` 反查回同一张卡。
- **注意**：修完仍需**实际打对应难度**才解锁；符卡练习只更新已有记录（首记由普通模式生成，`spell_record_book.gd:86-87`），练习本身不产新记录。
- **验收**：`./tools/verify.sh` 全绿：**97 scripts / 498 tests / 497 pass + 1 pending / 4885 asserts**。

### 2026-09-20 — 阶段台去掉「脚本改参数」面板（回归内容 .tres / 脚本默认值）

- **目标**：创作台第 4 页签（阶段组合台）不再对 move/shoot 脚本枚举 var 并生成可调 UI。
- **为什么**：阶段参数的权威来源是 `PhaseData.params` + 脚本内 var 默认值；工作台的 `param_panel` 把两者混成一份「临时面板值 → merge 进 phase.params」，而 `data/**` 现**零处**写 `params`（全走脚本默认值）——面板成了「看着能调、其实与内容脱节」的调试残留。移除后阶段台忠实跑所选 .tres。
- **改动**（`scripts/workbench/phase_bench.gd`）：
  - 删 `PARAM_PANEL` 预载 / `_move_params` / `_shoot_params` 成员 / `_rebuild_param_panels()` 及其 3 处调用（`_select_phase`、`_on_slots_changed`、`_on_hot_reloaded`）。
  - `_play()` 不再 `merge(panel.collect())`：直接用 `PhaseShell.build_copy()` 复制出的 `base.params`（Boss 照旧把同一字典灌给 move/shoot）。
  - `VERSION_TAG` `"v1.4-param"` → `"v1.5"`。
- **边界**：`param_panel.gd` **保留** —— 弹幕台 / 敌人台仍在用（它们的 `BulletData.params` / `EnemyData.params` 是发射时实时注入的，语义成立）；只阶段台不适用。
- **验证**：`test/test_phase_rig.gd` 的 `test_dual_param_panels_for_slots` → `test_phase_bench_drops_script_param_panels`（断言接口已删 + UI 树里不再有 `param_panel.gd` 实例）。
- **验收**：`./tools/verify.sh` 全绿：**97 scripts / 497 tests / 496 pass + 1 pending / 4844 asserts**。

### 2026-09-20 — 工作台坐标统一：游戏世界 `top_level`（创作台嵌入时子弹/Boss 错位）

- **症状**：创作台把工作台嵌在页签横栏（高 34）下方时，**子弹出生点比 Boss 低一个横栏高度**（`bullet - boss = (0,34)`），场地网格也对不上。standalone 看不出。
- **根因（两层）**：
  1. **网格 vs 世界**：`bench_base` 给"场地绘制/点击"多算了一遍页面偏移（`from_game(p)=p-_world_offset`），而世界（`BulletManager`/`BenchWorld`/幽灵）都是这个 `Control` 的子节点、用局部坐标 → 网格与世界差一个 `_world_offset`。
  2. **子弹 vs Boss**（真正的 34px）：内容用 `target.global_position`（**全局**坐标）发弹，而子弹渲染器 `BulletManager` 在 bench `Control` 子空间里，把 SoA 里的值当**局部**再叠一次父变换 → 多出页签偏移。游戏里 `World` 在 `(0,0)`，全局=局部，所以只在工作台暴露。
- **做法**：
  1. 删掉 `bench_base._world_offset` / `sync_world_offset()` / `_sync_world_offset_now()` / `to_game()` / `from_game()`；网格/点击/标记统一用局部坐标。
  2. **关键**：让"游戏世界"原点 = 画布原点 → `_field`、`BulletManager`、`BenchWorld` 三者 `top_level = true`（忽略页签偏移）。这样 `global_position` 就是游戏坐标，子弹/Boss/网格/幽灵全在同一空间。
- **验证**：新增 `test/test_workbench_align.gd`（把 `phase_bench` 嵌在 `(0,34)` 下）：场地原点 `(0,0)`、Boss 全局 = 游戏坐标、标记 == Boss、**子弹出生全局 == Boss 全局（`(0,0)`）**。
- **踩坑**：只删 `_world_offset` 不够 —— 那只修了"网格 vs 世界"；"子弹 vs Boss"的 34px 来自**全局/局部混用**（内容传 global，渲染器当 local）。
- **验收**：`./tools/verify.sh` 全绿：**97 scripts / 497 tests / 496 pass + 1 pending / 4845 asserts**。

### 2026-09-20 — CoroutineScript 加 `_on_start()` 钩子（免覆写 start + super）

- **动机**：内容常要在**首次 `_tick` 之前**做一次性初始化（建 `BulletData` / 注册生命周期钩子）。此前只能二选一：① 覆写 `start()` 并手动 `super.start(...)`（`CONTENT_GUIDE.md` 的模板）；② 在 `_tick` 里 lazy `if x == null`。前者每个文件抄样板，后者初始化落在首帧。
- **做法**：`CoroutineScript.start()` 设完 `ctx`/`target` 后调 `_on_start()`（**空默认 virtual**），再 `run(_tick)`。内容只覆写 `_on_start()`，不用 `super`。
- **兼容**：现有覆写 `start()` 的内容脚本不受影响（它们 `super.start(...)` → `_on_start()` 空实现）。
- **实例化时序**（记牢哪个钩子能用什么）：`CoroutineScript extends CoroutineRunner extends Node`；`new()`→`_init()`（无树/无 ctx/target/params 未注入）→ `add_child`→`_ready()`（仍无 ctx/target）→ `_apply_phase_params`（params 注入）→ `start(ctx,target)`→`_on_start()`（ctx/target/params 全就绪，早于首次 `_tick`）。
- **落点**：`scripts/coroutine/base/coroutine_script.gd`；`data/stages/stage01/phase/spell01/spell001_shoot.gd` 改用 `_on_start()`（去掉 `_tick` 里的 lazy 判断）；新增 `test/test_coroutine_start.gd`；`CONTENT_GUIDE.md` 补说明。
- **验收**：`./tools/verify.sh` 全绿：**96 scripts / 496 tests / 495 pass + 1 pending / 4838 asserts**。

### 2026-09-20 — F7 ②·补：内容资源 `BulletDef` 与运行时 `BulletType` 分离

- **动机**：上一版把 `data/bullets/*.tres` 做成了 `BulletType`（**运行时内核类型**）——但运行时那型是被 `BulletData._build_bullet_type()` **整份重建**的，`.tres` 只贡献了外观+碰撞，`BulletType` 的 `faction`/`tint_mode`/`hit_fx`/… 全由构造链填 → 编辑 `.tres` 时这些字段全暴露却**不被读**（看着"多余/残缺"）。
- **设计澄清**：本项目有**构造链**，其存在意义就是「只改一点属性不必新建资源」→ 内容资源只该放**共享、换发不换**的**外观 + 碰撞 + 朝向**；其余（阵营/染色/特效/伤害/出生雾）交给构造链。
- **改动**：
  - 新增 `scripts/data/bullet_def.gd`（`BulletDef`：`texture_key` + `hitbox_*` + `follow_dir`/`dir_offset`）；`data/bullets/*.tres` 改存 `BulletDef`（字段不变，只换 class）。
  - `BulletData.type(bt: BulletType)` → `BulletData.def(d: BulletDef)`；`.tex(key)` = `def(BulletCatalog.find(key))`，**只应用外观+碰撞+朝向**。
  - `BulletCatalog` 返回 `BulletDef`；`bullet_bench` / 测试注解同步。
  - 清死字段：`BulletType.texture_key`（运行时零消费者——渲染插座用 `BulletData.texture`）、`frame_count`（注释指向本仓不存在的 `BulletSystem.set_frame`）、`laser_width`/`laser_grow_time`；`BulletData.can_be_canceled`（运行时按 faction 清，零消费者）。
- **为什么游戏不受影响**：`BulletType` 仍是运行时类型；`hit_fx`/`damage`/`tint_mode` 等照旧由构造链设、`_build_bullet_type()` 拷入。`.tres` 从头就只负责外观+碰撞，不是漏。
- **验收**：`./tools/verify.sh` 全绿：**95 scripts / 494 tests / 493 pass + 1 pending / 4832 asserts**。

### 2026-09-20 — F7 ②：弹型数据化（`data/bullets/*.tres` + `BulletCatalog`，`bullet_configs` 退役）

- **目标**：把弹型的**外形引用 + 判定 + 朝向**从代码表 `AssetRegistry.bullet_configs` 迁到内容资源 `data/bullets/*.tres`（R17/E11），代码表整体退役。
- **做法**：
  - `data/bullets/<key>.tres` × 23（`BulletType`）：`id` + `texture_key`（→ `data/atlas/bullet_shapes.tres` 图集格）+ `hitbox_radius`/`hitbox_size` + `follow_dir`。贴图引用与判定**放同一资源**（正如"外形和碰撞放一起"）。
  - `scripts/data/bullet_catalog.gd`（`BulletCatalog`）：扫 `data/bullets/*.tres` 按 key（= 文件名）建索引；**未知 key 响亮告警**（`push_warning` + null），接替旧 `get_bullet_tex` 的**静默 null**。
  - `BulletData.type(bt)`：从资源载入外形/判定/朝向；`.tex(key)` 委托为 `type(BulletCatalog.find(key))`。**只覆盖 `tex` 曾覆盖的字段** → 与原行为逐字等价（阵营/染色/特效仍由构造链设，内容零改写）。
  - 删除 `AssetRegistry.bullet_configs` / `get_bullet_tex`；`laser` 改 `AssetRegistry.LASER_TEXTURE`（`laser_beam.gd` 兜底用）。
  - `marisa_opt1`：图集补**合体格** `魔理沙子机高速弹` = Rect2(352,944,512,32)（8×64 段连续）；`marisa_shoot` 改为从**原始图集**切片（`atlas = BulletShapes.BULLET_ATLAS_TEXTURE`，region 加格起点）。
- **顺手修的既有 bug**：`spell001_shoot.gd` 的 `.tex("中玉")` 从不在 `bullet_configs` 里 → 一直是**静默空贴图**（旧 `get_bullet_tex` 静默 null）。现补 `data/bullets/中玉.tres`（参考 rebuild：circle 24）。
- **踩坑**：`test_marisa_laser` 断言的是旧切片 region `(0,0,...)`；改图集后起点 = 格位置，测试同步改为 `BulletShapes.pixel_rect(LASER_SHAPE).position`（断言不用数值硬编码，跟着布局走）。
- **验收**：`./tools/verify.sh` 全绿：**95 scripts / 494 tests / 493 pass + 1 pending / 4833 asserts**。
- **遗留**：内容仍是字符串 key（`.tex("小玉")`），但 `BulletCatalog` 已响亮告警；进一步可改 `const 小玉 := preload(...)` + `.type(小玉)`（解析期报错），或把 faction/染色也并入 `.tres`。

### 2026-09-20 — F7·A 弹幕图集（敌弹进图集：1024² + AtlasLayout 数据化）

- **目标**：把敌弹贴图统一进图集，布局数据走 Resource（R17）；为后续 `bullet_configs` → `BulletType.tres` 数据化铺路。
- **做法（照搬 rebuild）**：
  - 贴图：`assets/Textures/bullet/bullet.png`（1024²，从 rebuild 复制）。
  - 布局数据：`data/atlas/bullet_shapes.tres`（`AtlasLayout`：`atlas_size` + 38 格 `形状 key → Rect2`）。
  - 机制层：`scripts/data/atlas_layout.gd`（`AtlasLayout`）+ `scripts/bullet/bullet_shapes.gd`（`BulletShapes`：preload 布局 + 贴图，`pixel_rect`/`uv_rect` + `atlas_texture(key)` 缓存 `AtlasTexture`）。
  - 内容表：`bullet_configs` 的 15 个敌弹条目从 `"tex": preload(png)` 改为 `"shape": &"..."`；`get_bullet_tex` 有 `shape` → `AtlasTexture`，否则退回 `"tex"`。玩家弹 / 激光 / 炸弹保持 `"tex"`（rebuild 图集未含这些格）。
- **为什么能零改渲染/内核**：渲染插座早就支持 `AtlasTexture` —— `BulletMultiMesh._group_key` 已把 region 混入分组键、`_get_or_create_group` 已解包 atlas+UV、shader 有 `region`；原生桥只按宿主给的 `tex_key_base` 分组。
- **验证**：
  - 哨兵 `test/test_atlas_layout.gd`：`atlas_size` == 贴图实际尺寸、38 格都在图内且 UV 归一、`bullet_configs` 的每个 `shape` 都能命中且解析为 `AtlasTexture`、同 key 缓存同实例。
  - **像素核对**（PIL 一次性）：38 格对源 PNG/条带 —— **29 格逐字节相等**，9 格（魔理沙主弹 + 8 帧子机高速弹）`maxdiff=2`（打包舍入噪声）。
- **对照 rebuild**：直接沿用其 `bullet_shapes.tres` 与 `bullet.png`，未改布局；差异仅在本仓把玩家弹留在独立 PNG（rebuild 的主弹格在表内，但本仓 `reimu_opt1/opt2`、`marisa_opt1/opt2`、炸弹、laser 不在 rebuild 图集）。
- **验收**：`./tools/verify.sh` 全绿：**95 scripts / 494 tests / 493 pass + 1 pending / 4838 asserts**。
- **遗留（同日已解决）**：② 弹型数据化见上条（`bullet_configs` 退役）；15 张敌弹源 PNG 仍在盘上（未删，留作对照/回退）。

### 2026-09-19 — F7·B 弹型朝向语义统一（清死字段 + 打通 `follow_dir`/`dir_offset`）

- **目标**：审计 `follow_dir` / `dir_offset` 朝向语义；消除 `BulletData.hitbox_rotation` 死字段；让朝向字段真正可从内容配置。
- **为什么**：基线 S13「弹型朝向 语义统一」挂 `[~]` 已久。审计发现**公式层是干净的**（三处逐字等价），坏的是**数据链断了** —— 内容根本够不着这两个字段。
- **审计结论（三处公式等价）**：
  - GDScript `BulletType.rotation_for()`：`follow_dir && vel≠0 ? vel.angle() + dir_offset : 0`
  - 原生 `danmaku_store.cpp::_hit_rot()`：同上（`hit_test` / `query_circle` 两处都走它）
  - 渲染桥 `danmaku_render_bridge.cpp group()`：`follow && (render_rot 或 vel≠0) ? (render_rot ?? atan2) + dir_offset : 0`（`follow=false` 时连 V19 `render_rot` 覆盖也归零，与 `rotation_for` 一致）
  - → 渲染与判定不会错位。
- **真正的缺陷（死字段 + 硬编码）**：`BulletData._build_bullet_type()` 硬编码 `bt.follow_dir = true`、**从不设** `bt.dir_offset`；`BulletData.hitbox_rotation`（从 `bullet_configs.rect.rotation` 读）**全仓零消费** = 死字段。净效果 = 内容无法表达 `follow_dir=false` / `dir_offset`。
- **新落点**：`scripts/data/bullet_data.gd`（删 `hitbox_rotation`；加 `follow_dir`/`dir_offset` 字段 + `.tex()` 读 `bullet_configs` 可选键 + `_build_bullet_type()` 下传）；`scripts/asset_registry.gd`（`bullet_configs` schema 文档 + 圆弹 `小玉`/`菌弹`/`环玉` 标 `follow_dir:false` —— 三张均为圆/环素材，旋转视觉不变）。
- **对照 rebuild**：其 `follow_dir=false` 集合 = `点弹`/`环玉`/`菌弹`/`小玉`。本仓 `点弹` 是**月牙**（有真实朝向），改 false 会变外观 → **B 不动**，留内容决策/试玩。
- **验收**：新增 `test/test_bullet_orientation.gd`（`rotation_for` 语义 + `BulletData`→`BulletType` 传递 + 实例直赋覆盖）；`test/test_native_collision.gd` 增 `follow_dir=false` 轴对齐 parity（锁 `else 0` 分支 + `dir_offset` 被忽略）。`./tools/verify.sh` 全绿：**94 scripts / 490 tests / 489 pass + 1 pending / 4774 asserts**。
- **遗留（已决）**：`点弹` 经拍板设为 `follow_dir=false`（2026-09-20，随 A 落表）；F7 另一半（图集 A）见下条。

### 2026-09-19 — spell001 种子弹 / 圈弹运动 + V21 `until_speed` 原语

- **需求**：① `_seed_bullet_data` 从「匀速飞到 `_seed_dist`」改成「速度渐渐降到 0」；② `_ring_bullet_data` 出生沿初方向直飞、**碰框前沿速度方向加速**；撞上/左/右框后**速度立即归 0（加速度随相位切换归 0）** → 停顿 → **朝 Boss 重新发射一颗弹幕**（自己自灭）。
- **做法**：
  - **种子弹**（无新原语）：`speed_lerp(_seed_speed, 0.0, T)` + `until_elapsed(T)`。`speed_lerp` 只改速度大小、方向取当前速度归一化 → 沿出生方向直线减速；`T = 2·_seed_dist/_seed_speed` 由「匀减速停车距离 = v·t/2」反解 —— 相位恰在速度归 0 那帧结束，种子停在 `_seed_dist` 处，`_seed_dist` 的「飞行距离」语义不变。
  - **圈弹**（2 段相位）：① `accel_heading(_ring_accel)` + `until_at_wall(左|右|上)`；② `set_speed(0.0)` + `until_elapsed(_ring_pause)` 停顿（加速度随相位切换自然归 0）；该相位 **on_end** = `emit(_return_bullet_data, toward(T_BOSS), 圈速).despawn()` —— 停顿结束**朝 Boss 重新发射一颗**、自己自灭。`_return_bullet_data` 是独立实例（同款外观、**不带生命周期** → 发射后直线飞）。
  - **V21 `until_speed(cmp, value)`**（新 Until 条件）：`|v| cmp value`（`CMP_GE` / `CMP_LE`）。原生 `danmaku_store.cpp` op **25**（`_check_until`；`behavior_batch` 复用 `_run_behavior_pass`，一处改动覆盖两条路径）+ GDScript builder（`C_SPEED` / `OP_C_SPEED` / `until_speed` / `_op_cond` / `_args_cond`）+ 参考解释器 `lifecycle_behavior.gd` + `DANMAKU_API §3.3` / `LIFECYCLE_MODEL` / `CONTENT_GUIDE` + parity 测试 `test_primitive_until_speed`。`DANMAKU_API §3.3` 计数 4 → 5。**内容已不用它（见下），保留为通用速度条件 / content 零引用。**
- **踩坑（API 陷阱）**：`set_speed` / `set_heading` 是 **Move（每帧施加）**，**不是**相位结束 Action！① 把 `set_speed(0)` 放进飞行的首相位 → 子弹**出生即刹停**、`until_at_wall` 永不触发（探针实测停死在起点 5px 处）；② 把 `set_heading(toward(T_BOSS))` 放进末相位 → **每帧重算 → 变成朝 Boss 持续追踪的曲线**，不是直线。正确分法：速度类放对应相位的 **Move**；**一次性动作（转向 / emit / despawn）放 on_end**（Action，相位结束时执行一次）。
- **回卷方向已拍板**：用**发射那一刻**的 Boss 位置（`emit(..., toward(T_BOSS), ...)`，与既有 `bounce` preset 同一习惯），不做「出生快照」（跨相位留点需 per-bullet 寄存器原语，暂缓）。
- **碰撞处理拍板（关 cull）**：一度按需求加过「撞框后 `accel_heading(-b)` 减速到 `v_min`（`until_speed`）」，但减速期间子弹继续往框外漂 ≈ `(v框² − v_min²)/(2·decel)`，而内核 cull = 框外 **90px**（`out_grace` 没接进内核弹）→ 有被提前回收的风险。用户拍板改为**撞框立即把速度归 0**（加速度随相位切换归 0），漂移只剩 1 帧、实测越框 **9.6–11.2px**，问题消失。
- **种子发射方向**：从 `Vector2.DOWN.rotated(randf()*TAU)`（360° 全随机）改为**固定向下 + 左右随机 `±_seed_spread_deg`**（默认 30°，`RNG.randf_range` 单次抽取，仍可复现）。
- **副作用 / 待调**：种子匀速→匀减速后平均速度减半，同样的 `_seed_dist` 现在要 **2× 时间**（160px / 260px·s⁻¹ → 1.23s，原 0.62s）；`_interval=1.2s` 与新飞行时间几乎相等，相邻两发种子首尾相接。`_ring_accel` / `_ring_pause` 可调；回卷速度复用难度圈速。
- **验收**：`./tools/verify.sh` 全绿（**486 / 485 pass + 1 pending，4669 asserts**）。
  - 种子原生探针：距起点 162.2px（`_seed_dist` 160 + 单帧左黎曼过冲 v₀·dt/2≈2.2px），第 73 帧速度归 0 后静止。
  - 圈弹原生探针（框 L64 R832 T32，Boss (448,200)，accel 200 → 撞框置 0 → pause 0.5）：v 183→430，撞框瞬间归 0（R 停 x=842，越框 ~10px）→ 停 0.5s → 第 105 帧在 (842,400) **emit** 出一颗 dir≈(-0.89,-0.45)、speed=180 的弹（朝 Boss），随后自灭（alive 1→0）。

### 2026-09-19 — 场地颜色滤镜（FieldFilterLayer）：从游戏框中心扩圆 → 停留 → 渐隐

- **需求**：加一层颜色滤镜，范围只在**游戏框内**；放 bomb 时从框中心生成逐渐扩大的滤镜圆，持续一段再渐隐。
- **做法**：
  - 新 shader `gdshader/field_filter.gdshader`：`rect_size / center_uv / radius / softness / filter_color / alpha`；圆内铺色、`smoothstep` 羽化边缘；只作用在挂它的 ColorRect（= 游戏框）内。
  - 新 `scripts/effect/field_filter_layer.gd`（`class_name FieldFilterLayer extends CanvasLayer`；场景 `scenes/effect/field_filter_layer.tscn` = CanvasLayer(layer 0) + 场地 ColorRect + ShaderMaterial）。订阅 `GameEvents.field_filter(color)`：`radius 0 → 对角线/2`（`expand_time`）→ `hold_time` → `alpha 1 → 0`（`fade_time`）；三个时长 + `edge_softness` 都是 @export；`color.a <= 0` 直接忽略。
  - `BombData` 加 `field_filter_color`（a=0 = 不启用）；`player._bomb()` 扣弹成功后 emit。`.tres`：灵梦 `Color(1,0.35,0.45,0.35)`、魔理沙 `Color(0.85,0.9,1,0.4)`。
  - `game_scene.tscn` 实例化；滤镜在游戏框内，HUD（layer 32）在其上、不被染色。
- **测试**：新增 `test_field_filter_layer.gd`（+3）：矩形位置/尺寸锁游戏框、透明色不播、有色时圆心=框中心 + 从半径 0 起 + 颜色来自数据。渲染探针：扩圆→铺满（radius 590）→渐隐，圆被框边界裁掉。
- **验收**：`./tools/verify.sh` 全绿（**485 / 484 pass + 1 pending，4666 asserts**）。

### 2026-09-19 — 震屏（ScreenShake）+ 自机 Bomb 接线（灵梦击中 / 魔理沙全程）

- **需求**：加震屏；实际触发 = 灵梦 bomb **击中时**（一次性冲击）、魔理沙 bomb **整个期间**（持续）。
- **做法**：
  - 新增 `scripts/effect/screen_shake.gd`（`class_name ScreenShake extends Camera2D`，挂 `game_scene` 的 `Camera2D`）：trauma 模型 —— `add_trauma(x)` 叠加后按 `DECAY` 衰减（冲击）；`set_sustain(x)` 按住不衰减（持续，传 0 停）；`_process` 里 `offset = rand·MAX_OFFSET·amount²`。只晃 World（2D）；HUD / 背景是 CanvasLayer，不受 Camera2D 影响。
  - `GameEvents` 加 `screen_shake(amount)` / `screen_shake_sustain(amount)`。
  - `BombData` 加 `shake_impulse` / `shake_sustain`（0..1，.tres 可调）。
  - 冲击：`KernelBomb._explode()`（击中/引爆）emit。持续：**基类** `BombEntity._hold_shake_sustain()`（子类 setup 读完 data 后调用）+ `_exit_tree()` 归零——所有 bomb 通用。
  - `.tres`：`reimu_bomb` impulse 0.8 + sustain 0.3；`marisa_bomb` sustain 1.0。
- **测试**：新增 `test_screen_shake.gd`（+4：冲击封顶 / 衰减归零 / 持续保持 / 默认不震）+ mist bomb 持有并归零。顺手把 `test_bomb_data` 里锁死 `explode_damage=150` / `count=8` 的**内容耦合**改成结构断言（夹具原则）——内容改了不该红。
- **验收**：`./tools/verify.sh` 全绿（**481 / 480 pass + 1 pending，4656 asserts**）。
- **3D 背景一起晃**：`ScreenShake.bind_layer(CanvasLayer)`（组合根 `game_scene.gd` 绑 `$Background`）；层 `offset` 取**负号**与 World 同向（Camera2D.offset 让 World 反向位移）。`Background/SubViewportContainer` over-scan 16px（`64,32~832,928` → `48,16~848,944`），晃到 ±14px 也不露边——超出场地的部分被 `false_front` 相框盖住。HUD 仍不晃。

### 2026-09-19 — 自机 Bomb 符卡名大字报（PLAYER 样式：左上 → 左下 → 停顿渐隐）

- **需求**：自机放 Bomb 时也播符卡名，位置与 Boss 反过来——先滑到左上角，再停在左下角，等一会儿渐隐。
- **做法**：
  - `BombData` 加 `@export var name: String`（符卡名；空串不播报）；`reimu_bomb.tres` / `marisa_bomb.tres` 已填真名（灵符「梦想封印 · 散」/ 恋符「极限火花」）。
  - `GameEvents` 加 `player_bomb(spell_name)`；`player.gd _bomb()` 扣弹成功后 emit。
  - `AnnounceLabel` 加 `enum Style { BOSS, PLAYER }`：BOSS = 先右下再右上（原样）；PLAYER = 先左上（`rest_x_left` 让视觉左缘贴父容器左缘）再左下，停 `PLAYER_HOLD(1.0s)` 后 `FADE_OUT(0.6s)` 渐隐；底衬 PLAYER 贴左缘（局部 x=0）；Bonus/Capture 只给 BOSS。
  - 自机最终落点可调：`@export var player_rest_offset: Vector2`（屏幕像素，**要偏上填负 y**），经 `player_rest_pos()` 叠加；Boss 样式不受影响。
  - 新增 `scenes/ui/player_spell_ui.tscn` + `scripts/scenes/player_spell_ui.gd`（订阅 `player_bomb`，用玩家青底衬）；`game_scene.tscn` 实例化。
- **测试**：`test_announce_label.gd` +2（左缘落点、PLAYER 底衬左对齐）；新增 `test_player_spell_ui.gd`（+2：bomb 触发大字报、空名不播）。渲染探针：左上 / 左下 / 渐隐 / 清场四段都对。
- **验收**：`./tools/verify.sh` 全绿（**475 / 474 pass + 1 pending，4643 asserts**）。
- **注**：`announce_label.tscn` 的 `background_offset = (0,20)` 与玩家青底衬是手动调的，已一并保留入库。

### 2026-09-19 — BossUI 场景化收尾（R21）+ 底衬位置可手动微调

- **R21 收尾**：`boss_ui.tscn` 声明 `Control/TimerLabel`(Label) + `Control/DotTemplate`(ColorRect)；`boss_ui.gd` 改用 `@onready` 取，阶段点改成 `_dot_template.duplicate()`（数量随 Boss 阶段数变，模板留在场景里），删 `DOT_SIZE`。至此 `boss_ui.gd` 不再有 `.new()` 建树。
- **底衬手动调**：`AnnounceLabel` 加 `@export var background_offset: Vector2`（单位屏幕像素；+x 右 / +y 下）；`_setup_background` 里 `自动位 + background_offset / SHRINK`（局部偏移会被父节点 0.6 缩放，先除回 1:1）。在 `announce_label.tscn` 根节点 Inspector 调。
- **测试**：新增 `test_boss_ui.gd`（+2：TimerLabel/DotTemplate 声明在场景、模板隐藏且 16×16）；`test_announce_label.gd` +1（offset 位移 = offset/SHRINK）。
- **验收**：`./tools/verify.sh` 全绿（**471 / 470 pass + 1 pending，4637 asserts**）。

### 2026-09-19 — AnnounceLabel 场景化（R21）：子节点挂进 .tscn，不再 new()+add_child

- **来源**：符卡名底衬用代码建 `TextureRect`，被问"为啥节点不是挂 tscn 里的" —— 违反 **R21（声明式建树）**。查历史：`boss_ui.gd` 的 `AnnounceLabel` / `_timer_label` / 阶段点 / 子标签本来就都是 `.new()`，我顺着旧模式做，是错的。
- **做法**：
  - 新增 `scenes/ui/announce_label.tscn`：`Label` 根（挂脚本）+ `Background`(TextureRect) + `BonusLabel`/`CaptureLabel`(Label)；对齐/字体/颜色/`show_behind_parent`/`expand_mode` 全在场景里声明。
  - `announce_label.gd` 改成 `$Background`/`$BonusLabel`/`$CaptureLabel` 自引用（`@onready`），新增 `set_bonus_text`/`set_capture_text`，`_on_finished` 统一亮出子标签；删掉建树代码。
  - `boss_ui.gd` 用 `ANNOUNCE_SCENE.instantiate()` 替代 `AnnounceLabel.new()`；删 `_add_info_labels`/`_make_sub_label`。
- **测试**：`test_announce_label.gd` 改为实例化场景；+1 条（子节点声明在场景、播报中隐藏、setter 生效）。渲染探针：名字 + 红底衬 + 金 `59273` + 绿 `00/01` 全部就位。
- **验收**：`./tools/verify.sh` 全绿（**468 / 467 pass + 1 pending，4630 asserts**）。
- **余**：`boss_ui.gd` 的 `_timer_label` / 阶段点 `ColorRect` 仍是 `.new()`（后续已在「BossUI 场景化收尾」条目收掉）。

### 2026-09-19 — 符卡名底衬（AnnounceLabel 可选背景）：同一套 transform，缩回正常后再渐显

- **需求**：符卡名背后加底衬；底衬**保持贴图原尺寸**（不拉伸也不缩放），随名字**一起滑（同路径）**，右缘贴边；名字缩回正常后再渐显。
- **做法（`scripts/components/announce_label.gd`）**：`play(text, parent_size, background := null)` 加可选底衬。底衬 = `TextureRect` **子节点**（`show_behind_parent = true`），随名字的 position 一起滑（路径一致）。贴图原尺寸：靠子 `scale = 1/SHRINK` 抵消父节点最终的 0.6 缩放，并反推子节点局部位置（`pivot=0`）使缩到 `SHRINK` 时**渲染尺寸 = 原尺寸**、右缘贴父容器右缘、垂直居中。`modulate.a` 初始 0，在 `HOLD` 之后与第一段滑出并行渐显（`BG_FADE = 0.35s`）。
- **接线（`scripts/scenes/boss_ui.gd`）**：`ENEMY_SPELL_NAME_BG = preload(.../enemy_spell_name_background.png)`；玩家符卡（Bomb 名）以后用 `player_spell_name_background.png`（本次只入库，未接线）。
- **素材**：`assets/Textures/ascii/{enemy,player}_spell_name_background.png`（各 400×63 RGBA；敌方红 / 玩家青）。
- **测试**：`test/test_announce_label.gd` +2（夹具 `PlaceholderTexture2D` 400×63）：有底衬 → 挂 `Background` 子节点 + `show_behind_parent` + **原尺寸** + 渲染尺寸 = 原尺寸 + 右缘 = 名字视觉右缘 + 初始 alpha 0；无底衬 → 不挂。
- **验收**：`./tools/verify.sh` 全绿（**467 / 466 pass + 1 pending，4622 asserts**）。
- **⚠ 待人工验收**：实机看底衬渐显时机 / 等比宽度；不合适先调 `BG_FADE` 或换底衬贴图。

### 2026-09-19 — 修符卡名右缘越界（AnnounceLabel 绕中心 pivot 缩放）

- **现象**：符卡名「音符「定点扩散」」右侧被齐刷刷切掉，收取数只露 `00`。
- **根因**：`AnnounceLabel.play()` 的滑出目标是 `parent_size - size*SHRINK`，但 `SHRINK` 是**绕中心 pivot 缩放**——视觉盒右缘 = 布局框 x + `size.x*(1+SHRINK)/2`，比场地右缘多出名字宽度的 20%（8 个全角字 = 77px）。越界部分被上层不透明 HUD 相框 `assets/Textures/front/false_front.png`（`GameUI` layer 32 的 `Front`，场地内 alpha=0 / HUD 区 alpha=255）盖住 → 看起来像"字被切"。
- **做法**：加 `const VISUAL_HALF := (1.0+SHRINK)/2.0` 与纯函数 `AnnounceLabel.rest_x(parent_w, label_w) = parent_w - label_w*VISUAL_HALF`（让**视觉右缘**贴父容器右缘）；两个滑出目标（右下 → 右上）都改用它，y 同理用 `VISUAL_HALF`。
- **测试**：新增 `test/test_announce_label.gd`（夹具 384×70 / 192×70，不碰真实内容）：视觉右缘贴边、短名不越左、名字越长落点越左。复现探针（真实 `game_scene.tscn` + `false_front`）：`stop=(460.8,0)`、`visual_right=768.0`，名字完整显示到相框边。
- **验收**：`./tools/verify.sh` 全绿（**465 / 464 pass + 1 pending，4614 asserts**）。
- **⚠ 待人工验收**：进游戏打关底符卡，确认名字完整贴住场地右缘、收取数不再被切。

### 2026-09-19 — Timeline.sequence_phases：Boss 阶段按序连打

- **要解决的问题**：`wait` 的一次性 `phase_cleared` 会**同时武装所有** wait 事件，表达不了「P0 打完 → gap → P1 → 打完 → P2」；`stage01.gd` 因此只能打 `phases[0]`。
- **做法**：`Timeline` 加 `sequence_phases(getter, phases, gap)`（排时间点）与 `start_sequence_now(...)`（事件驱动立即起）：
  - 起 `phases[0]`；每次 `phase_cleared`，非最后一张 → `next_at = _elapsed + gap`（`tick` 到点进下一张），最后一张 → 记 `_cursor` + 武装 wait；
  - 空表 → 视作「已打完」，立即武装 wait（避免后续 wait 永不触发）；
  - `start_phase` 抽出 `_arm_waits()`；`reset()` 清序列。
- **接线**：`stage01.gd` 道中 Boss → `sequence_phases(..., phases_for_difficulty(selected), 1.0)`；最终 Boss 在对话 `boss_fight` → `start_sequence_now(...)`（替代只打 `phase(0)`）。不再需要 `SPELL01` const。
- **测试**：`test_timeline_sequence.gd`（合成假 Boss）：按序 + gap、**只有最后一张击破后才武装 wait**、空表立即武装。
- **验收**：verify 全绿（462 / 461 pass + 1 pending，4609 asserts）。

### 2026-09-19 — 练习菜单：无可用难度时不落在锁定项（(II) 严格语义收口）

- **确认语义（(II)）**：每个难度必须自己配阶段（`phases_for_difficulty` 不回退）；未配置的难度在菜单里显示为锁定 `?`，不可练。
- **修 UX**：四个难度槽全锁时（无记录 或 无阶段），`_build_diff_list` 原来把 `_diff_index` 留在 0（Easy 锁定项），按 Z 会在锁定项上警告。改为全锁时 `_diff_index = -1`；`_start_practice` 守卫改成 `_diff_index < 0` → 明确警告「没有任何可用难度」且不开始。
- **测试**：`test_spell_practice_menu` 加「全锁 → `_diff_index = -1`、按 Z 不开始 / 不改选择」。
- **内容提醒**：当前只有 `phases_normal` 有阶段 → 只能练 Normal。要练 Easy/Hard/Lunatic 得在 Boss `.tres` 的 `phases_easy/hard/lunatic` 里填阶段。
- **验收**：verify 全绿（459 / 458 pass + 1 pending，4596 asserts）。

### 2026-09-19 — 练习菜单难度槽解耦：MENU_DIFFS 常量（恢复 4 槽）

- **问题**：`phases → phases_normal` 去回退后，练习菜单的 Easy/Hard/Lunatic 槽消失了 —— 因为 `_candidate_diffs` 拿 `phases_for_difficulty(diff)` 非空来**筛槽位**，旧回退只是掩盖了这层耦合。
- **做法**：菜单难度槽与「该难度有没有阶段」解耦：
  - `const MENU_DIFFS: Array[int] = [0, 1, 2, 3]`（普通面标准集合；未来 EX 面只有 Extra → 按 stage 分支 `[4]`）；
  - 锁定判据 = `无记录 OR 该难度无阶段`（不会出现「解锁了却打不开」）；
  - `_candidate_diffs` 更名 `_configured_diffs`，只服务「全收变蓝」：全部**已配置**难度收齐才算。
- **测试**：`test_spell_practice_menu` 原「只定义 Normal → 1 槽」改为「固定 4 槽，其余因无阶段锁定」。
- **验收**：verify 全绿（458 / 457 pass + 1 pending，4590 asserts）。

### 2026-09-19 — BossData 难度阶段去回退：phases → phases_normal

- **需求**：`phases` 不再充当各难度的默认回退；改名 `phases_normal`。
- **做法**：`BossData.phases` → `phases_normal`（builder `phase()` → `normal_phase()`）；`phases_for_difficulty(diff)` 各难度**直接返回自己的数组**（空即空），只有 `_`（Normal/未知）返回 `phases_normal`。调用点跟进：`BossCatalog`（规范序/归属/收集）、`boss_handle.phase(index)`、`stage_runtime.start_spell_card`、`stage01.gd` 时间线、两个 Boss `.tres` 的 `phases_normal`。
- **测试**：`test_boss_phase` 的「空回落 Normal」反转为「空即空」；`test_spell_practice_menu` 原本断「4 个难度槽」编码的正是旧回退 → 菜单加**可注入 boss**（`info["boss"]`，同 `catalog_root` 思路），5 条改用例改用**合成 Boss**（定义 4 难度 / 只定义 Normal），不再绑真实内容。
- **行为影响（重要）**：现在只有 `phases_normal` 有内容 → **Easy/Hard/Lunatic 的练习菜单只列 Normal、BossUI 难度点数为 0**（实战仍走 `phases_normal`）。要给某难度出卡就往 `phases_<diff>` 填。
- **验收**：verify 全绿（458 / 457 pass + 1 pending，4587 asserts）。

### 2026-09-19 — BossCatalog 名册数据化（A）：BossData/.tres + BossRegistry

- **问题**：`BossCatalog.all()` 是手写 GDScript 名册（每阶段一个 `const preload` + 一句 `.phase()`），符卡多了会堆成 80+ const + 一大坨嵌套构造；而 `BossData` 本就是 `@export` Resource。
- **做法**（与 `StageCatalog` 同构）：
  - `BossData` 加 `@export stage_id` / `order`（boss_index = 同面 order 升序）；
  - 每个 Boss 落 `data/stages/<stage>/boss/*.tres`；新 `BossRegistry`（`@export bosses: Array[BossData]`）+ `data/registry/boss_registry.tres`；
  - `BossCatalog.all()` 读注册表（空则扫 `data/stages/**/boss/*.tres`），按 stage_id 分组、order 排序、缓存；删掉 `KAMORUI/NON_MID01/NON01` 三个 const。
  → **加符卡 = 加 `PhaseData.tres` + 在 Boss 的 `.tres` 里 add 一项，零 GDScript**。
- **测试解耦**：`test_boss_catalog` 去掉「阶段数 = 2 / 具体卡名」，改成名册**自洽**断言（规范序 = phases 扁平拼接、phase_at 与规范序一致、boss_index 在范围）。
- **坑**：一次性 `godot -s` 生成器会把 `.godot/global_script_class_cache.cfg` 写坏（连带后续 GUT 报 `game_events.gd` 编译失败）→ `--import` 重建即恢复；生成 `.tres` 时 BossData 必须**先存后 load**，注册表才会「引用」而不是「内联」。
- **未做（另开）**：`Timeline.wait` 的多阶段连打语义不成立（一次 `phase_cleared` 会同时武装所有 wait 事件）——`stage01.gd` 时间线仍只打 `phases[0]`，多符卡编排需要 Timeline 自己的 `sequence_phases`。
- **验收**：verify 全绿（457 / 456 pass + 1 pending，4583 asserts）。

### 2026-09-19 — 修「清空数据」崩溃 + workbench 测试去内容耦合

- **bug**：`option_menu._refresh_values()` 先读 `item["def"]` 再判类型；动作项「清空数据」没有 `def` → 一进设置菜单就报错。改为 action 先分支（动作项无设置值）。
- **测试解耦**：`CatalogPanel` 内部写死 `CAT.new().scan()`，而 `test_catalog_panel` / `test_content_catalog` 拿**真实内容**断数量（`阶段（7）`）→ 加一张符卡就红。给面板加**可注入** `catalog_root`（默认 `res://data`）；两个测试全部改用**夹具目录**，真实内容只留「不数数量、不写具体路径」的结构冒烟。
- **验收**：用户未入库的新符卡 `spell002.tres` 在场时 verify 仍全绿（454 / 453 pass + 1 pending，4552 asserts）。

> 2026-09-13 ~ 2026-09-16 的内核迁移条目已归档：`docs/archive/LOG_2026-09_kernel_migration.md`。

### 2026-09-19 — 吃道具得分浮字（Item.collect → GameEvents.item_score → ScorePopupLayer）

- **需求**：P 点 / 点被自机吃掉时，在被吃掉位置显示本次得分并渐隐；后续细化到「金色只给过收点线/记忆释放」「点的分随深度递减」。
- **判据**：数字用项目现成的 `NumberSprite`（`ascii.png`），不引入 Label + 新字体；展示层不塞进 Item（R2/R7），走既有信号总线（与 `enemy_killed(score, position)` 同构）；池化复用，不每次 `new`。
- **做法**：
  - **触发**：`Item.collect()` 统一算 `gained`（POWER = `value`；POINT = 深度分），`>0` 时 `GameEvents.item_score.emit(gained, global_position, is_highlight)`。`Item.value` 死字段转正 = P 点吃下给的分（`POWER_SCORE := 10`，+1 火力 +10 分）。
  - **展示**：新 `ScorePopupLayer`（`Node2D`，`game_scene.tscn` 的 `World` 下声明）：池化 `NumberSprite`（ascii.png，`is_left_align`、5 位），`show_score()` 在被吃位置设值、上浮 `RISE` + alpha 1→0（`FADE_TIME`）后回池。`LayerConfig.SCORE_POPUP := 55`（EFFECT=50 之上）。
  - **点的分（深位递减）**：非金色收取时 `roundi(lerpf(max_point, MIN_POINT_SCORE=5000, t))`，`t = clamp((y - 收点线256) / (FIELD_BOTTOM 928 - 256), 0, 1)`；金色收取满分。`PlayerResources.add_max_point(score := -1)` 可传入账分并返回实际入账值，**max_point 恒 +10**。
  - **金色规则**：只给「过收点线」与「记忆释放强收（`force_collect()`，含它炸出的道具）」。`Item` 把合并的 `_auto_collect`（线 or 靠近）拆出 `_is_highlight`：过线 → 两者；靠近吸附/撞上 → 只 `_auto_collect`。`ScorePopupLayer.HIGHLIGHT_COLOR`。
  - **字号**：`NumberSprite` 按贴图像素逐位画、没有字号参数 → 新增 `@export var font_scale` 缩**每个浮字实例**（`ns.scale`），上浮距离同倍率。
- **踩坑**：
  - **别缩 `ScorePopupLayer` 节点**：那会把 `ns.position` 一起缩放、浮字位置跑偏。要改大小只动 `font_scale`。
  - **池复用必须在 `setup()` 归零**：新加的 `_is_highlight` 忘了重置，曾金色收掉的实例回池后被普通掉落复用 → 普通掉落误金色。给池化对象加字段一律在 `setup()` 清零。
- **验收**：`./tools/verify.sh` 全绿（453 / 452 pass + 1 pending，4406 asserts）；`test/test_score_popup.gd` 覆盖：P 点加分+发信号、点按线/中点/框底三档递减、金色贴框底仍满分、撞上/靠近白、过线/强收金、字号倍率、池复用不继承金色。

### 2026-09-19 — 弹雾回归 + 特效统一（A2）：EffectType / 逐行 fx_type / 纯特效行

- **背景**：参考内核（重建版）里「发弹预告」与「消弹消散」本是**同一套** —— `EffectType` + 逐行 `_fx_type` + `spawn_fx()` 纯特效行 + 一个渲染器。主项目原生迁移只搬了 `_fx` 相位（冻结），丢了 `_fx_type` + 纯特效行 + 特效渲染 → 弹雾整个消失，消弹退回宿主 `EnemyBulletClear` 节点 + `create_tween`。
- **判据**：特效是**短命行**不是节点；同一份描述符要能同时表达出生雾与消散；效果必须走 SoA + MultiMesh 批量，不能逐弹 `instantiate + create_tween`。
- **做法**：
  - C++ `DanmakuStore`：加逐行 `_fx_type` 列（`set_fx_type/get_fx_type_indices`）+ `spawn_fx(fx_type, pos, color, faction, life)` —— 纯特效行 `_type=-1`、无速度、寿命=相位；`setup/spawn/spawn_batch/_ensure_capacity/_swap_remove` 同步。
  - C++ `_run_behavior_pass`：补 `if (_fx[i] > 0) continue;` —— **相位内的弹不跑行为**（与参照 `behavior_processor.gd` 一致）。此前 `_fx` 恒 0，该缺口从没暴露；出生雾一开就现形（冻结期行为照跑、速度被改、还会提前 emit）。
  - C++ `DanmakuRenderBridge`：加特效表 `set_fx_table(tex_key/duration/scale_from/to/alpha_from/to/tint_mode)`；`group()` 按行 `fx_type` + 相位把弹与特效**分流**（特效键置高位命名空间，与弹键永不相撞）；新增 `fill_fx()`（带缩放 + alpha 淡出）。
  - `EffectType`：`key`(atlas) → `texture`；加 `alpha_from/alpha_to`。落 `data/fx/enemy_spawn_fx.tres`（弹雾.png，2.0→0.5 / 0.3s）、`data/fx/enemy_clear_fx.tres`（消弹.png，1.0→0.2 / 0.2s）。
  - `BulletType`：加 `is_spawn_fog`（逐弹型开关，默认 true）+ `spawn_fx`（逐弹型覆盖）；`BulletData` 加 `.with_spawn_fog()` / `.no_spawn_fog()`，删死字段 `fog_texture`。
  - `KernelNativeSystem`：`_fx_registry` + `spawn_fx()` + 快照 `_fx_type_index`；`BulletManager._enable_kernel` 里 `set_spawn_fx(ENEMY, 发弹特效)`（阵营默认，改一处全变）。
  - `KernelBulletPhysics`：`_play_clear` 从 `fx_pool.play(EnemyBulletClear)` 改为 `system.spawn_fx(消弹特效)`（提亮 1.5x 保留）；`sweep_enemy_bullets` 改成「先收集 / 回收，再统一发消散」——`spawn_fx` 向池尾追加，边遍历边追加会打乱 swap-with-last 的倒序前提。**雾中的弹同样进清场**（直接从发弹特效切成消散）。
  - `BulletMultiMesh`：弹 / 特效两路建组，共用 `bullet_batch.gdshader`（BLEND 分支的灰度混合 `mix(COLOR.rgb, white, gray)` 就是原雾 shader 的算法，无需新 shader）；特效组 z=`LayerConfig.EFFECT`。
- **删**：`scripts/effect/enemy_bullet_clear.gd`(+.uid)、`scenes/effect/enemy_bullet_clear.tscn`、`gdshader/bullet_fog_blend.gdshader`(+.uid)（`bullet_batch` BLEND 已覆盖）、`BulletData.fog_texture`、`AssetRegistry.FOG_TEXTURE`（纹理改由 `.tres` 直接引用）。
- **语义变化（重要）**：阵营默认打开后 **所有敌弹出生冻结 0.3s**（= 旧项目 `.enemy()` 即 `is_spawn_fog=true` 的原始语义）。不想给某型弹预告就 `is_spawn_fog=false` / `.no_spawn_fog()`。
- **踩坑 · `.enemy()` 覆写开关**：`non_mid01_shoot.gd` 写了 `.no_spawn_fog()` 却仍出雾 —— 链是 `.no_spawn_fog() … .enemy()`，`.enemy()` 里 `is_spawn_fog = true` 静默覆写。修法：把「敌弹默认出雾」从 `.enemy()` 挪到字段默认（`BulletData.is_spawn_fog = true`），`.enemy()` 不再碰它 → 开关与顺序无关；`test_spawn_fx` 加顺序反转守卫。
- **测试影响**：清弹类测试改为统计「真弹」（按 `get_type_indices() >= 0` 排除纯特效行）；`test_native_laser_anchor` 的激光段加 `.no_spawn_fog()`（该用例只验锚点）。新增 `test/test_spawn_fx.gd`（原生冻结/到期、阵营默认 + 逐弹开关、清弹切特效、渲染桥分流）。
- **验收**：`./tools/verify.sh` 全绿（check_syntax 301 / naming 0 / 启动零错；GUT 442 / 441 pass + 1 pending）。

### 2026-09-18 — 关 E1（R3）：场景期依赖自文档（@tool + _get_configuration_warnings）

- **判据**：R3 只覆盖**场景期外部依赖**（运行时注入豁免）。全项目真正的场景期 `@export` 引用只有 2 处：`nav_page.container_path`（空/无效 → 导航静默 no-op）、`game_over_menu.title_label`（null → 标题静默不更新）。
- **硬约束**：`_get_configuration_warnings` **必须 `@tool`** 才在场景停靠栏显示（Godot PR #75591）；`@tool` **不被子类继承**；且 `base_page._ready()` 会在编辑器里 `add_child(Overlay)` 污染 .tscn。
- **改**：
  - `base_page._ready()` 加 `Engine.is_editor_hint()` 守卫。
  - `nav_page.gd`：`@tool` + `_get_configuration_warnings()`（`container_path` 空/解析失败 → 警告）+ `_setup_nav()` 运行时 `push_warning` 响亮兜底。
  - `game_over_menu.gd`：`@tool` + 覆写 `_get_configuration_warnings()`（`title_label == null`）。
  - `character_screen` / `difficulty_screen` / `pause_menu`：仅 `@tool`（无 `_ready` 覆盖）。
  - `main_menu` / `player_data_menu` / `music_room_menu`：`@tool` + 给 `_ready`（及 `main_menu`/`player_data_menu` 的 `_input`、`main_menu`/`music_room_menu` 的 `_exit_tree`）加 `Engine.is_editor_hint()` 守卫，避免编辑器副作用。
- **计数**：`@tool` **3 → 11**；`_get_configuration_warnings` **0 → 2**。基线「🔴」删除 R3 行；审计表 R3 → ✅。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **待人工**：编辑器里打开 `main_menu.tscn` / 缺 `container_path` 的页面应看到相应警告（`@tool` 行为只有编辑器可见）。
### 2026-09-18 — 关 E2（R12）：唯一 `@export = preload` 拆成 export + 运行时兜底

- **现状**：`scripts/data/enemy_data.gd:9` 是全项目**唯一** `@export … preload`（R12 禁止）。它让「常量 preload」伪装成导出值（永不释放，又暗示可覆盖），且默认特效与 `AssetRegistry.enemy_visuals["death"]` 是**两份同源 preload**。
- **改（方案 A）**：
  - `@export var death_effect: PackedScene`（**无 preload 默认**，可置 null 释放）。
  - `enemy.gd`：`death_effect = data.death_effect if data.death_effect else AssetRegistry.enemy_visuals.get("death")` —— per-data 覆盖保留，**默认单源**收敛到 `AssetRegistry`。
  - 行为不变（无 `.tres` 覆盖该字段；`enemy.gd` 的 `if death_effect:` 兜底照旧）。
- **落点**：基线「🔴 待改进」删除 R12 行；外壳审计表 R12 由「1，待改」→「0，✅」。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — R15/E3 收尾：节点层 PascalCase（diffculty / jude / bar / content + root）

- **节点改名**（`.tscn` 节点名 + 代码引用 + `parent=` 路径）：
  - `scenes/game_scene.tscn`：`front`→`Front`、`diffculty`→`Difficulty`（拼写 + 大小写）、`debug`→`Debug`；`game_ui.gd` 4 处 `$"diffculty"` / `node.name == "diffculty"` 连带。
  - `data/enemy_visual/*_yin_yang_jade.tscn`：`jude`→`Judge`（×4）。
  - `scenes/workbench/creation_station.tscn`：`bar`→`Bar`、`content`→`Content`、`root`→`Root`；`creation_station.gd` 的 `$root/…` 连带。
  - 敌机外观场景根节点 `root`→`Root`（10 场景 + `kamorui`）。
- **结果**：非 addon 场景已无小写节点（`[node name="[a-z]` 归零）。
- **R15 收口**：目录段（`assets/Textures|Music|Sound`）立豁免、`stage03B` 大写保留（拍板）；**文件层 + 节点层已清**；基线「🔴 待改进」删除 R15 行。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — R15（E3）部分落地：文件层 snake_case + assets/* 目录立豁免

- **用户拍板边界**：`stage03B` 大写**保留**；**只改文件名**、**不碰 `.uid`**（Godot 自行刷新）；`YY_jade` = 阴阳玉。
- **文件改名（9 源文件 + 5 个 `.import` 侧车）**：
  - `assets/Textures/front/{False,True}Front{,2}.png` → `false_front{,2}.png` / `true_front{,2}.png`
  - `assets/fonts/SourceHanSerifCN-Medium.otf` → `source_han_serif_cn_medium.otf`
  - `data/enemy_visual/{red,green,blue,purple}_YY_jade.tscn` → `*_yin_yang_jade.tscn`
- **引用连带**：`scenes/game_scene.tscn`（FalseFront 路径）、`themes/ui_theme.tres` + `scripts/workbench/workbench_theme.gd`（字体）、`scripts/asset_registry.gd`（4 视觉 key + preload）、`scripts/data/enemy_data.gd`（4 预设方法 + key）。
- **契约**：`assets/Textures|Music|Sound` 三素材根目录立**明确豁免**（改名 = 3 目录 + ~236 路径 + 全量重导入，收益仅字面；与 `AssetRegistry` 豁免同源）。
- **`.uid` 值未动**；`.import` 的 `path`/`source_file`/`dest_files` 由 `godot --headless --import` 刷新为新文件名（`uid` 行不变）。
- **未做（用户指示「只改文件名」）**：小写节点 `diffculty` / `front` / `debug` / `jude` / `bar` / `content`（R15 节点层待办）。
- **守卫**：`check_naming` 新增 **⑦ 目录/文件名** —— 目录不得 PascalCase（豁免 `assets/Textures|Music|Sound` + `data/stages/stage03B`），文件名不得含 ASCII 大写（豁免 `README-OFL.txt` + `assets/Music/**` 内容槽曲目名）；当前 0。
- **踩坑**：改名后 `verify.sh` 先报 `ui_theme.tres` 找不到字体 —— 根因是 **Godot `uid_cache` 仍把 uid 映射到旧路径**；跑 `--import` 重建缓存后全绿。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — N8 执行（批次 2+3）：清 scripts/data · coroutine · components · enemy · autoload · player · replay · debug · asset_registry · ui_theme

- **批次 2（scripts/data）**：`r`→`record`、`e`→`entry`、`f`→`file_name`、`n`/`d`→`name_value`/`desc_value`、`s`→`text`、`q`→`quote_index`、`p`/`k`→`prop`/`key`、`t`→`type_id`；`bullet_data` 的 `r`→`rect`；`save_data` 的 `s`→`settings`。**保留**：`boss_data`/`enemy_data`/`bullet_data` 的链式 DSL 形参（`v`/`x`/`y`/`c`/`b`/`s`/`p`/`k`，单行）。
- **批次 2c**：`autoload`（`p`→`player`、`s`→`seed_value`）、`player`（`r`→`roll`）、`replay`（`f`→`file`、`d`→`data`）、`debug`（`r`→`radius`）。
- **批次 3**：`components`（`w`/`h`/`s`→`frame_w`/`frame_h`/`sprite`、`t`/`c`→`ratio`/`color`）、`enemy`（`r`→`entity_registry`、`t`→`fade_ratio`/`time_limit`、`e`/`t`→`item_type`、`n`→`new_name`、`v`→`shown`）、`coroutine`（`stage_director` `b`/`h`→`boss_node`/`handle`/`handler`；`boss_handle` 9 处 `b`→`boss`；`marisa_shoot` `s`→`segment`、`b`→`bullet_data`；`timeline` `t`→`event_time`；`player_service`/`stage_objects`/`bullet_service`/`stage_state`/`dialogue_runner`/`dialogue_steps` 全部改名）、`asset_registry`（`r`→`record`、`o`→`override_record`）、`ui_theme`（`t`→`type_name`、`n`→`entry_name`）。
- **踩坑 1**：`content_catalog._apply_meta` 首处替换只覆盖早退分支，回退分支仍用 `e` → 解析失败；补改。
- **踩坑 2**：`content_catalog` 里 `var text := ...` 遮蔽函数形参 `text` → 改 `line_text`。
- **踩坑 3**：`boss.gd` 局部 `registry` 遮蔽类成员 `registry`（warning-as-error）→ 改 `entity_registry`。
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **唯一待续**：`workbench`（152）。
### 2026-09-18 — N8 执行（批次 1）：单字母严格化规则 + check_naming ⑥；清 scripts/scenes

- **规则（入基线）**：单字母只允许 ① 循环索引 `i`/`j`/`k` ② **单行表达式** / 链式 DSL·构建器形参（生命周期不跨行） ③ **热路径**模块（`kernel_bridge/` · `laser/` · `bullet/` · `effect/` · `background/screen_fog_fx|background_sun|decor_manager`）。其余跨行 / 跨函数 / 字段一律全名。消除了旧 §123「除 i/j/k 全禁」与 §128「单行·热循环可用」的矛盾，并换掉过期例子 `bullet_system`（已 vendor）。
- **守卫**：`check_naming` 新增 **⑥ 类字段不得单字母**（当前 0），把「字段一律全名」锁成机械规则。
- **批次 1（`scripts/scenes/`，37 处改名）**：`t`→`tween`、`s`→`sprite`/`text`、`v`→`value`、`r`→`record`、`c`→`child`/`children`、`o`→`option`、`b`→`bubble`、`d`→`difficulty`、`n`→`count`、`k`→`key`、`x`/`y`→`target_x`/`target_y`。保留：索引 `i`、单行循环（`boss_ui` 的 `for d in _dots: ...`）、单语句形参（`diff_name(v)` / `_pad_cn(v)`）。
- **踩坑（重要）**：`for` 循环体比 grep 命中窗口长 —— `game_ui` 的 `s` 还用在 220–224 / 232–236，首轮漏改 → `check_syntax` 报 8 处 `Identifier "s" not declared`。**循环变量的改名必须读完整循环体，不能只看声明行。**
- **验收**：`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
- **待续（批次 2+）**：`workbench`(152) / `scripts/data`(74) / `coroutine`(61) / `components`(15) / `enemy`(11) / `autoload`(7) / `ui_theme`(7) / `debug`(4) / `asset_registry`(4) / `replay`(4) / `player`(3) / `stage`(2) / `item`(1)，约 350 处。
### 2026-09-18 — 关 N14 + N17：门面动词封闭清单；KernelBulletBackend → KernelBulletHost

- **N14 函数动词不统一**：
  - 现状：机制类严格守 `get_*`/`is_*`/`has_*`（`EntityRegistry.get_boss`、`PlayerService.get_player`、`Enemy.is_targetable`…）；偏差全在意图层 —— `ctx.active()`、`ctx.boss.current()/exists()`、`ctx.diff.picked()/at_least()`、`BossHandle.exists()`。
  - 拍板（A）：不强制改机械 `get_`，而是把「**`ctx.*` 门面 + `StageContext` + `BossHandle` 的方法名可用域动词**」写进基线，受**封闭清单**约束（`active`/`current`/`exists`/`picked`/`at_least`），新增须登记。零改名。理由：门面只说意图，且避免 stutter（`ctx.boss.get_boss()`）。
- **N17 `KernelBulletBackend` 命名**：
  - 融合已定（设计 §11「翻译层已删；宿主耦合永久保留」），它不是 bridge，而是**宿主侧内核后端**（持有原生 `KernelNativeSystem`、bomb、behavior host、laser fade、纹理插座）。「暂缓待形状」条件已满足。
  - 拍板（B）：改名 **`KernelBulletBackend` → `KernelBulletHost`**（与 `KernelBehaviorHost` 同族）。连带：类文件 `kernel_bullet_backend.gd` → `kernel_bullet_host.gd`（+`.uid`）、测试 `test_kernel_backend.gd` → `test_kernel_host.gd`（+`.uid`）、字段 `_kernel_bullet_backend` → `_kernel_bullet_host`、节点名字符串、18 个 `.gd` + 4 个当前态文档。
  - **历史不篡改**：`docs/archive/**` 与既有 `BEST_PRACTICES_LOG` 条目里的旧名保留（记录当时状态）。
- **验收**：删除 `.godot/global_script_class_cache.cfg` 触发 `--import` 重建全局类缓存后，`./tools/verify.sh` 全绿（436 pass + 1 pending / 437 测试 / 4354 断言）。
### 2026-09-18 — 关 N4：`StageContext` 形参前缀统一（修 `_p_ctx`）+ check_naming 补 `_p_` 检测

- **来源**：`TODO_TEMP` N 组 N4。规则「遮蔽成员用 `p_` / 真不用只用 `_` / 禁止叠加 `_p_`」**早已在基线「标识符命名契约」**；本轮只剩执行。
- **现状核对**：`p_ctx` **19** 个形参声明、`_ctx` **34** 行；唯一叠加违规 `_p_ctx` 在 `scripts/coroutine/player/linear_move.gd:5`（`_tick` 函数体完全不用 ctx）→ 改为 `_ctx`，与基类 `CoroutineScript._tick(_ctx: StageContext)` 对齐。
- **check_naming 补洞**：⑤ 原本只检测「形参名 == 成员名」，`p_ctx`/`_p_ctx` 都不等于 `ctx`，所以注释里写的「禁止叠加 `_p_`」**没被执行**。⑤ 新增 `_p_` 前缀检测 + 独立输出段 + 计入总数（`p_x` 或 `_x` 两种正解都提示）。
- **未做**：`p_ctx` / `_ctx` 的既有分工不动（前者用 ctx、后者只透传/忽略），这两类合规。
- **验收**：`check_naming` 0 条（含新 `_p_` 段）；`./tools/verify.sh` 全绿。
### 2026-09-18 — 关 N2：`ctx.*` 门面命名规律写死（保留 `ctx.bullets`，不改 `bullet_service`）

- **来源**：`TODO_TEMP` N 组 N2（`ctx.bullets` 是否改 `ctx.bullet_service`，待拍板）。
- **判据**：门面 → 类型的实际对应是「**门面=域名词，类型=`<Domain>Service`**」——`ctx.bullets`→`BulletService` 与 `ctx.enemies`→`EnemyService`、`ctx.items`→`ItemService`、`ctx.effects`→`EffectService` 同构。改名 `bullet_service` 会让它成为**唯一带 `_service` 后缀的门面**，反而破坏一致性。
- **既有拍板**：2026-09-13 A2b「`ctx.*` 意图门面是唯一豁免、故意不动」+ A2c「拍板：`ctx.*` 门面不动」；`ctx.bullets` 是 A2b 把 `StageRuntime.bullets` / `BulletService.world` → `bullet_manager` 后**有意保留**的门面名，非漏网。
- **落点**：基线「标识符命名契约」新增一行门面命名规律（含映射示例），把口头拍板变成契约。
- **未做**：不改名（零代码改动）；`test_boss_phase` 的「门面是 `ctx.bullets` 不是 `ctx.bullet_manager`」回归断言继续有效。
- **TODO**：删除 N2。
- **验收**：`./tools/verify.sh` 全绿（纯文档改动）。

### 2026-09-18 — 关 A6：`AssetRegistry` 立「内容槽索引表」契约豁免；E11 迁移绑 F7/S13

- **来源**：`TODO_TEMP` A · 融合审查新增最后一条 A6（替换性瓶颈标注）。A6 本质是**优先级依据**、无独立代码交付物，实体是 E11（+F7/S13）；其「替换性快照」已在 2026-09-14 复核时产出。
- **决定（A6 收回 E11）**：
  - 基线「命名边界契约」新增**明确豁免**：`scripts/asset_registry.gd` = **内容槽的代码侧索引表**（`bullet_configs` / `enemy_visuals` / `sounds` / `FOG_TEXTURE` / `BGM_PATHS`），其 `res://` 与中文 key 属内容槽引用、非机制标识符 → 当前合规。
  - **退役条件写死**：随 S13 图集 + 数据化（F7：打包 + `AtlasLayout` + `BulletType` `.tres`）逐表迁 `data/**`；**迁完一表移除一表豁免**，全迁完豁免终止 —— 「换素材成本最高处」不再靠草稿记账，而有契约与期限。
  - `asset_registry.gd` 文件头注释同步，豁免与退役条件在代码现场可见。
- **数字订正**：`asset_registry.gd` **74 → 75** 条含 `res://`；`scripts/**` **227 → 219** 行。快照与 E11 行同步。
- **TODO**：删除 A6（并入 E11）；E11 改为「契约已立，迁移随 F7/S13」。
- **验收**：`./tools/verify.sh` 全绿（纯文档/注释改动，无行为变化）。

### 2026-09-18 — 落 V13+V14：on_end_call 契约 + host 收窄；target 策略归宿主（V 线收官）

- **V13 `on_end_call` 逃逸口契约化**：
  - `KernelBehaviorHost.backend` 私有化为 `_backend`（全仓 0 处外部访问）→ 内容回调只能经 `host.queue_spawn()` 入队，拿不到整个后端。
  - `bullet_lifecycle.on_end_call` 注释 + `DANMAKU_API §3.4/§9.16` 明确契约：每相位结束最多一次、宿主侧、非热路径；签名 `(pos, boss_pos, has_boss, host)`；用了它描述符不再是唯一行为来源。
- **V14 targetability 策略归宿主**：
  - 参考解释器 `_target_pos(T_NEAREST_ENEMY)` 删除内嵌的「跳过时符 / 未开战 Boss」逻辑，改为对**宿主提供的候选集**取最近；targetability 由 `EntityRegistry.get_targetable_enemies()` → `Enemy.is_targetable()` 决定（已有 `test_boss_targeting` 覆盖），内核不再内嵌过滤。
  - `bullet_lifecycle.T_NEAREST_ENEMY` 注释 + `DANMAKU_API §3.6/§9.17` 写清目标契约：target 是固定枚举，候选集由宿主给。
- **测试**：`test_boss_targeting` 3/3、`test_lifecycle_hooks` 3/3、`test_lifecycle_presets` 8/8、`test_native_executor` 9/9、`test_lifecycle_primitives` 39/39 全过。
- **验收**：`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。
- **状态**：V 线（弹幕 VM 原语正交性审查）**全部完成**（V1–V20；V4 被 V18 吸收、V5 先行文档化）。

### 2026-09-18 — 落 V9+V10：emit_variant 独立 op（去掉隐藏分支通道）；RNG 消耗点显式化

- **V9 `_dir_branch` 移除**：`emit_variant` 现在是独立 action op（`OP_A_EMIT_VARIANT=46`），参数 `[action_id, p, hit_dk, hit_tg, hit_angle, miss_dk, miss_tg, miss_angle, speed, at]`；命中 = `toward(target)`、未命中 = `forward(spread)`。内核抽一次定分支、只回传分支号；方向由 op 参数直接算，`_resolve_dir` 不再写隐藏状态。`chance_toward` 仍是 creator 语法，且**只允许**作 `emit_variant` 的 dir（否则 warn + 退化为普通 emit）。
- **V10 RNG 消耗点显式化**：`_resolve_dir` 改为纯函数（多一个 `rnd` 参数，不抽 RNG、无副作用）；新增 `_draw_dir_rnd(dk)`，只有 `RANDOM` / `CHANCE` 方向表达式各抽一次，`emit_variant` 显式抽一次定分支。消耗点与次数写死在 op 语义里，不再藏在方向求值内部。
- **参考解释器**：`A_EMIT_VARIANT` 取未命中分支（参考不模拟随机/分支）；`random_dir` 的原生↔参考 parity 不变。
- **测试（复用既有）**：`test_emit_variant` 6/6、`test_kernel_random` 5/5（多 random_dir 顺序敏感）、`test_probe_descriptor` 4/4、`test_lifecycle_primitives` 39/39、`test_native_executor` 9/9 全过。
- **文档**：`DANMAKU_API §3.4/§3.5/§9.15` 同步（RNG 消耗点、emit_variant 独立 op）。
- **验收**：`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。

### 2026-09-18 — 落 V12 + V15：rotate 三模式；set_speed 在 v=0 用朝向

- **V12 `rotate` 拆轴（同一 op 内加 mode）**：
  - `rotate(w, limit=0)` = 同时转速度与朝向（原语义）；`rotate_velocity(w, limit=0)` = 只转速度；`rotate_heading(w, limit=0)` = 只转朝向。三者共用 `M_ROTATE` op（`mode`=ROT_BOTH/VELOCITY/HEADING），参数 `[w, limit, slot, mode]`；都分配 turned 槽，`until_turned()` 对三者通用。
  - 原生 case 3 按 mode 条件转 `v` / `h`；参考解释器无朝向 → mode=2 时速度不动（与原生 heading-only 的「速度不变」一致，parity 保住）。
- **V15 `set_speed` 的 v=0 边界**：`_apply_set_speed` 在 `|v|=0` 时改用**朝向**定方向（零速出生朝向 = (0,1)），不再静默 no-op，与 `set_heading` 对称。参考侧无朝向，用 (0,1) 近似（零速出生一致）。
- **测试（+5）**：`rotate_velocity` / `rotate_heading` parity；`rotate_velocity` 保朝向、`rotate_heading` 保速度的行为测试；`set_speed` 静止弹沿 (0,1) 给速度。`test_lifecycle_primitives` 34→39。
- **文档**：`DANMAKU_API §3.2/§3.6`、`LIFECYCLE_MODEL §3/§11` 同步。
- **验收**：`test_lifecycle_primitives` **39/39（127 断言）**、presets 8/8、native_executor 9/9、heading_state 4/4；`./tools/verify.sh` 全绿（**436 pass + 1 pending / 437 测试 / 4354 断言**）。

### 2026-09-18 — 落 V6+V7+V8：Until 层重整（通用节流 / at_wall 纯谓词 / at 操作数 / 收掉 until_state）

- **V6 通用节流**：条件 op 参数统一为 `[every, every_ticks, p0, p1, …]`；`_check_until` 先做节流（先帧门控 `_ptick % n`，再秒节流 `_pnext`）再分派。builder 加链式 `.every(sec)` / `.every_ticks(n)`，任何 Until 可套；`until_near(target, r)` 去掉 `every/every_ticks` 参数（preset 改用链式）。语义与旧 `near` 节流 1:1（`_ptick` 仍是每弹全局帧计数）。
- **V7 位置操作数 + 纯谓词**：`emit/emit_variant` 第 4 参由 `at_end: bool` 改为 `at: AT_CURRENT|AT_PHASE_END`（与方向表达式对称的位置轴）；`until_at_wall` 只做越界检测并输出「相位结束落点」，`emit(..., at=AT_PHASE_END)` 显式读它。删除未被实现、也没有下墙的 `WALL_BOTTOM` 常量。
- **V8 收掉裸槽 API**：移除公开的 `until_state(slot, cmp, value)`（slot 对创作者不可见，全仓只有 primitive 测试在用）；`until_turned()` 改为健壮——无前置 `rotate` 或 `limit<=0` 时 `push_warning` + 退化为 `until_never`；native/reference 的 `state` 条件加 slot 边界守卫（`slot=-1` 不再读上一颗弹的槽）。
- **测试**：移除 `test_primitive_until_state`（API 已删）；`test_primitive_action_emit` 显式用 `AT_CURRENT`；新增 `test_action_emit_at_phase_end_uses_wall_point`（`AT_PHASE_END` 落点 = 夹到 `FIELD_TOP`）。
- **文档**：`DANMAKU_API §3.3/§3.4/§3.6/§3.7/§3.8/§9.6`、`LIFECYCLE_MODEL §3/§11` 全部同步。
- **验收**：7 套相关测试全过（primitives 34/34、presets 8/8、native_executor 9/9、behavior_batch 3/3、heading_state 4/4、kernel_random 5/5、emit_variant 6/6）；`./tools/verify.sh` 全绿（**431 pass + 1 pending / 432 测试 / 4340 断言**）。

### 2026-09-18 — 落 V11 + V17：Move/Action 瞬时变换去重；RNG 顺序陷阱入档

- **V11（去重）**：原生 `_exec_move` 的 `set_heading`(case 7) / `set_speed`(case 8) 与 `_exec_action` 的 case 43/44 原本**各有一份实现**，语义相同、易漂移。抽出 `DanmakuStore::_apply_set_heading(...)` 与 `_apply_set_speed(...)`，四个 case 都调用；**纯重构、零行为变化**（case 8 从局部 `v` 改为重取 `_vx/_vy`，两者在该点等值）。参考解释器保持不动（冻结 oracle，本次无语义变化）。
- **V17（文档）**：`DANMAKU_API §9` 新增陷阱 15「**RNG 是单通道、按「op 顺序 + 弹行遍历顺序」消耗**：`random_dir` / `chance_toward` 每求值一次抽一次；加/删/重排方向表达式或改发射顺序都会平移之后所有随机序列（回放可复现，但结果会变）」；顺带把陷阱 14 的 `drift` 命名更新为 `position`(PHASE_START)。
- **验收**：`./tools/verify.sh` 全绿 —— check_syntax 301 脚本 0 失败 / check_naming 0 条 / 启动零错误 / GUT **431 pass + 1 pending（432 测试 / 4340 断言）**。

### 2026-09-18 — 落 V19：`render_heading` 拆出独立渲染朝向通道（位置 op 不再写 velocity）

- **来源**：弹幕 VM 原语正交性审查 V19。V18 后唯一残留的「位置 → 速度」泄漏：`position` op 在 `render_heading=true` 时写 `_vx/_vy`（为渲染朝向），却**不写 `_hx/_hy`** → 锚定期 velocity 与 heading 分离（`accel_heading`/`forward` 读旧朝向，渲染读 velocity）。
- **改（独立通道）**：
  - 原生 `DanmakuStore` 新增逐弹 `_render_rot` 列（NAN = 未设）；position op 的 render_heading 改设 `_render_rot = atan2(adir_y, adir_x)`，**不再写 velocity**；`_run_behavior_pass` 每帧重置，只有当前帧的 position op 会设。新增列按「6 处纪律」同步：`setup / _ensure_capacity / spawn / spawn_batch / _swap_remove / behavior_batch`（+ `get_render_rots`）。
  - `DanmakuRenderBridge::group` 增可选 `render_rots`：`follow_dir` 时优先用它，NAN 回退 velocity 角；`dir_offset` 逻辑不变。
  - `KernelNativeSystem` 快照加 `_render_rot`（容量 / swap / pull / getter）；`BulletMultiMesh._sync_native` 透传。
  - 参考解释器 `M_POSITION` 不再写 velocity（无渲染通道，不模拟）。`test_lifecycle_presets._parity` 加 `check_vel`；`marisa_laser` oracle（旧 behavior 仍写 velocity）改为只比位置。
- **视觉等价性**：override 值 = 旧路径 `atan2(v.y,v.x)`（v=dir(angle) 单位向量）→ 渲染 rot 等价；`follow_dir=false` 或未设 override 时完全走旧路径。
- **测试**：新增 `test_position_render_heading_uses_render_channel`（velocity 保持 + `render_rot = -PI/2`）。
- **验收**：相关 6 套件全过（primitives 34/34、presets 8/8、native_executor 9/9、laser_anchor 1/1、behavior_batch 3/3、heading_state 4/4）；`./tools/verify.sh` 全绿（**431 pass + 1 pending / 432 测试 / 4340 断言**）。
- **⚠ 待人工验收**：渲染朝向链路只有人眼能兜（2026-09-13 N4-real 教训）。上线前需实机确认**魔理沙激光段朝向**（render_heading override）与其它 `follow_dir` 弹旋转未变。

### 2026-09-18 — 落 V18：位置来源统一为 `position` op（模式派 + 显式过渡语义）

- **来源**：弹幕 VM 原语正交性审查 V18（上位吸收 V4/V5）。原 `anchor_drift`(op 9) / `drift`(op 10) 是两个 op 表达同一件事，且都以绝对写 `pos` 的方式与速度 op 混在一条轴上。
- **改（模式派）**：
  - 词汇：`drift` / `anchor_drift` 仍是 builder 糖，但都编译成**同一个** `M_POSITION`(op 9)，用 `mode` 区分 `POS_PHASE_START` / `POS_ANCHOR`；**删 op 10**。
  - `OPS_ARGS` / `ARGS` 8 → 12；position 参数 `[mode, anchor_id, off.x, off.y, angle, speed, flags, initial, slot, base_sx, base_sy]`（ANCHOR 用 1 槽；PHASE_START 用 3 槽记起点 + 位移）。加宽对其它 op 只是 padding，无行为变化。
  - 原生 case 9 统一；参考解释器 `M_POSITION` 同步。
- **显式过渡语义（文档化 + 测试）**：
  - 进入 / 切换：首帧 `pos = base + dir(angle)·initial`（位置立即被模式接管）。
  - 模式**只写 `pos`**，`v` / `h` 不受影响 → 释放后按速度轴自由飞（`drift` 后能按出生方向飞出）。
  - 离开模式：`pos` 留在模式最后结果，积分从该点接力。
  - 同相位多个 position op = **模式切换、后写者胜**（不是叠加）；与速度 op 混用会让速度变化在位置上看不见。
- **未做（明确留给 V19）**：`render_heading=true` 仍借道 velocity（渲染用），是唯一残留的「位置 → 速度」泄漏。**本轮不动**：渲染朝向链路（`DanmakuRenderBridge` 用 velocity 算 rot）只有人眼能验收（见 2026-09-13 N4-real 教训），需独立一轮加「per-row render 朝向通道」。
- **测试**：新增 `test_position_op_is_unified`（两种糖 → 同一 op）与 `test_combo_position_mode_preserves_velocity`（模式不碰 v）；既有 drift/anchor_drift/parity/heading 测试全过。
- **验收**：`test_lifecycle_primitives` **33/33（110 断言）**；`./tools/verify.sh` 全绿（**430 pass + 1 pending / 431 测试 / 4337 断言**）。

### 2026-09-18 — 修 V20：状态槽越界守卫（`slots > SLOT_STRIDE` 拒绝注册）

- **来源**：弹幕 VM 原语正交性审查 V20。`_pslots` 按固定 `SLOT_STRIDE=8` 分行索引，`register_program` 的 `slots` 无守卫；`drift` 每实例占 3 槽 → 同相位 3 个 `drift` 即 `slots=9`，`slots[8]` 会**写进下一颗弹的行**（末行真 OOB），静默串行。
- **改（拒绝式守卫）**：
  - 原生 `DanmakuStore::register_program`：`p_slots > SLOT_STRIDE` → `return -1`（**不发引擎消息**）。
  - `BulletLifecycle.compile()`：`slots > MAX_SLOTS(8)` → `push_warning` 早提示；新增 `const MAX_SLOTS := 8` 与原生 `SLOT_STRIDE` 对齐。
  - `KernelNativeSystem._program_for`：`pid < 0` 时**不 append** `_program_data`（否则 native pid 与 `_program_data` 索引错位），报错并缓存 -1。
  - 文档：`DANMAKU_API §3.7 / §9.14`、`LIFECYCLE_MODEL §3` 写明「同相位槽 ≤ 8，超限 program 被拒绝」。
- **测试**：`test_lifecycle_primitives.gd` 新增 `test_combo_slot_budget_overflow_rejected`（3 drift=9 槽 → pid=-1）与 `test_combo_slot_budget_at_limit_ok`（8 rotate=8 槽 → 接受）。
- **踩坑（重要）**：第一版用 `ERR_PRINT` / `push_error` → GUT 报 `Unexpected Errors`；**原生 `WARN_PRINT` 也被 GUT 记为 engine error**。改为原生**静默返回 -1** + GDScript `push_warning` 后通过。
- **验收**：`test_lifecycle_primitives` **31/31（104 断言）**；`./tools/verify.sh` 全绿（**428 pass + 1 pending / 429 测试 / 4331 断言**）。

### 2026-09-23 — 加 op 47 `clear_fx`：生命周期回收终于能有「消弹消散」特效

- **来源**：作者观察「弹幕执行 `despawn()` 时没有消散特效」。查证链路：原生 `despawn`(op 42) 只 `_tick_dead.push_back(i)`、**不发任何事件**；事件通道只有 emit/sfx/call 三种；消散特效 `_play_clear()` 全项目只被「死亡清弹圈扫掠」和「擦弹满记忆随机清弹」调用。对照旧参照实现（`test/reference` 的 `request_despawn`）**同样静默**，`DANMAKU_API` 对 `despawn` 的定义也只有「回收自己」→ **不是回归，是表达力缺口**。
- **决策（作者拍板 c）**：**不做「`despawn` 一律播」** —— `despawn` 大半是收尾清理且常发生在**屏外**（`bounce`/`radial_accel` 在 `at_wall` 撞墙回收、`avoid_player` 相位2 屏外回收、H/L 分裂弹超时清理），一律播 = 屏外闪光 + 高强度弹幕下的特效风暴。**改为显式 opt-in + 同色提亮**。
- **改（正交原语 + 事件带色）**：
  - 新增**纯 action op 47 `clear_fx`**：只回传「此刻位置 + 弹色」给宿主播消散，**不改任何列式状态**；`despawn_clear()` = `clear_fx().despawn()` 组合糖。`despawn()` 保持**静默**（默认语义不变，零回归面）。
  - 原生事件载荷新增 **`color`（`_ev_color`，与 kind/eprog/local/x/y/… **等长对齐**）**；op 47 发 **kind=3** 事件。
  - **为什么必须由原生带色（关键）**：`behavior_tick` 的顺序是「`_run_behavior_pass` → 先 `_swap_remove` 全部 `_tick_dead` → **最后**才 `return _events_dict()`」。宿主拿到事件时那些行**已被回收**，按 `res.bullet[k]` 回查颜色会读到被 swap 进来的**别的弹**。原生本来就存了 `std::vector<Color> _color`，顺手带上即可。
  - 宿主：`KernelNativeSystem.play_clear_fx(pos, tint)`（同色提亮 1.5×）成为**消弹消散的唯一实现**；`KernelBulletPhysics._play_clear` 降为薄包装（原本它是唯一实现，sweep 的 2 个调用点不动）。
  - 参照 oracle：`lifecycle_behavior._run_actions` 加 `A_CLEAR_FX` 分支（调 `host.play_clear_fx`，位置/颜色取该行 —— 参考侧在回收**之前**执行，故可直接回查，与原生「事件带色」等价）。
- **测试**：`test_lifecycle_primitives` 新增 `test_primitive_action_clear_fx`（纯 action：`act_count==1` 且弹**不回收**）与 `test_primitive_action_despawn_clear`（`act_count==2`）；harness 的 `FakeHost` 加 `clears` + kind=3 处理，`_parity` 比对**消散位置与颜色**。
  - **踩坑（差点白测）**：`_parity` 原来把弹色**写死 `Color.WHITE`**，颜色传播等于没验。已给 `_parity` 加可选 `tint` 参数，两条新用例都传非白 tint → 原生若没带 color，`clears[k]` 会是 WHITE 而参考侧是 tint，断言必红。
- **验收**：`test_lifecycle_primitives` **42/42（179 断言）**；`./tools/verify.sh` 全绿（**506 pass / 506 测试 / 5001 断言 / 0 pending**）。
- **代价 / 流程**：改了内核 → 必须重编 `.so`（debug + release，`./tools/build_gdextension.sh`）。这就是 `REBUILD_REPO_STATUS.md` 那条「原生行为语义变更 → 同步 `test/reference/` 参照并重跑 parity」的规矩，本轮照做。
- **未做**：内容侧**还没有人用** —— spell053 的 H/L 分裂弹（`until_elapsed(2) + despawn()`）目前仍是静默的，等作者定哪几处该改用 `despawn_clear()`。

### 2026-09-23 — 落地 `out_grace`：逐弹出界宽限（内核新列 + 参照同步 + 清掉 4 条假绿）

- **来源**：作者问「grace 在创作台是不是没生效」。查证结果比预想严重：`out_grace` **全仓零消费点**（只有定义 / `.bomb()` 赋值 / `grace()` setter），**不在 `BulletType`**、原生没有任何 grace 概念 → **整个原生管线里都是空转**；真实宽限只有全局 `cull_margin = 90px`（`bullet_manager.gd:231`）。`kernel_bullet_physics.gd` 的「待补」注释与 `kernel_bomb.gd`「bomb 因需要 out_grace 而绕开内核行」都指向同一笔债。
- **实测（修前）**：工作台 `phase_bench` 的 Boss 固定在 (448,250)，而 spell053 H/L 的 `radius_max = 625` → 发弹点落在 **(448, -375)**（框外 407px）→ **integrate 一帧即被剔除**。也就是 `.grace(4)` 想兜的往返探针，其实第一帧就没了（E/N 的 300 恰好卡在 90px 边缘内，所以只在 H/L 暴露）。
- **改（逐弹 / 时间语义；`grace = 0` 严格保持原行为）**：
  - 内核新增 `_out_grace` / `_out_time` 两列，并在**全部 6 处**同步：`setup` 的 assign、`spawn` / `spawn_batch` / `spawn_fx` 归零、`_ensure_capacity` resize、`_swap_remove` 搬运（该函数头注释本就写着「新增字段必须在这里同步」）。
  - 剔除语义：出界时 `grace <= 0 → 立即剔除`（原行为不变）；否则 `_out_time += dt`，`> grace` 才剔除；**回到界内 `_out_time = 0`**。
  - `set_out_grace(id, g)`（设值时 `_out_time` 归零）+ `get_out_grace(id)`（供验证/调试）。
  - `BulletType.out_grace`，与 `hitbox_*` **同规格**：类型级字段 → 发射时逐行推给内核，且内核**解释**它（区别于 damage/hit_sfx 的「只存不解释」）。`BulletData._build_bullet_type()` 带上；`KernelNativeSystem` 加快照列 + spawn 时 `set_out_grace` + `despawn` swap + `get_out_grace` 透传。
  - **参照 oracle 同步**（`test/reference/bullet_system.gd`）：同两列 + 同一 cull 语义 + `set_out_grace`；`_copy_row` / `_reset_row` 两个集中点各加两行。
- **测试**：`test_lifecycle_primitives` 新增 4 条 —— `zero_culls_immediately`（零回归）/ `keeps_outsider_alive_within_window` / `expires_after_window` / `resets_on_reentry`（跑 84 帧仍存活 ⇒ 证明「回界内清零」；若无清零，它 0.15s 就该死）。parity harness 扩了 `opts{cull, margin, grace}` 并**返回落帧存活数**供断言 —— 此前 `_parity` 把剔除区设成巨大框（等于不剔除），out_grace 根本无从测。
- **踩坑 / 清掉 4 条假绿（重要）**：`test_recent_mechanics` 原有 4 条 out_grace「测试」没有一条碰真代码 —— 2 条只断言 setter（`bd.out_grace == 2.5`），2 条**把判定逻辑在测试里重抄一遍**（`var grace := 2.0; var out_time := 0.0` + 循环），所以功能空着、门禁一直绿。已删掉两条重抄，链式那条补上「→ `BulletType.out_grace`」，另加 `test_grace_flows_into_kernel_row` 走真链路（`KernelNativeSystem.spawn` → 原生行 `get_out_grace`）。
- **实测（修后）**：同一位置 `grace=0` → 仍被剔除（零回归）；`grace=4` → **2.4s 后存活**（往返耗时 2.33s）✅。
- **验收**：`test_lifecycle_primitives` **46/46（205 断言）**；`./tools/verify.sh` 全绿（**509 pass / 509 测试 / 5028 断言 / 0 pending**）。
- **连带观察（内容侧，作者同日自行改的）**：`spell053_shoot.gd` 已改用 **`despawn_clear()`**（H/L `until_elapsed(4)`），并把 `夹角弹` / `夹角狙` 拆成独立 lifecycle —— `夹角狙` 无 `until`，靠 `.grace(4)` 出界后自然清理。**`test_probe_descriptor` 因此变红**（它把 `act_count == 1` 这个**内容形状**钉死了；当天就从 `despawn` 变 `despawn_clear`）。已改为只锁「有没有收尾 / 难度是否分派」，不再数 action 个数 —— 锁形状的测试会跟着内容迭代天天红。

### 2026-09-23 — 修符卡练习菜单：第一级切 stage 时第二级不重建

- **来源**：作者报「切换第一级菜单的 stage，第二级菜单没有更新」。
- **根因**：`spell_practice_menu.gd` 的 `_change_stage()` **只重建 `_phases` 数据、不重建二级 UI** —— `_build_phase_list()` 仅由 `_build_lists()` 调，而 `_build_lists()` 只在 `on_enter()` / `_refresh_char()` 走。第一级导航 `_set_idx()` → `_change_stage()` 于是数据切了、`_phase_box` 还留着上一个 stage 的行；`_do_accept_transition()`（按 Z 进第二级）也不重建。
- **复现（实测）**：存档 `stages=[1,4]`，在 stage 1 按 ↓ 后 —— 二级 UI 仍显示 `["非符1","非符2","符卡1"]`，而 `_phases` 已是 `["符卡1"]`。**连带**：三级是按**新** `_phases` 建的 → 二级与三级自相矛盾；且从行多的 stage 切到行少的时，`_highlight_one_vbox` 的索引会超出陈旧 children 数 → **一行都不高亮**。
- **改**：把「数据变了就重建 UI」这条不变量放回**唯一写入点** —— `_change_stage()` 末尾加 `_build_phase_list()`。任何调用方都拿到自洽状态，不用各自记得补。代价：`on_enter()` 多建一遍几行 Label。
- **测试**：新增 `test_stage_nav_rebuilds_phase_list`（合成书 stage1 两张 / stage2 一张；切过去二级应 1 行、切回来应 2 行 —— 反向也测，防「只清不建」）。**先确认它红（2 ≠ 1）再修**。
- **验收**：`test_spell_practice_menu` **8/8**；顺带用临时截图管线（`DISPLAY=:1` + Xvfb + llvmpipe 软件 Vulkan，`get_viewport().get_texture().get_image().save_png()`，跑在**存档副本**上不碰真存档）肉眼确认 Stage 4 的二级只剩 `符卡1`、与三级 No.053–056 对得上。工具用完即删。

### 2026-09-23 — 测试与内容解耦：机制测试自建夹具（+ `BossCatalog` 开注入口）

- **来源**：作者内容中文改名（`non01`→`卡摩瑞一非`、`spell03`→`哆来咪三符`…）→ 门禁红。作者追问「**这种测试为啥不能自建测试用资源呢**」。
- **分类（关键）**：内容绑定**不是**一刀切 —— 判据是「**测试对内容的依赖，应等于它要验证的内容属性**」：
  - **机制测试**绑内容 = 白交改名税（5 个报错文件里 **3 个**属此类）。
  - **内容校验**绑内容是**它的价值**（`test_data_validity`）。
  - **内容形状/行为**故意绑、红了是**信号**（`test_probe_descriptor`）。
- **根因不止"没自建"**：`ContentCatalog` **早就**支持 `scan(root)` 夹具根（`test_content_catalog` 已在用），但 **`BossCatalog` 是 `static` + 硬编码 `BOSS_SCAN_ROOT`、没有注入口**，且 `resolve_identity → phase_canonical_index → _phase_offset` 用 **`find(phase)`（对象身份）**在真实 stage order 里定位槽位 —— 所以 `test_boss_phase` **不是不肯自建，是建不了**。
- **改**：
  1. **`BossCatalog.set_catalog_override({stage: [BossData]})` / `clear_catalog_override()`** —— 直接投名册、跳过扫描（⚠️ static 缓存全局可见，测完必须 clear）。
  2. `test_workbench_align`：真 `spell001.tres` → **自建 `PhaseData`**（本用例只验坐标系）。
  3. `test_phase_rig`：**4 处**内容绑定全清 —— move/shoot 换成 `test/fixtures/**`（现成 `extends CoroutineScript`）；三处「按文件名找阶段」换成 `_pick_phase()`（取目录里第一张带 move+shoot 的，**不写死路径**）；`move 路径` 断言改为「= 该阶段自己引用的脚本」。
  4. `test_boss_phase`：两张真 `.tres` → 合成 `PhaseData` + 注入名册。
  5. `test_data_validity`：从「钉 `non01.tres` / `spell056.tres`」升级为**遍历全部阶段的不变量校验**（hp/时限/双脚本槽 + **uid 全局唯一**）—— 覆盖**更强**且改名不红。
  6. `test_probe_descriptor`：只换新路径（它**该**绑内容），并在文件头写明为什么。
- **验收**：`./tools/verify.sh` 全绿（**509 pass / 509 测试 / 5098 断言 / 0 pending**）。
- **遗留（审计结论，尚未做）**：还有 ~10 个文件绑着**别的内容族**（`player_data/*.tres`、`enemy01.gd`、`fx/*.tres`、`dialogue/*`）—— 这次改名没波及它们，但**下次改那些名字会一样坏**。契约已写进 `docs/TEST_INDEX.md`「内容绑定契约」，后续按类处理。

### 2026-09-23 — 内容解耦（第二批）：清掉其余 8 个白绑文件，明确 7 个「该绑」

- **来源**：接上一条的「遗留」。全仓审计出 15 个文件绑 `res://data/`，逐个判「机制 vs 内容」。
- **清掉（机制测试，8 个文件）**：
  - `player_data/*.tres` → `test/fixtures/fixture_lib.gd` 的 `player_data()`：`test_kernel_physics` / `test_kernel_swap` / `test_laser` / `test_player`。
  - `fx/*.tres` → `test_spawn_fx`：雾用夹具；**消散直接读引擎常量 `KernelNativeSystem.CLEAR_FX`** —— 消散特效是**引擎内置选择**，测试里再写一份内容引用，断言就退化成「消散 == 它自己」。
  - `enemy01.gd` / `enemy03.gd` → `test_ctx_services` / `test_enemy_data_serializable` / `test_enemy_rig`；新增 `test/fixtures/param_panel_probe.gd`（float/int/Vector2/Color 四类 + 零值陷阱），组合台三处「按文件名找脚本」全换成它。
  - `test_player` 里 `assert_eq(player_data.resource_path, ".../marisa_data.tres")` 是**把内容路径当期望值**的典型 → 改身份断言。
  - `test_dialogue.test_profiles_valid`：3 条硬编码路径 → **遍历 profile 目录**。
- **踩坑（3 个，都会让门禁红）**：
  1. `Player._init_shoot_script` 里有 `assert(_player_shoot_script is PlayerShootScript)` —— 裸 `CoroutineScript` 夹具会被断掉（并产生 engine error）。新增 `test/fixtures/player_shoot_probe.gd`（`extends PlayerShootScript`，基类默认实现就够，一行）。
  2. `Player.change_state` 会 `play(idle/lefting/left/righting/right)`；夹具 `animation` 留空 → `Condition "frames.is_null()" is true`。夹具必须带最小 `SpriteFrames`。
  3. `PROBE_SCRIPT.resource_path` 在 **preload 常量**上编译期不可见（Parse Error）→ 用「路径常量 + `preload(路径常量)`」。
- **明确「该绑」（7 个文件，已补 in-file 说明，**别再去夹具化**）**：`test_data_validity`（内容校验）· `test_dialogue`（profile 遍历校验）· `test_bomb_data`（**出货** bomb 类型/结构 —— 换错子类会让 `spawn_bomb` 按实际类型分派时静默变质）· `test_mist_bomb`（出货 mist bomb）· `test_probe_descriptor`（内容形状）· `test_enemy04_move` / `test_stage01_dialogue`（内容行为）。
- **验收**：`./tools/verify.sh` 全绿（**509 pass / 509 测试 / 5100 断言 / 0 pending**）。
- **结果**：绑 `res://data/` 的测试文件 **15 → 7**，且 7 个全部属「红了有意义」的类别。清单与接缝表落在 `docs/TEST_INDEX.md`「内容绑定契约」。

### 2026-09-23 — 符卡练习菜单：非符时三级不显示名字

- **来源**：作者要求「第二级选中的是**非符**时，第三级不要显示名字」。
- **为什么对**：第三级的名字行对**符卡**是有信息的 —— 实测同一张「符卡1」四个难度显示**不同卡名**（`音符「定点扩散」` ×2 + `递符「定向传播」` ×2）。而对**非符**，名字就是二级已经写过的「非符N」，四个难度重复 4 遍纯属噪音（改前截图：`卡摩瑞的道中非符1` ×4）。
- **改**：`_build_diff_list()` 的名字行改成「**锁定 → 「?」；符卡 → 卡名；非符 → 不建这一行**」。
  - `rec.uid != 0` 判符卡（与 `_change_stage` 同口径）。
  - **锁定态仍保留「?」** —— 那是「不可选」信号，不是名字；不建的话非符的锁定槽会失去唯一提示。
  - `var record` 提到 `if` 之外（难度行还要用它），顺带把 `vbox` 声明顺序理正（第一版手滑删了声明，靠语法门禁立刻抓到）。
- **测试**：`test_spell_practice_menu` 新增 `test_nonspell_has_no_name_row`（锁定槽 2 行含「?」/ 解锁非符 1 行）与 `test_spell_has_name_row`（2 行 + 卡名，用 `BossCatalog.set_catalog_override` 注入夹具卡名，不绑真实内容）；原 `test_locked_slot_shows_question_mark` 的「解锁槽第 0 子节点是 Label」假设已不成立，改为断言「解锁非符**不是** Label」。
- **踩坑**：新测试第一版忘了设 `rec.phase_index`（`SpellRecord` 默认 **-1**）→ `phase_at(1, -1, …)` 返回 null → 名字显示 `-`。构记录夹具时 `stage/phase_index/uid/difficulty` 一个都不能漏。
- **验收**：`test_spell_practice_menu` **10/10**；`./tools/verify.sh` 全绿（**511 pass / 511 测试 / 5109 断言 / 0 pending**）。截图肉眼确认：非符三级只剩 `Easy/Normal/Hard/Lunatic + 战绩`，符卡三级仍是「卡名 + No.xxx 难度 战绩」。
- **后续修正（同日，作者报「非符状态下的选项高和符卡状态下不一样」）**：第一版做成「非符**不建**名字行」→ 选项高度从 **81 掉到 33**，切难度时三级会跳。
  - **实测**：符卡选项 = 81（名字行 44 + 难度行 33 + separation 4）；非符 = 33；而 **空 `Label`(font 30) 的最小高仍是 44**。
  - **改**：名字行**始终占位** —— 锁定 `?` / 符卡 卡名 / 非符 **空串**。结果两种状态都是 **81**，四个难度行落点完全重合。
  - **测试**：把「数子节点个数」换成**锁高度一致性** —— `test_diff_option_height_same_for_nonspell_and_spell`（同一 `_diff_box` 先建非符、await 一帧量高，再建符卡量高，断言 `nonspell_h == spell_h` 且非符名字为空）。数行数的断言是脆的，量高度才是需求本身。
  - **验收**：`test_spell_practice_menu` **9/9**；`./tools/verify.sh` 全绿（**510 pass / 510 测试 / 5103 断言 / 0 pending**）。

### 2026-09-23 — 舞台显示名：id 与名字解耦（3 面 B 线 = id 4 + "Stage 3B"）

- **来源**：作者报「哆来咪的 BossData `stage_id` 是 4，但她其实是 stage 3B 的 Boss；符卡练习第一级菜单没法显示这种 stage 名字」。
- **诊断（两层）**：
  1. **全项目没有「舞台名」数据源** —— 菜单第一级把 int 直接拼成 `"Stage %d"`，连 stage 1 也只显示 "Stage 1"。
  2. **`stage_id` 是记录主键**（`SpellRecord.stage`），必须唯一、不能复用，也不该承载「3 面 B 线」这种路线后缀 → 所以 `4` **不是笔误**，而是「3B 的主键」（3 留给 A 线）。**名字才该是给人看的标签**。
- **不做**：在菜单里写 `{4: "Stage 3B"}` 映射 —— 内容知识塞进 UI，违反命名边界契约（机制层引用内容只能走数据资源 / 场景装配 / 内容脚本）。
- **改**：
  - `StageData` 加 `@export var display_name: String = ""`（空 = 回落 `Stage %d`）。
  - `StageCatalog.display_name_of(stage_id)` —— **UI 一律走它**，别自己拼 `"Stage %d"`。
  - 菜单第一级改用 `StageCatalog.display_name_of(stage)`。
  - 新增 `data/stages/stage03B/stage_data/stage03b.tres`：`stage_id = 4` / `display_name = "Stage 3B"`，**不进注册表**（还没有关卡脚本，`StageData.validate` 会拒）→ 走目录扫描。
- **顺带修一个真 bug**：`StageCatalog._load_all()` 只扫 `res://data/stages/` **顶层** `.tres`，而文件实际在 `<面>/stage_data/<面>.tres`（嵌套）→ **扫描兜底从未生效**（`scan` / `all` / `background` 在注册表缺项时全是死路）；且 `find()` 注册表命中不到时**不回退扫描**。
  - 现在：`_load_all()` 递归收 `<dir>/**/stage_data/*.tres`；`find()` 未收录 → 回退扫描。
  - **先写红测试再修**：`test_stage_catalog.test_scan_fallback_finds_nested_stage_data`（置 `registry = null` 强制走扫描），修前返回 null。
- **分工定调（写进代码注释）**：**注册表 = 可玩清单**（`validate` 要求 `create_script`）；**仅命名 / 背景的舞台走目录扫描**。
- **踩坑**：新 StageData 一开始命名 `stage03B.tres` → 命名门禁 ⑦ 抓「文件名不得含 ASCII 大写」（目录 `stage03B` 是拍板豁免的，**文件不是**）→ 改名 `stage03b.tres`（内容按目录扫描找，文件名不参与引用）。
- **验收**：`test_stage_catalog` **2/2**、`test_spell_practice_menu` **10/10**、`test_data_validity` **5/5**；`./tools/verify.sh` 全绿（**514 pass / 514 测试 / 5109 断言 / 0 pending**）。截图确认第一级显示 `Stage 1` / `Stage 3B`。

### 2026-09-23 — 练习菜单第一级左对齐（+ 拆掉一个「名字骗人」的场景属性）

- **来源**：作者要求「第一级菜单的选项向左对齐」。
- **改（代码）**：`_make_label(text, align)` 加对齐参数（默认 CENTER 不动二级），**第一级传 `HORIZONTAL_ALIGNMENT_LEFT`** —— 列表起点对齐比居中好读。
  - **踩坑**：第一版只改了签名没改函数体，参数没用上 → 被 37 条「警告即错误」当场抓住（`The parameter "align" is never used`）。门禁又一次拦住低级错。
- **改（场景）**：作者在 `spell_practice_menu.tscn` 的 `StageBox` 上加过 `alignment = 1` —— 那是 **`BoxContainer.alignment`＝子节点「垂直」排布**，不是文字对齐；结果整列内容垂直居中、首行比二/三级低 **241px**（视觉上像"列飘了"）。按作者选择**删掉该属性**，回到顶部对齐（三列首行齐平）。
  - **教训**：`BoxContainer.alignment` 的名字极易被当成"文字对齐"。文字对齐是 `Label.horizontal_alignment`；容器上的 `alignment` 只管子节点的分布（BEGIN/CENTER/END）。
- **测试**：`test_stage_label_uses_catalog_name` 补一条 `horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT`（锁需求本身）。
- **验收**：`test_spell_practice_menu` **10/10**；`./tools/verify.sh` 全绿（**514 pass / 514 测试 / 5110 断言 / 0 pending**）。

### 2026-09-24 — Boss 符卡背景（每 Boss 一张 2D 层）接通

- **来源**：作者问「boss 的符卡背景相关」，并已画好 `卡摩瑞符卡背景.png`，要求接上。
- **诊断（原状：一条接到一半的管子）**：`PhaseData.background ## 可选换背景` **字段有、运行时 0 消费者、0/10 张 phase 填过** —— 填了没任何反应。
  - 原因：那个字段要的是**整套 3D 背景场景**（`stage01_background.tscn` = Camera3D + WorldEnvironment + 地面网格 + 装饰 + 雾）。给每张符卡做一套，美术成本离谱，所以一直空着。
  - 唯一在跑的是**关卡级**背景：`GameScene._load_background(StageData.background_scene)`；练习模式用 `StageCatalog.background(stage_id)`（还是同一张）。
- **方案（作者拍板「B」）**：**每 Boss 一张 2D 图**压一层，不换 3D 场景。
  - `BossData.spell_background: Texture2D`（每 Boss 一张）
  - `LayerConfig.SPELL_BG := -20`（3D 背景之上、自机子弹 -10 之下）
  - 新 `scripts/scenes/spell_backdrop.gd`（Sprite2D）：`should_show(phase)` 纯函数（**只在符卡期间**，非符不显示）、`apply()` 淡入淡出、`_ready()` 自己定 z / 居中
  - `scenes/game_scene.tscn` 加 `World/SpellBackdrop`：`Background` CanvasLayer 是 **layer = -1**、`World` 是默认 0 → 夹层正好
  - `game_scene.gd`：`boss_spawned` 记当前 Boss → `phase_start` 决定显隐
  - 场地实测 `FIELD_LEFT..RIGHT / TOP..BOTTOM` = **768×896**，而作者的图**正好 768×896** → 居中、不缩放、四边对齐
- **踩坑 1（练习模式丢字段）**：真机验证第一版 `visible=false`。根因：`start_spell_card()` **自建 `BossData.new()`**（只塞 phase/visual/name），`spell_background` 被丢掉。
  - 改：`PracticeSession.spell_background` 随载荷带一张（`start()` 加参数），`game_scene` 优先取 Boss 的、回落取载荷的。
  - **顺带分清职责**：判定归背景层（只问「是不是符卡」），「用哪张图」归调用方。
- **踩坑 2（信号类型谎言）**：`GameEvents.boss_spawned(boss: Enemy)` 实际发的是 `Boss`，而 **`Boss` 与 `Enemy` 是兄弟**（都 `extends Area2D`）—— 全项目接收方都靠 `boss: Node` + `as Boss` 绕（`boss_ui` 就这么写）。本次照同一套路，**未改信号声明**（改了要动 4 处接收方，另议）。
- **踩坑 3（我的测试锁了内容值）**：`test_data_validity` 里写过 `assert_eq(display_name_of(4), "Stage 3B")` → 作者把名字改成全角 `Stage３Ｂ` 后**立刻红**。已改为只锁「配了名、且不等于回落值」—— **名字叫什么不该由测试规定**。
  - 另：`Stage３Ｂ` 的 `３Ｂ` 是**全角**（U+FF13 / U+FF22），疑似中文输入法全角模式误入，已提醒作者。
- **验收**：`test_spell_backdrop` **4/4**、`test_data_validity` **6/6**；`./tools/verify.sh` 全绿（**519 pass / 519 测试 / 5127 断言 / 0 pending**）。
  - **真机验证**：练习模式进卡摩瑞「符卡001」→ `visible=true alpha=1.00 图=768×896`，截图确认图案铺满场地、弹幕压在它之上、场外 3D 背景照旧；随后发一个非符 `phase_start` → `visible=false alpha=0.00`。
- **追加（同日，作者要求「向上无缝滚动」）**：做成 **region 窗口滚动** —— 窗口恒为**场地尺寸**（768×896，所以不溢出场外），`region_rect.position.y` 按 `SCROLL_SPEED`(24 px/s) 递增并对图高取模，配合 `texture_repeat = TEXTURE_REPEAT_ENABLED` 无缝循环。
  - **前提是图本身纵向可平铺** —— 实测作者那张 768×896 的**顶行 vs 底行 758/768 像素（98%）在容差内一致** ✓ 是按平铺画的。
  - 只在显示时滚（`set_process` 随显隐开关），静止态不烧帧。
  - **踩坑**：GDScript 里 `region_rect.position.y = x` **不生效**（值类型返回副本）→ 必须 `var r := region_rect; r.position.y = ...; region_rect = r`。
  - 真机验证：`window.y 82.0 → 155.7`（2 秒），截图确认图案上移且整场连续无接缝。

### 2026-09-24 — 符卡宣言音（`card`）：又一处「注册了没人播」

- **来源**：作者问「可以让符卡在开始的时候播放 card 音效吗」。
- **诊断**：`AssetRegistry.sounds["card"]`（= `assets/Sound/card.wav`）**注册了但全项目无人播放** —— 和 `PhaseData.background` 一样，是条"接了一半"的管子。
- **改**：`boss_ui._on_phase_start()` 里，`phase.uid != 0`（符卡）分支加 `AudioManager.play_sfx(AssetRegistry.sounds["card"])`。该函数本来就是**符卡宣言**的唯一入口（报幕 / 阶段点同在此），所以一行就够；非符分支不动（不放宣言音）。
- **测试**：`test_boss_ui` 加两条（符卡 → 池里出现 `card` 流 / 非符 → 不出现），断言看的是 **SFX 池里 player 的 `stream` 身份**（headless 下 `playing` 标志不可靠）。**2 → 4 用例**。
- **踩坑（探针顺序）**：真机验证第一版打印 `false` —— 我自己的探针 `connect` 得比 `boss_ui._ready()` **早**，于是回调跑在它**前面**，看到的是空池。改 `CONNECT_DEFERRED`（等直连处理器跑完）后 → `池里有 card = true（占用 1 路）` ✓。
  - **教训**：验证"某处理器干了什么"时，探针的**连接顺序**决定它看到的是处理前还是处理后。
- **验收**：`test_boss_ui` **4/4**；`./tools/verify.sh` 全绿（**523 pass / 523 测试 / 5134 断言 / 0 pending**）。

### 2026-09-24 — 修崩溃：玩家数据菜单读不存在的 `SpellRecord.name`

- **来源**：作者贴报错 —— `player_data_menu.gd:103 _collect_cards(): Invalid access to property or key 'name' on a base object of type 'Resource (SpellRecord)'`（主菜单 → 那个页面 → 立刻崩）。
- **根因**：`SpellRecord` 只有 uid / character / stage / phase_index / phase_type / phase_number / difficulty / boss_index / attempts / captures / practice_* —— **没有 `name` 字段**。名字按设计**不存快照**（存了会锁死"首次遇到的那个难度"的卡名），要**现从花名册取**。`_collect_cards()` 却写了 `record.name`。
- **改**：收集时用记录**自己的难度**现取：
  ```gdscript
  var phase: PhaseData = BossCatalog.phase_at(record.stage, record.phase_index, record.difficulty)
  "name": phase.name if (phase and phase.name != "") else "-",
  ```
  （与符卡练习菜单同一套路；`record.phase_index` 就是规范序号，所以 `phase_at` 直接对得上。）
- **测试**：新建 `test_player_data_menu.gd`（该菜单**此前零覆盖**）：造一条 SPELL 记录 → 挂上菜单场景（`_ready` 即走 `_collect_cards`）→ 断言收集到 1 张、名字非空、uid 带出。**这条在修前必然红**。
- **验收**：`test_player_data_menu` **1/1**；真机复现路径不再报错（`卡片数=1 首字名字=卡摩瑞的非符1`）；`./tools/verify.sh` 全绿（**524 pass / 524 测试 / 5137 断言 / 0 pending**）。

### 2026-09-24 — 符卡「发动前走位」：`PhaseData.pre_move_script`（作者选 B）

- **来源**：作者问「可以设置发动符卡**之前** boss 的移动、站位吗」。原时序是：宣言（报幕/card 音效/符卡背景）**立刻**发生 → 1 秒涨血（无敌）→ move/shoot 才起跑。**"发动前"根本没有槽位**。
- **方案（作者拍板 B：做成数据）**：
  - `PhaseData.pre_move_script: Script` —— 宣言**之前**跑完的移动脚本（空 = 不等待，宣言立即发生）。
  - `Boss.start_phase()` 拆成两段：前半保留（校验/血条/身份/记录）→ `if data.pre_move_script: await _run_pre_move(data)` → **`_declare_phase(data)`**（emit `phase_start` + 涨血 tween + 启动 move/shoot，即原后半段整体搬过去）。
  - `_run_pre_move()`：`new()` → `add_child` → `_apply_phase_params` → `start(ctx, self)` → `await pre.finished` → `queue_free`。跑完前若 `_phase_data` 已被换掉（或 Boss 已亡）→ **放弃这次宣言**（防幽灵宣言）。
- **踩坑（夹具写法）**：`CoroutineScript.auto_stop` **默认 false**（持续运行语义）—— `_tick` 返回 false **不会**结束脚本。做"跑一下就结束"的夹具必须在 `_init()` 里 `auto_stop = true`，否则测试/验证会挂住。
- **测试**：`test_boss_phase` **16 → 18**：① 配了 pre_move → 走位没跑完**不宣言**、跑完才宣言；② 没配 → **立刻**宣言（不引入额外延迟）。
- **真机验证**：把夹具走位挂到符卡001 → 宣言推迟到 **+1895 ms**（无走位时≈0），且 Boss 在宣言前已移位（x 448 → 424）。
- **示例脚本（作者要）**：新增 `data/boss_scripts/move/move_to_point.gd` —— 走到指定站位后**自己结束**（`dest` 默认 `(448, 240)`、`move_time` 1.2s，可用 `params` 覆盖）；带 `const META` 所以创作台目录里能选到。
  - **真机验证**：挂到符卡001 → Boss 精确停在 **(448.0, 240.0)**，宣言发生在走位之后 ✓
  - 写法要点（都可当模板）：`_init()` 里 `auto_stop = true`；`_tick` **第一轮**起 tween 并 `return p_ctx.clock.wait(move_time)`，**第二轮**返回 `false` 结束 —— 这样"等位移走完"和"结束"各占一轮，不用手写计时。
  - 使用说明写进 `CONTENT_GUIDE.md`（含"必须能结束"的铁律与 `auto_stop` 默认 false 的坑）。
  - **`params` 可用（已实测）**：`_run_pre_move()` 在 `start()` **之前**注入 `_apply_phase_params(pre, data.params)`，所以 pre_move 与 move/shoot 走同一条注入链。实测 `{"dest": Vector2(300,200), "move_time": 0.4}` → Boss 停在 **(300.0, 200.0)** ✓
  - ⚠️ **但 `params` 是**同一阶段共用的一份字典**（pre_move / move / shoot 拿到同一个）→ **键名会互相干扰**：示例的 `move_time` 与 `random_dir_move.gd` 同名，同阶段并用时两者拿到同一个值。已写进 `CONTENT_GUIDE.md`。
- **验收**：`test_boss_phase` **18/18**；`./tools/verify.sh` 全绿（**526 pass / 526 测试 / 5140 断言 / 0 pending**）。截图确认第一级左对齐且首行与二级齐平。

### 2026-09-23 — 三列布局：「空」要按**文字边缘**算，不是按**列框**算

- **来源**：作者左对齐第一级后觉得「两边的空不对称」，于是改了场景锚点（`StageBox` 0.1/0.3 → 0.25/0.45，`DiffBox` 0.7/0.9 → 0.65/0.85）。
- **实测**（脚本量「一级文字左缘」与「三级战绩右缘」，视口 1280）：

  | 版本 | 左空 | 右空 | 对称 | 列框重叠 |
  |---|---|---|---|---|
  | 作者改后 | 320 | 192 | ❌ 差 128 | ⚠️ **64px** |
  | 原锚点 | **128** | **128** | ✅ | 0 |

  - **原锚点本来就是对称的**：左对齐后一级文字贴列框左缘 → 128；三级战绩右对齐到 1152 → 右空 128。正好 **128/128**。
  - **把列框整体右移反而更不对称**：左空涨到 320，右空只降到 192；而且 `StageBox`(320..576) 与 `PhaseBox`(512..768) **列框重叠 64px** —— 潜在问题：舞台名一长就会撞进第二列。
- **改**：锚点改回 `StageBox 0.1/0.3` + `DiffBox 0.7/0.9`（`PhaseBox` 一直是 0.4/0.6），一级保持左对齐。实测 **128/128、重叠 0、`align=0`**。
- **认知（值得记）**：「空」的度量基准必须跟**内容对齐方式**一致 —— 左对齐就量**文字左缘**，居中才量**列框中心**；两者混用会得出"不对称"的错误结论，然后越修越歪。
- **遗留（给作者选）**：三列**内部对齐不一致**（一级左、二级居中、三级卡名居中 + 难度行左）才是"看着不匀"的真正来源。彻底整齐的做法是**三列统一左对齐** —— 已渲染对照：`StageBox 0.1/0.3` + 二级/三级也 `LEFT` → 列距 384 均匀、左右仍 128/128。
- **后续（同日，作者拍板）**：**一级改回居中**（左对齐试过一轮后不要了）。代码整体回退（`_make_label` 去掉 `align` 参数、调用点不带参），锚点保持 `0.1/0.3` + `0.7/0.9` 不变。
  - **居中时的度量基准反过来**：按**列框**算 —— 三列框 128..384 / 512..768 / 896..1152 → 左右各 128 ✅；中间列中心 640 = 屏幕中心 ✅。（左对齐时才是量文字左缘。）
  - 测试里那条「一级左对齐」断言**删掉**：对齐是纯视觉偏好，锁了只会在调整时白红；`test_stage_label_uses_catalog_name` 只保留「名字来自 `StageCatalog`」这条真契约。
- **验收**：`test_spell_practice_menu` **10/10**；`./tools/verify.sh` 全绿（**514 pass / 514 测试 / 5110 断言 / 0 pending**）。

### 2026-09-24 — 修「符卡练习：结算菜单与主菜单同时出现」

- **来源**：作者报「符卡练习里，快击破 Boss 前中弹 → 结束菜单会和主菜单一起出现」。
- **根因（两条结算路各走各的，而 overlay 挂在 autoload 的菜单栈上、切场景后仍在）**：
  - **中弹** → `GameScene._on_player_death()` → **`await 2 秒`** → `push_overlay_menu(Game Over)`
  - **击破** → `_on_practice_cleared()` → 立刻 `change_scene(主菜单)`
  - 死亡那 2 秒内击破 → 主菜单先出现；**2 秒后** Game Over 又叠上去 ✗（另一个场景早已不在，但 overlay 是 autoload 的，不受影响）。
- **改**：`GameScene` 加**结算闸门** `_ending`：**谁先到谁生效，其余一律放弃**。
  - `_on_player_death()`：入口查一次；**await 之后必须再查**（`_ending or not is_inside_tree()`）—— 关键闸门就在这 2 秒之后。
  - `_on_practice_cleared()` / `_on_stage_cleared()`：入口查 + 置位（同类第三条路一并纳管）。
- **验证**（脚本复现该竞态）：中弹 → 0.5s 后模拟击破结算（置 `_ending`）→ 再等 2.5s（越过死亡路的 2 秒）→
  `GameManager._menu_nav.is_overlay_open() = false` ✅ **没叠菜单**（`_menu_nav` 虽私有但可观测，正好当断言点）。
- **验收**：`./tools/verify.sh` 全绿（**526 pass / 526 测试 / 5143 断言 / 0 pending**）。
- **同类隐患（尚未处理）**：`_on_player_death` 的 2 秒是**写死的等待**；若这段时间里发生了别的场景切换（如暂停菜单里退出），闸门能挡住叠加，但"为什么要等 2 秒"本身没有配置项。

### 2026-09-24 — 示例②：对角扫场（右上角 → 左下角，快慢快）

- **来源**：作者要「boss 发动符卡时，立绘从游戏框右上角移到左下角，快慢快」。
- **实现**：`data/boss_scripts/move/corner_sweep.gd`（同为 `pre_move_script` 用途）。
  - 起点 `(FIELD_RIGHT, FIELD_TOP)` = 右上角、终点 `(FIELD_LEFT, FIELD_BOTTOM)` = 左下角（R17：不写死 832/32/64/928）。
  - **快慢快 = 两段 tween 接力**：前半 `TRANS_QUAD + EASE_OUT`（快→慢）到**中点**，后半 `EASE_IN`（慢→快）到终点；中点正好是场地中心 → 视觉上「冲到中央、缓一下、再冲出去」。
  - 参数：`move_time` / `hold_middle` / `from_corner`（默认先瞬移到右上角再起跑）。
- **踩坑（命名门禁）**：局部变量取名 `start` → **遮蔽基类 `CoroutineScript.start()` 方法**，被"警告即错误"拦下（`is shadowing an already-declared function`）→ 改名 `corner`。
- **验证（量速度曲线）**：只采"运动窗口"（位移连续 > 0 的帧），96 帧 = 1.6s ✓
  - 起 `(816,50)`（瞬移后第 1 帧）→ 终 **`(64,928)` = 左下角** ✓
  - **每帧位移：前段 17.2 → 中段 0.3 → 后段 17.2** = **快→慢→快** ✅
  - 教训：第一版探针把**移动结束后的静止尾巴**也算进统计，中段读到 0 而误判 —— 量速度曲线要先切出运动窗口。
- **验收**：`./tools/verify.sh` 全绿（**526 pass / 526 测试 / 5146 断言 / 0 pending**）。

### 2026-09-24 — 符卡宣言立绘（每 Boss 一张，右上→左下 快慢快 → 淡出）

- **来源**：作者要「boss 发动符卡时，**立绘**从游戏框右上角移到左下角，快慢快」。
  - **我先理解错了**：以为挪的是场上 Boss（改了 `pre_move_script`）。作者纠正「是立绘不是 boss」🥺 —— 项目里**立绘**是对话系统那套（`dialogue_box.gd` 的「立绘 + 气泡」），而 `kamorui1–4.png` 这几张立绘**此前没有任何地方引用**：**战斗中的立绘这个元素根本不存在**，得新加。
- **方案（作者三选，全按推荐）**：`BossData.portrait` + 战斗内立绘层 + 扫描后淡出 + 层级在**弹幕之下**。
  - `BossData.portrait: Texture2D`（每 Boss 一张）
  - `LayerConfig.SPELL_PORTRAIT := -15`（符卡背景 -20 之上、自机子弹 -10 之下）
  - 新 `scripts/scenes/spell_portrait.gd`：`sweep(tex)` —— 右上角 `(FIELD_RIGHT, FIELD_TOP)` 起，两段 tween 接力（`EASE_OUT` 到中点 + `EASE_IN` 到左下角），再 `FADE_SEC` 淡出隐藏；重复调用被 `_busy` 忽略
  - `scenes/game_scene.tscn` 加 `World/SpellPortrait`；`game_scene._on_phase_start()` 里 `_spell_portrait.sweep(_resolve_spell_portrait(phase))`（只在符卡期间；练习模式回落 `BossCatalog` 现查）
  - 内容：卡摩瑞道中 / 关底 的 `portrait` 都挂 `kamorui1.png`（可换）
- **踩坑（两次静默失败的 .tscn 编辑）**：我用**精确字符串**替换 `game_scene.tscn`，但**作者在编辑器里保存过场景** → Godot 给节点补了 `unique_id=`、给 ext_resource 补了 `uid=` → 两处替换**都没匹配上却静默通过**：结果 `ext_resource` 缺行、`%SpellPortrait` 为 null，启动验证直接红 ✗
  - **教训**：改 `.tscn` 一律用**子串/行锚点**并 **assert 命中**，别用整行精确匹配（编辑器随时重排）。
- **验证**：`test_spell_portrait` **3/3**（层级三断言 / 右上角起跑+淡出隐藏 / 空图与重入守卫）；真机：立绘节点存在、`(832,32)` 起 → 中点 ≈`(448,480)` → 末 `(64,928)`，可见→淡出。
- **验收**：`./tools/verify.sh` 全绿（**529 pass / 529 测试 / 5157 断言 / 0 pending**）。

### 2026-09-24 — 自机 Bomb 立绘 / 符卡背景渐隐 / 根治练习模式丢字段（三合一）

- **自机 Bomb 立绘（作者要求：左下 → 右上，与 Boss 镜像）**
  - `spell_portrait.gd` 抽出内部 `_sweep(tex, corner, dest)`，对外两个命名入口：`sweep()`（Boss 右上→左下）/ `sweep_from_bottom_left()`（自机 左下→右上）—— **快慢快与淡出逻辑只有一份**。
  - `PlayerData.portrait: Texture2D`（新字段）；`game_scene.tscn` 加 `World/PlayerPortrait`；`game_scene` 接 `GameEvents.player_bomb(player_spell_name)`；内容：`reimu_data.tres` → reimu1.png、`marisa_data.tres` → marisa1.png。
  - **踩坑（.tres 属性顺序）**：把 `portrait = ExtResource(...)` 插到 **`script = ` 之前** → Godot **静默丢弃**该属性（不报错！）→ 真机上"没扫场也没报错"。**规矩：`[resource]` 段 `script = ` 必须最先。**
- **符卡背景应在符卡结束时渐隐（作者要求）**
  - 原来只在 `phase_start` 更新 → 背景会挂到下一阶段。现接 `GameEvents.phase_end` → `_spell_backdrop.clear()`（走背景层自己的 `FADE_SEC`）。
  - 行为变化：**连符卡之间**现在会"淡出→再淡入"（更接近东方观感）。
- **根治：练习模式自建 BossData 丢字段**
  - 根因：`StageRuntime.start_spell_card()` 自建 `BossData.new()`（只塞 phase/visual/name）→ `spell_background` / `portrait` 这类字段全丢。为此 `PracticeSession.spell_background` 与 `_resolve_spell_portrait()` 的练习回落各绕了一次。
  - 改：`start_spell_card(..., p_data: BossData = null)`，给了就用**真 BossData 的 duplicate()**（阶段表收敛成"就这一张卡"，不改原资源）；`GameScene._start_practice_game()` 用 `BossCatalog.boss_of_phase(stage_id, phase_index)` 现查后传入。
  - 验证：练习 Boss 的 `BossData` → 名=卡摩瑞、**立绘=true、符卡背景=true、阶段表=1** ✓
  - 遗留：两处练习回落（`PracticeSession.spell_background` / `_resolve_spell_portrait` 的 BossCatalog 分支）现在成了**冗余兜底**，可择机删。
- **同一个错的第 4 次：测试锁了"可调数值"**（这次是作者在调手感时被门禁挡住）
  - `test_spell_portrait` 断言立绘起点 `(832,32)`，而作者把两个角常量外扩到框外 ±(200,150)、时长改成 2.0/0.25 → **4 条红**。改成锁「**用哪个常量 + 朝哪边走**」（起点 == `PORTRAIT.CORNER_*`、x/y 增减方向）→ 以后调手感不再红。
  - `test_recent_mechanics.test_open_reduce_default_off` 断言默认 `open_reduce_time == 0`（"默认关闭"），作者把默认调成 **3.0** → 红。改成锁**不变量**（时长非负、比例 0~1）。
  - **沉淀**：测试要锁的是**契约与不变量**；**数值、坐标、默认值、内容名字**都是作者会调的，锁了就是给门禁埋雷。
- **验收**：`./tools/verify.sh` 全绿（**531 pass / 531 测试 / 5211 断言 / 0 pending**）。

### 2026-09-24 — 音效音量均衡（`AssetRegistry.SFX_DB`）

- **来源**：作者问「有没有办法处理 Godot 里声音资源的音量，感觉不均衡」。
- **病根（量出来的，不是猜的）**：全项目 17 个音效，**几乎每个调用点都写死同一个 `-12.0`**（`item` / `enemy_die` / `graze` / `player_shoot` / `player_card` / `normal_damage` …）→
  相对响度**完全由 wav 自身电平决定**，且**没有一处能统一调**。
  - 实测各 wav 的 RMS 从 **-5.5 dBFS（`normal_damage`）到 -18.6 dBFS（`marisa_damage`）＝ 13 dB 落差** ✗ 这就是"不均衡"的来源。
- **改（R17 + 零调用点改动）**：
  1. 脚本量每个 wav 的 RMS（注意：这批音源多是 **8-bit PCM**，不是 16-bit），向 -20 dBFS 对齐后**减去全表均值**（中心化）→ 生成 `AssetRegistry.SFX_DB`（dB，均值≈0）。
     **中心化的意义**：调用点原有的 `-12.0` 仍是**总电平**，表只表达**相对**关系 → 一个调用点都不用改。
  2. `AudioManager.play_sfx()` 里加 `_base_db(stream)`：首次用时把 `sounds` 反查成 `stream → dB`，播放时叠加。
- **怎么调**：觉得哪个音不对，**只改 `SFX_DB` 里那一行**，不用碰播放代码。
- **测试**（`test_sfx_mix`，只锁不变量不锁数值）：① 每个音效都有基准 dB（漏一个就退回老问题）② 整表中心化（均值≈0，否则总音量被整体推高/压低）③ 基准值 ±12 dB 内（超出说明音源电平异常，该查源文件）。
- **验收**：`test_sfx_mix` **3/3**；`./tools/verify.sh` 全绿（**534 pass / 534 测试 / 5247 断言 / 0 pending**）。
- **作者手调（同日）**：`kira` +1.7 → **-1.5**（-3.2 dB）、`player_shoot` +3.2 → **+0.2**（-3.0 dB）。
  - `kira` 印证了 RMS 平齐的局限：**高频短促音**在同等 RMS 下听感更响（人耳 2–5 kHz 最敏感）。
  - `player_shoot` 属**持续音**（连打时一直在响）→ 疲劳感强，压到略高于平均。
  - 这就是这张表的设计用途：**只改一行**，不动播放代码、不动调用点；调完 `test_sfx_mix` 只校验不变量（每音效都有值 / 中心化 / ±12dB），**不拦你调数值**。
  - 再调：`shoot` -2.4 → **+0.6**、`player_card` -1.1 → **+1.9**（各 +3.0 dB；作者要求这两个更突出）。
- **`-12` 收进默认值（作者要求「不想每次都写一个 -12」）**
  - `AudioManager.SFX_LEVEL_DB := -12.0` —— **总电平有了名字**（原来 17 处调用点各写一遍魔术数字）。
  - `play_sfx(stream, volume_db := SFX_LEVEL_DB, min_interval := 0.0)`：不传就是它；需要节流的高频音走新入口 `play_sfx_throttled(stream, min_interval)`（总电平仍走默认）。
  - 包装层（`ctx.audio.play_sfx` / `Player._play_sfx`）默认值同步；弹幕 DSL 的 `lc.sfx(key, db)` 默认值也指向同一常量。
  - **落地**：17 处调用点 + 内容脚本 6 处手写的 `-12.0` 全部清掉（`grep -rn -- '-12\.0' scripts/ data/` 现在只剩常量定义与注释）。
    副作用正好：前两次下压让均值漂到 -0.36，这次抬两个把均值拉回 **≈0** ✓

### 2026-09-24 — 练习模式没有 BGM（作者："符卡练习里声音怎么那么大"）

- **诊断**：BGM 是**关卡脚本**起的（`StageDirector.bgm(key)` ← `stage01.gd` 的 `timeline.do(...)`）。练习模式**没有关卡脚本**，而且进练习前还主动 `AudioManager.stop_bgm()` → **只有 SE、完全没有 BGM** → 没有音乐衬托，SE 听着"特别大"。
  - 顺带排除：`SFX_DB` 节流没丢（`play_sfx_throttled` 三处仍在）、`apply_settings()` 正常应用存档音量 —— 不是回归。
- **改（数据驱动，R17）**：BGM key 是**语义字符串**（`stage1` / `stage3B`），而 `stage_id` 是 int（3B 的 id 还是 4）→ **不能机械映射**，所以把它放进关卡数据：
  - `StageData.bgm_key: String`（新字段）；`stage01.tres → "stage1"`、`stage03b.tres → "stage3B"`（3B 没有可玩 StageData，靠目录扫描查到 ✓）。
  - `GameScene._start_practice_game()`：`StageCatalog.find(stage_id).bgm_key` → `AssetRegistry.get_bgm(key)` → `AudioManager.play_bgm(...)`。
- **测试（不变量，不锁曲名）**：`test_data_validity` 加一条 —— **填了 bgm_key 就必须能解析出曲目**（防改名/删曲后练习静默没声），并确认 3B（stage 4）能从目录扫描查到。
- **真机验证**：练习模式 `BGM playing=true`、曲目正确 ✓
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 练习模式音效偏大（作者反馈，收尾）

- **来源**：作者报「符卡练习里的游戏声音怎么那么大」，我先误修了 BGM（补上练习 BGM 本身是对的，见上一条），作者澄清**指的是音效**。
- **两层原因**：
  1. **感知层（主因）**：练习模式原本**完全没有 BGM**，SE 没有音乐衬托 → 同样的 dB 听着更响。上一条补 BGM 后应明显缓解。
  2. **绝对层**：`AudioManager.SFX_LEVEL_DB`（全局 SE 总电平）原为 -12.0，作者认为整体偏大。
- **改**：`SFX_LEVEL_DB` **-12.0 → -15.0**（-3 dB）。
- **调音量的两个旋钮（写进注释）**：
  - 觉得**所有**音效整体偏大/偏小 → 动 `SFX_LEVEL_DB`（一个数，3 dB ≈ 明显一档）
  - 只嫌**某一个**吵 → 动 `AssetRegistry.SFX_DB` 里那一行
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 修「符卡练习里**弹幕音效**格外大」

- **来源**：作者先报"练习里声音大"，我先误修了 BGM（补练习 BGM 本身该做，但不是这条）；作者澄清是**弹幕音效**格外大。
- **根因**：弹幕音效走 **lifecycle 事件**那条路（`kernel_native_system` 的 `sfx` 事件 → `AudioManager.play_sfx(stream, vals[k])`）—— **只靠"同帧同音去重"，没有最小间隔**。
  内容里 `lifecycle.sfx(&"kira")` 是**每颗子弹**发一次（`卡摩瑞一符.gd` 等 6 处）→ 同一帧去重后仍可到 **~60 次/秒** 的同一个音 = **机关枪** ✗ 听感上就是"格外大"。符卡练习里弹幕最密，所以这里最明显。
- **改**：`AudioManager.BULLET_SFX_MIN_INTERVAL := 0.05`（最多 ~20 次/秒），弹幕 sfx 事件接入该节流。
- **连带**：上一条被中断的命令**其实已落盘** `SFX_LEVEL_DB = -12.0 → -15.0`（全局 SE 总电平 -3 dB）—— 本轮补上门禁验证与注释。
- **调音量的三个旋钮**（写进注释）：
  1. 所有音效整体大小 → `AudioManager.SFX_LEVEL_DB`
  2. 某一个音效偏大/偏小 → `AssetRegistry.SFX_DB` 里那一行
  3. **弹幕音效太密/太吵** → `AudioManager.BULLET_SFX_MIN_INTERVAL`
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — kira 仍偏大：把两个旋钮一次性调到位

- **来源**：作者再报「符卡练习的 kira 音效还是很大」（前一次只把密度 60→20 次/秒 ≈ 5 dB，降得太保守）。
- **kira 的播放点普查**（先确认没漏）：
  1. `lifecycle.sfx(&"kira")` —— **每颗子弹**一次（`卡摩瑞一符/一非/二非/道中一非`、`哆来咪三符` 共 5 处）← 主犯
  2. `enemy04.gd` 的 `radial_accel(..., &"kira", -18.0)` ← 自带 -18 dB，已很低
  3. `enemy02.gd` 一处一次性播放
  4. `Player._memory_release()` 一次性播放（记忆解放）
  5. 原生事件编码确认**没有偏移/量化**（GDScript `[sid, db]` ↔ C++ `_ev_val.push_back(a[1])`），所以 `vals[k]` 就是 dB ✓ 不是编码问题。
- **改**：① `AssetRegistry.SFX_DB["kira"]` **-1.5 → -6.0**（-4.5 dB）② `BULLET_SFX_MIN_INTERVAL` **0.05 → 0.08**（60 → 12 次/秒）。
- **根治建议（留待作者定）**：`kira` 在**密集弹幕**里逐颗播放，本质是内容选择 —— 引擎侧节流只是兜底。若还想更干净，把那些 lifecycle 里的 `sfx(&"kira")` 去掉或改成只在"反弹"时发（东方原作的反弹音就是稀疏的）。
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 符卡练习 SE 场景级压低（作者的反馈优先于我的测量）

- **背景**：作者连报三次「符卡练习里 kira/音效格外大」。我查了/量了：单次播放 dB、`sfx_volume`、Master/SFX 总线 —— **全都与正常流程一致**；实战 5 秒探针甚至**没抓到 kira 从 AudioManager 池里播过**（说明探针**没跑到真实路径**，多半是扩展/参考实现的差异）→ **我的测量不足以证明"没问题"**，不该拿它反驳作者 ✗。
- **处置**：不再追根因，直接给**场景级**修法 —— 正常流程的混音**一个数都不动**：
  - `AudioManager.sfx_trim_db: float = 0.0`（额外压低 dB，<=0），并入 `play_sfx` 的音量计算。
  - `GameScene.PRACTICE_SFX_TRIM_DB := -6.0`；`_start_practice_game()` 置位，`_exit_tree` 归零（防漏到下一局）。
  - 还是大就往更负调（-6 → -9 → -12），**一个常量**。
- **教训（重要）**：当局者（作者）反复报同一个现象、而我的测量复现不出来时，**该先怀疑自己的测量方法，而不是对方的耳朵**。这次绕了三轮才转到"先按作者说的修"。
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 真凶：`lc.sfx()` 的 `db` 默认 0.0（= 满音量，比正常大 15 dB）

- **来源**：作者第四次坚持「就是 `lc.sfx()` 的声音大」。前三次我都在改**音量表**（`SFX_LEVEL_DB` / `SFX_DB` / 节流），全部无效 —— 因为**这条路压根没走音量表**。
- **根因**：`BulletLifecycle.sfx(key, db := **0.0**)` —— `0.0 dB` 不是"未设置"，是**满音量**；而内容里普遍写 `lc.sfx(&"kira")` **不传 db** → 拿到 0.0，比应有的 `SFX_LEVEL_DB`(-15) **大 15 dB** ✗
  - `LifecycleCatalog` 的 radial 预设兜底也是 `0.0` —— 同一个坑，一并修。
- **修**：`sfx(key, db := AudioManager.SFX_LEVEL_DB)`；catalog radial 兜底同样改常量。
- **实测**：`lc.sfx(&"kira")` 实际播放 **-9.1 → -24.1 dB** ✓（显式传 db 的不受影响 ✓ preset `bounce` 也走对 ✓）
- **撤补偿（作者定，按序）**：① 练习场景压低 `-6 → 0`（本次，旋钮保留）→ ② `kira` 基准 `-6.0 → -1.5` → ③ 总电平 `-15 → -12`。逐步回退、逐步试听，避免一次退过头。
- **教训（重要，写进认知）**：
  1. **`0.0 dB` 不是"没设置"** —— 把 0.0 当"未指定"用作默认值，是"某个音莫名大 15 dB"的经典成因。
  2. 作者反复指着同一个地方说"就是它"时，**先去读那条路的代码**，而不是继续调我自己以为相关的旋钮 —— 这次绕了四轮。
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 撤补偿 ③：全局 SE 总电平回到 -12.0

- 真凶修好后按序回退补偿：**① 练习场景压低 -6 → 0**（上一条）、**③ `SFX_LEVEL_DB` -15 → -12**（本次，+3 dB 全局）。
- **② 暂未回退**：`AssetRegistry.SFX_DB["kira"]` 仍是 **-6.0**（原值 -1.5）。现在 `kira` 与其它音走**同一条公式**（`总电平 + 基准 + sfx_volume`），继续额外压它会让它偏小 —— 留待作者听感决定。
- **当前混音三层（都只影响各自范围）**：
  1. `SFX_LEVEL_DB = -12.0` 全局总电平
  2. `AssetRegistry.SFX_DB` 每音效相对基准（`kira` 仍是 -6.0 的保守值）
  3. `AudioManager.sfx_trim_db`（场景级，当前 0.0）+ `PRACTICE_SFX_TRIM_DB`（练习专用，当前 0.0）
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 手调：player_shoot 偏大 / 菜单音偏小（③ 之后的再平衡）

- **来源**：撤 ③（全局 +3 dB）后作者反馈「player_shoot 又大了，菜单相关的又小了」。
- **改**（都是 `AssetRegistry.SFX_DB` 的一行，±3 dB 一档）：
  - `player_shoot` -2.8 → **-5.8**（持续音，随全局 +3 一起变大了）
  - `select` -4.7 → **-1.7**、`cancel` -3.0 → **0.0**（菜单导航/返回）
- **为什么菜单音会偏小（RMS 表的第二类系统性偏差）**：
  - `kira` 那类是「**短促高频 → RMS 低估 → 表里偏高 → 听着更响**」；
  - 菜单点击音是「**极短促 → RMS 高估 → 表里偏低 → 听着偏小**」✗ 同一张 RMS 表的两个反向失真。
  - 结论不变：**RMS 只是起点，最终以耳朵为准**；这张表就是为"事后手调"设计的。
- **验收**：`./tools/verify.sh` 全绿（**535 pass / 535 测试 / 5251 断言 / 0 pending**）。

### 2026-09-24 — 从符卡练习返回 → 回到练习菜单的**第三级**（而不是主菜单）

- **需求**：作者要求「从符卡练习界面返回时，回到符卡练习菜单的第三级菜单，而不是直接到主菜单」。
- **为什么原来回主菜单**：练习页是 `GameManager.push_page(...)` 压进菜单栈的**子页面**；开练习时整个场景被 `change_scene(game_scene)` 换掉，菜单栈虽然还在（`MenuNav` 由 autoload 持有），但**游戏场景不在栈里** → 离开时只能 `change_scene(main_menu)`，落回主菜单**根**、且练习页的状态已丢 ✗
- **改（四层配合，共 ~40 行）**：
  1. `PracticeSession.return_menu_state: Dictionary` —— 开练习前写入 `{section=DIFF, stage, phase, diff, char}`；**故意不在 `clear()` 里清**（必须活过 `finish() → clear()` 的会话拆除）。
  2. `SpellPracticeMenu._restore_return_state()` —— 在 `on_enter` 建完列表后调用：按状态逐级重建（`_build_phase_list()` → `_build_diff_list()` → `_highlight()`），**消费后清空**（所以放哪都安全：清空后再调是 no-op，不会在切角色时误跳级）。
  3. `GameManager.pending_page_path` + `MainMenu._consume_pending_page()` —— 换场景后自动把某页压回来（通用机制，不只服务练习）。
  4. `GameScene._on_practice_cleared()` —— 不再回主菜单根，改为设 `pending_page_path = 符卡练习页` 再换场景。
- **测试**：`test_spell_practice_menu` **10 → 12**：① 有待还原状态 → `_section` 回到 DIFF(2) 且状态被消费；② 无状态 → **no-op**（正常进入不受影响）。
- **未覆盖（待作者确认）**：我做的是**练习结算/离开**这条路；若作者指的是**暂停菜单里的"返回"**，那条路我这次没找到（`scripts/ui/pause_menu.gd` 里没有 `change_scene`/`main_menu`），需要把同样的两行（设 `pending_page_path`）接到那个入口 —— 请指一下文件或确认走哪条路。
- **验收**：`./tools/verify.sh` 全绿（**537 pass / 537 测试 / 5254 断言 / 0 pending**）。

### 2026-09-24 — 修「正常进入符卡练习也跳第三级」+ Game Over 返回接上

- **作者反馈两点**：① 返回其实是走 **Game Over** 那条路（不是结算路）；② 我上一版让**从主菜单正常进入**符卡练习也直接进第三级 ✗（我引入的 bug）。
- **② 的根因（残留状态）**：`return_menu_state` 是 static ✗ 上一局写进去后，若离开时**没经过还原**（如 Game Over → 主菜单），它就**留着** ✗ 下次正常进入菜单 → `_restore_return_state()` 看到"有状态"就还原 → **直接跳第三级** ✗
  - **改：把"还原"从"有状态就还原"改成"本次是返回才还原"** —— 加一次性授权 `PracticeSession.restore_menu_on_enter`（仅返回路置 true）；
    且 `_restore_return_state()` **无论是否真还原，都把状态与授权一起消费** → 残留不可能再泄漏 ✓
- **① Game Over → 练习菜单第三级**：`game_over_menu.gd` 的返回分支加练习模式判断 —— 置 `restore_menu_on_enter` + `pending_page_path = 符卡练习页` 再回主菜单场景（主菜单加载后自动压回练习页并还原层级）✓
  - 顺带把**结算路**（`_on_practice_cleared`）也补上同一个授权标志，两条路一致 ✓
  - 暂停菜单（`pause_menu.gd:40`）也有同样的"返回主菜单"分支，**未改动**（"返回主菜单"可能是刻意退出 ✗）—— 要一起改说一声 ✓
- **测试**：`test_spell_practice_menu` **12 → 13** —— 新增**回归测试**「残留状态但未授权 → 不跳级，且残留被清掉」（就是作者报的 bug）✓
- **验收**：`./tools/verify.sh` 全绿（**538 pass / 538 测试 / 5256 断言 / 0 pending**）。

### 2026-09-24 — 「从练习返回」收尾：又修 4 个 bug（全是"我以为等价"）

作者逐条实测反馈出来的，按出场顺序：

1. **`MenuNav: 未注入 PageHost`** —— 时序 ✗
   `MainMenu._ready()` 里 `PageHost` 在**第 41 行**才 `set_page_host`，而我把压页插在第 24 行 → 被拒。
   → 改为「**先同步藏容器**（第 24 行附近）→ `set_page_host` 之后**立刻**压页」。
2. **主菜单列与练习页重叠** —— 绕过了既有路径 ✗
   我直接 `GameManager.push_page()`，丢掉了主菜单开页时的 `_deactivate_title()`（淡出+隐藏选项列）。
   → 改为走主菜单自己的 `_open_page()`。**教训：有现成入口就别自己拼等价调用。**
3. **选项列先闪一下** —— "藏"和"压"的时机要求不同 ✗
   隐藏必须**同步**（不能是 0.12s 淡出 ✗），压页必须**等 PageHost**；拆成"先藏、后压"两处才对。
4. **返回后第二级菜单显示错** —— 只赋 index 没重建数据 ✗
   还原时只写 `_stage_index` 再 `_build_phase_list()`，但 `_phases` 还是上一个 stage 的 ✗
   → 改用 `_change_stage()`（设 index + 重建 `_phases` + 建二级）。
   **这是"切 stage 不重建二级"的第二次** —— 两处现已收敛到同一个入口。
5. **暂停菜单返回**也接同一条路（`is_practice_mode` 判断保证逐面练习/正常游戏不受影响）✓

- **四条路最终**：Game Over / 暂停 / 练习结算 → 练习菜单**第三级**；主菜单正常进入 → 第一级；逐面练习与正常游戏 → 主菜单（未受影响）。
- **仍未加测试**：本轮的 UI 时序（闪一帧/重叠）与"暂停返回"无法自动验证（需要真实暂停流程）✗ 已在交接说明里注明；「残留状态」有回归测试 ✓
- **验收**：`./tools/verify.sh` 全绿（**538 pass / 538 测试 / 5256 断言 / 0 pending**）。

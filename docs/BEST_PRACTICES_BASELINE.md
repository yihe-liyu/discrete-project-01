# 项目基线（STG 品质需求 × 工程红线）

> 本文件只记 **"项目当前状态"**，不记变更历史。用法：
> - 主轴 **STG 品质需求（S1–S13）** = "我想做出什么样的东方弹幕游戏"，这是目的地。
> - 横切 **工程红线库（R1–R22）** = "怎么写才符合 Godot 最佳实践"，这是护栏，服务于上面的需求。
> - 每个需求下：**状态** 打勾 ✔/🚧/✘，并列出**适用的工程红线 ID**（不重复原文，避免膨胀）。
> - 改动**状态** → 更新本行；记录**心得/为什么这样改/没抄旧版什么** → 追加到 BEST_PRACTICES_LOG.md。
> - 目标：本文件随项目成熟 **只收敛、不膨胀**；TODO 小节最终清空。
> - 旧项目改造前审计快照见 BEST_PRACTICES_BASELINE_OLD_AUDIT.md（留底，不随重建更新）。
> - **同步说明（2026-09）**：红线库 / 帧序·层序·命名边界契约已与重建版 `BEST_PRACTICES_BASELINE.md` 对齐；S 小节状态沿用原项目自评，**尚未逐条重审**——重审并入 `NEW_KERNEL_REFACTOR_PLAN.md` 的**轨道 B**。

---

# 工程红线库（R1–R21）（护栏，原则只写一次）

| ID | 红线 |
|----|------|
| R1 | 场景可独立运行（F6 能跑），零外部硬依赖 |
| R2 | 依赖由父级/上下文向下注入；禁止 get_node("..") / current_scene.find_child() 全树搜 |
| R3 | 有**场景期**外部依赖用 @tool + _get_configuration_warnings()，让编辑器自文档（运行时注入的依赖编辑器验不了，豁免） |
| R4 | 输入用 _input/_unhandled_input，不在 _process 轮询 |
| R5 | 引用用 @export / %唯一名 / @onready 缓存，避免每帧 get_node(字符串) |
| R6 | 禁止外部调 _私有方法 / has_method("_"); 对外接口用公开虚函数 |
| R7 | 信号过去式命名；接口断开显式 disconnect（_exit_tree） |
| R8 | 共享功能用 class_name，共享数据用 Resource，static var 替代部分单例 |
| R9 | autoload 是最后手段，只放"自管数据、不插手他人"的真全局 |
| R10 | 能轻则轻：Object < RefCounted < Resource < Node |
| R11 | 先设属性再 add_child；属性顺序：初始值 → _init → 导出值 |
| R12 | 常量导入用 preload；可变的用 @export/load（可置 null 释放）；禁止 @export=preload |
| R13 | 周期性逻辑用 Timer；运动学/时间步稳定用 _physics_process |
| R14 | 运行时存档走 user://，不写 res:// |
| R15 | 命名：文件/文件夹 snake_case（小写），节点 PascalCase；**中文只进内容槽**（标识符 ASCII，判据见「命名边界契约」） |
| R16 | 大二进制用 Git LFS；.gitignore 忽略 .godot/（及 user:// 类存档） |
| R17 | 数据驱动：数值走 .tres/Resource/集中配置，不散落魔术数字 |
| R18 | 单一职责：上帝对象要拆，一个类只做一件事 |
| R19 | DRY：公共逻辑抽层，不复制粘贴（含常量与阈值） |
| R20 | 可复用子系统拆成独立子场景；公共 UI/组件抽独立 |
| R21 | 用节点树声明式建结构，而非纯 new()+add_child 命令式拼 |
| R22 | 注释：类/成员/方法文档用 `##`（类文档放最顶，成员/方法紧贴上方）；普通/内联/分区注释用 `#`；警示/待办等用全大写关键字（`# TODO:` / `# NOTE:` / `# ATTENTION:`） |

---

## 物理帧顺序契约（`process_physics_priority`，越小越先）

> **`_physics_process` 的顺序看 `process_physics_priority`；`process_priority` 只管 `_process`**（曾因此把行为跑在自机前 → 激光段恒差一个 v·dt）。
> 目标形态：由组合根按 `FrameOrder` 统一赋值，不在 `.tscn` 里散写数字。

| 优先级 | 谁 | 做什么 |
|---|---|---|
| `-10` | BulletSystem | 积分位置、递减计时/相位、剔除 |
| `0` | World / 敌机 / 自机 / 子机 | 移动、发弹、跟随 |
| `5` | BulletBehavior | 弹行为：设速度 / 锚定 / 标记回收 |
| `10` | CollisionCoordinator | 检测 + 派发 |

> 原项目现状：无显式 `FrameOrder`，顺序依赖 autoload 的 `_physics_process`（见轨道 B / B5）。

---

## 渲染层次契约（`z_index`，越小越底）

| z_index | 谁 |
|---|---|
| `PLAYER_BULLET -10` | 自机弹（在自机 / 子机之下） |
| `PLAYER 0` | 自机 |
| `ENEMY 5` | 杂兵 |
| `OPTION 6` | 子机（在自机之上） |
| `ENEMY_BULLET 10` | 敌弹（在自机 / 子机之上） |
| `BOSS 15` | Boss |
| `BOSS_HP_RING 20` / `POS_INDICATOR 25` | 血环 / 位置指示器 |
| `ITEM 40` / `FX 50` / `DEBUG 60` | 道具 / 特效 / 调试叠层 |

> 常量由 `LayerConfig` 单一来源给，实体/渲染批次在 **代码里** 设 `z_index`，不在 `.tscn` 里散写数字。
> 原项目现状：**30 处散写 `z_index`**（见轨道 B / B5）。

---

## 命名边界契约（标识符 ASCII / 内容槽可中文）

> **判据**：重命名这个文件，会不会有代码（`.gd`）或数据（`.tres`/`.tscn`）里的路径字符串要跟着改？
> - **会 → 标识符 → 必须 ASCII**：`.gd` 文件名、`class_name`、节点/信号名、常量 key、**目录段**、被 `preload` 或路径字符串写死的文件。
> - **不会（只靠枚举或被数据引用） → 内容槽 → 中文可读标签 OK**。
> - **机制层代码（`scripts/**`）引用内容 → 只能走三种落点**：数据资源 `@export` / 场景装配（`.tscn` 给 `@export` 赋值）/ 内容脚本（`data/**`），不得写死路径/key。
> - **跨层字符串 key**（数据里存、代码表里查）：默认归标识符 → ASCII；除非其定义表本身已迁为内容资源。

> 原项目现状：TODO 记录了 **77 个中文文件名 / PascalCase 目录（assets/Textures 等）/ `diffculty` 拼写**——需按本契约重审（见轨道 B / B1）。

---

# STG 品质需求（主轴：做一款好玩的东方弹幕游戏）

> 图例：`[x]` 已落地且有代码证据；`[~]` 部分落地 / 待核；`[ ]` 未做。
> **2026-09 按代码证据重审**（原自评多为未勾）—— 证据为文件 / 方法引用，校准原则：有硬证据才翻。

## S1. 输入与手感（game feel）
状态：🚧（基本达成，余事件驱动收口） ｜ 适用红线：R4, R5, R11
- [x] 自机移动每帧响应、无输入缓冲 Bug（十字方向、斜向速度归一）—— `player.gd`（`move_input.normalized()` + `is_focused` 切速）
- [x] focus/普速切换即时生效，Hitbox 实时显示 —— `player.gd is_focused` + `hit_point_display.gd`
- [~] 蓄力键/炸弹/解放记忆为事件驱动（_unhandled_input），无轮询 —— `memory_release`/`cancel&bomb` 已接线（`player.gd:79-81`、`_memory_release`），但走 `_physics_process` 的 `is_action_just_pressed` 轮询；全库 `_unhandled_input` 仅 1 处
- [x] 判定不额外延迟：受击/擦弹按帧精确判定 —— `player.gd miss()/graze` 在物理帧

## S2. 自机判定与擦弹（hitbox / graze）
状态：✔（机制闭环） ｜ 适用红线：R1, R2, R10
- [x] 自机判定点极小且始终可见（HitPointDisplay 常显）—— `scripts/player/hit_point_display.gd`
- [x] 擦弹半径清晰（focus 时反馈），擦弹次数计入 HUD —— `player.gd graze_radius` + `game_ui.gd`
- [x] 无敌期间的碰撞被正确忽略，死亡清弹（death clear）覆盖全场 —— `is_invincible`（`bullet_physics.gd` 检查）+ `scripts/bullet/death_clear.gd`
- [x] 碰撞用宽相网格，不做全弹 O(n²) —— 内核 uniform grid；旧 `SpatialHash` 已随旧池删除（W4a-2）

## S3. 自机操控与武器（移动 / Option / 射击 / 炸弹）
状态：🚧 ｜ 适用红线：R2, R6, R10, R20
- [x] 射击方向/弹型按角色数据（reimu/marisa）驱动，可复用 —— `scripts/data/player_data.gd` + `coroutine/player/reimu_shoot.gd`/`marisa_shoot.gd`
- [x] Option 子机行为独立、可复用 —— `reimu_option_visual.gd`/`marisa_option_visual.gd` + `option_follow.gd`
- [~] 炸弹：无敌时长、清弹、特效、资源扣除符合预期 —— `cancel&bomb` + Bomb 弹 + `death_clear` 已在；资源扣除（`use_bomb`）待核
- [~] 武器/行为脚本走注入（ctx），不摸全局 —— 走 `StageContext` + `CoroutineScript`，但仍有全局直读（`GameState`），待收口

## S4. 弹幕可读性与公平（readability & fairness）
状态：🚧 ｜ 适用红线：R2, R10, R17
- [x] 弹型/颜色语义一致（敌弹颜色 vs 自机弹），背景/雾不吞弹 —— `BulletData.tint_mode`（MULTIPLY/BLEND）+ `bullet_batch` shader 分模式
- [~] 弹幕有"预告/起手"（telegraph），不存在无解弹幕 —— `spawn_fog` + `scripts/bullet/bullet_fog.gd` 在；无解性仍靠人工试玩
- [~] 弹幕密度、速度、命中点可读，玩家能瞬间判断下一步 —— `background/*` + `screen_fog_fx.gd` 已有；需人工调校
- [x] 每颗子弹命中判定精确（hitbox 形状/偏移，测到像素级）—— `BulletData.hitbox_shape/offset/rotation` + `bullet.gd`

## S5. 敌人 / 阶段 / Boss / 符卡（phases & spell cards）
状态：✔（机制闭环） ｜ 适用红线：R2, R17, R18, R20
- [x] 敌人/Boss 由 Data 驱动（EnemyData/BossData/PhaseData），可复现 —— `scripts/data/{enemy_data,boss_data,phase_data}.gd` + `boss_catalog.gd`
- [x] 阶段时序（入场→非符→符卡）、HP 增长、超时判定明确 —— `boss.gd _enter_phase/_clear_phase` + `is_timeout_only`
- [x] 符卡可读：显示卡名、开奖（收/不收）规则一致 —— `scripts/scenes/boss_ui.gd` + `spell_record_book.gd`
- [x] 阶段脚本（move / shoot / timeline）走 CoroutineScript + 注入，不摸全局 —— `stage_director.gd` + `StageContext` + `timeline/*`

## S6. 资源经济（Power / lives / bombs / score / graze / memory）
状态：🚧 ｜ 适用红线：R8, R9, R18
- [x] 掉落→收集→加成链路清晰（power/point/life/bomb 碎片集满合成）—— `enemy.gd _drop_item` + `scripts/item/{item,item_pool}.gd` + `PlayerResources`（经 GameState 转发）
- [~] 分数来源（击破/Bonus/最大点/擦弹/记忆）可追溯，无黑箱 —— 击破/擦弹/最大点已入账；Bonus 待核
- [x] 残机/炸弹上限、碎片合成规则集中在单一 owner（不用全局散改）—— `PlayerResources`（W4b-1 抽出；GameState 暂转发）
- [x] 各资源只通过显式入口修改（封装，防作弊/防割裂）—— `PlayerResources` 显式入口 + `changed` 信号

## S7. 难度曲线（Easy → Lunatic）
状态：🚧 ｜ 适用红线：R17, R8
- [x] 每难度数值走 diff_pick / Resource，不散落 if 判断 —— `diff_pick`（多文件）+ `boss_data.phases_for_difficulty`
- [~] 曲线平滑无"断崖"；高难增加的是密度/速度/预判压力，而非不可读 —— 需人工试玩调校
- [~] 难度切换可复现（同一 seed 同难度结果一致）—— `RNG` 种子 + 难度分表已在；端到端验证待补

## S8. 反馈与演出（feedback / fx / sound / fog）
状态：✔（机制闭环） ｜ 适用红线：R2, R7, R20
- [x] 受击/消除/擦弹/Boss 阶段有即时视觉+音效反馈 —— `scripts/effect/*` + `AudioManager`
- [x] 弹雾/背景与弹幕对比度足够，不吞弹、不刺眼 —— `bullet_fog.gd` + `screen_fog_fx.gd` + `background/*` + `decor_manager.gd`
- [x] 特效走服务/对象池（hit_effect / miss_effect），不再频繁 instantiate —— `FxLayer` + `MissEffectManager`（均为组合根注入，非 autoload）
- [x] 演出（入场/放 logo/BGM/对话）用 Timeline，可复现、可暂停 —— `coroutine/timeline/*` + `dialogue_runner.gd`

## S9. 性能（几千发子弹下的帧率余量）
状态：🚧 ｜ 适用红线：R10, R19
- [x] 子弹用内核 SoA 池 + MultiMesh，规避每弹节点开销 —— `BulletSystem` + `bullet_multi_mesh.gd`；**旧 `BulletPool`/`Bullet` 节点/`SpatialHash` 已删（W4a-2）**
- [~] 无每帧临时分配（贪心 alloc）；热路径避免 get_node("...") —— MultiMesh 同步每帧做分组/拼 key（旧代码自注有分配）；字符串 `get_node` 仅 5 处
- [x] 碰撞/移动每帧 walk 用数组索引（内核 SoA），不频繁排序
- [~] 大量对象时帧率稳定（目标：满载 60fps 有冗余）—— `test/perf_stress/*` 有压测场景，需实机确认

## S10. 可复现与回放（determinism / replay）
状态：🚧 ｜ 适用红线：R10, R13, R17
- [~] 唯一 RNG 走 RNG（种子可设），不用 randf()/randi() 全局 —— `RNG.randf` 21 处，但仍有 2 处裸 `randf()` + 5 处裸 `randi()`
- [x] 帧/时间步用固定物理过程（_physics_process）+ 世界时钟，与帧率无关 —— `_physics_process` + `ReplayRecorder` 明确铁律
- [~] 回放记录输入序列可重放，且结果与首次一致 —— `replay_recorder.gd` 已有录制（输入位掩码 + seed），**播放器"后续接入"**
- [~] 工作台"固定种子/快进/续跑"功能以此为基础 —— `workbench/bullet_bench.gd _seed/_speed_spin` 已有，续跑待核

## S11. 场景流程与演出（stage flow / bgm / dialogue）
状态：✔（结构闭环） ｜ 适用红线：R1, R20, R21
- [x] 关卡流程（Main→World→GUI）结构化，入口点清晰 —— `scenes/ui/main_menu.tscn`（main_scene）+ `game_scene.gd` + `StageRuntime`
- [x] 换关时 World 子级可替换；GUI 不随关消失（独立存活）—— `StageRuntime`
- [x] 背景/环境独立子场景，可复用；BGM 语义 key 管理 —— `data/stages/stage01/background/*` + `music_registry.tres`
- [x] 对话/剧情由 DSL/步骤驱动，可复现、可暂停、不耦合 UI 细节 —— `dialogue_line/dialogue_step/dialogue_runner/dialogue_steps.gd`

## S12. 玩家体验与可访问（UX / menus / practice）
状态：✔（体系完整） ｜ 适用红线：R4, R6, R7, R20
- [x] 菜单统一继承（NavPage/BasePage），推/跳转/退场动画一致 —— `scenes/nav_page.gd`（extends `BasePage`）+ 各页
- [x] 暂停、重开、符卡/关卡练习、回放、手册、玩家数据等可达 —— `pause_menu/spell_practice_menu/stage_practice_menu/replay_menu/manual_menu/player_data_menu.gd`
- [~] 菜单只发信号、由上层决定状态与场景，UI 不直接写全局 —— 多为 `BasePage` 信号，但仍有直接读 `GameState`，待收口
- [~] 页面可独立运行（F6），用 @export/% 引用，不硬编码节点名 —— 需逐页 F6 核验

## S13. 素材与图集（atlas / 贴图规格）
状态：✘（未用图集） ｜ 适用红线：R12, R17
- [ ] 弹幕贴图统一进图集（一图一 MultiMesh）；布局数据走 Resource（R17）—— **原项目是逐张独立 PNG**（`assets/Textures/bullet/*.png`，中文文件名属内容槽 = 合规）+ `AssetRegistry.bullet_configs` 代码侧配置；未做图集
- [ ] 格间留 ≥1px 余量（gutter）—— 未用图集，不适用
- [ ] 拆图集阈值（单图 > 1024² 或形状数 > 80 → 拆）—— 未用图集，不适用
- [~] 弹型朝向：`follow_dir` / `dir_offset` 语义统一 —— `bullet.gd` 有 `hitbox_rotation`；朝向语义需审计

---

# 🔴 待改进（达标后清空）
> 这里是"当前版本"尚未达标的项（工程红线与 STG 需求均可能命中）。每修一条删一条，最终清空。
- [ ] R14：存档写 res://（应改 user://）—— 符卡簿/音乐/记录（见 OLD_AUDIT）
- [ ] R4：_process 轮询输入（nav_page 及 3 份复制）
- [ ] R3：仅 2 处 @tool、_get_configuration_warnings 零实现
- [ ] R12：@export var x = preload(...)（enemy_data.gd:9）
- [ ] R15：77 个中文文件名、assets/Textures 等 PascalCase 目录、diffculty 拼错
- [ ] R16：40MB+ 二进制未配 Git LFS
- [ ] R18/R19：workbench.gd / spell_practice_menu.gd 上帝对象 + 三台热更新逻辑复制

> **S1–S13 重审说明（2026-09）**：原自评多为未勾，实际大量已落地——已按代码证据逐条重审。另两处过时项已核：
> - **R14「存档写 res://」已不成立**：`save_manager.gd` 用 `user://save_data.cfg`。
> - **R15 的「77 个中文文件名」多为 `assets/Textures/**` 内容槽**（新命名边界契约下合规）；真正待办是 **PascalCase 目录段（如 `assets/Textures`）+ `diffculty` 拼写**。

## 外壳工程红线审计（2026-09 实测，轨道 B 的输入）

| 红线 | 实测 | 判断 |
|---|---|---|
| R9 autoload | **4 个**（W1 12→10，W2 10→8，W3a 8→7，W3b 7→6，W4b 6→5，W4c 5→4） | `GameEvents / GameManager / RNG / AudioManager`；已达目标 |
| R18 单一职责 | `BulletManager` / workbench 4286 行 | `GameState` 已拆（W4b）；余 `BulletManager`/workbench |
| R21 声明式建树 | workbench 178 处 `.new()` + 183 处 `add_child` | 最大表面积（开发工具，可后） |
| R6 私有调用 | **0 处**（K2 已清：`has_method("_")` 12→0、生产对外私有调用 6 组→0） | ✅ 公开虚函数 + 类型化接口 |
| 层序契约 | 30 处散写 `z_index` | 收敛到 `LayerConfig` |
| 帧序契约 | 无显式 `FrameOrder` | 引入 `FrameOrder` |
| R14/R15/R2/R5 | res:// 写存档 0、中文 .gd 文件名 0、`get_node("..")` 0、`find_child` 0（K4 已清） | 比预期干净；R15 的目录/拼写问题见上方 TODO |
| R4 输入 | 12 文件轮询 `Input.is_action` | 需按「移动例外」理解（重建版同做法），非硬违规 |

> **轨道 B 进度（2026-09-11）**：**W1–W3b 已完成**（余 W4）。
> - W1：`LayerConfig` 去 autoload（纯常量 → `class_name`）、`MissEffectManager` 场景节点化（组合根 `GameScene` 注入）。autoload 12→10。
> - W2：`StageObjects` 去 autoload（→ `StageContext.objects`）、`HitEffectPool` → `FxLayer`（组合根注入，节点在 `game_scene.tscn` 声明）。autoload 10→8。
> - R21 收口：`FxLayer` 与 `MissEffectManager` 均已改为 `game_scene.tscn` 声明式节点（后者为 W1 产物，在 W2 补正）。详见 §12.7 / §12.8。
> - W3a：`AssetRegistry` 去 autoload（→ `class_name` 静态表，调用点 0 改动）。autoload 8→7。详见 §12.9。
> - W3b：`StageManager` autoload → `StageRuntime`（World 下场景节点）+ `ctx.stage` 注入。autoload 7→6。详见 §12.10。
> - W4a-1：内核弹幕后端**转正为默认**（旧池保留回滚，F2 切换）；新增 `active_count()`。详见 §12.11。
> - W4a-2：删除旧池（`BulletPool`/`Bullet`/`BulletPhysics`/`SpatialHash`/`bomb_behavior`/`bullet_fog`/`bullet.tscn`）+ `use_kernel`/F2；内核成为唯一后端。详见 §12.12。
> - W4b-1：`GameState` 单局资源抽成 `PlayerResources`（单一 owner），GameState 转发（调用点零改动）。详见 §12.13。
> - W4b-2a：`Player` 增 `resources`（组合根注入同一实例）。全量 55/303/3191 绿。
> - W4b-3a：运行时引用（自机 / 敌机 / Boss）抽成 `EntityRegistry`，`StageRuntime` 持有并绑定，`GameState` 退为过渡门面。`grep GameState` **46 → 41 文件**。详见 §12.14。
> - W4b-3b：`refs` 注入内核弹幕路径（`BulletManager` / 桥接碰撞与清弹 / `KernelBomb` / 桥接行为 / `LaserEngine` / `HitboxOverlay`）。`grep GameState` **41 → 35 文件**。详见 §12.15。
> - W4b-2b：资源消费者直读 `Player.resources`（经 `refs.get_player_resources()`）。`grep GameState` **35 → 31 文件**。详见 §12.16。
> - W4b-4：`GameState` → `SaveData`（纯 `static`，去 autoload）；资源归 `Player`、实体归 `EntityRegistry`。`grep GameState` **31 → 0**；autoload **6 → 5**。详见 §12.17。
> - W4c：`BulletManager` 去 autoload（组合根创建 / 注入的弹幕世界 + `static current`）。autoload **5 → 4**。详见 §12.18。
> - K1（命名收口）：9 个黑话/缩写文件改名（`cs_`/`ov_` 等）、`RigBase` → `BenchBase`、3 个 `.tres` + preload/测试路径同步；语义不一致 **8 → 0**（acronym 大小写刻意不动）。详见 §12.19。
> - K1b（目录收口）：`scripts/autoload/` **8 → 4 文件**（只留真 autoload）；`bullet_manager`/`death_clear` → `scripts/bullet/`，`scene_transition`/`menu_nav` → `scripts/scenes/`。详见 §12.20。
> - K2（R6 收口）：`BasePage` 生命周期改公开虚函数 + `MenuNav` 栈类型化；`BenchBase` 公开 `snapshot/restore/preset_from_entry`；`Player`/`Boss`/`LaserBeam` 私有入口公开化。`has_method("_")` **12 → 0**。详见 §12.21。
> - K4（R2 收口）：Boss 指示器 UI 层 / 背景相机 / 炸弹爆图父节点均改组合根注入；`find_child` **2 → 0**、`$".."` **4 → 0**。详见 §12.22。

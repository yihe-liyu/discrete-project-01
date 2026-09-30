# 项目基线（STG 品质需求 × 工程红线）

> **改动前先扫这一份**：这里**只留规则与状态**，所以它应该越读越薄。
> - 主轴 **STG 品质需求（S1–S13）** = 目的地；横切 **工程红线库（R1–R22）** = 护栏，服务于上面的需求。
> - **改状态** → 只改下面「状态总表」的**一行**；**补证据**（文件/方法/实测数字）→ 写进
>   [`BASELINE_EVIDENCE.md`](BASELINE_EVIDENCE.md)（附录，可查不必通读）；
>   **记心得 / 为什么这样改 / 没抄旧版什么** → `BEST_PRACTICES_LOG.md`。
> - 目标：随项目成熟**只收敛、不膨胀**；「待改进」小节最终清空。
> - 旧项目改造前审计快照：`docs/archive/BEST_PRACTICES_BASELINE_OLD_AUDIT.md`（留底，不随重建更新）。

---

## 改动前 60 秒（最高频的几条）

- **依赖**：父级 / 上下文注入；禁 `get_node("..")`、禁全树搜（R2）
- **命名**：文件·目录 snake、节点 PascalCase、**标识符 ASCII**（中文只进内容槽）（R15 + 命名契约）
- **数据**：数值进 `.tres` / 集中配置，不散魔术数字（R17）
- **建树**：结构在 `.tscn` 里声明，服务节点别 `new()` + `add_child` 拼（R21）
- **注释**：类 / 成员用 `##`，普通 / 内联用 `#`（R22）
- **改动后**：改内核 C++ → 重编扩展；改 `class_name` / 删脚本 → 刷 `.godot` 缓存；`./tools/verify.sh`（见「踩坑铁律」）

---

## 状态总表（S1–S13）

> 图例：`✔` 已落地且有代码证据 ｜ `🚧` 部分落地 / 待核 ｜ `✘` 未做。
> 「还差什么」只写**结论**；逐条证据（`[x] —— 文件/方法`）在 [BASELINE_EVIDENCE.md](BASELINE_EVIDENCE.md#stg-品质需求主轴做一款好玩的东方弹幕游戏)。

| # | 需求 | 状态 | 适用红线 | 还差什么 |
|---|---|---|---|---|
| S1 | 输入与手感 | ✔ | R4 R5 R11 | — |
| S2 | 自机判定与擦弹 | ✔ | R1 R2 R10 | — |
| S3 | 操控与武器（Option/射击/炸弹） | ✔ | R2 R6 R10 R20 | — |
| S4 | 弹幕可读性与公平 | 🚧 | R2 R10 R17 | 无解性与密度手感靠人工试玩调校 |
| S5 | 敌人 / 阶段 / Boss / 符卡 | ✔ | R2 R17 R18 R20 | — |
| S6 | 资源经济（Power/lives/bombs/score/graze/memory） | ✔ | R8 R9 R18 | — |
| S7 | 难度曲线 | 🚧 | R17 R8 | 曲线靠人工调校；同种子端到端验证待补 |
| S8 | 反馈与演出 | ✔ | R2 R7 R20 | — |
| S9 | 性能（几千发弹下的余量） | 🚧 | R10 R19 | MultiMesh 同步每帧分组/拼 key 有分配；满载 60fps 待实机确认 |
| S10 | 可复现与回放 | 🚧 | R10 R13 R17 | 回放**播放器**待接入；工作台"续跑"待核 |
| S11 | 场景流程与演出 | ✔ | R1 R20 R21 | — |
| S12 | 玩家体验与可访问 | ✔ | R4 R6 R7 R20 | 逐页 F6 可独立运行待核验 |
| S13 | 素材与图集 | ✔ | R12 R17 | —（`laser` 按拍板留独立 PNG；2026-09-30 复核：gutter / 拆图阈值两条**判据结论化 + 机械化**，见证据文档） |

---

# 工程红线库（R1–R22）（护栏，原则只写一次）

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
| `-10` | `KernelNativeSystem`（原生 `DanmakuStore` 权威） | `integrate`（积分/寿命/相位/剔除）+ `behavior_tick`（行为）+ 每帧 pull 只读快照 |
| `-4` | `KernelBulletHost` | 延后动作 flush（emit/call 队列）+ 激光整批渐隐 |
| `0` | `BulletManager` / World / 敌机 / 自机 / 子机 | 碰撞规则（`KernelBulletPhysics`：命中/擦弹/伤害/清弹，几何走原生网格）+ 移动、发弹 |


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

---

## 其他契约（只指出处，不在本文重复）

- **bomb 数据模型**（`BombData` 家族 + `KernelBulletHost.spawn_bomb` **按实际类型**分派）→ `ARCHITECTURE.md` §6「新增自机 bomb」· `CONTENT_GUIDE.md` §四。
- **弹型与贴图**（`data/bullets/*.tres` = 外观 + 碰撞 + 朝向；运行时 `BulletType` **不是**内容资源；贴图 = 1024² 图集）→ `DANMAKU_API.md` §7.1。
- **纹理插座（M3 ③ 已拍板）**：`_texture_by_index` / `texture_for_index()` 是**设计 seam，不是债** → `docs/archive/M3_TEXTURE_OWNERSHIP_DECISION.md`。

---

## 命名边界契约（标识符 ASCII / 内容槽可中文）

> **判据**：重命名这个文件，会不会有代码（`.gd`）或数据（`.tres`/`.tscn`）里的路径字符串要跟着改？
> - **会 → 标识符 → 必须 ASCII**：`.gd` 文件名、`class_name`、节点/信号名、常量 key、**目录段**、被 `preload` 或路径字符串写死的文件。
> - **不会（只靠枚举或被数据引用） → 内容槽 → 中文可读标签 OK**。
> - **机制层代码（`scripts/**`）引用内容 → 只能走三种落点**：数据资源 `@export` / 场景装配（`.tscn` 给 `@export` 赋值）/ 内容脚本（`data/**`），不得写死路径/key。
> - **跨层字符串 key**（数据里存、代码表里查）：默认归标识符 → ASCII；除非其定义表本身已迁为内容资源。
> - **明确豁免 · `AssetRegistry`（2026-09-18 立）**：`scripts/asset_registry.gd` 是**内容槽的代码侧索引表**（`bullet_configs` / `enemy_visuals` / `sounds` / `BGM_PATHS`），其 `res://` 与中文 key 属**内容槽引用**、非机制标识符 → 当前**合规豁免**。**退役条件**：随 S13 图集 + 数据化（`F7`：打包 + `AtlasLayout` + `BulletType` `.tres`）逐表迁入 `data/**`；迁完一表即**移除该表豁免**，全表迁完豁免终止。**F7 进度（2026-09-20）**：`bullet_configs` 表**已整体退役** —— 弹型迁 `data/bullets/*.tres`（`BulletCatalog` 读取），贴图迁 1024² 图集 + `data/atlas/bullet_shapes.tres`；本表仅余 `enemy_visuals` / `sounds` / `BGM_PATHS` / `LASER_TEXTURE`（`laser` 按拍板留独立 PNG）。

> - **明确豁免 · `assets/` 素材根目录（2026-09-18 立）**：`assets/Textures` / `assets/Music` / `assets/Sound` 三个**内容素材根目录**保留 PascalCase —— 改名 = 3 目录 + ~236 处路径（含 137 条 `.import`）+ 全量重导入，收益仅「字面合规」；与「`AssetRegistry` 内容槽索引表」同源。


---

## 注入契约（组合根 → 场景节点）

> 场景内依赖**只能代码注入**：Godot 4.7 下 `.tscn` → `@export` 节点引用不会解析成节点（K4 实测后回退），所以「声明式接线」对节点依赖不可用 —— R21 只覆盖**建树**，不覆盖接线。
> 按「**写入是否需要副作用**」二选一：

| 写入 | 落点 | 例子 |
|---|---|---|
| **需要副作用**（转发子模块 / 重建装配 / 校验 / 统一断开） | **只读属性 + `inject_*()` / `setup_*()` 方法**；方法即唯一写入口 | `BulletManager.inject_fx_pool()` / `inject_entity_registry()`；`BehaviorProcessor.setup()` / `LaserEngine.setup()` |
| **纯赋值**（组合根把已建好的节点挂上，无副作用） | 允许**裸 public var**，但必须 `##` 注明「组合根注入」 | `StageRuntime.world` / `bullet_manager` / `miss_layer` / `fx_pool` / `ui_layer`；`BulletManager.fx_parent` |

> `ctx.*` 服务（`RefCounted`）由 `StageContext` 懒建 + 回填，不自行摸全局。
> 有意例外：`StageContext.effects` getter 每次访问把**绑定 `stage`** 的 Miss / FX 层回填给服务（保持最新）。
> **P2（2026-09-13）**：`StageContext` 不再回退 `BulletManager.current`；无 stage 的 ctx（自机射击 / 子弹共享 ctx）由宿主显式绑 stage（`Player.bind_ctx` / `BulletManager.inject_stage_runtime`）。

---

## 标识符命名契约（同物同名 / 类型→名 / 节点→名）

> 判据：**同一个东西，全项目一个名**。名字**从类型或节点派生**，不自造；缩写必须过白名单。

| 对象 | 规则 |
|---|---|
| **私有字段**（`_x`，实现细节） | `_` + **类型名 snake**：`EntityRegistry` → `_entity_registry`；`KernelBulletHost` → `_kernel_bullet_host`；`LaserEngine` → `_laser_engine` |
| **公开字段 / 属性**（对外状态） | **同样类型派生、不缩写**（2026-09-13 拍板）：`refs` → `entity_registry`；`world` / `bullets` → `bullet_manager`。**唯一豁免 = `ctx.*` 意图门面**（见 §3：`ctx.bullets` / `ctx.player` / `ctx.audio`… 是设计好的动词域，不是随手缩写） |
| **场景节点引用**（`@onready`） | 节点名 snake + `_`：`%FxPool` → `_fx_pool`。**节点名与变量名不符 = 有一方错**：变量错就改变量；节点名太弱（`UI`）或不具体就先改节点 |
| **类型是内置基类**（`Node2D`/`Control`/`Sprite2D`…） | 节点名赢：`muzzle: Marker2D = $Muzzle` ✅ |
| **同类型多实例** | `限定词_类型snake`（`stage_entity_registry`）—— 同作用域内必须可区分 |
| **集合 / 映射** | 集合用复数（`enemies`）；映射用 `值_by_键`（`_type_by_sig` / `_damage_by_index`） |
| **布尔** | （a）`is_` / `has_` / `can_` / `should_` 前缀（`is_running` / `has_boss`）；或（b）**动词开头**、天然表达"做/不做"（`draw_velocity_lines` / `allow_wrap` / `link_ground_to_fog` / `enable_native_behaviors`）；禁无主语名词（`flag` / `active`） |
| **回调 Callable** | 变量/形参 `on_x`（`on_overlap`）；信号处理**方法** `_on_x`（`_on_player_death`）—— 不互换 |
| **生命周期钩子**（框架调用、子类覆写，非信号） | `on_enter` / `on_leave` / `on_activate` / `on_deactivate`（`MenuNav` 调）—— 与信号处理 `_on_*` 区分，不斜杠 |
| **preload 常量** | 场景 `*_SCENE`；脚本 `*_SCRIPT`；已有 `class_name` 的别再起别名 |
| **函数** | 取值 `get_*`；判定 `is_*` / `has_*`；动作动词开头；事件处理 `_on_*` |

> **缩写白名单（封闭）**：`ctx`（`StageContext`）+ 循环索引 `i`/`j`/`k`（索引专用）。其余**整词**缩写一律不缩写 —— `refs` / `world` / `bullets` / `sys` / `sd` / `st` / `bm` / `bg` / `nav` / `tl` 都算违规。**单字母**另受下一条约束。
> **适用范围**：私有字段、公开状态字段、局部变量都适用；仅 `ctx.*` 门面豁免（2026-09-13 拍板）。（**现状与存量清理经过**见证据文档。）
> **门面命名（2026-09-18 拍板，关 N2）**：`ctx.*` 门面一律用**域名词**（可数集合用复数），**不跟类型名、不加 `_service`**；类型名才带 `Service`。例：`ctx.bullets`→`BulletService`、`ctx.enemies`→`EnemyService`、`ctx.items`→`ItemService`、`ctx.effects`→`EffectService`。`ctx.bullets` 是 A2b/A2c 改名后**有意保留**的门面名，非漏网。
> **门面动词（2026-09-18 拍板，关 N14）**：`ctx.*` 门面 + `StageContext` + 导演句柄 `BossHandle` 的**方法名**允许域动词（只说意图、避免 stutter，如 `ctx.boss.get_boss()`），受**封闭清单**约束，新增须登记：`active` / `current` / `exists` / `picked` / `at_least`；**机制类**（`EntityRegistry` / `PlayerService` / …）仍严格 `get_*`（取值）/ `is_*`·`has_*`（判定）/ 动作动词。
> **形参遮蔽成员** → 加 `p_` 前缀（`p_ctx` 遮蔽 `CoroutineScript.ctx`）；**真的不用** → 单 `_`（`_ctx`）；**禁止叠加** `_p_`。
> **单字母 / 极短名（2026-09-18 严格化，关 N8）**：只允许三种作用域 —— ① 循环索引 `i`/`j`/`k`；② **单行表达式**内的临时量 / 链式 DSL·构建器形参（整个生命周期不跨行）；③ **热路径**模块（`kernel_bridge/` · `laser/` · `bullet/` · `effect/` · `background/screen_fog_fx.gd` · `background/background_sun.gd` · `background/decor_manager.gd`）内的循环/数学临时量。**其余一律全名**：任何**跨行**存活、**跨函数**传递、或作为**类字段**（`check_naming` ⑥ 守卫）的单字母都要改名。存量分批清理见 `TODO_TEMP` N8。
> **校验**：`bash tools/check_naming.sh`（默认只报告；`--fail` 交 CI；`verify.sh` 第 2 步已启用 `--fail`）。**当前 0 条**（2026-09-13 收敛）；覆盖 ① 私有字段名 / ② 同类型多私名 / ③ `@onready` 节点名 / ④ 节点名 PascalCase 四类，**外加 ⑤ 形参·局部·循环变量遮蔽类成员**（2026-09-13 补，对应上条 `p_` 规则；静态扫描，不依赖 Godot reload；**2026-09-18 补：⑤ 校验形参「禁止叠加 `_p_`」+ ⑥ 类字段不得单字母 + ⑦ 目录/文件名不得 PascalCase·含 ASCII 大写**（⑦ 豁免：`assets/Textures|Music|Sound` · `data/stages/stage03B` · `assets/Music/**` 内容槽））——**公开字段与局部缩写仍需人工守**（本表 + 白名单）；`test/reference/**` 是冻结的 vendor 参照实现（原 `scripts/kernel`，不在生产），不适用本契约（豁免）；私有字段接受 `_<类型snake>` 与 `_<限定词>_<类型snake>`（同类型多实例）。

### 会话状态契约（per-run static）

> **每个跨场景存活的 per-run static 必须有唯一的置位点与唯一的复位点。** 复位统一走 `SaveData.reset_session()`（练习载荷 + `current_stage_id` + `restarting` + `is_stage_practice`）；**新游戏**（`main_menu._start_game_flow`）与**进练习**（`SaveData.start_practice`）都必须先经过它。

| static | owner | 置位 | 复位 |
|---|---|---|---|
| `is_practice_mode` / `practice_*` | `SaveData` | `start_practice` | `reset_session`（经 `_clear_practice`） |
| `current_stage_id` | `SaveData` | 默认 1；通关 +1（**仅当下一关存在**） | `reset_session` |
| `restarting` | `SaveData` | `pause_menu` / `game_over_menu` | `reset_session` |
| `is_stage_practice` | `SaveData` | `stage_practice_menu` | `reset_session` |
| `BulletManager.current` | 各自 | `_ready` | `_exit_tree` |
| `AssetRegistry._bgm_cache` / `BossCatalog._cache` | 各自 | 懒加载 | 进程级缓存，无需清 |

> **反例（已修）**：只复位布尔标志、留下载荷（`end_practice` 曾只清 `is_practice_mode`）→ 下一局进入别的流程时带脏状态。**校验**：`test/test_session_state.gd`。

---

## 踩坑铁律（改动前扫一眼）

> 从滚动日志蒸馏的**跨子系统**教训；内核 / lifecycle 专项见 `DANMAKU_API.md` / `LIFECYCLE_MODEL.md`，过程见 `docs/archive/LOG_*`。

- **池化/复用对象加字段 → `setup()`/`reset()` 必须归零**（`Item` 漏 `_is_highlight` → 回池复用误金色；原生行同理）。
- **遍历中 `despawn` 必须倒序**（swap-with-last；dead 重放降序，升序丢大 id）。
- **改内核 C++ → 必须 `./tools/build_gdextension.sh` 重编**；`test/reference/**` 只作冻结参照。
- **改 `class_name` / 删脚本·场景后 → `godot --headless --import` 刷 `.godot` 缓存**（否则 stale class/uid 加载失败）。
- **preset/builder 不覆写显式开关**（`.enemy()` 别设 `is_spawn_fog`，否则静默翻回显式关闭）。
- **缩放 Node2D 父层会连带子节点 `position`**：改尺寸缩**每个实例**，别缩容器层（`NumberSprite` 字号即此）。
- **绕中心 pivot 缩放 → 视觉盒 ≠ 布局框**：视觉盒每侧比布局框多 `size*(1-scale)/2`；贴边落点要按**视觉右缘**算，否则布局框贴边、文字越界被上层不透明 HUD 相框盖掉（符卡名 `AnnounceLabel.rest_x`；`false_front.png` 在 GameUI layer 32，场地外不透明）。
- **GDScript 警告 = 错误**（`check_syntax` 全扫）；原生 `WARN/ERR_PRINT` 被 GUT 记 Unexpected Errors → 内核静默返回、宿主 `push_warning`。
- **场景期依赖用 `@tool` + `_get_configuration_warnings()`**（同 R3；运行时注入豁免）。
- **Godot 的 `erase_section` / `remove_*` 对「不存在」目标会 `ERR_FAIL`（不是 no-op）**：先 `has_section` / `file_exists` 守卫；GUT 会把它记成 Unexpected Errors。
- **测试用夹具，别拿真实内容当断言标准**：目录扫描类（`ContentCatalog` / `CatalogPanel`）一律 `scan(夹具根)` / 注入 `catalog_root`；真实内容只做「不数数量、不写具体路径」的结构冒烟——否则加一张符卡就红。

---

# 🔴 待改进（达标后清空）

> 每修一条删一条。长版细节（行数、实测数字、决策经过）见 [BASELINE_EVIDENCE.md](BASELINE_EVIDENCE.md)。

- [ ] **R16**：47MB 二进制未配 Git LFS（`.gitattributes` 仅 EOL 规范化）
- [ ] **R18/R19**：`workbench.gd`(695) / `spell_practice_menu.gd`(754) 上帝对象 + 3 个超长 `_build_ui`（**行数只是提示，判据是"一个类只做一件事"**；2026-09-27 实测）
- [ ] **R21**：`workbench` 11 处 `.new()` + 15 处 `add_child`（开发工具，可后）
- [ ] **R2（残余）**：`item_service.gd:16` / `player.gd:286` 经 `current_scene` 取 World，可改注入
- [ ] **编排路线**（`docs/archive/STAGE_FLOW_PLAN.md`）：Step 2 书签原生 / Step 6 `ctx.background` 注入服务 待做；Step 5/7 暂缓（产品决定）
- [ ] **内核融合（M3）**：M1/M2 已完成、M3 已拍板「纹理句柄」；判据已改为**结构性**（0 类型映射 / 0 内容签名侧表）—— 经过见证据文档

> 曾经的"重审说明 + K0 实测审计表"已移入 [BASELINE_EVIDENCE.md](BASELINE_EVIDENCE.md)（历史快照，只增不改）。

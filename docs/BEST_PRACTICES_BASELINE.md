# 项目基线（STG 品质需求 × 工程红线）

> **改动前先扫这一份**：只留规则与状态。证据/实测数字 → [`archive/BASELINE_EVIDENCE.md`](archive/BASELINE_EVIDENCE.md)（附录，可查不必通读）；
> 为什么这样改 / 踩过什么坑 → `BEST_PRACTICES_LOG.md`。目标：**只收敛、不膨胀**，「待改进」最终清空。
> 旧项目审计快照 → `docs/archive/BEST_PRACTICES_BASELINE_OLD_AUDIT.md`（留底，不更新）。

## 改动前 60 秒

- **依赖**：父级 / 上下文注入；禁 `get_node("..")`、禁全树搜（R2）。
- **命名**：文件/目录 snake、节点 PascalCase、标识符 ASCII（中文只进内容槽）（R15）。
- **数据**：数值进 `.tres` / 集中配置，不散魔术数字（R17）。
- **建树**：结构在 `.tscn` 里声明，服务节点别 `new()` + `add_child` 拼（R21）。
- **注释**：类/成员用 `##`，普通/内联用 `#`（R22）。
- **改动后**：改 C++ → 重编扩展；改 `class_name` / 删脚本 → 刷 `.godot` 缓存；`./tools/verify.sh`。

## 状态总表（S1–S13）

> `✔` 已落地有证据 ｜ `🚧` 部分落地 / 待核 ｜ `✘` 未做。逐条证据在 [`archive/BASELINE_EVIDENCE.md`](archive/BASELINE_EVIDENCE.md)。

| # | 需求 | 状态 | 红线 | 还差什么 |
|---|---|---|---|---|
| S1 | 输入与手感 | ✔ | R4 R5 R11 | — |
| S2 | 自机判定与擦弹 | ✔ | R1 R2 R10 | — |
| S3 | 操控与武器（Option/射击/炸弹） | ✔ | R2 R6 R10 R20 | — |
| S4 | 弹幕可读性与公平 | 🚧 | R2 R10 R17 | 无解性与密度手感靠试玩调校 |
| S5 | 敌人 / 阶段 / Boss / 符卡 | ✔ | R2 R17 R18 R20 | — |
| S6 | 资源经济（Power/lives/bombs/score/graze/memory） | ✔ | R8 R9 R18 | — |
| S7 | 难度曲线 | 🚧 | R17 R8 | 曲线靠调校；同种子端到端验证待补 |
| S8 | 反馈与演出 | ✔ | R2 R7 R20 | — |
| S9 | 性能（几千发弹下的余量） | 🚧 | R10 R19 | MultiMesh 同步每帧分组/拼 key 有分配；满载 60fps 待实机确认 |
| S10 | 可复现与回放 | 🚧 | R10 R13 R17 | 回放**播放器**待接入；工作台“续跑”待核 |
| S11 | 场景流程与演出 | ✔ | R1 R20 R21 | — |
| S12 | 玩家体验与可访问 | ✔ | R4 R6 R7 R20 | 逐页 F6 可独立运行待核验 |
| S13 | 素材与图集 | ✔ | R12 R17 | —（`laser` 按拍板留独立 PNG） |

## 工程红线库（R1–R22）

| ID | 红线 |
|----|------|
| R1 | 场景可独立运行（F6 能跑），零外部硬依赖 |
| R2 | 依赖由父级/上下文向下注入；禁止 `get_node("..")` / `find_child` 全树搜 |
| R3 | 场景期外部依赖用 `@tool` + `_get_configuration_warnings()`；运行时注入豁免 |
| R4 | 输入用 `_input` / `_unhandled_input`，不在 `_process` 轮询 |
| R5 | 引用用 `@export` / `%唯一名` / `@onready` 缓存，避免每帧 `get_node(字符串)` |
| R6 | 禁止外部调 `_私有方法` / `has_method("_")`；对外接口用公开虚函数 |
| R7 | 信号过去式命名；接口断开显式 `disconnect`（`_exit_tree`） |
| R8 | 共享功能用 `class_name`，共享数据用 `Resource`，`static var` 替代部分单例 |
| R9 | autoload 是最后手段，只放“自管数据、不插手他人”的真全局 |
| R10 | 能轻则轻：`Object < RefCounted < Resource < Node` |
| R11 | 先设属性再 `add_child`；顺序：初始值 → `_init` → 导出值 |
| R12 | 常量导入用 `preload`；可变的用 `@export`/`load`；禁止 `@export=preload` |
| R13 | 周期性逻辑用 `Timer`；运动学/时间步稳定用 `_physics_process` |
| R14 | 运行时存档走 `user://`，不写 `res://` |
| R15 | 命名：文件/目录 snake_case，节点 PascalCase；标识符 ASCII，中文只进内容槽 |
| R16 | 大二进制用 Git LFS；`.gitignore` 忽略 `.godot/` 与 `user://` 类存档 |
| R17 | 数据驱动：数值走 `.tres`/`Resource`/集中配置，不散落魔术数字 |
| R18 | 单一职责：上帝对象要拆，一个类只做一件事 |
| R19 | DRY：公共逻辑抽层，不复制粘贴（含常量与阈值） |
| R20 | 可复用子系统拆独立子场景；公共 UI/组件抽独立 |
| R21 | 用节点树声明式建结构，而非纯 `new()` + `add_child` |
| R22 | 注释：类/成员/方法用 `##`；普通/内联/分区用 `#`；警示/待办用 `# TODO:` / `# NOTE:` / `# ATTENTION:` |

## 顺序与层次

**物理帧顺序**（`process_physics_priority`，越小越先；`process_priority` 只管 `_process`）：

| 优先级 | 谁 | 做什么 |
|---|---|---|
| `-10` | `KernelNativeSystem` | `integrate`（积分/寿命/相位/剔除）+ `behavior_tick` + 每帧 pull 只读快照 |
| `-4` | `KernelBulletHost` | 延后动作 flush（emit/call 队列）+ 激光整批渐隐 |
| `0` | `BulletManager` / World / 敌机 / 自机 / 子机 | 碰撞（`KernelBulletPhysics`）+ 移动、发弹 |

> 目标形态：由组合根按 `FrameOrder` 统一赋值，不在 `.tscn` 里散写数字。

**渲染层次**（`z_index`，越小越底；常量由 `LayerConfig` 单一来源给）：

| z_index | 谁 |
|---|---|
| `PLAYER_BULLET -10` | 自机弹（自机/子机之下） |
| `PLAYER 0` | 自机 |
| `ENEMY 5` | 杂兵 |
| `OPTION 6` | 子机（自机之上） |
| `ENEMY_BULLET 10` | 敌弹（自机/子机之上） |
| `BOSS 15` | Boss |
| `BOSS_HP_RING 20` / `POS_INDICATOR 25` | 血环 / 位置指示器 |
| `ITEM 40` / `FX 50` / `DEBUG 60` | 道具 / 特效 / 调试叠层 |

## 命名：只留判据

**命名边界**（标识符 ASCII / 内容槽可中文）：

- 判据：重命名它，代码/数据里的**路径字符串**要不要跟着改？会 → 标识符（ASCII）；不会 → 内容槽（中文可）。
- 标识符：`.gd` 文件名、`class_name`、节点/信号名、常量 key、目录段、被 `preload` 写死的文件。
- 机制层代码引用内容只走三种落点：`@export` / `.tscn` 赋值 / 内容脚本；不得写死路径/key。
- 豁免：`scripts/asset_registry.gd`（内容槽代码侧索引表，随 F7 逐表退役）；`assets/Textures|Music|Sound` 保留 PascalCase。

**标识符命名**（判据：同一个东西全项目一个名，名字从类型/节点派生）：

| 对象 | 规则 |
|---|---|
| 私有字段 | `_` + 类型名 snake：`EntityRegistry` → `_entity_registry` |
| 公开字段/属性 | 同样类型派生、不缩写；唯一豁免 = `ctx.*` 意图门面 |
| `@onready` 节点引用 | 节点名 snake + `_`：`%FxPool` → `_fx_pool`；名不符 = 有一方错 |
| 内置基类 | 节点名赢：`muzzle: Marker2D = $Muzzle` |
| 同类型多实例 | `限定词_类型snake`：`stage_entity_registry` |
| 集合/映射 | 集合复数（`enemies`）；映射 `值_by_键`（`_type_by_sig`） |
| 布尔 | `is_`/`has_`/`can_`/`should_`，或动词开头（`allow_wrap`）；禁无主语名词 |
| 回调 | 变量/形参 `on_x`；信号处理方法 `_on_x`（不互换） |
| 生命周期钩子 | `on_enter` / `on_leave` / `on_activate` / `on_deactivate` |
| preload 常量 | 场景 `*_SCENE`；脚本 `*_SCRIPT`；已有 `class_name` 不再起别名 |
| 函数 | 取值 `get_*`；判定 `is_*`/`has_*`；动作动词开头；事件 `_on_*` |

> 缩写白名单（封闭）：`ctx` + 循环索引 `i`/`j`/`k`。`refs`/`world`/`bullets`/`sys`/`bm`/`bg`/`nav`/`tl` 都算违规。
> `ctx.*` 门面用域名词（`ctx.bullets`→`BulletService`），不跟类型名、不加 `_service`；门面动词封闭清单：`active`/`current`/`exists`/`picked`/`at_least`。
> 形参遮蔽成员加 `p_`（`p_ctx`）；真的不用 → `_`；禁止叠加 `_p_`。单字母只许循环索引 / 单行临时量 / 热路径数学临时量。
> **校验**：`bash tools/check_naming.sh`（`verify.sh` 已 `--fail`，当前 0 条）；公开字段与局部缩写仍需人工守。

## 注入与会话

**注入契约**（Godot 4.7 下 `.tscn` → `@export` 节点引用不解析，场景依赖只能代码注入）：

| 写入 | 落点 |
|---|---|
| **需要副作用**（转发/重建/校验/统一断开） | 只读属性 + `inject_*()` / `setup_*()`；方法即唯一入口 |
| **纯赋值**（挂已建好的节点） | 允许裸 public var，但必须 `##` 注明「组合根注入」 |

> `ctx.*` 服务由 `StageContext` 懒建 + 回填，不摸全局；`StageContext.effects` 每次把绑定的 Miss/FX 层回填（有意例外）。
> 无 stage 的 ctx（自机射击/共享 ctx）由宿主显式绑 stage（`Player.bind_ctx` / `BulletManager.inject_stage_runtime`）。

**会话状态**（每个跨场景 per-run static 必须有唯一置位点与复位点；复位统一走 `SaveData.reset_session()`）：

| static | owner | 置位 | 复位 |
|---|---|---|---|
| `is_practice_mode` / `practice_*` | `SaveData` | `start_practice` | `reset_session` |
| `current_stage_id` | `SaveData` | 默认 1；通关 +1（仅当下一关存在） | `reset_session` |
| `restarting` | `SaveData` | `pause_menu` / `game_over_menu` | `reset_session` |
| `is_stage_practice` | `SaveData` | `stage_practice_menu` | `reset_session` |
| `BulletManager.current` | 各自 | `_ready` | `_exit_tree` |
| `AssetRegistry._bgm_cache` / `BossCatalog._cache` | 各自 | 懒加载 | 进程级缓存，无需清 |

> 校验：`test/test_session_state.gd`；只复位布尔、留下载荷 = 脏状态（已修）。

## 踩坑铁律（只留高频）

- 池化/复用对象加字段 → `setup()`/`reset()` 必须归零（`Item` 漏 `_is_highlight` 即此）。
- 遍历中 `despawn` 必须倒序（swap-with-last；升序丢大 id）。
- 改内核 C++ → 必须 `./tools/build_gdextension.sh` 重编；`test/reference/**` 只作冻结参照。
- 改 `class_name` / 新增/删脚本 → `godot --headless --import` 刷 `.godot`；`.tres` 的 `ext_resource` 用生成的 uid，别手编。
- GDScript 警告 = 错误（`check_syntax`）；原生 `WARN/ERR_PRINT` 会被 GUT 记 Unexpected Errors → 内核静默返回、宿主 `push_warning`。
- preset/builder 不覆写显式开关（`.enemy()` 别设 `is_spawn_fog`）。
- Godot 的 `erase_section` / `remove_*` 对不存在目标会 `ERR_FAIL`：先 `has_section` / `file_exists` 守卫。
- 重构成果靠机械护栏：`tools/check_structure.sh` 看住组合台同名场景壳 / 测试白盒预算只减不增 / 唯一来源常量 / 舞台接线唯一；护栏要先证明会红。
- 被托管视图的输入领地要显式划分：宿主 chrome 占更高 `CanvasLayer`（GUI 拾取按画布层从高到低）。
- 测试用夹具，别拿真实内容当断言标准；内容只做“不数数量、不写死路径”的结构冒烟。

> 其余跨子系统教训见 `BEST_PRACTICES_LOG.md`；内核/lifecycle 专项见 `DANMAKU_API.md` §3 / 附录 A（速查）。

## 其他契约（只指出处）

- **bomb 数据模型**（`BombData` 家族 + `KernelBulletHost.spawn_bomb` 按实际类型分派）→ `ARCHITECTURE.md` §6 · `CONTENT_GUIDE.md` §四。
- **弹型与贴图**（`data/bullets/*.tres` = 外观+碰撞+朝向；贴图 = 1024² 图集）→ `DANMAKU_API.md` §7.1。
- **纹理插座**（`_texture_by_index` / `texture_for_index()` 是设计 seam，不是债）→ `docs/archive/M3_TEXTURE_OWNERSHIP_DECISION.md`。

## 🔴 待改进（达标后清空）

- [ ] **R16**：47MB 二进制未配 Git LFS（`.gitattributes` 仅 EOL 规范化）。
- [ ] **R18/R19**：`spell_practice_menu.gd`（754）上帝对象；`workbench.gd` 已从 786 拆到 523（PreviewSuspender / PreviewLayout / PreviewInput / PreviewStageWorld / PreviewPhaseTimer / PreviewDebugTools / PreviewUI），但关卡加载/重跑、播放/书签接线仍在一个类里；判据是“一个类只做一件事”，行数只是提示。
- [ ] **R21**：`workbench` 11 处 `.new()` + 15 处 `add_child`（开发工具，可后）。
- [ ] **R2（残余）**：`item_service.gd:16` / `player.gd:286` 经 `current_scene` 取 World，可改注入。
- [ ] **编排路线**（`docs/archive/STAGE_FLOW_PLAN.md`）：Step 2 书签原生 / Step 6 `ctx.background` 注入服务待做；5/7 暂缓。
- [ ] **内核融合（M3）**：M1/M2 完成、M3 已拍板「纹理句柄」；判据改为结构性（0 类型映射 / 0 内容签名侧表）。

> 历史“重审说明 + K0 审计表”见 [`archive/BASELINE_EVIDENCE.md`](archive/BASELINE_EVIDENCE.md)（只增不改）。

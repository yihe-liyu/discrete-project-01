# ARCHITECTURE —— 项目架构总纲

> 本文是项目的**架构单一真源**：告诉你“这是什么、分几层、每层放什么、每个系统归谁管、改/加东西该去哪”。
> 用途：让架构“看得见、可照做、防止回头路”。改/加任何东西前，先对一下本文。
> 子系统详细见 `docs/DIALOGUE.md`、`docs/SPELL_SYSTEM_TARGET.md`、`docs/BACKGROUND_VISUAL_PLAN.md`、`docs/STAGE_FLOW_PLAN.md`。

---

## 0. 一句话

**内容 = 数据（resources），领域 = 纯逻辑（服务），运行时 = 薄节点（只演），表现 = UI（订阅信号）。**
**每一份“知识”有且只有一个 owner；系统之间走服务（ctx.*）或信号，绝不伸手进别人状态。**

---

## 1. 五层模型（“什么”放哪）

| 层 | 放什么 | 例子 | 关键约束 |
|---|---|---|---|
| **内容/数据层** | 资源（.tres/.gd 数据） | `BossData``PhaseData``EnemyData``StageData``BackgroundEnvPreset``DecorLayer` | **类型化、可校验、可序列化**；内容=数据，不写死在行为脚本里 |
| **领域逻辑层** | 纯逻辑（不含场景 node） | `BossCatalog`(身份)`RecordService`(记录)`StageObjects`(命名引用)`ctx.*`(服务) | 每个知识点**一个 owner**；不碰 Godot 场景树 |
| **运行时/节点层** | 场景 node（薄 host） | `Boss``Enemy``Player``Bullet` | **只“演”**：持有运行时状态 + 发信号；**不自己算跨对象知识** |
| **表现层** | UI | `boss_ui``dialogue_box` | **订阅信号**，不轮询、不伸手 |
| **(性能层)** | 性能关键路径 | `bullet_multi_mesh``spatial_hash` | 单独放，别跟业务混 |

**跨层铁律**：上面的层（领域/运行时）**知道**下面的层（内容/数据），但下面的层**不知道**上面。UI 只订阅，不驱动。

---

## 2. 系统地图 + 所有权

### 2.0 关键知识点 → owner（一人一份，只此一处）

| 知识 | owner | 位置 |
|---|---|---|
| 阶段身份（phase_index/第N张/boss_index） | **BossCatalog.resolve_identity** | `scripts/data/boss_catalog.gd` |
| 记录（attempts/captures/成绩） | **RecordService** | `scripts/coroutine/services/record_service.gd` |
| 运行对象引用（名字→对象） | **StageObjects** | `scripts/autoload/stage_objects.gd` |
| 状态变化通知（显示名/HP/阶段） | **信号**（可观察属性） | 各节点 |
| 参数（阶段/敌人调参） | **typed**（待修：现为 `params` 反射 = C4） | `phase_data.gd``enemy_data.gd` |

### 2.1 主要子系统（责任 / intent 接口 / 文件）

| 系统 | 责任 | 对外接口（intent） | 主要文件 |
|---|---|---|---|
| **Boss/敌人** | 演一段阶段 | `start_phase(phase)``get_boss_name`“set_boss_name”“current_phase” | `scripts/enemy/boss.gd“enemy.gd` |
| **子弹/激光** | 生成/物理/清理大量弹 | `ctx.bullets.shoot_spread(...)`“death_clear” | `scripts/bullet/*“laser/*` |
| **玩家** | 移动/射击/僚机/道具 | `ctx.player`“ctx.effects” | `scripts/player/player.gd“coroutine/player/*` |
| **对话** | 纯逻辑步骤 + 渲染 | `ctx.play_dialogue_steps(steps)`“d.event(...)” | `scripts/coroutine/services/dialogue/*` |
| **记录** | 持久化符卡簿 | `RecordService.record_phase_*` | `scripts/data/spell_*.gd` |
| **背景** | 环境/装饰/相机/太阳/雾 | `StageBackground`(相机/太阳/雾命令，待接 ctx.background) | `scripts/background/*` |
| **时间线/关卡** | 编排“何时做什么” | `tl.at()“{do,cmd,spawn_boss,...}` | `scripts/coroutine/timeline/*“stage_manager.gd` |
| **工作台** | 预览/调试/书签 | `workbench` | `scripts/workbench/*` |

---

## 3. 接口契约原则（好/坏接口的判据）

> **好的接口：调用方只说“我要什么”，不碰“怎么实现”。**（intent 层，而非 how 层）

- `ctx.audio.play_bgm(bgm)` ✅ 说“放这首歌”。
- `spawn_boss + register + set_name + create_tween 飞入` ❌ 调用方得懂“进场怎么做” → 应收成 `spawn_boss("boss_final", BossEntry.from(...).hidden())`。
- `params` 反射（`if k in script: script.set(...)`）❌ 调用方得知道“键名”，打错静默 → 应收成 **typed**。

**修接口 = 从“怎么操作零件”升到“声明我要什么”。** 每写一个接口，问：调用方这句是在说**要什么**还是在说**怎么做**？——在“怎么做”，就往里再收一层。

---

## 4. 边界铁律（“绝不”清单）

1. **内容=数据**——别在关卡/行为脚本里 `EnemyData.new()...spawn()` 现场捏内容；内容做成资源，脚本只引用。
2. **一知识一 owner**——身份问 `BossCatalog`、记录走 `RecordService`、引用走 `StageObjects`、状态走信号；**绝不自己算**。
3. **系统走服务（ctx.*），不摸全局**——别 `GameState.record_*``BulletManager.` 到处摸；删 `else Global` 双路。
4. **节点只演、只发信号**——`Boss` 不算身份/记录，`hp``boss_data` 不该裸暴露。
5. **UI 订阅，不轮询**——`boss_ui` 不再每帧拉 `get_boss_name`。
6. **参数 typed、可校验**——别用 `params` 反射。
7. **关卡脚本偏“声明式”**——编排用命令/事件，别自己包 `_on_dialogue_event` 大 match + 手工 spawn+tween。

---

## 5. 架构债 / 待修清单（按优先级）

| # | 债 | 层 | 该修成 | 优先级 |
|---|---|---|---|---|
| A | ~~`params` 反射（C4）~~ | 内容/参数 | ✅ 已修到「校验+响亮」（`ParamValidator`）；「全 typed 资源」未做 | 已做（2026） |
| B | ~~双路 `if ctx else Global`~~ | 领域/接口 | ✅ 已修：系统操作统一走 `ctx.*`，删除 else-Global 回退 | 已做（2026） |
| C | 调用方拼内容（`EnemyData.new()...spawn`） | 内容/接口 | 内容做资源 | 中 |
| D | 关卡脚本胖（大 match + 手工 spawn/tween） | 编排/接口 | 事件派发 + intent 层接口 | 中 |
| E | Boss 公开可变（`hp`“boss_data） | 运行时/封装 | 只读/访问器 | 低 |
| F | 时间分片/暂停缝（C6） | 运行时/时间 | 统一时间所有权 | 低（系统性） |

---

## 6. 操作指南《如何新增 X》

> **完整流程见 `CONTENT_GUIDE.md`（根目录，单源）。** 下面是浓缩原则。

> 做内容前先问：**这是系统能力（全关卡可复用）还是这关内容（只这关）？**

### 新增 Boss
- 内容：`boss_catalog.gd` 加 `BossData`（名字/视觉/阶段）+ `PhaseData` 资源。
- 身份/记录：**不用碰**——`resolve_identity`“`RecordService` 自动生效。
- 运行时：`boss.gd` 如需新“演”逻辑，加方法；**别在 Boss 里写身份/记录**。
- 引用：关卡 spawn 后 `StageObjects.register("boss_xxx", b, Boss)` 用名字引用。
- 绝不：在 Boss 里 `record_*`、算 `phase_index`。

### 新增符卡/阶段
- `PhaseData` 资源 + 子弹/移动脚本；**参数用 typed**（别裸 `params`）。
- 阶段身份由 `BossCatalog` 规范序自动编号；**别手写 index/第N张**。

### 新增敌人
- `EnemyData` 资源 + 行为脚本；**别在关卡脚本 `EnemyData.new()...spawn`**，做成资源引用。

### 新增关卡
- `StageData` + 关卡脚本（`CoroutineScript`）；内容=数据；boss 用槽位；记录走服务；编排声明式。

### 新增“系统能力”（新动作）
- 给**系统**加方法（如 `Boss.start_phase`），或给 `StageObjects`“服务加操作；**别在关卡脚本里临时实现**。
- 然后 `cmd(slot, action, args)`“`_stage_events.on(name, handler)` 调用它。

---

## 7. 索引 / 该读哪些

- **总纲（本文）**：分层/系统地图/所有权/边界/债/操作指南。
- **路线**：`docs/STAGE_FLOW_PLAN.md`（(b) 规划：对象自治/身份归位/命令化 + 七步）。
- **对话**：`docs/DIALOGUE.md``DIALOGUE_REFACTOR_PLAN.md`。
- **符卡**：`docs/SPELL_SYSTEM_TARGET.md`。
- **背景**：`docs/BACKGROUND_VISUAL_PLAN.md`。

## 8. 命名约定 · 禁令 · 现状（并入自 SPEC §14/§15/§17）

### 8.1 命名约定
| 类别 | 约定 | 例 |
|---|---|---|
| 类名 | PascalCase | `BulletData` |
| 文件名 | snake_case | `bullet_data.gd` |
| 私有成员 | `_` 前缀 | `_pool` |
| 公共成员 | 无前缀 | `active_bullets` |
| 信号 | snake_case | `stage_cleared` |
| 信号回调 | `_on_`+信号名 | `_on_enemy_killed` |
| @export | snake_case + 注释 | `@export var focus_speed: int ## 低速速度` |
| 常量 | UPPER_SNAKE | `POOL_SIZE` |
| 枚举 | PascalCase | `Type.POWER` |

**避讳**：`range`→`patrol_range`、`dir`→`direction`（避免遮蔽内置）。

### 8.2 禁止操作（SPEC §15.4）
- ❌ 直接 `randf()/randi()`（走 RNG）
- ❌ 直接写 `GameState.current_score/lives/power_raw`
- ❌ 协程/碰撞回调内 `await`
- ❌ `ctx.active()==false` 时调 StageContext 方法
- ❌ 直接 instantiate 子弹（走 BulletManager）
- ❌ 外部调 `Enemy/Boss.die()`
- ❌ 场景切换期间读 `current_scene` 子节点
- ❌ 直接改 `.uid` 文件（Godot 维护）

### 8.3 现状 / 待补 / 债务（SPEC §17 摘）
- ✅ 已实现：引擎核心/Autoload、弹幕、敌人Boss、玩家、协程框架、道具、特效、背景、音频、UI/菜单、对话、记忆释放、数据类、Stage1。
- ⏳ 待补：Stage 2~6、Boss 战多面、部分美术占位。
- 🐛 债务：DifficultyScreen 覆写 NavPage 90%、PauseMenu/GameOverMenu `_on_leave` 重复。
- 🚧 缺：Bomb 释放（`cancel&bomb` 未接读取）、Stage Practice（占位）、Replay（只录不放）、Continue/Result 结算。

> 完整/原始的命名与文件树见已归档的 `docs/archive/SPEC.md`（未来不再逐系统维护，交给 ARCHITECTURE + 子系统文档）。

---

*本文是“应当怎样”的契约；与现状不符处即架构债（见 §5），逐项修平。*

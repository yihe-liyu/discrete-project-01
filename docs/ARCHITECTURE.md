# ARCHITECTURE —— 当前架构模型

> **本文回答**：系统分几层、谁负责什么、一个物理 tick 里按什么顺序发生、状态归谁、哪些边界不能破、代码在哪。
> **不回答**：怎么加一张卡（→ [CONTENT_GUIDE](../CONTENT_GUIDE.md)）、每个测试保护什么（→ [TEST_INDEX](TEST_INDEX.md)）、
> replay 为什么可能不一致（→ [REPLAY_MODEL](REPLAY_MODEL.md)）、历史决策（→ [BEST_PRACTICES_LOG](BEST_PRACTICES_LOG.md)）。

## 0. 一句话

**内容 = 数据 / 代码资源，领域 = 服务，运行时 = 薄节点，表现 = 订阅信号；玩法只有一个 tick 权威，所有跨对象操作走服务或事件。**

## 1. 分层

| 层 | 放什么 | 典型文件 | 约束 |
|---|---|---|---|
| **内容 / 数据** | `.tres` + `data/**/*.gd` 内容脚本 | `data/stages/**`、`data/boss_scripts/**`、`data/dialogue/**` | code-first；内容不 `get_parent()`、不 `create_tween()`、不直接读 `Input` |
| **领域 / 服务** | 无场景节点的规则、目录、记录、服务 | `scripts/data/**`、`scripts/coroutine/services/**`、`scripts/stage/**` | 一知识一 owner；不持有场景树 |
| **运行时 / 节点** | 持有运行时状态、接收 tick、发信号 | `GameScene`、`StageRuntime`、`Player`、`Enemy`、`Boss`、`BulletManager`、`ItemPool` | 只“演”和“推进”；不自己算跨对象身份 / 记录 |
| **表现 / UI** | HUD、菜单、对话框、背景、特效 | `scripts/scenes/**`、`scripts/background/**`、`scripts/effect/**` | 订阅信号；纯表现可 `_process` / Tween / Timer |
| **内核** | 原生弹幕存储、积分、behavior、宽相 | `gdextension/src/**`、`scripts/kernel_bridge/**` | `DanmakuStore` 是弹幕权威；GDScript 只读快照 / 发命令 |

## 2. 组合根与运行时图

```text
project.godot
  autoload: GameEvents / GameManager / RNG / AudioManager / SimClock
        │
        ▼
MainMenu / 菜单栈 ──change_scene──▶ GameScene（组合根）
        │
        ├─ SubViewport / World
        │    ├─ StageRuntime（关卡生命周期）
        │    ├─ BulletManager（弹幕世界 + 宿主碰撞）
        │    ├─ ItemPool / FxPool / MissCircleLayer / Telegraph
        │    └─ Player / Enemy / Boss（运行时节点）
        ├─ GameUI（HUD）
        └─ 3D 背景（StageBackground）
        │
        └─ StageHost.wire_world / wire_player：唯一接线入口
                 │
                 ▼
        StageRuntime.load_stage(data)
          ├─ CoroutineScript（关卡脚本，Timeline 编排）
          ├─ StageContext（ctx.* 服务门面）
          └─ EntityRegistry（自机 / 敌机 / Boss）
```

### 2.1 关键对象

| 对象 | 责任 | 不负责 |
|---|---|---|
| `GameScene` | 装配、开局资源、录制/回放钩子、结算与场景切换 | 阶段内部规则 |
| `StageRuntime` | `load_stage` / `spawn_*` / `finish_stage` / `stop_stage`；关卡脚本生命周期 | 具体弹幕 / 阶段数值 |
| `StageContext` | `ctx.clock / bullets / player / enemies / boss / items / audio / effects / dialogue / objects / background / telegraph` 懒加载门面 | 自己保存游戏状态 |
| `CoroutineScript` / `CoroutineRunner` | 每 tick 推进任务；`Timeline` 只排“何时” | 识别游戏机制 |
| `StageDirector` / `BossHandle` | 内容层场景动词：`boss / dialogue / bgm / on`、`enter / phase / retreat / defeat` | 直接操作节点内部 |
| `EntityRegistry` | 自机 / 敌机 / Boss 的单一活动列表 | 记录 / 身份计算 |
| `StageCatalog` / `StageRouteCatalog` / `BossCatalog` | 关卡、路线、Boss / 阶段身份的只读目录 | 运行时推进 / 记录写入 |
| `SaveData` / `SaveManager` | 会话状态（路线 / 当前 stage / 开局资源）与 `user://` 存档 | 关卡内部规则 |
| `BulletManager` | 弹幕门面、激光/清弹/宿主碰撞 | 持有弹幕权威数据（在原生 store） |
| `ReplayV2Session` | 录制 / 回放会话、输入注入、哈希校验 | 保存逐帧游戏状态 |

## 3. 一个物理 tick 的顺序

`SimClock` 是玩法时间的唯一权威（`scripts/autoload/sim_clock.gd`，优先级 `-10000`）：

```text
SimClock._physics_process
  1. 处理上一 tick 的延迟解冻 / 重新压住暂停
  2. 若暂停菜单暂停（非玩法冻结）→ 本 tick 不推进
  3. tick_prepare(next)      ← 回放注入 mask/命令；录制 flush 对话等帧间事件
  4. tick += 1
  5. PlayerInput.latch()     ← 本 tick 唯一输入快照
  6. tick_observer(tick)     ← 录制 / 回放哈希校验（在 gameplay 之前）
  7. 冻结 owner 倒计时
```

之后按 `process_physics_priority` 从小到大：

| 优先级 | 谁 | 做什么 |
|---:|---|---|
| `-10000` | `SimClock` | 建立 tick 边界、锁输入、录制/回放钩子 |
| `-100` | `MarisaShoot`（射击协程） | 同步激光锚点；再让 `CoroutineRunner` 推进射击状态机 |
| `-50` | `TickMover` | Boss / 敌人 / 复位的 tick 化移动 |
| `-10` | `KernelNativeSystem` | 原生积分 + `behavior_tick` + 拉只读快照 |
| `-4` | `KernelBulletHost` | 延后动作 flush + 激光渐隐 |
| `0` | `BulletManager` / `Player` / `Enemy` / `CoroutineRunner` / 多数节点 | 宿主碰撞、移动、发弹、时间线/协程推进 |
| `100` | `Boss` | 阶段计时、HP 缓降、奖励分 tick |

> **债务**：`0` 这一档目前靠场景树顺序，而不是显式的 `FrameOrder`。这段顺序在录制/回放中稳定，但“新增节点插在哪”仍是隐式知识；目标是由组合根显式赋优先级。

### 3.1 一次 run 的生命周期

```text
菜单选难度/角色
  → SaveData.selected_* / selected_route
  → GameScene._ready
      ├─ SimClock.reset / GameManager.PLAYING
      ├─ StageHost.wire_world / wire_player / wire_registry
      ├─ 普通局：ensure_route → start_recording（抓 seed/state）
      ├─ _setup_player → 开局资源（reset / 跨面继承）→ capture_start_resources
      └─ StageRuntime.load_stage
            ├─ StageData.validate
            ├─ new CoroutineScript → StageContext → start(ctx)
            ├─ StageDirector / BossHandle / Timeline
            ├─ 背景脚本启动
            └─ stage_started

每 tick：SimClock → gameplay（见 §3）

关卡收尾：
  StageDirector.finish_stage → StageRuntime._on_stage_finished
    → 高分写入 → stage_cleared / all_enemies_defeated
    → GameScene 结算：继续下一面（capture_run_state + advance_route + reload）
      或结束（finish_recording + 回主菜单）
玩家死亡：
  Player.miss → GameEvents.player_death → GameScene 延迟 → Game Over / finish_recording
```

### 3.2 实体生命周期（简）

- **敌人**：`StageRuntime.spawn_enemy_data` → 实例化 + 注入 `ctx`/params + `add_enemy_to_scene` → `Enemy._ready` 注册 → 行为 `CoroutineScript.start` → `die()`（掉落 / 特效 / 计分）或 `despawn()`（静默回收）。
- **Boss**：`StageRuntime.spawn_boss` → `add_enemy_to_scene` → `Boss.setup/start_boss`（注册）→ `start_phase`（宣言 / HP 缓降 / 移动 / 射击）→ `clear_phase`（奖励 / 掉落 / 信号）→ `die` / `retreat` / `defeat`。
- **道具**：`ItemPool.spawn` → `Item` 下落 / 吸附 → 收集或出屏回收；跨面资源由 `PlayerResources` 持有。
- **弹幕**：`BulletManager` 门面 → `KernelBulletHost` 写原生 `DanmakuStore` → 每 tick 原生积分 → `KernelBulletPhysics` 判定；GDScript 只读快照。

### 3.3 冻结与暂停

- 玩法冻结只走 `SimClock.freeze(owner, frames, auto_unfreeze)`；冻结期间 `SceneTree.paused = true`，`SimClock` 继续走 tick 倒计时。
- 不压 `Engine.time_scale`，不用真实时间 `Timer` / Tween 做玩法时间。
- 暂停菜单自己暂停树；`SimClock` 只在“自己暂停的”情况下负责恢复，且覆盖层打开时不抢恢复。
- 纯表现层可以继续 `_process` / Tween；它不能写模拟状态。

## 4. 状态所有权

| 状态 | 唯一 owner | 写入方式 |
|---|---|---|
| 当前 tick / 冻结 | `SimClock` | 每物理 tick 唯一入口 |
| 本 tick 输入 mask / 命令 | `PlayerInput` | `latch()` 一次；玩法只读 |
| 路线 / 当前 stage / 会话 | `SaveData` | 菜单 / `GameScene`；`reset_session()` 统一复位 |
| 关卡 / 路线 / Boss 目录 | `StageCatalog` / `StageRouteCatalog` / `BossCatalog` | 只读；注册表 + 资源扫描 |
| 自机资源 | `PlayerResources` | `Player` / 道具 / Boss 奖励通过明确 API |
| 自机位置 / bomb / miss | `Player` | `_physics_process`（固定 `SimClock.DT`） |
| 弹幕行数据 | `KernelNativeSystem` / `DanmakuStore` | 原生积分；GDScript 只读快照 |
| 激光 | `LaserEngine` | `step(SimClock.DT)` 唯一驱动 |
| 道具 | `ItemPool` | `spawn` / `recycle`；`Item` 自身推进 |
| Boss 阶段 / HP / 计时 | `Boss` | `start_phase` / `advance_ticks` / `clear_phase` |
| 敌机列表 | `EntityRegistry` | `register_enemy` / `unregister_enemy` |
| 命名对象引用 | `StageObjects` | `register` / `resolve`（per-run） |
| 阶段身份 / 记录 | `BossCatalog` / `RecordService` | 只读 / 明确记录 API |
| 对话状态 | `DialogueBox` / `DialogueRunner` | 固定 tick 推进 + 回放命令 |
| 回放会话 | `ReplayV2Session` | 录制 / 回放 / 停止 |

## 5. 事件模型

- **输入**：`PlayerInput.ACTIONS` 固定顺序；每 tick 一次 `latch()`；离散命令（bomb / memory / 对话推进 / 关闭）在 tick 边界消费。
- **对话**：`DialogueRunner` 固定 tick 推进；行间 `EVENT` 在 `advance` 时触发；`StageDirector.on(key, handler)` 路由到内容 handler；`boss_enter / boss_fight / stage_end` 是内容事件，不是硬编码分支。
- **时间线**：`Timeline.at/wait/every` 只排“何时”；执行 `Callable`；阶段序列通过 `Boss.phase_cleared` 推进。
- **信号**：`GameEvents`（Boss 生成/击破、阶段开始/结束、玩家死亡/炸弹等）供表现与组合根订阅；模拟状态不依赖 UI 订阅顺序。
- **场景切换**：`GameManager.change_scene` / `reload_current_scene`；切面前由 `SaveData.capture_run_state` 保存跨面资源；录制/回放通过 `_continuing_replay` 跨 scene 保留。

## 6. 边界铁律

1. **玩法只用 `SimClock.DT`**：不读 `delta`、不 `create_tween()`、不 `Timer`、不 `Engine.time_scale`、不直接 `Input`（走 `PlayerInput`）。
2. **纯表现不写模拟状态**：背景、UI、震屏、命中特效、死亡特效可以 `_process` / Tween；不能改 HP / 分数 / 生成弹幕。
3. **一知识一 owner**：身份问 `BossCatalog`、记录问 `RecordService`、命名引用问 `StageObjects`、活动实体问 `EntityRegistry`。
4. **内容只碰动词**：`timeline.*` / `_dir.*` / `ctx.*`；不 import `StageRuntime`、不手拼 `BulletManager`、不 `get_parent()`。
5. **依赖向下注入**：`GameScene` / `StageHost` 注入；禁止全树搜、`get_node("..")`。
6. **回放只注入输入/命令，不改状态**：没有 force despawn / graze / RNG resync；哈希不一致 = 模拟有问题。

完整红线 / 命名 / 会话规则见 [BASELINE](BEST_PRACTICES_BASELINE.md)。

## 7. 代码地图

| 目录 | 内容 |
|---|---|
| `scripts/autoload/` | `GameEvents`、`GameManager`、`RNG`、`AudioManager`、`SimClock` |
| `scripts/scenes/` | `GameScene`、菜单、UI、对话框、HUD |
| `scripts/stage/` | `StageRuntime`、`EntityRegistry`、`StageHost`、`StageData` 装配 |
| `scripts/coroutine/` | `CoroutineRunner/Script`、`Timeline`、`StageDirector`、`BossHandle`、`TickMover`、`ctx.*` 服务 |
| `scripts/player/` | `Player`、`PlayerInput`、`PlayerResources`、射击协程 |
| `scripts/enemy/` | `Boss`、`Enemy`、HUD/视觉 |
| `scripts/bullet/` | `BulletManager`、MultiMesh、清弹 |
| `scripts/laser/` | `LaserEngine`、`LaserBeam`、`LaserSkeleton` |
| `scripts/item/` | `ItemPool`、`Item` |
| `scripts/kernel_bridge/` | 原生 store 的 GDScript 桥、宿主碰撞、bomb |
| `scripts/sim/` | `SimHash`（总 / 分项状态哈希） |
| `scripts/replay/` | `ReplayV2`、`ReplayV2Session`（v1 `ReplayRecorder` 仅历史） |
| `scripts/data/` | 数据类、目录、存档、难度、身份 |
| `data/` | 内容：stage / boss / phase / dialogue / bullets / routes / registry |
| `scenes/` | 运行时场景与 UI 场景 |
| `gdextension/src/` | 原生 `DanmakuStore` / behavior / 宽相 |
| `test/` | GUT + 夹具 + 原生 parity |
| `tools/` | 门禁、bench、内容 manifest / preflight |

## 8. 改东西去哪

| 要改 | 落点 |
|---|---|
| 阶段数值 / 弹幕脚本 | `data/stages/<面>/phase/**` + `PhaseData.tres` / `BossData.tres` |
| 关卡节奏 / 敌人 / Boss 事件 | `data/stages/<面>/stage_data/*.gd` + `Timeline` + `StageDirector` |
| 对话台词 / 事件 | `data/dialogue/stage/*.gd` + `_dir.on(...)` |
| 新弹幕运动 | `SpawnSpec.with_behavior(BulletBehaviors.xxx)`；新数学才加 C++ pack |
| 新全局系统能力 | 加服务 / 节点 API，再让内容通过动词调用 |
| 新内容注册 | `data/registry/stage_registry.tres` / `boss_registry.tres` |
| 改 tick / 回放 | 先读 [REPLAY_MODEL](REPLAY_MODEL.md)，改完必须跑回放测试 + 升 `SIM_VERSION` |

## 9. 当前结构债（2026-11-23）

| 债 | 影响 | 方向 |
|---|---|---|
| 没有单一 `Simulation.step` | gameplay 仍是节点 `_physics_process`；顺序靠优先级 + 树序 | 显式 `FrameOrder` / 手动 step，才能 headless 快进 |
| `0` 档顺序隐式 | 新节点插队可能改变模拟 | 组合根统一赋优先级 |
| `content_hash` 为空 | 内容变了仍可能通过 `sim_version` | 内容 manifest / build stamp 写进 header |
| `SimHash` 32 位 | 碰撞概率 + 覆盖字段需维护 | 诊断用足够；需要更强校验再升 64 位 |
| 回放长局未收口 | 当前在对话 → Boss 入场出现 `boss_pos` 分歧 | 见 [REPLAY_MODEL](REPLAY_MODEL.md) 的“已知问题” |
| 内容完成度 | Stage 2/3B 仍在制作 | 不把空目录当“已完成” |

## 10. 接下来读什么

- 回放 / 确定性： [REPLAY_MODEL](REPLAY_MODEL.md)
- 硬规则 / 命名 / 注入： [BASELINE](BEST_PRACTICES_BASELINE.md)
- 测试地图： [TEST_INDEX](TEST_INDEX.md)
- 内容怎么加： [CONTENT_GUIDE](../CONTENT_GUIDE.md) + [CONTENT_AUTHORING_CONTRACT](CONTENT_AUTHORING_CONTRACT.md)
- 弹幕 / 内核： [DANMAKU_API](DANMAKU_API.md) + [NATIVE_BEHAVIOR_PACK](NATIVE_BEHAVIOR_PACK.md)

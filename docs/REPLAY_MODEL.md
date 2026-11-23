# REPLAY MODEL —— 确定性回放模型

> **本文回答**：replay 依赖哪些状态、每 tick 按什么顺序推进、哪些东西会破坏一致性、当前实现到哪、出现分歧怎么定位。
> **不回答**：具体内容怎么写（→ [CONTENT_GUIDE](../CONTENT_GUIDE.md)）、通用架构（→ [ARCHITECTURE](ARCHITECTURE.md)）、测试文件清单（→ [TEST_INDEX](TEST_INDEX.md)）。
> **状态**：现行实现为 **Replay**（兼容性标记 `sim-v9`）；`sim-v8` 的 Boss 入场差拍已定位并修复。`sim-v9` 已通过 **10,843 tick、Stage 1 → Stage 2 Game Over 的完整 run 回放，零分歧**，见 §9。

## 0. 定义

Replay = **同 seed + 同逐 tick 输入/命令 + 同内容 + 同模拟语义** ⇒ 重跑出同一串规范状态。

- 只存“输入 + 命令 + 起点状态”，不存逐帧位置/弹幕/RNG trace。
- 回放不是“播放录像”，是“重新跑同一套模拟”；哈希不一致说明模拟不确定，不能用 force 修正掩盖。
- 旧格式不兼容；加载时按 magic / 格式版本直接拒绝。

## 1. 非目标

- 不保证跨 `SIM_VERSION` / 跨内容版本的回放；语义变了就拒绝。
- 不保证跨平台逐位一致（暂未验证 ARM64 / 不同 GPU / 不同浮点环境）。
- 不保证 UI / 特效 / 音频逐帧一致；只保证模拟状态。
- 不保存“中途存档 / 任意回滚”；只从起始 stage 重跑。

## 2. 模拟边界

### 2.1 属于模拟（会影响 hash）

| 子系统 | 状态 |
|---|---|
| 时间 | `SimClock.tick`、冻结 owner / 剩余帧 |
| 输入 | 本 tick mask、离散命令（bomb / memory / 对话推进 / 关闭） |
| 自机 | 位置、`PlayerResources`、无敌/复活/bomb/deathbomb、射击状态机 |
| 弹幕 | 原生行 uid / type / 位置 / 速度 / 行为状态、激光、清弹圈 |
| Boss | 阶段 uid、HP、累计 tick、开局减伤 tick、位置 |
| 敌机 | 活跃列表、HP、位置、行为协程状态 |
| 道具 | 活跃道具类型 / 位置 |
| 对话 | `DialogueRunner` 当前步骤 / 等待状态；对话事件触发的舞台副作用 |
| RNG | 宿主 gameplay RNG 的 seed/state；内核 RNG 由宿主 seed 派生 |
| 舞台 | 当前 stage、路线位置、开局资源、Boss/敌人生成与事件顺序 |

### 2.2 不属于模拟（不得反向写模拟）

- 背景 / 相机 / 雾 / 装饰位置（纯表现）
- 震屏、命中特效、死亡特效、屏幕闪白
- 菜单、按钮动画、HUD 补间
- 音频播放 / BGM 淡入淡出（除 gameplay 逻辑读取的音效 key 外）
- 日志 / 诊断字符串

> 纯表现可以用 `_process` / Tween / Timer；**不得**改 HP、分数、生成/删除弹幕、推进对话、改 RNG 的 gameplay 流。

## 3. 一个 tick 的 replay 视角

```text
tick N 开始
  SimClock.tick_prepare(N)
    ├─ 回放：PlayerInput.set_override_mask(录像 mask)
    ├─ 回放：queue bomb / memory / 对话推进 / 关闭
    └─ 录制：flush 本 tick 的对话 pending（若有）
  tick = N
  PlayerInput.latch()
     └─ 本 tick 的 mask / 命令冻结；玩法只读
  SimClock.tick_observer(N)
    ├─ 录制：SimHash.of + SimHash.fields → 写 mask / commands / hashes / field_hashes
    └─ 回放：拿同一 tick 的 hash 对比；不一致 → 报字段并结束
  冻结倒计时（不改变本 tick 的 hash 时点）
  ---- 以下为 gameplay ----
  SimClock 内部 TickMover 列表（observer 之后）→ MarisaShoot -100
  → KernelNativeSystem -10 → KernelBulletHost -4
  → BulletManager / Player / Enemy / CoroutineRunner (default 0) → Boss 100
tick N 结束
```

> 关键：**hash 观测在 gameplay 之前**。因此 `tick_prepare` 里注入的输入 / 对话事件、`latch` 的 mask，都必须与录制端“同一时点、同一状态”对齐。
> 这是对话 → Boss 入场差拍的敏感点：事件在 `prepare` 应用 vs 在 gameplay 中延后，会改变“哪一 tick 的 hash 里出现 Boss 位移”。

## 4. 录制格式

JSON header：

```text
magic = "TSR2"
version = 2
tick_rate = 60
seed / rng_state        宿主 RNG 起点
sim_version             模拟语义版本（当前 sim-v9）
content_hash            data/** 的 SHA-256 内容指纹（空 = 旧文件 / 未计算）
metadata                difficulty / character / route_id / start_stage_id/no / result / score / ...
start_resources         录制起点的自机资源快照（跨面 / 中途起点）
masks_hex              每 tick 1 字节输入 mask
commands_hex           每 tick 1 字节离散命令位
hashes                 每 tick 总 SimHash（32 位）
field_hashes           每 tick 分项哈希（诊断；旧文件可为空）
```

命令位：

| bit | 含义 |
|---:|---|
| `1` | bomb |
| `2` | memory release |
| `4` | 对话推进（Z / 跳过本句） |
| `8` | 关闭对话 |

### 4.1 `SimHash` 分项

`SimHash.fields()` 当前拆成：

```text
tick / rng / player / resources
boss_phase / boss_hp / boss_time / boss_pos
enemies / items / lasers / bullets
```

总 hash 与分项 hash 独立计算；分项只用于定位，不参与判定。`SimHash` 是 32 位 FNV-1a，诊断足够，不是密码学证明。

## 5. 回放生命周期

### 5.1 开始录制

1. `GameScene._ready`：若不在练习 / 不在回放，先确保路线与起始 stage，抓 RNG seed/state。
2. `ReplaySession.start_recording(meta)`：写 header，清空缓冲，`SIM_VERSION`。
3. `_setup_player` + 开局资源（`reset_all` / 跨面继承）。
4. `ReplaySession.capture_start_resources`：只抓一次，记录起点资源。
5. `StageRuntime.load_stage` 之后挂 `SimClock` 钩子：`_on_record_prepare` / `_on_record_observe`。
6. 每 tick：prepare flush 对话 pending；observe 写 mask / commands / 总 hash / 分项 hash。
7. 结束：Game Over / 通关 / 退出 -> `finish_recording(meta)`；跨面继续时保留录音，不 cancel。

### 5.2 开始回放

1. 从文件加载，校验 magic / version / `sim_version` / 长度。
2. `SaveData.reset_session`；设置难度 / 角色 / 路线 / 起始 stage。
3. `RNG.set_seed` + `restore_state`；`start_playback` 重置下标。
4. `GameScene._ready` 走普通开局分支；`apply_start_resources` 只应用一次。
5. 挂 `_on_replay_prepare` / `_on_replay_observe`。
6. 每 tick：prepare 注入 mask/命令/对话；observe 比对 hash；不一致 -> `report_fields` + 结束。
7. 通关 -> `_advance_playback_stage`：capture 当前资源、advance route、reload；继续同一录像。
8. 玩家死亡 -> 结束回放，回 Replay 菜单。

## 6. 必须保持的不变量

1. **时间**：玩法状态只按 `SimClock.DT` 推进；不读引擎 `delta`。
2. **顺序**：同一 tick 的所有状态变更，由固定优先级 + 树序决定；不依赖渲染帧。
3. **输入**：每 tick 只 latch 一次；玩法不直接读 `Input`。
4. **事件**：对话推进 / 关闭、Boss 生成 / 阶段切换、stage 结束都在 tick 边界；不在 Tween/Timer 回调里改模拟。
5. **RNG**：gameplay 只走 `RNG`（宿主）/内核 RNG；纯表现走 `RNG.fx_*`；不把表现随机混进 gameplay 流。
6. **起点**：`start_stage` / `start_resources` / seed / rng_state / 难度 / 角色必须可恢复。
7. **版本**：模拟语义改动必须升 `SIM_VERSION`；内容改动最终要进 `content_hash`。
8. **无修正**：回放只校验，不 force despawn / graze / spawn / RNG resync。

## 7. 失败分类

| 类别 | 典型症状 | 先查 |
|---|---|---|
| 起点不一致 | `idx=0` 就不一致 | metadata / 路线 / 起始 stage / `start_resources` / RNG 起点 |
| 事件差拍 | 某个剧情/入场后几 tick 才分叉 | 对话 advance / `StageDirector` 事件 / `BossHandle.enter` / Timeline |
| 环境时间 | 移动/计时晚 1–N tick | Tween / Timer / `_process` / `delta` / `time_scale` |
| RNG 污染 | 状态看起来一样，只有 `rng` 分项不同 | 表现层是否调用 gameplay RNG |
| 顺序 | 同一 tick 内位置/碰撞差 | `process_physics_priority` / 树序 / 新节点插入 |
| 内容 / 版本 | 旧录像整体不可信 | `sim_version` / `content_hash` / 资源变更 |
| 覆盖不足 | 总 hash 相同但行为不同 | `SimHash` 漏字段（如 Boss 位置曾漏过） |

## 8. 调试流程

1. **先看 `field`**：`Replay 分歧字段 idx=... field=...` 已把范围缩到子系统。
2. **再看 `exp/cur`**：总 hash 只说明不同；分项 hash 说明哪一块。
3. **同进程 `debug_capture`**：录制时保存人类可读快照，回放时 `debug_compare` 打印第一条不同的行（位置 / HP / 数量等）。快照只在同一次 Godot 进程内有效，重启后加载旧录像没有期望快照。开发期默认开（`ReplaySession.debug_capture = true`），只占内存、不写文件；正式收尾前应关掉。
4. **同一份录像复现**：先不要改 gameplay；只加观测 / 日志，确认是“起点、事件、时间、RNG、顺序、覆盖”哪一类。
5. **定位到 tick**：用分项哈希做二分/线性扫描，找第一个分叉 tick。
6. **最小修复**：只改根因；改完升 `SIM_VERSION`，重录一次作为回归 fixture。
7. **回归**：`test_game_scene_replay`（录制/回放、bomb、跨面）+ `test_replay` + `test_sim_hash`。

## 9. 已定位问题与修复（2026-11-23）

`sim-v8` 的 Stage 1 长局在 `idx=5747` 出现 `field=boss_pos`：

```text
exp boss pos=(987.801,494.475)
cur boss pos=(1000.000,500.000)
```

- 录制里 Boss 已开始入场，回放仍停在出生点；`boss_phase / hp / time` 与其它分项相同。
- 追踪到 `boss_enter` 在 `tick_prepare` 中触发，`BossHandle.enter` 创建的 `TickMover` 节点明明在树里、`can_process=true`，但它的 `_physics_process` 从未被 Godot 调用（`frame=0`）。
- 根因不在移动数学、RNG 或对话事件本身，而在**在物理回调中新增节点后，节点自动步进的注册空档**。
- 修复：`TickMover` 不再自动 `_physics_process`，改为注册到 `SimClock`，由 `SimClock` 在 observer 之后、gameplay 之前统一 `tick_mover()`；`SimClock.reset()` 清空列表。
- 回归：`test_tick_mover` 覆盖“在 `tick_prepare` 中新增 mover 也必须推进”。
- `SIM_VERSION` 升到 `sim-v9`；旧的 `sim-v8` 录像会被拒绝。
- **验证**：
  - 临时端到端：Stage 1 录制 + 回放 5760 tick（覆盖战前对话、`boss_enter`、Boss 入场），零分歧；192s，不放进常驻 GUT。
  - **真实完整 run（2026-11-23 18:45）**：`sim-v9`，10,843 tick，Stage 1 Lunatic → Stage 2 Game Over，逐 tick 总/分项哈希零分歧；日志无任何 `分歧`。
  - 常驻回归：`test_tick_mover`（prepare 中新挂 mover + 冻结不推进）+ `test_game_scene_replay`。
- 内容闸门：新录制写 `content_hash = ContentFingerprint.compute()`（`data/**` 源文件 SHA-256）；回放 / 菜单会拒绝内容指纹不匹配的旧录像。
- 调度器：`TimeScheduler` 已落地（固定 DT、倍率、单帧补 tick 上限），最小 600 tick 用例通过。
- **已尝试但不采用**：replay 专用 `ReplayDriver` 手动接管 GameScene 节点。它能在 1s 内跑 600 tick，但与 live 的节点顺序 / 新节点入树时序不一致，首个分歧出现在 `bullets`/`items`（约 idx 61–273），不是可接受的快进。结论：不能靠“driver 自己维护节点顺序”复制 live；必须先有共享的 `Simulation.step` / `FrameOrder`。
- 仍未做：完整 GameScene 的 headless 快进、跨平台逐位一致性。

## 10. 完成判据

- 同一份录像完整回放 Stage 1 → Boss → 通关 / Game Over，零 `分歧`。
- 同一输入跑两次（录制 + 回放）逐 tick 总 hash + 分项 hash 一致。
- 600 tick 能在 headless 手动 step 下 < 5s 跑完：最小 harness 已实测通过（`test_replay` 的 600 tick 用例）；完整 GameScene 仍需显式 step driver。
- `content_hash` 非空；内容变更能拒绝旧 replay（已落地，`ContentFingerprint`）。
- 玩法目录的 `Input` / `create_tween` / `create_timer` / `time_scale` 由 lint 禁止（当前靠人工审计）。

## 11. 相关文件

| 文件 | 作用 |
|---|---|
| `scripts/replay/replay.gd` | 格式 / 序列化 / 校验 |
| `scripts/replay/replay_session.gd` | 会话、输入注入、哈希、菜单列表 |
| `scripts/sim/sim_hash.gd` | 总 hash / 分项 hash / 人类可读快照 |
| `scripts/scenes/game_scene.gd` | 录制/回放钩子、起点资源、跨面 |
| `scripts/autoload/sim_clock.gd` | tick 权威 / prepare / observer / freeze |
| `scripts/player/player_input.gd` | 输入锁存 / override / 命令 |
| `scripts/scenes/dialogue_box.gd` | 对话 tick / 推进命令 / 回放应用 |
| `test/test_replay.gd` · `test/test_game_scene_replay.gd` · `test/test_sim_hash.gd` | 回归 |

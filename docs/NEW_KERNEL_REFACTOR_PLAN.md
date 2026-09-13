# 原项目 × 新弹幕内核：迁移与改造方案

> 定位：把原项目「节点弹池 + 12 autoload + 协程行为 + 独立 LaserEngine」的弹幕链路，**逐步**迁到重建版内核的架构（SoA 核心 + 组合根注入 + 数据资源 + 显式帧序/层序 + 无头测试），同时保持游戏可玩、可回退。
> 前置阅读：`1-st-touhou-star-rebuild/docs/DECISION_DANMAKU_ARCHITECTURE.md`（含「为何不建议 big-bang」与两个方向的对比）。
> 方法论：**Strangler（绞杀者）** —— 新内核先自包含接入，旧调用点经 adapter 原样可用；再逐子系统替换；最后删旧实现。
> 状态（2026-09-13）：**Track A / Track B 均已完成**——内核是唯一弹幕后端（`use_kernel` 已转正、旧池已删），autoload **12 → 4**。逐波实施记录已移入 **[BEST_PRACTICES_LOG.md](BEST_PRACTICES_LOG.md)**；本文只保留**方案 / 契约 / 决策**。§1 是迁移前的现状审计快照。

---

## 0. 前提与代价（先讲清）

- **方向**：以**原项目为树干**（它有完整游戏外壳与大量内容），新内核作为**自包含子系统**接入，而不是把原项目一次性改造成重建版。
- **不是**：整体硬搬内核、或 big-bang 重写。那会把「内核移植」与「大改造」两个相反方向的重构叠加（详见决策备忘第 7 节）。
- **代价**：过渡期同时存在两套弹幕实现（adapter 桥接），需要严格边界与测试；里程碑较多。
- **硬约束**：**每一步都要能跑**（至少主菜单 + stage01 可玩、GUT 全绿）。

---

## 1. 现状审计（原项目）

### 1.1 体量

| 目录 | 行数 | 文件 |
|---|---|---|
| `scripts/autoload/` | 2267 | 17（含 12 autoload） |
| `scripts/workbench/` | **4286** | 25 |
| `scripts/scenes/` | 3786 | 21 |
| `scripts/coroutine/` | 2017 | 32 |
| `scripts/data/` | 1428 | 21 |
| `scripts/bullet/` | 557 | 5 |
| `scripts/laser/` | 500 | 4 |
| `data/stages/` | 1071 | 16 |
| 合计 | **18,719** | 170 |

### 1.2 弹幕链路（要被替换的部分）

```text
BulletData(builder Resource)  --shoot-->  BulletManager(autoload facade)
                                             |-- BulletPool(node 池, POOL 4000 / MAX 5000)
                                             |      -- Bullet(Node2D + Sprite2D + Fog + CoroutineScript)
                                             |-- BulletPhysics(RefCounted)
                                             |      |-- SpatialHash(敌弹)   每帧 clear + insert
                                             |      -- SpatialHash(敌人)
                                             -- LaserEngine(独立：LaserSkeleton/LaserBeam/Presets)
BulletMultiMesh(Node2D)  --每帧遍历 active_bullets--> 写 MultiMesh（按 贴图×阵营×tint 分组）
```

要点：
- 弹是 **Node2D**（不是 pure data），行为是挂在弹上的 **CoroutineScript** 节点。
- 渲染**已经**是 MultiMesh（`bullet_multi_mesh.gd`），只是数据源是节点列表、且每帧做分组/哈希。
- 碰撞**已经**有 `SpatialHash`（`scripts/bullet/spatial_hash.gd`），但是 **Dictionary<Vector2i, Array> + 每帧 clear/insert**，且分两张哈希表（敌弹 / 敌人）。
- 激光是本项目独立体系（`scripts/laser/`），与子弹池分离。

### 1.3 全局耦合

| 符号 | 文件数 / 出现次数 |
|---|---|
| `GameState` | 42 / 186 |
| `StageContext` | 38 / 80 |
| `BulletData` | 31 / 62 |
| `AssetRegistry` | 31 / 49 |
| `CoroutineScript` | 30 / 47 |
| `BulletManager` | 22 / 46 |

12 个 autoload：`GameEvents / GameManager / BulletManager / GameState / StageManager / RNG / AudioManager / MissEffectManager / HitEffectPool / LayerConfig / AssetRegistry / StageObjects`。

### 1.4 内容模型

```text
data/stages/<stage>/
  phase/<phase>/xxx_*.gd     # CoroutineScript 阶段/弹丸行为
  bullet/*.gd                # 弹丸行为协程（gravity / bounce / radial_accel ...）
  enemy/*.gd                 # 敌人/杂兵脚本
  stage_script/*.gd          # 关卡脚本
  stage_data/*.tres          # StageData 资源
  background/*
data/boss_scripts/           # Boss 脚本
```

阶段脚本继承 `CoroutineScript`，实现 `_tick(p_ctx: StageContext)`；弹丸行为同理，通过 `target.velocity / target.global_position` 驱动。

### 1.5 测试

`test/` 下 58 个 `extends GutTest`（GUT 插件在 `addons/gut`）。

---

## 2. 目标内核契约（迁移目标）

来自重建版，迁移时保持这些**契约**不变：

- **数据**：`BulletType` / `EffectType` / `PlayerData` / `AtlasLayout`（`Resource`，.tres）。
- **服务**（组合根注入，不 autoload）：`BulletSystem` / `BulletRenderer` / `BehaviorProcessor` / `CollisionCoordinator` / `FxLayer` / `HitFeedback`。
- **核心**：SoA 行 + `spawn(bullet_data, pos, vel, color, move, params)`；宽相 uniform grid；`Behavior` 注册名 + `params`（共享只读）/ `state`（每弹可写）。
- **契约**：`FrameOrder`（INTEGRATE/WORLD/BEHAVIOR/COLLISION）、`LayerConfig`（z 顺序）。
- **测试**：`godot --headless --script` 的无头 SceneTree 套件。

---

## 3. 旧 → 新 接口映射表

| 原项目 | 重建版 | 迁移备注 |
|---|---|---|
| `BulletData`（builder Resource） | `BulletType`（数据 .tres）+ `EffectType` | builder 方法 → 一次性编辑 .tres；`.tex(key)` 的 hitbox 元数据来自 `AssetRegistry.bullet_configs` → 迁到 `AtlasLayout` + .tres |
| `Bullet`(Node2D) + `extra` | SoA 行 + `params` / `state` | 节点字段（velocity/damage/…）→ 行字段或 params；`extra` → 句柄/params |
| `BulletPool` | `BulletSystem` | 池 + 宽相一体；swap-with-last 语义与旧池不同（旧池是 Array.erase） |
| `BulletMultiMesh` | `BulletRenderer`（阵营/类别批） | 分组键（贴图×阵营×tint）在旧版每帧算 → 新版按弹型缓存 + `kind` 过滤 |
| `BulletPhysics` + `SpatialHash` | `CollisionCoordinator` + `CollisionResolver` + BulletSystem 宽相 | 碰撞规则（命中/擦弹/记忆加成/音效）留在实体回调 |
| `BulletManager`(autoload) | 组合根注入 + **adapter facade** | 过渡期保留同名 API，内部转发新内核 |
| `LaserEngine` / `LaserBeam` | `LaserShot` + `LaserFollowBehavior`（分段）或保留激光引擎 | 重建版激光是「分段流水」；原版是骨架/曲线体系，需逐个激光预设决策 |
| `CoroutineScript` 弹行为 | `Behavior`（注册名 + params/state） | 逐行为改写；`target` → `(system, id)`；`get_dt()` → `system.get_delta()` |
| `BulletService`(`ctx.bullets`) | `Emitter` + `shoot_pattern` / `LaserShot` | 内容 API 由 builder 风格转向 数据 + 发射器 |
| `HitEffectPool` / `MissEffectManager` | `FxLayer`（池化节点） | `play(scene, pos, vel, color)` 接口近似 |
| `AssetRegistry.bullet_configs` | `data/atlas/bullet_shapes.tres` + `BulletType` .tres | 图集布局与判定元数据分离 |
| `GameState.memory_value` 命中加成 | 实体回调里读 `PlayerResources`（或 adapter） | 规则不该进内核 |
| `SpatialHash`（已有） | BulletSystem 内建宽相 | 旧版可保留给敌人查询，直到敌人也迁移 |

---

## 4. 分阶段计划

> 每阶段都必须：**可运行、GUT 全绿、可回退（独立分支/提交）**。阶段间用 adapter 衔接。

### Phase 0 — 冻结与基线
- **动作**：
  - 在原项目打 tag / 建分支 `kernel-migration`。
  - 记录基线：GUT 全绿；跑一遍重建版的 `tools/bench_danmaku.gd` 做对照；记录当前帧率与最大弹数。
  - 确认 Godot 4.7 下 GDExtension/原生**暂不引入**（本方案纯 GDScript 迁移）。
- **产出**：基线快照（帧率、弹数、测试数）。
- **回退**：无（不动代码）。

### Phase 1 — 内核自包含接入 + adapter（不改任何调用点）
- **动作**：
  - 把重建版内核文件作为**子目录**引入原项目（例如 `scripts/danmaku_kernel/`）：`bullet_system / bullet_renderer / behaviors / collision_* / fx_* / defs（BulletType/EffectType/AtlasLayout）/ player_data`。
  - 在 `GameManager`（或新组合根）里创建内核实例并注入；**保留 `BulletManager` 这个 autoload 名字**，内部改为**持有内核 + adapter**。
  - adapter 实现 `BulletManager` 现有公开 API：`shoot_bullet / shoot_player_bullet / shoot_enemy_bullet / shoot_bomb_bullet / return_bullet / re_fire / clear_all / pause/resume`。
  - **最硬的一处**：旧内容会拿 `Bullet` 节点引用（`shoot_spread(count==1)` 返回 Bullet，用于设置 `extra` / `rotation`）。新内核没有节点 → 提供 **`BulletHandle`**（RefCounted，(system,id) 句柄），暴露旧代码用到的成员/方法并转发：
    - `global_position` / `velocity` / `rotation` / `damage` / `extra` / `is_ready` / `_grazed` …
    - 只在**内容显式取引用**时创建（不是每弹都建），避免热路径开销。
  - 本阶段可先只让 `BulletSystem` 跑起来（弹能飞、能画），`BulletManager` 的旧 API 走 adapter；**碰撞/内容仍走旧路径**，或双写过渡。
- **涉及文件**：`scripts/autoload/bullet_manager.gd`、`scripts/autoload/bullet/*`、新增 `scripts/danmaku_kernel/*`、新增 `scripts/danmaku_kernel/adapter/*`、`game_manager.gd`（组合根）。
- **验收**：`BulletManager.shoot_*` 调用点不报错；新内核里能看到弹飞行；旧 GUT 全绿。
- **回退**：删内核目录 + 还原 `bullet_manager.gd`。

### Phase 2 — 渲染切到 BulletRenderer
- **动作**：关闭 `BulletMultiMesh._sync`（保留文件但不启用）；启用内核的 `BulletRenderer`（阵营/类别批 + `kind` 过滤 + 激光批）。
- **涉及**：`bullet_manager.gd`（不再 add `BulletMultiMesh`）、`bullet.gd` 的 Sprite2D 可见性、`layer_config.gd`（对齐 z 顺序）。
- **验收**：视觉与旧版一致（弹型/颜色/朝向/激光）；bench 渲染 CPU 不退化。
- **回退**：重新启用 `BulletMultiMesh`。

### Phase 3 — 碰撞切到 CollisionCoordinator + 宽相
- **动作**：
  - 启用 `BulletSystem` 的宽相 `query_circle`；停用 `BulletPhysics` 的两张 `SpatialHash`（或仅保留敌人查询）。
  - 把 `BulletPhysics` 的规则（玩家弹 vs 敌人、敌弹 vs 自机 + 擦弹 + 记忆清弹、Bomb vs 敌弹/敌人、命中音效、命中特效）搬到实体回调 / `CollisionCoordinator` 注册 + `HitFeedback`。
  - 处理旧特殊语义：`out_grace`（出界宽限）、`can_be_canceled`、`memory_value` 命中加成、`is_timeout_only` 的 Boss 不可击。
- **涉及**：`bullet_physics.gd`、`bullet_manager.gd`、`player.gd`、`enemy.gd`、`boss.gd`、`effect/*`。
- **验收**：命中/擦弹/清弹行为一致；bench 查询 µs 级；最大弹数下不掉帧。
- **回退**：切回 `BulletPhysics`。

### Phase 4 — 内容层迁移（逐个 stage / phase 做，最大的一块）
- **动作**：
  1. `BulletData` builder 调用 → `BulletType` .tres（贴图/染色/判定/阵营/命中特效）。
  2. 弹丸 `CoroutineScript` 行为 → 注册 `Behavior`（`accel/curve/avoid_player/laser_follow/...`），`target.velocity` → `set_velocity`，`target.global_position` → `set_position`，`get_dt()` → `get_delta()`。
  3. 阶段 `CoroutineScript` 的分阶段发射 → `Emitter` + `shoot_pattern`（或保留阶段计时，只替换发射 API）。
  4. 激光预设 → 重建版分段激光或保留；逐个决策。
  5. `AssetRegistry.bullet_configs` → `AtlasLayout` + `BulletType` 的 hitbox 字段。
- **策略**：**一次只迁一个 stage/phase**，例如先 `stage01/phase/non01`，用重建版测试补齐后，再动下一个。
- **验收**：每迁完一个 phase，与原版逐项对比（弹数、轨迹、颜色、判定、特效）；GUT 对应测试通过。
- **回退**：该 phase 单独回退。

### Phase 5 — 拆 autoload / GameState（逐步，不追求一次到位）
- **动作**：
  - 把 `GameState` 里「弹幕/实体需要」的部分（`player`、`active_enemies`、`memory_value`…）改成**显式注入**到内核/实体（组合根），而不是全局读。
  - 保留 `GameState` 作为「全局存档/菜单状态」，但内核与弹幕实体不再直接依赖它。
  - 把 `BulletService` 的 `ctx.bullets` 逐步替换为注入的 `Emitter` / 内核 API。
- **验收**：内核文件里 `grep GameState` = 0（这是可量化的硬指标）。
- **回退**：adapter 可临时补全局读。

### Phase 6 — 契约统一 + 测试迁移
- **动作**：
  - 引入 `FrameOrder`（显式物理帧顺序）与 `LayerConfig`（层序契约），替换原项目里散落的 `process_priority` / autoload 顺序依赖。
  - GUT 测试：新内核的部分改为重建版风格的无头 SceneTree 套件；GUT 保留用于旧外壳。
  - 补行为/碰撞/渲染的等价性测试（重建版已有 45 套可参考/移植）。
- **验收**：进测试数量不下降；关键语义有等价性测试。

### Phase 7 — 清理与收尾
- **动作**：删除 `scripts/bullet/bullet.gd` / `bullet_multi_mesh.gd` / `bullet_fog.gd` / `bomb_behavior.gd`、`scripts/autoload/bullet/*`、旧 `laser/*`（若已迁移）；删 adapter 中不再被调用的分支；更新 `ARCHITECTURE.md` / `STAGE_FLOW_PLAN.md`。
- **验收**：`grep BulletManager` / `grep Bullet` 的调用面收敛到内容层/新 API；GUT + 无头测试全绿。

---

## 5. Adapter 设计（Phase 1 的核心，单独展开）

过渡期的目标是「**旧调用点一行不改**」。adapter 的职责：

1. **名字保留**：`BulletManager` 仍是 autoload，但变成薄壳。
2. **API 转发**：旧 API → 新内核：
   - `shoot_bullet(data,pos,dir)` → `BulletSystem.spawn(convert(data), pos, dir, ...)`
   - `shoot_enemy_bullet / shoot_player_bullet / shoot_bomb_bullet` → 按 faction 转 `spawn`
   - `return_bullet(bullet)` → 若是 `BulletHandle` 则 `system.despawn(id)`
   - `re_fire` → 先 `despawn` 再 `spawn`（或内核提供 re-spawn）
   - `clear_all` → `system.clear()` + `FxLayer.clear_pool()`
3. **数据转换**：`BulletData` → `BulletType` 的**缓存转换**（按 `BulletData` 实例缓存一份 `BulletType`，避免每次 spawn 新建）。这个转换是过渡期的关键粘合点，Phase 4 完成后删除。
4. **句柄**：`BulletHandle` 兼容层（见 Phase 1）。注意池化复用 → 句柄要带代际（`generation`）校验，否则悬垂。
5. **全局读取**：adapter 内部读 `GameState` / `RNG` / `AudioManager` / `HitEffectPool`，但**内核不读**——全局只存在于 adapter 与实体回调。

```gdscript
# 过渡期 BulletManager 形态（示意）
var _system: BulletSystem          # 新内核
var _fx: FxLayer
var _type_cache: Dictionary = {}   # BulletData -> BulletType

func shoot_enemy_bullet(data: BulletData, pos: Vector2, dir: Vector2) -> BulletHandle:
    var bt := _to_bullet_type(data)
    var id := _system.spawn(bt, pos, dir.normalized() * data.speed_value(), data.tint, _move_of(data), _params_of(data))
    return BulletHandle.new(_system, id)
```

---

## 6. 风险与缓解

| 风险 | 说明 | 缓解 |
|---|---|---|
| 双实现期语义漂移 | 新旧弹幕同时存在，行为不一致 | 每阶段做**等价性对比**（弹数/轨迹/判定/特效）；adapter 只桥接、不放规则 |
| 节点引用 → 句柄 | 旧内容持 Bullet 节点引用；句柄化后池化复用会悬垂 | 句柄带 generation；只在显式取引用时创建；提供 `is_valid()` |
| 一帧时序差 | 旧 autoload 顺序 vs 新 `FrameOrder` | 引入 `FrameOrder` 显式赋值；对激光/锚点类行为做单帧回归 |
| 确定性 | 旧 `RNG`（可播种）vs 新内核 RNG | 内核 RNG 可播种（S10）；迁移后重放验证 |
| 测试双轨 | GUT vs 无头 SceneTree | 旧外壳留 GUT；内核用无头套件；关键路径两边都测 |
| workbench 4286 行 | 大量依赖旧 `BulletManager/BulletData` | 优先迁它依赖的 API；adapter 保证它能跑；必要时后置 |
| 性能 | adapter 若逐弹跨边界会有开销 | adapter 只做批量/发射级转发；句柄按需创建；bench 把关 |
| 内容迁移量 | 2 个 stage、多 phase、大量行为 | **一次一个 phase**，先易后难；先迁「纯数学」行为，逃生门行为最后 |

---

## 7. 验收（每阶段通用）

1. 原项目 GUT 全绿；新内核无头套件全绿。
2. 主流程冒烟：主菜单 → stage01 可玩。
3. `tools/bench_danmaku.gd` 同口径对比不退化（可临时把内核搬进 bench 工程）。
4. 关键语义有**等价性测试**（同波弹数、同位置轨迹、同判定结果）。
5. 一个可独立回退的提交。

---

## 8. 不做 / 暂缓

- **不做 big-bang**：不一次性重写 170 文件。
- **不动 workbench 的业务逻辑**：只保证它依赖的弹幕 API 可用。
- **不引入 GDExtension/原生**：本方案纯 GDScript 迁移；原生是之后单独评估的另一条线（见决策备忘第 6 节）。
- **不做数据驱动 behavior VM**：Phase 4 先「协程 → 代码 Behavior」；VM 化留到之后再议。
- **不迁移游戏外壳**（菜单/对话/音乐室/存档）：它们与弹幕内核解耦，保持不动。

---

## 9. 工作量粗估（粗粒度，供排期）

| Phase | 内容 | 相对量 |
|---|---|---|
| 0 | 基线冻结 | 极小 |
| 1 | 内核接入 + adapter + 句柄 | **大**（最关键的粘合） |
| 2 | 渲染切换 | 小-中 |
| 3 | 碰撞切换 | 中-大（规则多） |
| 4 | 内容迁移（逐 phase） | **最大**（随内容线性） |
| 5 | 拆 autoload/GameState | 中（面广） |
| 6 | 契约统一 + 测试 | 中 |
| 7 | 清理 | 小 |

> 结论：Phase 1（adapter + 句柄）与 Phase 4（内容）是成败关键；**先把 Phase 1 的句柄方案想透，再开始动任何内容**。

---

## 10. 起步检查清单（开始前逐项确认）

- [ ] 已读 `1-st-touhou-star-rebuild/docs/DECISION_DANMAKU_ARCHITECTURE.md`，接受「以原项目为树干」的代价。
- [ ] 已打 tag / 分支；GUT 基线全绿。
- [ ] 已确认 Godot 版本（4.7）下**不引入原生**。
- [ ] 已选定 Phase 1 的 `BulletHandle` 语义（字段/方法清单、generation、is_valid）。
- [ ] 已选定第一个要迁的 phase（建议 `stage01/phase/non01`）。
- [ ] 已准备等价性对比方法（同波弹数/轨迹/判定）。

---

## 11. 轨道 B：外壳工程红线对齐（与轨道 A 并行）

> 目的：新内核不仅换弹幕，也把**工程红线（R1–R22）**带进整个原项目（外壳 / 场景 / workbench / autoload）。
> 与轨道 A **并行**、共用同一份 baseline（原项目 `docs/BEST_PRACTICES_BASELINE.md` 已同步到 R1–R22 / S1–S13 + 帧序·层序·命名边界契约）。

### B1 baseline 升级（已完成）
- 把重建版 R1–R22 / S1–S13 + 命名边界 + 帧序/层序契约合并进原项目 baseline。
- **待办**：逐条重审 S1–S13 状态（原项目自评较旧，部分 `[ ]` 实际已落地，如 S2「碰撞用空间哈希」——原项目已有 `SpatialHash`）。

### B2 去 autoload / 拆 god object（R9 / R18）
- 12 autoload → 真全局（存档 / 音频 / 设置）+ 注入。
- 拆 `GameState`(405 行) / `BulletManager` / `workbench`。
- 与轨道 A 的 **Phase 5** 合流。

### B3 workbench 声明式化（R21）
- workbench **178 处 `.new()` + 183 处 `add_child`** → 子场景。
- 优先级可后（开发工具，不影响玩家）。

### B4 私有调用 → 公开虚函数（R6）
- **12 处 `has_method("_")`**。

### B5 层序 / 帧序契约
- **30 处散写 `z_index`** → `LayerConfig`。
- 引入 `FrameOrder`，取代 autoload 的 `_physics_process` 顺序依赖。

### B6 注释规范（R22）
- 全库审计（机械、量大）。

### B7 数据驱动（R17）
- 散落魔术数字 → `.tres` / 集中配置。

### B8 其余逐条 spot check
- R4 / R5 / R7 / R10–R14 / R16。R14（res:// 写存档）与 R15 文件名层目前较干净；R2/R5 也比预期好（`get_node("../")` 0）。

### 外壳红线审计（2026-09 实测，B 的输入）

| 红线 | 实测 | 判断 |
|---|---|---|
| R9 autoload | 12 个 | 最大面；多数应改注入 |
| R18 单一职责 | `GameState` 405 / `BulletManager` / workbench 4286 | god object 需拆 |
| R21 声明式建树 | workbench 178 `.new()` + 183 `add_child` | 最大表面积（可后） |
| R6 私有调用 | 12 处 `has_method("_")` | 改公开虚函数 |
| 层序契约 | 30 处散写 `z_index` | 收敛到 `LayerConfig` |
| 帧序契约 | 无显式 `FrameOrder` | 引入 `FrameOrder` |
| R14/R15/R2/R5 | res:// 写存档 0、中文 .gd 文件名 0、`get_node("../")` 0、字符串 `get_node` 5 | 比预期干净 |
| R4 输入 | 12 文件轮询 `Input.is_action` | 按「移动例外」理解，非硬违规 |

### 验收
- 每个 R 项从 baseline 的「待改进」删除时附证据（grep 计数 / 测试）。

---

## 12. B2 详解：autoload 分类与去单例方案

> 输入：12 个 autoload 的引用面（下表）+ R9（只放真全局）/ R8（Resource/static 替代）/ R18（拆 god object）。
> 目标：12 → **≤5 个真全局**；其余改 `class_name` / 注入 / 拆 / 内核替换。

### 12.1 分类总表

| autoload | 行数 | 引用(文件/次数) | 性质 | 处置 | 波次 |
|---|---|---|---|---|---|
| `GameEvents` | 22 | 11 / 51 | 纯信号总线（无状态） | **保留**（真全局） | — |
| `RNG` | 32 | 26 / 51 | 决定论单一随机源 | **保留**（或改 `static` class） | — |
| `AudioManager` | 206 | 17 / 36 | 音频服务（单路 BGM + 16 路 SFX + 音量） | **保留**（收窄跨 autoload 耦合） | — |
| `GameManager` | 126 | 10 / 53 | 外壳状态机 + 场景切换 + 暂停 | **保留并升级为组合根** | — |
| `LayerConfig` | 21 | 13 / 24 | 纯常量 | **改 `class_name`（去 autoload）** | W1 |
| `MissEffectManager` | 96 | 2 / 3 | 全屏 miss 圆（CanvasLayer + shader） | **改场景节点**（外壳注入） | W1 |
| `StageObjects` | 42 | 3 / 8 | 关卡命名对象注册表（帧级作用域） | **改注入**（per-stage，`StageContext` 持有） | W2 ✅ |
| `HitEffectPool` | 67 | 6 / 10 | 特效节点池 | **改注入**（`FxLayer`，随轨道 A） | W2 ✅ |
| `AssetRegistry` | 153 | 31 / 49 | 静态资源表 + 内容 key | **改 `class_name`（静态表）+ 数据资源**（R17/S13） | W3a ✅（.tres 迁移随 S13） |
| `StageManager` | 169 | 14 / 35 | 关卡生命周期 + 生成敌人/Boss | **改注入/场景节点**（`StageRuntime` under World + `ctx.stage`） | W3b ✅ |
| `BulletManager` | 165 | 22 / 46 | 弹幕门面 | **内核替换**（轨道 A Phase 1 + adapter） | W4a ✅（内核唯一后端；去 autoload 归 W4c） |
| `GameState` | 405 | **42 / 186** | 全局游戏数据（god object） | **拆分**（最高优先） | W4 |

**目标 autoload 集合（≈4~5）**：`GameEvents / RNG / AudioManager / GameManager` + 一个**瘦身存档全局**（`GameState` → `SaveData/Profile`）。

### 12.2 GameState 拆分（核心）

现在 `GameState` 一身多职：

| 现职责 | 目标归属 |
|---|---|
| `selected_difficulty / selected_character / current_stage_id` | 持久化元数据 → `SaveData/Profile`（可留瘦 autoload 或 `static`） |
| `spell_book / save_mgr / spell_book_mgr` + 高分 | 持久化数据 → 同上（存档全局） |
| `player / active_enemies / stage_registry` | **运行时引用 → 组合根注入**（Player 节点 / `CollisionCoordinator` 注册表 / stage 数据） |
| `score / lives / bombs / power / graze / memory_value` | **`PlayerResources`**（注入到 Player，`changed` 信号；对应重建版） |
| `_apply_ui_theme()` | 外壳/主题初始化（移出 `GameState`） |

**迁移顺序（防双写不一致）**：
1. 新建 `PlayerResources`，与 `GameState` **双写**并存；
2. 实体改读 `PlayerResources`（GameState 仍在写，仅作兼容）；
3. 拆 `player / active_enemies` 为组合根注入（`CollisionCoordinator` / `WorldQuery` 承接）；
4. 最后把 `GameState` 瘦身为存档全局，删掉运行时字段。
> 注意：重建版已有现成 `PlayerResources`（`scripts/game/player_resources.gd`）可参考/移植。

### 12.3 关键处置要点

- **LayerConfig → `class_name`**：纯 `const`，去掉 autoload 即可；需同步把所有 `LayerConfig.XXX` 引用改为 `class_name` 静态常量（行为等价）。**零风险、先做**。
- **AssetRegistry → 静态表 + 数据**：`bullet_configs` 是「代码侧内容配置」，应迁为数据（R17）——但先别一步到位；先把它从 autoload 变 `class_name`（`static const`），再逐项迁 .tres（与 S13 图集一起）。
- **HitEffectPool → FxLayer**：它的 `Engine.get_main_loop().current_scene.get_node_or_null("World")` 是典型的**全树找父级**（违反 R2/R9）；改成由组合根注入的 `FxLayer`（重建版已有）。
- **StageObjects → per-stage 注入**：它本来就是「帧级作用域」（load_stage 注册、stop 清空），不该是全局；改由 `StageContext`/`World` 持有，生命周期随关卡。
- **StageManager → StageRuntime**（W3b 已落地）：它直接调 `GameState.reset_all/clear_enemies` 与 `BulletManager.clear_bullets`（跨 autoload 插手）；现为「关卡=World 的子节点」+ `ctx.stage` 注入服务（对应重建版 `game.gd load_stage` + 关卡脚本）。跨 autoload 直呼待 W4。
- **MissEffectManager → 场景节点**：它是个 CanvasLayer 渲染特效，引用只有 2/3，改由外壳场景挂载并注入最省事。
- **GameManager → 组合根**：它已经在委派 `SceneTransition`/`MenuNav`；把它作为**唯一的壳入口**，在 `_ready` 里创建并注入内核/服务（对应重建版 `game.gd`）。
- **AudioManager 的跨耦合**：它 `connect(GameManager.game_state_changed)`、读 `AssetRegistry.sounds` —— 改由组合根接线（或保留，但明确「音频只听事件」）。

### 12.4 迁移波次（按风险从低到高）

| 波次 | 内容 | 风险 | 说明 |
|---|---|---|---|
| **W1** | `LayerConfig` → `class_name`；`MissEffectManager` → 场景节点 | 极低 | 引用 24 / 3，机械改 |
| **W2** | `StageObjects` → per-stage 注入；`HitEffectPool` → `FxLayer` | 低-中 | 引用 8 / 10；后者随轨道 A —— **已完成（§12.8）** |
| **W3** | `AssetRegistry` → `class_name` + 数据；`StageManager` → `StageDirector` | 中-高 | 引用 49 / 35；**W3a/W3b 均已完成（§12.9 / §12.10）** |
| **W4** | `GameState` 拆分；`BulletManager` 内核替换 | 最高 | 引用 186 / 46；**拆 W4a（内核转正/删旧池）/ W4b（GameState）/ W4c（去 autoload）** |

### 12.5 验收（可量化）

- autoload 数：**12 → ≤5**（**已达 4**：W1 后 10，W2 后 8，W3a 后 7，W3b 后 6，W4b 后 5，W4c 后 **4**：`GameEvents / GameManager / RNG / AudioManager`）。
- `grep -rIl "\bGameState\b" scripts`：**42 → 0**（目标 ≤ 5，**已达成**）。
- **内核文件里 `GameState` 出现次数 = 0**。
- 每删/改一个 autoload：GUT 全绿 + 主流程冒烟（主菜单 → stage01 可玩）。

### 12.6 风险

- 引用面大的项（`GameState` / `AssetRegistry` / `BulletManager`）必须先做**兼容门面**再迁，不能直接删。
- 迁移期**双写**（`GameState` vs `PlayerResources`）要有兜底与对账测试。
- autoload 之间的横向耦合（`AudioManager → GameManager`、`StageManager → GameState/BulletManager`）要把「谁调谁」改成**组合根接线**，否则拆完还是隐式全局。

### 12.7 实施记录（W1–W4c / K1–K14）

> 逐波「做了什么 / 为什么 / 踩坑 / 验收」见 **[BEST_PRACTICES_LOG.md](BEST_PRACTICES_LOG.md)**（唯一历史记录）。此处只留索引。

| 波次 | 一句话 |
|---|---|
| W1 | `LayerConfig` 去 autoload（纯常量 → `class_name`）、`MissEffectManager` 场景节点化；autoload 12→10 |
| W2 | `StageObjects` → `StageContext.objects`；`HitEffectPool` → `FxLayer`（组合根注入）；10→8 |
| W3a | `AssetRegistry` 去 autoload（→ `class_name` 静态表，调用点 0 改动）；8→7 |
| W3b | `StageManager` → `StageRuntime` 场景节点 + `ctx.stage`；7→6 |
| W4a-1/2 | 内核弹幕后端**转正为默认**；随后删旧池（`BulletPool`/`Bullet`/`BulletPhysics`/`SpatialHash`/`bullet_fog`）——内核唯一后端 |
| W4b-1..4 | `GameState` 资源抽 `PlayerResources`、实体抽 `EntityRegistry`、资源消费者直读 `Player.resources`、`GameState` → `SaveData`（纯 static）；`grep GameState` 42→0 |
| W4c | `BulletManager` 去 autoload（组合根创建 / 注入 + `static current`）；autoload → **4** |
| K1/K1b | 脚本命名 / 目录归属收口（`scripts/autoload/` 只留 4 个真 autoload） |
| K2/K3/K4 | R6（私有调用→公开虚函数）/ R4（输入事件驱动）/ R2（全树搜→注入）收口 |
| K5 | 三台热更新管线收口 `BenchBase`（workbench 净 -116 行） |
| K6/K7 | `BulletManager` 声明式化（R21 收尾）；`FxLayer`→`FxPool`、`MissEffectManager`→`MissCircleLayer` 命名消歧 |
| K8–K11 | `Player.setup_character` 幂等 / `resources` 类型化 + 惰性属性 / `MenuNav` 容器注入 |
| K12–K14 | 符卡练习诊断守卫；练习资源未归零修复；`reset_*` 静默空跑守卫（确立 P0/P1/P2 日志判据） |

**结果**：autoload **12 → 4**（`GameEvents / GameManager / RNG / AudioManager`）；`grep GameState` **0**。

---

## 13. Track A 实施记录（S0–S4d）

> 逐波记录见 **[BEST_PRACTICES_LOG.md](BEST_PRACTICES_LOG.md)**（S0–S4d 条目）。此处只留索引与仍生效的决策。

| 步 | 成果 |
|---|---|
| S0 | 内核 vendor 进 `scripts/kernel/`（14 `.gd` / 1,221 行），唯一改动 = 删 `BulletRenderer` 注入；`test_kernel_vendor` |
| S1 | `KernelBulletBackend`：`BulletData → BulletType` + 内容签名缓存 + 纹理旁表 |
| S2 | `BulletMultiMesh` 双数据源（内核 SoA / 旧节点） |
| S3a | `use_kernel` 开关：路由 spawn/积分/渲染/剔除/暂停（不含碰撞） |
| S3b | `KernelBulletPhysics`：敌弹↔自机（命中 + 擦弹双阈值 + 记忆随机清弹） |
| S3c | 自机弹↔敌人（`damage`/`hit_sfx` 宿主侧表；**A 方案成立**） |
| S3d | 死亡清弹接内核（`DeathClear` 抽 `Callable` 注入，旧循环一行未改） |
| S4a–d | 行为桥：`world_accel` / `homing` / `radial_accel` / `bounce` / `non_mid_flee` / `marisa_laser` / bomb 宿主节点 / 记忆变红 |

> **当前状态**：`use_kernel` 默认 **true**（W4a-1 转正）、旧池已删（W4a-2）——内核是唯一后端；逐波验收数字见 LOG。

---

## 14. 决策：S3 碰撞 / 伤害模型（A 方案 · 宿主侧规则移植）

> 原 S3 计划 = 「加 `use_kernel` + 委托后端」。读全 `BulletPhysics` / 内核 `CollisionResolver` / `BulletType` 后确认：S3 不是换发射入口，而是换掉**整个弹幕运行时**。动手前必须在 A / B 分叉里选。

### 14.1 硬阻塞：内核 `BulletType` 没有 `damage`

| | 原项目 | 重建内核 |
|---|---|---|
| 伤害载体 | `BulletData.damage`（默认 **10.0**，Bomb **50.0**） | **无此字段** |
| 结算 | `enemy.take_damage(bullet.damage * bonus)`（记忆 <50 时 `bonus = 1.15~1.05`） | `take_damage(1.0)` |
| 量级 | Boss HP 1000 → 约 100 发 | 同 Boss 需 1000 发 |

→ 直接把原项目弹幕灌进内核，Boss TTK 差 **~10×**、杂兵（HP 3 / 24）差更多——这是玩法崩坏，不是表现细节。

### 14.2 必须一起搬的规则（内核没有对等物）

敌弹↔自机命中 + 擦弹双阈值、擦弹随机清弹、`bomb` 弹 vs 敌弹/敌人、命中音效规则、命中特效（颜色取弹当前色）、`out_grace`（出界宽限）、死亡清弹扩散圈。除积分/渲染外，全部落在宿主桥接。

### 14.3 选 A（宿主侧规则移植）

| 选项 | 做法 | 优点 | 代价 |
|---|---|---|---|
| **A（采用）宿主侧规则移植** | 新建 `KernelBulletPhysics` 逐条移植旧规则；宿主专有字段（`damage`/`out_grace`/`can_be_canceled`/`hit_sfx`/`hitbox_shape`）走 `KernelBulletBackend` 侧表 | **内核零改动**；语义 1:1；Strangler 可回退 | 桥接 ~200 行；规则仍散在宿主 |
| B 内核补 `damage` + 用内核协调器 | 给 `BulletType` 加 `damage`；改用 `CollisionCoordinator` | 长期干净、双宿主一致 | 改重建版内核 + 重新 vendor；graze/bomb 仍要宿主补 |

**理由**：路 B 的定位是「原项目为干」——A 保持原项目玩法语义不变、内核零改动，风险最小；B 属于「内核定型后」的整理。S3b / S3c 已验证 A 成立（`damage` 走侧表 1:1 保住）。

### 14.4 帧序（硬约束）

内核 `BulletSystem.process_physics_priority = -10`（先积分）→ 桥接行为 **-5** → 延后 flush **-4** → 宿主碰撞 **0**。否则碰撞读到**上一帧**位置。

---

## 15. 决策：S4 行为桥与端口契约

> **核心结论：只有一个扩展点（`Behavior` 注册表），没有「特殊途径」。**

### 15.1 行为清单与落点（实测）

| 宿主行为 | 用在哪 | 处置 |
|---|---|---|
| `BulletData.accel` / `gravity_bullet` | 魔理沙 opt2 / stage01 杂兵 | `world_accel`（桥接） |
| `radial_accel_bullet`（沿向加速 + 顶边 re_fire） | stage01 enemy04 | `radial_accel`（桥接 + 延后队列） |
| `bounce_bullet`（三面反弹 + 瞄准 Boss re_fire） | stage01 非符1 | `bounce`（桥接） |
| `non_mid01_bullet`（近自机逃 + 近 Boss 散圈） | stage01 中boss非符 | `non_mid_flee`（桥接，散圈回调留内容） |
| `move_homing`（追杀最近敌人） | 灵梦 opt1 | `homing`（桥接，用内核 `WorldQuery`） |
| `marisa_laser_follow`（锚定漂移 + 松手渐隐） | 魔理沙非 focus 激光 | `marisa_laser`（桥接 `global_position` 语义）+ 整批 fade |
| `bomb_behavior`（绕自机扩张 + 追踪 + 爆炸） | 炸弹 | **宿主节点 `KernelBomb`**（不进内核池） |
| `orbit_probe`（减速往返 + 分裂） | stage03B | 本轮不做 |

内核现成：`accel` / `curve` / `laser_follow` / `avoid_player`。

### 15.2 唯一扩展点 = `Behavior` 注册表

一切行为——内核自带、桥接自定义、未来的 VM 步骤——都是 `Behavior` 子类，经同一入口注册：

```gdscript
func register_behavior(move_name: StringName, behavior: Behavior) -> void
```

**逃生口不是后门，它就是前门本身。** VM（`ScriptedBehavior`）只是注册表里的第 N 个租户，和手写 `Behavior` 平级。纪律三条：

1. 必须跑在 behavior pass（不绕帧序 / 协调器）；
2. 只读写自己那一行（`_behavior_params` 只读 / `_behavior_state` 每弹）；
3. 需要宿主全局 → 放 `scripts/kernel_bridge/behavior/`，内核保持零宿主引用。

### 15.3 端口契约（内容 → 内核）

内容行为脚本**可选**实现（duck-typed，不改 `CoroutineScript` 基类）：

```gdscript
## 内容脚本声明其内核等价物。无此方法 = 未映射（按直线发射并计数）。
func kernel_port() -> Dictionary:
    return {
        move = &"world_accel",
        params = {&"world_accel": Vector2(0, gravity)},
    }
    # 未来 VM：return {program = [ {op=&"wait", t=0.3}, ... ]}
```

- **`move` 与 `program` 双形态**：VM 是纯加法，内容 API 不返工。
- 无 `kernel_port()` / 无 `move` / 无 `program` → `unmapped_behavior_count += 1`，直线。
- 映射按**内容签名**（`Script` × `params` hash）缓存，不每发 `instantiate`。
- `BulletData.accel != Vector2.ZERO` 且无 coroutine（宿主语义互斥）→ 直接 `move=&"world_accel"`。
- 替换弹提供 **`spawn_factory: Callable`**（每次返回新 `BulletData`），**不要** `duplicate()`——`Resource.duplicate()` 会丢 `texture` 字段（S4c-1 实测）。

### 15.4 行为归属线

| 层 | 放什么 | 例子 |
|---|---|---|
| 内核 `scripts/kernel/behavior/` | 纯机制、零宿主依赖 | `accel` / `curve` / `laser_follow` / `avoid_player` |
| 桥接 `scripts/kernel_bridge/behavior/` | 需宿主 / 内容 API 的行为 | `world_accel` / `homing` / `bounce` / `non_mid_flee` / `marisa_laser` |
| 内容 `data/**` | 用 `kernel_port()` 把参数翻译成上述名字 | `gravity_bullet` → `world_accel` |

**S4 期间新通用行为先进桥接层**，保持内核冻结；内核定型后再回迁重建版 → vendor。

### 15.5 仍生效的两个决策

- **`bomb` 走宿主节点（不进内核池）**：bomb 需要 `out_grace`（越界不被剔除），而 A 方案下内核 cull 统一、无 per-type grace；bomb 只 8 颗、生命周期短、宿主动作多 → 宿主 `Node2D` 最干净。
- **`out_grace` 与出生雾暂缓**：stage01 + 玩家路径当前不需要；将来作为弹型**属性**接入（正好是 GDExtension 的数据属性之一）。

### 15.6 Timeline 感与 VM（预留，不现在建）

- 「像 Timeline 一样方便」属于 **L 方案**（数据驱动 behavior VM），**GDExtension 只是它的加速器**，不是前提。
- 便宜的中间步：**行为链**（一颗弹挂有序行为槽）能吃掉大半「流程感」。
- **VM 触发条件**：行为种类/复杂度爆炸到「`Behavior` 子类写法开始重复」，或解释器成为热点。当前 ~8 个行为、多为 1–2 个公式参数 → **不建**（YAGNI）。
- 别混三件事：演出 Timeline（计划内，允许）｜敌人发射模式 Timeline/协程（**否决**）｜弹幕运动流 VM（第三类，就是 L）。

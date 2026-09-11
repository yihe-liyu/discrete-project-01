# 原项目 × 新弹幕内核：迁移与改造方案

> 定位：把原项目「节点弹池 + 12 autoload + 协程行为 + 独立 LaserEngine」的弹幕链路，**逐步**迁到重建版内核的架构（SoA 核心 + 组合根注入 + 数据资源 + 显式帧序/层序 + 无头测试），同时保持游戏可玩、可回退。
> 前置阅读：`1-st-touhou-star-rebuild/docs/DECISION_DANMAKU_ARCHITECTURE.md`（含「为何不建议 big-bang」与两个方向的对比）。
> 方法论：**Strangler（绞杀者）** —— 新内核先自包含接入，旧调用点经 adapter 原样可用；再逐子系统替换；最后删旧实现。

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
| `StageObjects` | 42 | 3 / 8 | 关卡命名对象注册表（帧级作用域） | **改注入**（per-stage，`StageContext` 持有） | W2 |
| `HitEffectPool` | 67 | 6 / 10 | 特效节点池 | **改注入**（`FxLayer`，随轨道 A） | W2 |
| `AssetRegistry` | 153 | 31 / 49 | 静态资源表 + 内容 key | **改 `class_name`（静态表）+ 数据资源**（R17/S13） | W3 |
| `StageManager` | 169 | 14 / 35 | 关卡生命周期 + 生成敌人/Boss | **改注入/场景节点**（`StageDirector` under World） | W3 |
| `BulletManager` | 165 | 22 / 46 | 弹幕门面 | **内核替换**（轨道 A Phase 1 + adapter） | W4 |
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
- **StageManager → StageDirector**：它直接调 `GameState.reset_all/clear_enemies` 与 `BulletManager.clear_bullets`（跨 autoload 插手）；目标是把「关卡=World 的子节点」+ 注入服务（对应重建版 `game.gd load_stage` + 关卡脚本）。
- **MissEffectManager → 场景节点**：它是个 CanvasLayer 渲染特效，引用只有 2/3，改由外壳场景挂载并注入最省事。
- **GameManager → 组合根**：它已经在委派 `SceneTransition`/`MenuNav`；把它作为**唯一的壳入口**，在 `_ready` 里创建并注入内核/服务（对应重建版 `game.gd`）。
- **AudioManager 的跨耦合**：它 `connect(GameManager.game_state_changed)`、读 `AssetRegistry.sounds` —— 改由组合根接线（或保留，但明确「音频只听事件」）。

### 12.4 迁移波次（按风险从低到高）

| 波次 | 内容 | 风险 | 说明 |
|---|---|---|---|
| **W1** | `LayerConfig` → `class_name`；`MissEffectManager` → 场景节点 | 极低 | 引用 24 / 3，机械改 |
| **W2** | `StageObjects` → per-stage 注入；`HitEffectPool` → `FxLayer` | 低-中 | 引用 8 / 10；后者随轨道 A |
| **W3** | `AssetRegistry` → `class_name` + 数据；`StageManager` → `StageDirector` | 中-高 | 引用 49 / 35；涉及内容与关卡流程 |
| **W4** | `GameState` 拆分；`BulletManager` 内核替换 | 最高 | 引用 186 / 46；与轨道 A Phase 1/5 合流 |

### 12.5 验收（可量化）

- autoload 数：**12 → ≤5**。
- `grep -rIl "\bGameState\b" scripts`：**42 → 仅存档相关**（目标 ≤ 5）。
- **内核文件里 `GameState` 出现次数 = 0**。
- 每删/改一个 autoload：GUT 全绿 + 主流程冒烟（主菜单 → stage01 可玩）。

### 12.6 风险

- 引用面大的项（`GameState` / `AssetRegistry` / `BulletManager`）必须先做**兼容门面**再迁，不能直接删。
- 迁移期**双写**（`GameState` vs `PlayerResources`）要有兜底与对账测试。
- autoload 之间的横向耦合（`AudioManager → GameManager`、`StageManager → GameState/BulletManager`）要把「谁调谁」改成**组合根接线**，否则拆完还是隐式全局。

### 12.7 W1 实施记录（2026-09-11，已完成）

| 项 | 变更 |
|---|---|
| `LayerConfig` | `scripts/autoload/layer_config.gd` → **`scripts/layer_config.gd`**，加 `class_name LayerConfig` 并去掉 autoload 项；25 处 `LayerConfig.XXX` 引用零改动（静态常量，行为等价） |
| `MissEffectManager` | `scripts/autoload/miss_effect_manager.gd` → **`scripts/effect/miss_effect_manager.gd`**，加 `class_name MissEffectManager` 并去掉 autoload 项 |

**组合根注入链**：`GameScene._ready()` 创建 `MissEffectManager` 子节点 → `StageManager.miss_layer` → `StageContext.effects` → `EffectService.miss_layer`（为空静默跳过，便于测试/无场景上下文）→ `MissEffectManager.add_circle()`。`GameScene._exit_tree()` 置空注入槽；`BulletManager.clear_all()` 删去对 UI 特效的全局直呼（弹幕门面不再知道 miss 圈存在）。

**验收**：

- autoload 数 **12 → 10**。
- `test/test_miss_effect.gd`（8 用例，含 `ProjectSettings.has_setting("autoload/MissEffectManager")` = false 断言）。
- `test/test_composition_root.gd`：实例化 `game_scene.tscn`，断言建出 `MissEffectManager` 子节点且已注入 `StageManager.miss_layer`。
- 全量 GUT **279/279 全绿**（3199 断言）。

**踩坑**：新增 `class_name` 后要让 Godot 重建 `.godot/global_script_class_cache.cfg`（跑一次 `godot --headless --import`），否则 headless 直接报 `Identifier "LayerConfig" not declared`——不是代码错。

**顺带修（与本波无关，验证时暴露）**：`test/test_recent_mechanics.gd` 的练习记录用例非幂等——历史遗留的 `stage=99` 幽灵记录会让 `get_or_create` 命中旧值继续累加（实测 attempts=6/captures=3）造成假失败；已加起始清除，并清掉本地 `.tres` 幽灵项。

---

## 13. Track A spike 记录：S0 内核 vendor（2026-09-11，已完成）

> 分支 `kernel/s0-vendor`（从 `main` @ tag `pre-kernel-adapter` 起）；内核来源 = 重建版 tag `kernel-v1`（commit `238507a`）。

**做了什么**

- 复制内核核心进 `scripts/kernel/`（14 个 `.gd`，1,221 行）：`bullet_system.gd` + `behavior/` + `collision/` + `bullet_type.gd` / `effect_type.gd`。
- **不带**渲染与图集：`bullet_renderer.gd` / `bullet_shapes.gd` / `atlas_layout.gd` / `layer_config.gd`——渲染继续用原项目 `BulletMultiMesh`（它本就按纹理分组、且支持独立 PNG 与图集区域；见重建版决策备忘 §10.4 的 hybrid 结论）。
- **唯一 vendoring 改动**：`bullet_system.gd` 删掉 `BulletRenderer` 注入（`_ready` / `setup_renderers`）——内核本体不引用宿主渲染器类型（R2/R9）。
- 新增 `scripts/kernel/README.md`：写清**来源 / 单一真相 / 边界规则**（禁止 import 原项目 autoload 与实体层；唯一允许 `LayerConfig`）。
- 新增 `test/test_kernel_vendor.gd`（2 用例）：证明内核**独立**可 `new` / `spawn` / `query_circle` / `hit_test` / `despawn`。

**验收**：全量 GUT **56 套 / 281 测试 / 3208 断言全绿**（原 279 + S0 的 2）；`--import` 无撞名 / 解析错误。

**结论**：决策备忘 §10.2「内核不认识原项目全局」成立——搬进来除那 4 行渲染注入外，零改动即可编译运行。**下一拼图 S1** = `KernelBulletBackend`（`BulletData → BulletType` 映射 + 纹理旁表）。

**回退点**：原项目 tag `pre-kernel-adapter`；重建版 tag `kernel-v1`。

---

## 14. Track A spike 记录：S1 适配层（2026-09-11，已完成）

> 分支 `kernel/s0-vendor`（S0/S1 同分支，尚未并 `main`）。

**做了什么**

- 新增 `scripts/kernel_bridge/kernel_bullet_backend.gd`（`KernelBulletBackend`）——**宿主侧桥接**（内核不认识 `BulletData`）：
  - `shoot(data: BulletData, pos, direction)` → 内核 `BulletSystem.spawn(...)`；语义对齐 `Bullet.bind`：**direction 定方向，`data.velocity` 只取长度**。
  - `BulletData → BulletType` 映射：faction / tint_mode / hitbox / hit_fx。**圆判定时把内核 `hitbox_size` 归零**（原项目默认 size(8,8) 但 shape=CIRCLE，不归零每颗圆弹会变矩形）。
  - **按内容签名缓存** `signature_of()`：原项目两种用法并存——`enemy01` 复用同一实例改速度、`cs_reimu`/`non01_shoot` 每发 `BulletData.new()`；按实例缓存会让内核弹型表**每发长一个**。
  - **纹理旁表** `texture_for_index(ti)`：内核 `BulletType` 不含 `Texture2D`，S2 渲染靠它取「哪张图」。
  - S1 只做直线；`coroutine_script` / `accel` 未映射时按直线发射并计入 `unmapped_behavior_count`（S4 接线前用来观察覆盖面）。
- 新增 `test/test_kernel_backend.gd`（6 用例 / 14 断言）：内容签名复用 / 速度语义 / 纹理旁表 / 阵营映射 / 圆矩形判定 / 未映射计数。

**验收**：全量 GUT **57 套 / 287 测试 / 3222 断言全绿**。

**未接线**：`BulletManager` 尚未委托后端——S1 仍是纯增量（原路径一行未改）。

---

## 15. Track A spike 记录：S2 渲染读内核快照（2026-09-11，已完成）

> 分支 `kernel/s2-swap`（自 `main` @ merge S0/S1）。**仍未接线**：`BulletManager` 照旧走旧池，所以 S2 现在是一条**备用渲染路径**。

**做了什么**

- `scripts/bullet/bullet_multi_mesh.gd` 改为**双数据源**（Strangler）：
  - `set_backend(KernelBulletBackend)` 注入后 → `_sync_kernel()` 读内核 SoA 快照（position / velocity / color / faction / type_index / type_registry + `backend.texture_for_index()`）。
  - 未注入 → `_sync_nodes()` 旧路径（遍历 `BulletManager.active_bullets`）**逐字保留**，可随时回退。
  - 抽出 `_group_key()` **两路共用**（纹理 RID + region + 阵营 + tint_mode），批次数才可比对；抽出 `_hide_all()` / `_hide_group()`。
- **阵营枚举必须显式映射**：内核 `Faction{ENEMY=0, PLAYER=1, NONE=2}` vs 宿主 `Bullet.FACTION_PLAYER=0 / ENEMY=1 / BOMB=2` **顺序不同**；`_host_faction()` 负责转换，否则敌弹/自机弹的 z 会互换。
- 朝向/颜色对齐旧路径语义：`bt.rotation_for(velocity)` + `colors[i]` + `scale = ONE`。
- 新增 `test/test_kernel_render.gd`（5 用例 / 7 断言）。

**验收**：全量 GUT **58 套 / 292 测试 / 3229 断言全绿**。

**坑**：headless（dummy 渲染器）下 `MultiMesh.get_instance_transform_2d()` **读回恒为 0**——逐实例几何不能在 CI 里断言；S2 的断言因此落在批次数 / `visible_instance_count` / `z_index` / 材质 / 网格尺寸，**画面一致性留给 S3 之后的手动试玩**。

**下一拼图 S3**：`BulletManager` 加 `use_kernel` 开关，`shoot_enemy_bullet` 委托后端；需手动试玩 stage01 验证表现一致。

---

## 16. S3 前置决策：碰撞 / 伤害模型（2026-09-11，**待定**）

> 原计划 S3 = "加 `use_kernel` + 委托后端"。读全 `BulletPhysics` / 内核 `CollisionResolver` / `BulletType` 后确认：**S3 不是"换发射入口"，而是"换掉整个弹幕运行时"**——只换发射会让弹幕变成"只飞不判定"或"数值差 10–50 倍"。下面是动手前必须先定的分叉。

### 16.1 硬阻塞：内核 `BulletType` **没有 `damage`**

| | 原项目 | 重建内核 |
|---|---|---|
| 伤害载体 | `BulletData.damage`（默认 **10.0**，Bomb **50.0**） | **无此字段** |
| 结算 | `enemy.take_damage(bullet.damage * bonus)`（记忆 <50 时 `bonus = 1.15~1.05`），`Enemy` 内部**小数累积** | `Enemy._on_bullet_overlap` → `take_damage(1.0)` |
| 量级 | Boss HP 1000 → 约 100 发 | 同 Boss 需 1000 发 |

→ 直接把原项目弹幕灌进内核，**Boss TTK 差 ~10×，杂兵（HP 3 / 24）差更多**。这是玩法崩坏，不是表现细节。

### 16.2 其他必须一起搬的规则（全在 `BulletPhysics`，内核没有对等物）

| 规则 | 原项目 | 内核现状 |
|---|---|---|
| 敌弹 vs 自机 **命中 + 擦弹双阈值** | `_resolve_enemy_bullets_near_player`（`graze_radius` 查询 + `_hit_target` 精判 + `_grazes_player`） | `CollisionResolver` **明确声明不含 graze**（"擦弹属玩家机制"） |
| 擦弹的**随机清弹**（记忆≥50 时 5%~30%） | 同上 | 无 |
| `bomb` 弹 vs 敌弹 / 敌人（同一弹对同一敌人只伤一次） | `_bomb_vs_enemy_bullets` / `_bomb_vs_enemies` | 无对等物（内核是 `cancel_bullets` 一次性圆） |
| 命中音效规则（专属 key；默认仅 Boss <30% 播） | `_player_vs_enemies` | 无 |
| 命中特效（`bullet.hit_effect`，颜色取弹当前色） | `_spawn_effect` | `BulletType.hit_fx` 有场景，但不带颜色/tint 逻辑 |
| `out_grace`（出界宽限；探测弹往返） | `BulletManager._physics_process` | 内核只有 `cull_rect + cull_margin`（固定余量，非按型） |
| 死亡清弹（Miss/Bomb 扩散圈） | `DeathClear` 遍历 `_pool` | `cancel_bullets` 一次性圆，需外部驱动 |

### 16.3 另一个坑：帧序

原项目碰撞在 `BulletManager._physics_process`（autoload，priority 0）；内核 `BulletSystem` 是它的子节点（同为 0，**父先子后**）→ 碰撞会读到**上一帧**位置。必须显式设 `BulletSystem.process_physics_priority = FrameOrder.INTEGRATE(-10)`，并另起一个 `FrameOrder.COLLISION(10)` 的驱动节点。

### 16.4 分叉（选一个）

| 选项 | 做法 | 优点 | 代价 |
|---|---|---|---|
| **A（推荐）宿主侧规则移植** | 新建 `KernelBulletPhysics`（宿主桥接）把 `BulletPhysics` 规则**逐条**移植到内核 API；宿主专有字段（`damage` / `out_grace` / `can_be_canceled` / `hit_sfx` / `hitbox_shape` / `hitbox_rotation`）走 `KernelBulletBackend` 的**侧表** | 内核**零改动**；语义 1:1；Strangler 可回退 | 桥接 ~200 行；规则仍散在宿主 |
| **B 内核补 `damage` + 用内核协调器** | 给 `BulletType` 加 `damage`；宿主改用 `CollisionCoordinator` / `CollisionResolver`（玩家/敌人注册） | 长期干净、双宿主一致 | 改**重建版内核**（`kernel-v2`）+ 重新 vendor；重建版 `Enemy/Boss` 的 damage 用法要跟着改；graze/bomb 仍要宿主补 |

**建议 A**：路 B 的定位是"原项目为干"——A 保持原项目玩法语义不变、内核零改动，风险最小；B 属于"内核定型后"的整理（对应决策备忘"内核稳定再宣布唯一之家"）。

### 16.5 建议把 S3 拆成三步（每步独立回归）

| 步 | 内容 | 可验证 |
|---|---|---|
| **S3a** | `use_kernel` + spawn / 积分 / 渲染 / `cull_rect` / pause 路由（**明确不含碰撞**） | headless 回归 + **视觉试玩**（弹幕会飞、会画，但穿过玩家） |
| **S3b** | 敌弹 ↔ 自机：命中 + 擦弹双阈值 + 擦弹随机清弹（核心生存规则） | headless + 试玩（能中弹、能擦弹） |
| **S3c** | 自机弹 ↔ 敌人（damage 侧表 + 记忆加成 + 音效/特效）+ bomb + 死亡清弹 + out_grace | headless + 完整试玩 |

> **开关不能用 F1**：`debug_toggle` 已被 `scripts/debug/debug_drawer.gd` 与 `scripts/scenes/main_menu.gd` 占用。**最终决定**：`use_kernel` 默认 `false`（Strangler：主流程零改动），试玩时用 `set_use_kernel(true)` 切换。

---

## 17. Track A spike 记录：S3a 内核路由（2026-09-11，已完成）

> 分支 `kernel/s2-swap`。**范围**：让 `BulletManager` 能把弹幕整个切到内核池（spawn / 积分 / 渲染 / 剔除 / 暂停 / 清空），**不含碰撞**（见 §16.5）。默认 `use_kernel = false`（Strangler：主流程零改动）。

**做了什么**

- `scripts/autoload/bullet_manager.gd`：
  - 新增 `use_kernel` / `_kernel: KernelBulletBackend` / `kernel_system()` / `set_use_kernel(v)` / `_enable_kernel()`。
  - `shoot_bullet` / `shoot_player_bullet` / `shoot_enemy_bullet` / `shoot_bomb_bullet` 四入口按开关分流。
  - `set_use_kernel(true)` 先清旧池再装配；`set_use_kernel(false)` 清内核池并把渲染数据源复位。
  - `_enable_kernel()`：`process_physics_priority = -10`（§16.3 帧序）、`cull_rect = 东方框`、`cull_margin = 90`（对齐旧 `is_offscreen`）、`_multi_mesh.set_backend(_kernel)`（S2 路径）。
  - `_physics_process` 的旧碰撞 / 出屏回收整块收进 `if not use_kernel:`；`clear_all / clear_bullets / pause_processing / resume_processing` 同步路由。
- 新增 `test/test_kernel_swap.gd`（4 用例 / 8 断言）：路由到内核池 / `cull_rect` 对齐 / 切回旧路清空内核池 / 帧序优先。

**验收**：全量 GUT **59 套 / 296 测试 / 3237 断言全绿**。

**切到内核会怎样（不骗你）**：弹幕会**飞、会画**（内核积分 + S2 渲染快照），但**不判定**（碰撞未接），且**行为不全**（`bounce / gravity / radial` 仍是每弹协程，内核不跑 → 这些弹变直线；可用后端 `unmapped_behavior_count` 观察）。所以 S3a 的试玩验证的是"轨迹 / 朝向 / 颜色 / 层次对不对"。

**下一拼图 S3b**：敌弹 ↔ 自机（命中 + 擦弹双阈值 + 擦弹随机清弹），新建 `KernelBulletPhysics` 宿主桥接。

---

## 18. Track A spike 记录：S3b 敌弹 ↔ 自机（2026-09-11，已完成）

> 分支 `kernel/s2-swap`。**范围**：把旧 `BulletPhysics._resolve_enemy_bullets_near_player` 1:1 移植到内核几何上（命中 + 擦弹双阈值 + 记忆随机清弹）。

**做了什么**

- 新增 `scripts/kernel_bridge/kernel_bullet_physics.gd`（`KernelBulletPhysics`，宿主桥接）：
  - `process()` 由 `BulletManager._physics_process`（priority 0）在**内核积分之后**调用（内核 `BulletSystem` = priority -10，先跑）。
  - `_enemy_bullets_vs_player()`：`CollisionResolver.overlap_ids(.., player.graze_radius, ENEMY)` 取候选 → **倒序**逐弹 `hit_test(id, pos, hitbox_radius)` 精判 → `player.miss()` + `despawn`；否则 `hit_test(id, pos, graze_radius)` → `mark_grazed` + 擦弹结算（`graze_count / add_score(10) / add_memory` + 音效）。
  - 记忆 ≥50 时按旧公式 `remap(50, 100, 0.05, 0.30)` 随机清弹（`RNG.randf()`，S10 可复现）。
- `BulletManager` 增 `_kernel_physics`，在 `_enable_kernel()` 里装配；`_physics_process` 的 `else` 分支调 `process()`。
- 新增 `test/test_kernel_physics.gd`（4 用例 / 7 断言）：命中→回收+无敌 / 擦弹→计数且不回收 / 擦弹不重复计 / 无敌时穿过。

**验收**：全量 GUT **60 套 / 300 测试 / 3244 断言全绿**。

**几何语义对齐（关键）**：内核 `hit_test(id, center, radius)` 内部按 `radius + 弹半径` 判圆（矩形/偏移走 `HitGeometry` 统一实现），与旧 `_check_circle / _check_rect` 同义；**擦弹就是"更大 radius 的同一次判定"**。

**下一拼图 S3c**：自机弹 ↔ 敌人（`damage` 侧表 + 记忆加成 + 音效/特效）+ bomb + 死亡清弹 + `out_grace`。

---

## 19. Track A spike 记录：S3c 自机弹 ↔ 敌人（2026-09-11，已完成）

> 分支 `kernel/s2-swap`。**范围**：把旧 `BulletPhysics._player_vs_enemies` 的规则移植到内核几何上；**damage 走宿主侧表**（内核 `BulletType` 无此字段，见 §16.1）。**A 方案至此验证成立**。

**做了什么**

- `KernelBulletBackend` 新增宿主专有侧表：`_damage_by_index`（伤害）/ `_hit_sfx_by_index`（命中音效 key），随 `_sync_host_tables()` 与纹理旁表一起增长；访问器 `damage_for_index(ti)` / `hit_sfx_for_index(ti)`。**内核零改动**。
- `KernelBulletPhysics` 新增 `_player_bullets_vs_enemies()`：
  - 倒序遍历内核行，只处理 `Faction.PLAYER`；对 `GameState.get_active_enemies()` 逐个 `hit_test(i, enemy.pos, enemy.hitbox_radius)`。
  - 命中 → `enemy.take_damage(damage * bonus)` + `add_memory(MEMORY_HIT_BY_BULLET)` + 音效规则 + 命中特效 + `despawn`。
  - 与旧实现一致：Boss 时符 / 未开战（`current_phase() == null or is_timeout_only`）时弹穿过；`bonus = 1 + remap(memory, 0, 50, 0.15, 0.05)`（记忆 <50 时）。
  - 命中音效 1:1：专属 key 任何敌人命中都播（音量表 `HIT_SFX_VOLUME`）；默认仅 Boss 残血播；未知 key 回退 `normal_damage` 并告警。
- 新增测试：`FakeEnemy`（轻量假敌人）+ damage 侧表用例；`test_kernel_physics` 现 5 用例 / 9 断言。

**验收**：全量 GUT **60 套 / 301 测试 / 3246 断言全绿**。

**A 方案成立的关键证据**：`damage` 不引入内核也能 1:1 保住（侧表 + 宿主规则）→ §16.1 的 "Boss TTK 差 ~10×" 风险被规避，内核仍零改动。

**本步仍未接（明确列出，别以为是全的）**：

- `bomb`（X 键）：原项目是 `bomb_bullet` + `BOMB_BEHAVIOR` 协程自爆——依赖 S4 行为移植。
- **死亡清弹**（Miss / Boss 击破 / Bomb 扩散圈）：`DeathClear` 仍遍历旧 `_pool`；内核池需另接。 **→ S3d 已接，见 §20。**
- `out_grace`：内核按 `cull_margin=90` 统一剔除，未按弹型宽限（bomb 的 9999 宽限会失效）。
- **行为**（`bounce / gravity / radial` 等）：内核不跑 `coroutine_script` → 目前按直线飞（S4）。
- **自机弹记忆变红**：旧 `Bullet.bind` 在 `memory<50` 时把 `sprite.modulate` 往红 lerp，桥接尚未复现。

**试玩入口**：`BulletManager.set_use_kernel(true)`（默认 `false`；游戏内按 **F2** 热切）。**完整可玩性还差 S4（行为）+ 上面 3 项**——当前切过去能看到/打到，但 Bomb、反弹弹会不对。

## 20. Track A spike 记录：S3d 死亡清弹（2026-09-11，已完成）

> 分支 `kernel/s2-swap`。**范围**：把旧 `DeathClear` 的展开清弹圈接到内核池。**这是试玩唯一发现的行为缺失**（Boss 阶段击破 / Miss 时弹幕不清）。

**问题**：`DeathClear.process()` 直接遍历 `_pool.active_bullets`（旧 `Bullet` 节点数组）。内核路径下旧池恒空 → 清弹圈空转，弹留在屏幕上。

**做了什么**

- **不重写清弹圈**：`DeathClear` 仍是“展开半径 + 切生长激光头”的唯一实现；只把“清圆内敌弹”抽成注入回调 `_kernel_sweep: Callable`（签名 `(center, radius, on_clear) -> bool`，true = 已由内核清完，跳过旧循环）。旧池逐弹循环**原样保留**在 `if not handled:` 分支。
- `KernelBulletPhysics.sweep_enemy_bullets()`：倒序遍历内核行，只清 `Faction.ENEMY` 且在半径内的弹；逐弹 `on_clear`（掉道具）→ `HitEffectPool.play(_CLEAR_EFFECT, pos, ZERO, sys.get_color(i))` → `despawn(i)`。与旧循环 1:1（颜色取内核当前色；**含出生雾中的弹**）。**内核零改动**——直接复用现成 `despawn`。
- `BulletManager._kernel_sweep_death_clear()`：`use_kernel` 为真 → 交内核扫掠并返回 true，否则返回 false 交回旧循环；回调在 `_ready` 注入 `DeathClear.setup()`。

**为什么不用内核现成的 `cancel_bullets()`**：读实现后两点不合——(1) 它是一次性全清，而死亡清弹是**逐帧扩张半径**；(2) 它的消散特效发成内核“纯特效行”（`_type_index < 0`），而当前渲染桥只认弹型行，特效行不会画。故走宿主侧逐弹扫掠、复用 `HitEffectPool`。

**为什么分派落在 BulletManager**：双后端分派的唯一归属地（S3a 起的约定）；`DeathClear` 保持后端无关，旧池路径零风险（原循环一行未改）。

**顺手修正的一处认知**：旧 `Bullet.bind()` 末尾**无条件** `is_ready = true`（`bullet.gd:135`），所以出生雾中的弹也会被死亡清弹清掉——内核扫掠据此**不做** `fx_phase` 过滤，与旧行为一致。

**验收**：`test_kernel_physics` +2（圆内/圆外、自机弹免疫）、`test_kernel_swap` +2（内核集成、旧池回归）；全量 GUT **60 套 / 305 测试 / 3254 断言全绿**。

**S3 收敛后剩余（未接）**：`bomb`（X，依赖 S4）、`out_grace`（按弹型出界宽限）、行为（`bounce / gravity / radial`，S4）、自机弹记忆变红（桥接未复现）。





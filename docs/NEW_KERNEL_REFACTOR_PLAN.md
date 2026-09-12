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

- autoload 数：**12 → ≤5**（进度：W1 后 10，W2 后 8，W3a 后 7，W3b 后 **6**：`GameEvents / GameManager / BulletManager / GameState / RNG / AudioManager`）。
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

**组合根注入链**：`MissEffectManager` 节点在 `game_scene.tscn` 的 `Main` 下**声明**（R21；W2 补正，原为 `GameScene._ready()` 里 `new()+add_child`）→ `GameScene._ready()` 注入 `StageManager.miss_layer` → `StageContext.effects` → `EffectService.miss_layer`（为空静默跳过，便于测试/无场景上下文）→ `MissEffectManager.add_circle()`。`GameScene._exit_tree()` 置空注入槽；`BulletManager.clear_all()` 删去对 UI 特效的全局直呼（弹幕门面不再知道 miss 圈存在）。

**验收**：

- autoload 数 **12 → 10**。
- `test/test_miss_effect.gd`（8 用例，含 `ProjectSettings.has_setting("autoload/MissEffectManager")` = false 断言）。
- `test/test_composition_root.gd`：实例化 `game_scene.tscn`，断言建出 `MissEffectManager` 子节点且已注入 `StageManager.miss_layer`。
- 全量 GUT **279/279 全绿**（3199 断言）。

**踩坑**：新增 `class_name` 后要让 Godot 重建 `.godot/global_script_class_cache.cfg`（跑一次 `godot --headless --import`），否则 headless 直接报 `Identifier "LayerConfig" not declared`——不是代码错。

**顺带修（与本波无关，验证时暴露）**：`test/test_recent_mechanics.gd` 的练习记录用例非幂等——历史遗留的 `stage=99` 幽灵记录会让 `get_or_create` 命中旧值继续累加（实测 attempts=6/captures=3）造成假失败；已加起始清除，并清掉本地 `.tres` 幽灵项。

---

### 12.8 W2 实施记录（2026-09-11，已完成）

| 项 | 变更 |
|---|---|
| `StageObjects` | `scripts/autoload/stage_objects.gd`（autoload）→ **`scripts/coroutine/services/stage_objects.gd`**（`class_name StageObjects extends RefCounted`）；注册表由 `StageContext.objects` 持有（per-ctx，随关卡生命周期），`StageDirector` 注册/清理，并把同一注册表注入 `BossHandle`。删 autoload 项 |
| `HitEffectPool` | `scripts/autoload/hit_effect_pool.gd`（autoload）→ **`scripts/effect/fx_layer.gd`**（`class_name FxLayer extends Node2D`，池化节点）。删 autoload 项 |

**`FxLayer` 注入链**：`FxLayer` 节点在 **`game_scene.tscn` 的 `World` 下声明**（R21：声明式建树，非 `new()+add_child`；与 `ItemPool` 同规格）→ `GameScene._ready()` 注入 `StageManager.fx_layer`（供 `StageContext.effects` → `EffectService.fx_layer`）+ `BulletManager.inject_fx_layer()`（转发给 `BulletPhysics.fx` / `DeathClear.fx` / `KernelBulletPhysics.fx`）。所有调用点带 `fx == null` 静默守卫（单测/无场景安全）。`GameScene._exit_tree()`：`BulletManager.clear_all()` 内含 `fx_layer.clear_pool()`，随后 `inject_fx_layer(null)` + `StageManager.fx_layer = null` 解除注入。**消灭了 `Engine.get_main_loop().current_scene.get_node_or_null("World")` 这种全树找父级（R2/R9）**。

**验收**：

- autoload 数 **12 → 8**（当前：`GameEvents / GameManager / BulletManager / GameState / StageManager / RNG / AudioManager / AssetRegistry`）。
- `test/test_composition_root.gd` 增 `test_game_scene_creates_and_injects_fx_layer`：实例化 `game_scene.tscn`，断言 `World/FxLayer` 建出且注入 `StageManager.fx_layer` / `BulletManager.fx_layer`。
- `test/test_stage_director.gd` 改为纯逻辑（`StageContext.new(null).objects` + 句柄持注册表），去掉 autoload 依赖。
- `test/test_fx_layer.gd`（3 用例）：挂树/复用/清池语义。
- 全量 GUT **62 套 / 333 测试 / 3327 断言全绿**。

**踩坑**：同 W1——新增 `class_name` 必须重建 `.godot/global_script_class_cache.cfg`（本次用 `godot --headless --editor --quit`），否则 headless 报 `Could not find type "StageObjects" / "FxLayer"`，并连锁出 81 个假失败（`Scripts 61→59`）。不是代码错。

**R21 补正**：`FxLayer` 与 `MissEffectManager` 均改为 `game_scene.tscn` 声明式节点（前者 W2 初版、后者 W1 产物在本次一并收口），`game_scene.gd` 只保留 `@onready` 引用 + 注入。

**边界澄清**：`FxLayer` 仍是**宿主侧**节点（`class_name` + `game_scene.tscn` 声明、组合根注入），不是内核服务——`scripts/kernel/**` 不引用它；`scripts/kernel_bridge/**` 桥接层可以收到注入的 `fx`。把消弹特效下沉进内核属于 W4 收敛话题，本波不动内核。

---


### 12.9 W3a 实施记录（2026-09-11，已完成）

| 项 | 变更 |
|---|---|
| `AssetRegistry` | `scripts/autoload/asset_registry.gd`（autoload）→ **`scripts/asset_registry.gd`**（`class_name AssetRegistry`，无 extends → RefCounted）；`_bgm_cache` 改 `static var`，`get_bgm / get_bgm_title / _unlock_music_by_key / get_bullet_tex` 改 `static func`。删 autoload 项 |
| 调用点 | **0 改动**——`const` 静态表与 `static func` 都按 `AssetRegistry.xxx` 访问，语法与原 autoload 实例一致 |

**为什么可以零改动**：原 `AssetRegistry` 的可变状态只有 `_bgm_cache`（懒加载缓存），`static var` 语义等价（进程内常驻）。`bullet_configs / sounds / enemy_visuals / BGM_PATHS / FOG_TEXTURE` 本来就是 `const`。

**验收**：

- autoload 数 **8 → 7**。
- `test/test_asset_registry.gd`：`autoload/AssetRegistry` 已移除 + 静态表/方法可用。
- `test/test_composition_root.gd` 增 `test_removed_autoloads_stay_removed`（统一守卫 W1/W2/W3a 去掉的 5 个 autoload）。
- 全量 GUT **63 套 / 336 测试 / 3337 断言全绿**。

**暂缓（不属本步）**：`bullet_configs` / `sounds` / `enemy_visuals` → `data/*.tres`（R17）与 S13 图集迁移一起做；现在只把 autoload 降成静态表。

**W3b**：见 §12.10（已完成）——`StageRuntime` 场景节点 + `ctx.stage`，`add_enemy_to_scene` 的 World 查找已改注入。

---

### 12.10 W3b 实施记录（2026-09-11，已完成）

**目标**：`StageManager` autoload → `StageRuntime` 场景节点 + `ctx.stage` 注入；autoload 7 → 6。

**做法（strangler 两步）**：

- **W3b-1**（`c3b4758`）：抽出 `scripts/stage/stage_runtime.gd`（`class_name StageRuntime extends Node`，World 下声明）；`StageManager` 暂留薄门面转发，调用点零改动；`world` 注入修掉 `add_enemy_to_scene` 的 `get_tree().current_scene.get_node_or_null("World")`（R2）。
- **W3b-2**（本次）：删除 `StageManager` autoload；所有调用点迁到 `ctx.stage` / 直接引用。

**落点**：

- `StageRuntime`：持有 `world` / `miss_layer` / `fx_layer` / `current_background` 与生命周期/工厂；创建 ctx 时回填 `ctx.stage`。
- `StageContext.stage`：内容经此拿服务；`ctx.effects` 读 `stage.miss_layer/fx_layer`，`ctx.get_decor()` 读 `stage.current_background`。
- `EnemyData.spawn(ctx)` → `ctx.stage.spawn_enemy_data`；`StageDirector` → `ctx.stage.spawn_boss`。
- 组合根：`game_scene.tscn` / `workbench.tscn` 的 `World` 下声明 `StageRuntime`；`_ready` 注入 `world`/槽位。
- 组合台：`bench_base.gd:ensure_stage_runtime()` 自备（`enemy_bench`/`phase_bench`）；`bookmark_panel.stage_runtime` 由 Workbench 注入；`creation_station` 切页调 workbench 的公开 `stop_stage()`。

**踩坑**：`workbench._load_stage()` 的"清 World 残留"循环把新放进 `World` 的 `StageRuntime` 一起 `queue_free` → `_stage_runtime` 变 freed。已排除 `StageRuntime`（与 `_ghost` 同级）。**教训：把结构性服务节点放 World 下时，任何"清 World"循环都要排除它。**

**验收**：autoload **7 → 6**；`test_composition_root` 增 StageRuntime 声明/注入/真加载断言；全量 **63 套 / 337 测试 / 3341 断言全绿**。

---

### 12.11 W4a-1 实施记录（2026-09-11，已完成）

**目标**：把内核从"开关后的备选"**转正为默认弹幕后端**，旧池保留为回滚（strangler 的"翻开关"步）。autoload 数不变。

**变更**：

- `BulletManager.use_kernel` 默认 `false → true`；F2 语义从"切到内核"变为"切回旧池回滚"。
- 新增后端无关的 `BulletManager.active_count()`；统计/断言从旧池专属 `active_bullets` 迁过来（`bullet_bench` / `enemy_bench` / `phase_bench` / `workbench` / `debug_drawer`）。
- 旧池专属测试显式 `set_use_kernel(false)`：`test_hit_sfx_rules`（旧 `BulletPhysics`）、`test_bullet_batch`（旧渲染分组）、`test_bounce_bullet`（旧 bounce 脚本）；`test_bullet_rig` / `test_creation_station` 改用 `active_count()`。

**验收**：kernel 默认下全量 **63 套 / 338 测试 / 3342 断言全绿**。

**转正暴露的回归（已修）**：默认翻 `true` 后 `_enable_kernel()` 在 autoload `_ready` 跑——**自机尚未生成**，`BehaviorContext` 缓存了 null 自机且不再刷新 → `non_mid_flee` / `homing` 的"接近自机"判定失效（中boss非符逃跑弹直线飞）。修：`BulletManager.refresh_kernel_player()`，由组合根在自机就绪后调（`GameScene._setup_player` / `workbench._setup_world` / `bench_base.build_world`）。回归测试 `test_composition_root:test_game_scene_refreshes_kernel_player`。

**待办（W4a-2）**：试玩确认未映射内容无回归后，删旧池（`BulletPool`/`Bullet`/`BulletPhysics`/`DeathClear` 旧循环/`BulletMultiMesh._sync_nodes`）+ `use_kernel`/F2/`active_bullets`。

---

### 12.12 W4a-2 实施记录（2026-09-11，已完成）

**目标**：删除旧弹幕子系统，内核成为**唯一**后端（不再有开关/旧池）。

**删除**：

- `scripts/autoload/bullet/bullet_pool.gd` / `bullet_physics.gd`、`scripts/bullet/bullet.gd` / `spatial_hash.gd` / `bomb_behavior.gd` / `bullet_fog.gd`、`scenes/bullet.tscn`。
- `BulletManager` 的 `use_kernel` / `set_use_kernel` / F2 `kernel_toggle` / `active_bullets` / `use_multi_mesh` 与全部旧分支。

**收窄**：

- `BulletManager`：内核唯一；`active_count()` 直读内核；`_on_laser_graze()` / `_sweep_death_clear()` 注入给 `LaserEngine` / `DeathClear`。
- `DeathClear`：不再持旧池，逐帧调注入的内核扫掠。
- `BulletMultiMesh`：删 `_sync_nodes`，只读内核快照；`Bullet.FACTION_*` → 本地常量。
- `LaserEngine`：`BulletPhysics` 依赖 → 注入 `on_graze` Callable（`KernelBulletPhysics.on_graze` 转公开）。
- `player.gd`：删 `bomb_behavior` 预载（内核 `KernelBomb` 不读它）。
- 内容脚本去 `Bullet` 类型标注（旧 `_tick` 变死代码但可编译）。

**测试**：随旧代码删 9 个旧池套件；`test_kernel_swap` 重写为内核唯一；`test_laser` 改用注入 Callable。

**验收**：`check_syntax` **190 脚本 / 0 失败**；全量 **54 套 / 299 测试 / 3181 断言全绿**。autoload 数不变（6；`BulletManager` 去 autoload 归 W4c）。

**修复（本次）**：魔理沙激光段贴图不旋转——内核 `MarisaLaserBehavior` 只 `set_position` 没设 `velocity`，渲染桥按 `velocity` 算朝向 → 零速度返回 0。补 `set_velocity(bullet_id, dir)`（与旧 `marisa_laser_follow._tick` 的 `target.velocity = dir` 一致）。回归断言已加。

---

### 12.13 W4b-1 实施记录（2026-09-11，已完成）

**目标**：把 `GameState` 的单局资源状态抽成单一 owner `PlayerResources`（R18），**调用点零改动**（GameState 转发属性/方法），行为不变。

**落点**：

- 新增 `scripts/player/player_resources.gd`（`class_name PlayerResources extends RefCounted` + `changed`）：火力 / 分数 / 擦弹 / 残机 / 雷 / 碎片 / 记忆 + 显式入口 + `reset_*` + `regen`。
- `GameState`：`var resources := PlayerResources.new()`；`current_score / lives / life_fragments / bomb_count / bomb_fragments / power_raw / max_point / graze_count / memory_value` 改**转发属性**；`add_*` / `collect_*` / `lose_life` / `use_bomb` / `reset_*` / `_process` 委托；`MEMORY_*` 常量单一来源 `PlayerResources`。

**验收**：`test/test_player_resources.gd`（4 用例）；全量 **55 套 / 303 测试 / 3191 断言全绿**。

**W4b-2a（本次）**：`Player` 增 `resources`（`_ready` 取同一实例）；`player.gd` 的资源引用清零（`use_bomb`/`memory_value`/`reduce_memory`/`add_memory`/`lose_life`）。全量 55/303/3191 绿。

**后续（W4b-2b/3/4）**：其余消费者（`game_ui` / `item` / `boss` / 内核桥接 / 菜单）改直接持 `PlayerResources` → 注入 `player` / `active_enemies` → 瘦身 `GameState` 成存档全局。注意：W4b-2a 只覆盖有天然注入点的 `Player`；全量去耦合需按文件逐个消除 `GameState` 引用（共 ~45 生产文件）。

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

## 21. Track A/S4 方案：行为桥与端口契约（2026-09-11，决策）

> **范围**：把旧 `coroutine_script` / `BulletData.accel` 的运动行为接到内核 `Behavior`。本文先钉**契约**，再按 S4a–d 落地。**核心结论：只有一个扩展点（`Behavior` 注册表），没有“特殊途径”。**

### 21.1 行为清单（实测，2026-09-11）

| 宿主行为 | 用在哪 | 内核现状 | 处置 |
|---|---|---|---|
| `BulletData.accel`（世界匀加速） | 魔理沙 opt2、stage03B 分裂弹 | 无 | **S4a** `world_accel` |
| `gravity_bullet`（竖直向下加速） | stage01 杂兵01/02/03 | 无（= 世界向下 accel） | **S4a** 端口 → `world_accel` |
| `radial_accel_bullet`（沿初方向加速 + 碰顶边 re_fire） | stage01 enemy04 | `accel` 覆盖加速；re_fire 无 | S4c（加速已在） |
| `bounce_bullet`（沿向加速 + 三面反弹 + 瞄准 Boss re_fire） | stage01 非符1 | 无 | **S4c** 桥接 |
| `non_mid01_bullet`（近自机逃 + 近 Boss 散圈消失） | stage01 中boss非符 | `avoid_player` 覆盖逃跑 | **S4c** 散圈 |
| `move_homing`（追杀最近敌人） | 灵梦 opt1 | `WorldQuery` 在、行为缺 | **S4b** `homing` |
| `marisa_laser_follow`（锚定漂移 + 松手渐隐） | 魔理沙非focus激光 | `laser_follow` 覆盖漂移 | **S4c** 渐隐 |
| `orbit_probe`（减速往返 + 分裂） | stage03B | 无 | **本轮不做**（2 文件 WIP） |
| `bomb_behavior`（绕自机扩张 + 追踪 + 爆炸） | 炸弹 | 无 | **S4d** 桥接 |

内核现成：`accel` / `curve`（宿主没人用）/ `laser_follow` / `avoid_player`。

### 21.2 唯一扩展点 = `Behavior` 注册表

一切行为——内核自带、桥接自定义、未来的 VM 步骤——都是 `Behavior` 子类，经同一入口注册：

```gdscript
func register_behavior(move_name: StringName, behavior: Behavior) -> void
```

**逃生口不是后门，它就是前门本身。** VM（`ScriptedBehavior`）只是注册表里的第 N 个租户，和手写 `Behavior` 平级。
纪律三条（守住即“干净”）：

1. 必须跑在 behavior pass（不绕帧序 / 协调器）；
2. 只读写自己那一行（`_behavior_params` 只读 / `_behavior_state` 每弹）；
3. 需要宿主全局 → 放 `scripts/kernel_bridge/behavior/`，内核保持零宿主引用。

> 已有同形先例：`EnemyRoutine = MovePattern × ShootPattern`（数据驱动）+ 没覆盖就写新的 `MovePattern` 子类；`VisualShader` ↔ `Shader`；VFX Graph + Custom HLSL。

### 21.3 端口契约（内容 → 内核）

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

- **`move` 与 `program` 双形态**：VM 是纯加法，内容 API 不返工（§21.6）。
- 无 `kernel_port()` / 无 `move` / 无 `program` → `unmapped_behavior_count += 1`，直线。
- 映射按**内容签名**（`Script` × `params` hash）缓存，不每发 `instantiate`（沿用 S1 弹型缓存思路）。
- `BulletData.accel != Vector2.ZERO` 且无 coroutine（宿主语义互斥）→ 直接 `move=&"world_accel"`。

### 21.4 帧序与装配

- 优先级（原项目无 `FrameOrder`，用绝对 `process_physics_priority`）：内核积分 **-10** → 行为 **-5** → 宿主碰撞 **0**。
- 装配点：`KernelBulletBackend.setup_behaviors(player, enemy_provider)`，由 `BulletManager._enable_kernel()` 调；`WorldQuery` provider = `GameState.get_active_enemies`。
- 已知限制：`BehaviorContext` 在 setup 时捕获 player 引用；若为空，涉及自机的行为（`avoid_player` / `laser_follow`）需在 S4b/c 再处理“动态取自机”。S4a 只用 `world_accel`，不受影响。

### 21.5 行为归属线

| 层 | 放什么 | 例子 |
|---|---|---|
| 内核 `scripts/kernel/behavior/` | 纯机制、零宿主依赖 | `accel` / `curve` / `laser_follow` / `avoid_player`（未来 `homing`） |
| 桥接 `scripts/kernel_bridge/behavior/` | 需宿主 / 内容 API 的行为 | `world_accel`（S4a）、`bounce` / `bomb` / 散圈（S4c/d） |
| 内容 `data/**` | 用 `kernel_port()` 把参数翻译成上述名字 | `gravity_bullet` → `world_accel` |

**S4 期间新通用行为先进桥接层**，保持内核冻结（承接 S3 的 A 方案：内核零改动）；内核定型后再回迁重建版 → vendor（README 单一真相的口子）。

### 21.6 Timeline 感与 VM（预留，不现在建）

- 想要“像 Timeline 一样方便”：那属于 **L 方案**（数据驱动 behavior VM，见 `DECISION_DANMAKU_ARCHITECTURE.md` §4），**GDExtension 只是它的加速器**（§6.6 / §8），不是前提。
- 便宜的中间步：**行为链**（一颗弹挂有序行为槽）能吃掉大半“流程感”，几乎不加机制。
- **VM 触发条件**：行为种类/复杂度爆炸到“`Behavior` 子类写法开始重复”，或解释器成为热点。当前 ~8 个行为、多为 1–2 个公式参数 → **不建**（YAGNI）。
- 逃生门已留：端口契约 §21.3 已容 `program`；VM 落地时是**纯加法**。
- 别混三件事：演出 Timeline（计划内，允许）｜敌人发射模式 Timeline/协程（**否决**）｜弹幕运动流 VM（第三类，就是 L）。

### 21.7 分步与验收

| 步 | 内容 | 可见成果 |
|---|---|---|
| **S4a** | 行为管道 + `world_accel` + `BulletData.accel` + `gravity` 端口 | 杂兵重力 / 世界加速弹不再走直线 |
| **S4b** | `homing`（用现成 `WorldQuery`） | 灵梦 opt1 会追敌 |
| **S4c** | 桥接内容行为：`bounce` / 散圈 / 顶边 re_fire / marisa 渐隐 | 非符1 反弹、中boss非符散圈、激光会消失 |
| **S4d** | `bomb` + `out_grace` + 出生雾 + 自机弹记忆变红 | X 键与收尾项 |

每步独立可试玩（F2 切内核）、可回退、单独提交。

### 21.8 S4a 落地（2026-09-11，已完成）

- 桥接 `scripts/kernel_bridge/behavior/world_accel_behavior.gd`：世界方向匀加速，只改 velocity（位置由系统积分）。
- `KernelBulletBackend`：`setup_behaviors()`（注册 `accel`/`curve`/`laser_follow`/`avoid_player`/`world_accel`，优先级 **-5**）、`_port_for()`（duck-typed `kernel_port()`，按 `Script×params` 缓存）、`shoot()` 端口解析（`move` 归一，无端口计未映射）。
- `BulletManager._enable_kernel()`：幂等装配行为管道，并刷新自机引用（`is_instance_valid` 守卫，防 freed player 传参会崩）。
- 内容端口：`gravity_bullet.gd.kernel_port()` → `world_accel`；`BulletData.accel` 直接 `world_accel`。
- 验收：新 `test_kernel_behavior`（5） + `test_kernel_swap` 管道用例；全量 **61 套 / 312 测试 / 3269 断言全绿**。

### 21.9 S4b 落地（2026-09-11，已完成）

- 桥接 `scripts/kernel_bridge/behavior/homing_behavior.gd`：移植旧 `move_homing.gd`；每帧转向限制 + 速度爬升 + 持续时长，**只 set_velocity**。
- 目标查询用现成 `WorldQuery.get_enemies()`；「跳时符 / 未开战 Boss」放桥接层（引用宿主 `Boss` / `PhaseData`，内核不碰）。
- `move_homing.gd.kernel_port()` → `homing` + 6 参数。
- `setup_behaviors()` 改为**可重复注入** `WorldQuery` provider（支持测试 / 换关）。
- 测试夹具 `test/fixtures/no_port_behavior.gd`：把「未映射计数」用例与 S4 进度解耦。
- 验收：`test_kernel_behavior` +2（有敌偏转 / 无敌不偏，且速度按 `lerp` 爬升）；全量 **61 套 / 314 测试 / 3274 断言全绿**。
- 语义备注：旧 `_apply_homing` 里的 `speed_mult/alignment` 随后被 `normalize()*current_speed` 覆盖——**死代码**，桥接未复刻。

### 21.10 S4c-1 落地：`radial_accel_bullet`（顶边 re_fire 试点）（2026-09-11，已完成）

- 新桥接 `KernelBehaviorHost`（延后动作队列）：内核契约禁止行为循环中途增删行，故行为 `request_despawn` + 入队，循环后由 `KernelBulletBackend._physics_process`（**-4**）`flush()`。
- 新桥接 `RadialAccelBehavior`：沿初方向加速 + 碰 `FIELD_TOP` 换成向下弹（模板由内容提供）。
- `radial_accel_bullet.gd.kernel_port()` → `radial_accel`；`spawn_data`（米弹 / 紫 / blend）+ sfx key 都在**内容侧**。
- 优先级链补全：内核积分 **-10** → 行为 **-5** → 延后 flush **-4** → 宿主碰撞 **0**。
- 验收：`test_kernel_behavior` +2；全量 **61 套 / 316 测试 / 3279 断言全绿**。

### 21.11 S4c-1 修复：替换弹贴图丢失（2026-09-11，已完成）

**试玩现象**：内核路径下 `radial_accel` 到顶边不换弹（看不到向下的弹），但端口/行为诊断打印都正常。

**定位**：打印证明「映射 + 顶边换弹」都发生 → 问题在**入队之后**。补断言发现 **替换弹 `texture_for_index(ti) == null`**，再定位到 **`BulletData.duplicate()` 会丢 `texture`（Resource 字段）** → 渲染桥 `_sync_kernel` 对 `tex == null` 的弹直接 `continue` → **弹在物理上存在，但完全不画**。

**修法**：

- 内容 `kernel_port()` 用 **`spawn_factory: Callable`**（每次调用返回**新** `BulletData`）替代「共享模板 + `duplicate()`」。
- `KernelBulletBackend` **保活**端口探测实例（`_port_probes`）——端口里的 Callable 绑在探测实例上，释放会让回调失效。
- 行为改 `factory.call()`。

**教训**：`Resource.duplicate()` 对 `texture` 这类 Resource 字段不可靠（本次实测丢）；跨「模板」复用一律走**工厂**，别 duplicate。**「弹在但看不见」的第一嫌疑 = 贴图 / 分组键**，先查 `texture_for_index`。

**验收**：新增工厂测试（每次新对象 + 贴图不丢）+ 替换弹贴图断言；全量 **61 套 / 319 测试 / 3289 断言全绿**。

### 21.12 S4c-2 落地：`bounce_bullet`（非符1 反弹弹）（2026-09-11，已完成）

- 桥接 `BounceBehavior`：沿飞行方向加速；碰**左/右/上**框（下墙穿出）→ 位置夹回框边 → 朝 `GameState.get_boss()`（无 Boss 退化向下）转 `bounce_angle` → 工厂造替换弹 + `kira` 音效 + `request_despawn`。
- `bounce_bullet.gd.kernel_port()` → `bounce`；`spawn_factory` = 米弹 / GOLD / blend（与旧 `_re_fire` 1:1）；`spawn_speed` 可覆盖。
- 测试：无 Boss 碰左框 → 向下弹；沿飞行方向加速（未碰框不换弹）。
- 验收：`test_kernel_behavior` +2；全量 **61 套 / 321 测试 / 3296 断言全绿**。
- 已知：旧脚本的 `spawn_tex` / `spawn_color` 是**死变量**（`_re_fire` 硬编码米弹 / GOLD）——照旧不复刻。

### 21.13 S4c-3 落地：`non_mid01_bullet`（中boss非符弹丸）（2026-09-11，已完成）

- 桥接 `NonMidFleeBehavior`：TRAVEL → 自机进入 `player_proximity`（默认 150）→ FLEE（沿远离自机方向）；FLEE 期每 3 帧问内容 `on_flee_burst(pos, boss_pos, has_boss, host)`，返回 true → `request_despawn`。
- **难度 / RNG / 散圈形状全留内容**：`non_mid01_bullet.kernel_port()` 提供 `on_flee_burst` 回调；`diff_pick`（= `arr[GameState.selected_difficulty]`）与 `RNG` 在内容侧，桥接只传 `boss_pos / has_boss / host`。
- **散圈走延后队列**：内容 `_kernel_spread`（内核版 shoot_spread）只 `host.queue_spawn`，避免行为循环中途 spawn。
- 测试：TRAVEL→FLEE 转向；内容回调近 Boss 入队散圈（flush 后 pool 非空）。
- 验收：`test_kernel_behavior` +2；全量 **61 套 / 323 测试 / 3302 断言全绿**。

### 21.14 S4c-4 落地：`marisa_laser_follow`（漂移 + 整批渐隐）（2026-09-11，已完成）

- **漂移**：内核现成 `LaserFollowBehavior`；内容 `marisa_laser_follow.kernel_port()` → `move=&"laser_follow"`，params = `anchor_id / anchor_offset / drift_speed / angle`。`cs_marisa` 改为**发射前**把角度/锚点写进 `b.params`（旧池路径照旧配 `extra`）。
- **渐隐**：新桥接 `MarisaLaserFade`（对应重建版 `LaserShot`）——按住射击 = `set_render_fade(LASER, 1)`；松手 / focus = 每帧递减到 0 → 清掉所有 `kind==LASER` 行。渲染桥 `_sync_kernel` 现按 `bt.kind` 乘 `get_render_fade`。
- **Kind 标记**：`shoot()` 见 `move==&"laser_follow"` 时给该 `BulletType.kind = LASER`（激光段贴图唯一，共享弹型无副作用）。
- 测试：端口映射 + LASER kind + 松手渐隐到 0 并清行。
- 验收：`test_kernel_behavior` +1；全量 **61 套 / 324 测试 / 3306 断言全绿**。
- 已知：渐隐是**整批**（按 Kind），非逐弹 alpha——与重建版一致；逐弹 alpha 需内核 `set_color`，按 A 方案不做。

### 21.15 S4c-4 修复：子机锚点必须用 `global_position`（2026-09-11，已完成）

**试玩现象**：魔理沙激光不跟随子机，跑到屏幕另一侧。

**根因**：`cs_player._sync_options` 把子机挂成**玩家的兄弟节点**（`leader.get_parent().add_child(opt)`），`opt.position` 相对 World；内核 `LaserFollowBehavior` 读 `node.position`（假设子机是玩家的子节点）→ `anchor = 玩家世界位 + 子机世界位`，**偏移翻倍**。

**修法**：新增桥接 `MarisaLaserBehavior`（`global_position` 语义，与旧实现一致），内容端口改 `move=&"marisa_laser"`；内核 `LaserFollowBehavior` 保留但宿主不用。
**顺带**：端口成员改名 `port_*`，避免与旧 lambda 的局部 `drift_speed / drift_angle` 冲突（编辑器 `SHADOWED_VARIABLE`）。

**验收**：新增锚点断言（x 贴子机世界位，非翻倍）；全量 **61 套 / 325 测试 / 3308 断言全绿**。

### 21.16 S4d-1 落地：自机弹记忆变红（2026-09-11，已完成）

- `KernelBulletBackend.shoot`：PLAYER 弹在 `GameState.memory_value < 50` 时把 tint 往 `Color.RED` lerp `remap(mem,0,50,1,0)*0.5`（旧 `Bullet.bind` 同式，**spawn 时定一次**）。
- 验收：`test_kernel_behavior` +2（mem=0 偏红 / mem=100 原色）；全量 **61 套 / 327 测试 / 3310 断言全绿**。

### 21.17 S4d 剩余：bomb 架构决策（2026-09-11，待定）

`bomb_behavior` 需要：绕自机扩张 → 追踪 → 爆炸（清弹 + 伤害 + 视觉）；且 `BulletData.bomb().out_grace = 9999`（防轨道越界被内核 cull 剔除）。内核 cull 是按 `cull_rect + margin` **统一**判定，A 方案（内核零改动）下**没有 per-type out_grace**。两条路：

- **A 内核行为 + cull 守卫**：bomb 留在内核池；桥接临时放大 `cull_margin`。统一 SoA，但 `cull_margin` 是全局 hack，计数 / 清理易漏。
- **B 宿主节点 bomb（推荐）**：bridge `KernelBomb` Node2D 自带 Sprite 渲染、不走内核池；天然无 cull / out_grace / kind 问题，清弹 / 伤害 / 视觉都是宿主动作。代价：bomb 不在 SoA（8 个实例无所谓），行为逻辑在桥接重复一份。

→ 待用户选。

### 21.18 S4d-2 落地：bomb 宿主节点（B 方案）（2026-09-11，已完成）

- 新桥接 `KernelBomb`（Node2D + 自带 Sprite）：1:1 移植 `bomb_behavior.gd`（绕自机扩张 → 持有 → 追踪 → 爆炸）。爆炸 = 清弹（`start_death_clear`）+ 范围伤害 + 视觉。
- `BulletManager.shoot_bomb_bullet` 内核分支改 `_kernel.spawn_bomb()`；`clear_all` / `clear_bullets` 调 `_kernel.clear_bombs()`。
- **为什么不在内核池**：bomb 需要 `out_grace`（轨道越界不被内核 cull 剔），而 A 方案下内核 cull 统一、无 per-type grace；bomb 只有 8 颗、生命周期短、宿主动作多 → 宿主节点最干净。
- 验收：`test_kernel_swap` +1（bomb 返回宿主节点且不进内核池 / 读 params）；全量 **61 套 / 328 测试 / 3314 断言全绿**。

### 21.19 `out_grace`（出生保护）与出生雾：暂缓，留给 GDExtension（2026-09-11，决定）

- **`out_grace`**：内核 cull 统一（`cull_rect + margin`），A 方案下无 per-type grace。stage01 + 玩家路径**当前不需要**（只有 stage03B 探测弹用，本轮范围外）；bomb 走宿主节点后也不需要。**决定**：暂缓，将来作为弹幕 / 弹型的**属性**接入（正好是 GDExtension 的数据属性之一）。
- **出生雾**：`spawn_fog` 只是「弹出生时被雾遮一下」的视觉；内核路径现在立即显示。**决定**：暂缓（低级视觉差）。

### 21.20 S4d-3：bomb 弹丸持续清弹（2026-09-11，已完成）

- 试玩反馈：bomb 原来只在**爆炸那一下**清；期望**每颗 bomb 弹丸自己周围持续清**（不是以自机为中心的圈）。
- 新增 `BulletManager.clear_enemy_bullets_in_circle(center, radius)`（双后端：内核 `sweep_enemy_bullets` / 旧池逐弹 `return_bullet` + 消散特效）。
- `KernelBomb` / `bomb_behavior.gd` 每帧围绕自己调一次，`clear_radius` 默认 **90**（可 `params` 覆盖），**不节流**。
- 验收：`test_kernel_swap` +1（bomb 周围敌弹被清）；全量 **61 套 / 329 测试 / 3316 断言全绿**。

















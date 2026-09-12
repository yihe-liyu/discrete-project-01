# Godot 最佳实践日志（BEST PRACTICES LOG）

> 本文件**随意长**：记录"为什么这样改 / 当时学到什么 / 踩过的坑"。
> 与 BEST_PRACTICES_BASELINE.md（只反映当前状态）分工：**状态更新去 baseline，心得记录来 log。**

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

### 2026-09-11 — W4b-2b：资源消费者直读 PlayerResources（经 refs.player）

- **目标**：把单局资源读取从 `GameState` 转发推进到 `Player.resources`（方案 A：Player 持有，消费者经注册表/注入读），过渡期同一实例、行为等价。
- **做法**：`EntityRegistry.get_player_resources()`（安全访问器）；内核桥接 `_player_res()` 取它；`cs_player` 用 `leader.get("resources")`；`item` 经 `ItemPool.refs` 注入；`game_ui.resources` 由 `GameScene` 注入；`boss` 增 `registry`（`add_enemy_to_scene` 注入）并用 `_refs()` 取资源/自机；`stage_runtime` 用 `refs.get_player_resources()` 取分数。
- **对照旧项目**：旧资源散在 `GameState`，实体/桥接/UI 全走全局读写；现在统一经「自机持有的 `PlayerResources`」。
- **度量**：`grep -rIl "\bGameState\b" scripts` **35 → 31 文件**（引用 159 → 122），清零：`item/item.gd` / `kernel_bridge/kernel_bullet_physics.gd` / `kernel_bridge/kernel_bullet_backend.gd` / `coroutine/player/base/cs_player.gd`。
- **验收**：`check_syntax` 191/0；全量 **56 套 / 311 测试 / 3212 断言全绿**；orphans 12。
- **踩坑**：`item.gd` 把 `var player := GameState.player` 改成无类型后，`var to_player := ...` / `var dir := ...` 推不出类型 → 必须显式标注 `Vector2`（Godot 「Cannot infer the type」是 Parse Error，会让依赖脚本编译失败）。
### 2026-09-11 — W4b-3b：refs 深注入内核弹幕路径（BulletManager / 桥接 / 激光 / 工作台）

- **目标**：把「自机 / 敌机 / Boss」的读取从 `GameState` 门面推进到注入的 `EntityRegistry`，覆盖内核弹幕后端、碰撞/清弹、桥接行为、激光与工作台覆盖层。
- **做法**：`BulletManager.inject_world_refs(refs)`（组合根调用）→ 传播给 `KernelBulletBackend` / `KernelBulletPhysics` / `LaserEngine`；`KernelBulletBackend.spawn_bomb` 把 `refs` 传给 `KernelBomb`；桥接行为经 `KernelBehaviorHost.get_boss()`（`backend.refs`）；`HitboxOverlay` 由工作台注入 `refs`。无 `refs` 时回退 `EntityRegistry.current`。
- **对照旧项目**：桥接层原来直呼 `GameState.player/get_active_enemies/get_boss`；现在统一经注入的注册表。
- **踩坑（承接 W4b-3a）**：`for enemy: Node2D in <含已释放实例的数组>` 与 `var p: Player = refs.player` 会在**赋值/迭代时**抛 `Trying to assign invalid previously freed instance`——必须先 `is_instance_valid` 再赋给类型化变量；迭代用无类型 `for enemy in ...` + 逐个 `is_instance_valid`。
- **度量**：`grep -rIl "\bGameState\b" scripts` **41 → 35 文件**（引用 172 → 159），清零文件：`autoload/bullet_manager.gd` / `laser/laser_engine.gd` / `kernel_bridge/kernel_bomb.gd` / `kernel_bridge/behavior/bounce_behavior.gd` / `kernel_bridge/behavior/non_mid_flee_behavior.gd` / `workbench/hitbox_overlay.gd`。
- **验收**：`check_syntax` 191/0；全量 **56 套 / 311 测试 / 3212 断言全绿**；orphans 12。
- **顺带**：`bench_base.build_world` 先 `ensure_stage_runtime()`（子弹台原来没有关卡运行时 → 幽灵/注册表注入会落空）。
### 2026-09-11 — W4b-3a：运行时引用抽成 EntityRegistry（StageRuntime 持有 + GameState 过渡门面）

- **目标**：把 `GameState` 的运行时引用（`player` / `active_enemies` / `get_boss`）搬出 god object，改为「组合根持有的 `EntityRegistry`」，为 W4b-4 瘦身 `GameState` 铺路。
- **为什么**：R18（`GameState` 是 god object）+ R2/R9（依赖向下注入，不读全局）。`GameState` 只该管存档/持久化；战场实体（自机 / 敌机 / Boss）是**每关世界**的状态，应随 `StageRuntime` 存亡。
- **对照旧项目**：旧 `GameState.active_enemies` 是全局数组，实体 `_ready` 自注册、`clear_enemies` 遍历 queue_free；现注册表由 `StageRuntime` 持有，`Enemy` 经注入的 `registry` 注册，`stop_stage` 调 `refs.clear()`。
- **做法（strangler）**：新 `scripts/stage/entity_registry.gd`（`class_name EntityRegistry extends RefCounted`：`player` / `enemies` / `register_enemy` / `get_boss` / `clear`）；`StageRuntime.refs` 持有并在 `_enter_tree` `GameState.bind_refs`；`GameState.player` / `active_enemies` / `get_active_enemies` / `get_boss` / `clear_enemies` 改为**转发门面**。已迁直接消费者：`Enemy`（注入 registry）、`PlayerService` / `BossService`（经 `StageContext.refs`）、`MoveHoming`；组合根（`GameScene._setup_player` / `bench_base.build_world` / `workbench._setup_world`）注入自机。
- **踩坑**：`EntityRegistry.player` 起初写成**无类型** Variant → 自机 free 后仍指向已释放实例，门面 getter 返回时报 `previously freed instance`（10 个用例失败）。改成内建 `Node2D` 类型后 Godot 自动置 null，getter 再加 `is_instance_valid` 兜底。教训：宿主实体引用**不要用无类型 Variant 保存**。
- **修复 2（同波，试玩发现）**：被击中不出反色圈——`start_spell_card` 自建 ctx **没设 `stage`**，练习模式 `player.ctx = boss.ctx` 于是拿不到 `miss_layer`；另给 `StageRuntime.current`（当前关卡 static 回退），`ctx.effects` 对无 `stage` 的共享 ctx（射击 / 子弹）也稳。
- **修复 1（同波，试玩发现）**：自机不能射击 / 子机消失——`Player._init_shoot_script` 自建一个**无 `stage`** 的 `StageContext`，而 `ctx.refs` 只从 `stage` 取 → 该 ctx 解析不到自机，`ctx.player.get_player()` 恒 null。加 `EntityRegistry.current`（当前世界 `static var` 回退，R8）+ `StageContext.refs` 优先 `stage`、否则回退 `current`。教训：注入型上下文要把「无 stage 的共享 ctx（射击 / 子弹共享 ctx）」纳进解析链，否则静默失效。
- **度量**：`grep -rIl "\bGameState\b" scripts` **46 → 41 文件**（`enemy` / `player_service` / `boss_service` / `move_homing` / `ghost_player` 摘除），引用 180 → 172。
- **验收**：`test/test_entity_registry.gd`（4 用例）；`check_syntax` 191 脚本 / 0 失败；全量 **56 套 / 307 测试 / 3203 断言全绿**；orphans 12。
- **后续（W4b-3b）**：把 `refs` 注入 `BulletManager` / `KernelBulletBackend` / `KernelBulletPhysics` / `KernelBomb` / 桥接行为 / `LaserEngine`，去掉内核弹幕路径对门面的读取。
### 2026-09-11 — W4a-2 修复：魔理沙激光贴图不旋转

- **现象**：内核唯一后端下，魔理沙非 focus 激光段的贴图不随漂移方向旋转。
- **根因**：内核 `MarisaLaserBehavior` 只 `system.set_position()`，**没设 `velocity`**；渲染桥 `_sync_kernel` 按 `BulletType.rotation_for(velocity)` 算贴图朝向，而 `rotation_for` 在 `velocity == ZERO` 时返回 `0.0` → 贴图永远轴对齐。旧 `marisa_laser_follow._tick` 有 `target.velocity = dir`，内核版漏了。
- **修复**：`marisa_laser_behavior.gd` 补 `system.set_velocity(bullet_id, dir)`；回归断言 `test_marisa_laser_anchors_to_global_position`（velocity != 0 且 angle == -PI/2）。
- **教训**：移植行为时，**凡是渲染/特效依赖的字段（velocity/rotation）都要一起设**——旧路径可能靠 `Bullet.bind` 顺带设了，内核 `set_position` 不会。
- **验收**：全量 **55 套 / 303 测试 / 3193 断言全绿**。

### 2026-09-11 — W4b-2a：Player 注入 PlayerResources（资源引用清零）

- **目标**：把 `PlayerResources` 注入 `Player`，让玩家逻辑直接持有资源真源（为后续消费者迁移铺路）。
- **做法**：`Player.resources`（`_ready` 过渡期取 `GameState.resources` 同一实例）；`player.gd` 的 `use_bomb` / `memory_value` / `reduce_memory` / `add_memory` / `lose_life` 改走 `resources`。
- **验收**：全量 **55 套 / 303 测试 / 3191 断言全绿**。
- **说明**：`GameState` 仍是 owner（组合根注入统一实例）；全量去除 `GameState` 引用需按文件逐个迁移（UI/道具/Boss/桥接/菜单），是后续小步。

### 2026-09-11 — W4b-1：GameState 资源抽成 PlayerResources（转发，零改动）

- **目标**：`GameState` 的单局资源状态（火力/分数/擦弹/残机/雷/碎片/记忆）抽成单一 owner（R18），为后续"消费者直接注入"铺路。
- **为什么**：R18（上帝对象要拆）+ R8（共享状态用 `class_name`）。`GameState` 405 行、186 引用，直接大改风险高——先用**转发属性**把状态搬到 `PlayerResources`，调用点零改动、行为不变。
- **对照旧项目**：旧资源字段散在 `GameState` 里、方法直接改字段；现状态归 `PlayerResources`，对外入口收敛 + `changed` 信号（R7）。
- **新落点**：`scripts/player/player_resources.gd`；`GameState.resources` + 9 个转发属性 + 方法委托；`MEMORY_*` 常量单一来源。
- **验收**：`test/test_player_resources.gd`（4）；全量 **55 套 / 303 测试 / 3191 断言全绿**。
- **注意**：转发是**过渡态**——下一步（W4b-2）把 Player/UI/kernel 改成直接持 `PlayerResources`，再去掉转发属性。
### 2026-09-11 — W4a-2：删旧弹幕池（内核唯一后端）

- **目标**：删除整个旧弹幕子系统，内核成为唯一后端，去掉 strangler 开关（W4a 收口）。
- **为什么**：R9（去单例/开关残留）+ R19（不留死代码）+ 收敛内核合流。
- **对照旧项目**：旧 `BulletManager` 是"双后端门面"（旧 `Bullet` 节点池 ↔ 内核 SoA）。W4a-1 转正后旧池已是回滚备份，试玩确认无回归后即可整体删除。
- **删除**：`bullet_pool.gd` / `bullet_physics.gd` / `bullet.gd` / `spatial_hash.gd` / `bomb_behavior.gd` / `bullet_fog.gd` / `bullet.tscn` + `use_kernel`/F2/`active_bullets`/`use_multi_mech` 全部旧分支。
- **收窄**：`DeathClear` 改调注入的内核扫掠；`BulletMultiMesh` 删 `_sync_nodes`；`LaserEngine` 的 `BulletPhysics` 依赖改为注入 `on_graze` Callable；`player.gd` 去 `bomb_behavior`。
- **验收**：`check_syntax` 190 脚本 / 0 失败；全量 54 套 / 299 测试 / 3181 断言全绿。
- **教训/注意**：`active_bullets` 是旧池专属 API，删除时所有统计要换 `active_count()`、调试叠层要换内核行遍历（`debug_drawer`/`hitbox_overlay` 已改）。
### 2026-09-11 — W4a-1 修复：内核转正暴露"自机引用未刷新"（道中非符逃跑弹失效）

- **现象**：内核转正为默认后，中boss非符的 `non_mid_flee` 逃跑弹不生效（弹丸直线飞、不转向）。
- **根因**：`use_kernel = false` 时 `_enable_kernel()` 是**游戏内按 F2** 才跑，那时自机已存在；转正后它在 autoload `_ready` 跑——**自机尚未生成**（`GameState.player == null`），`BehaviorContext.setup(null, ...)` 把自机缓存成 null，之后再没刷新 → `ctx.get_player_position()` 恒 `Vector2.ZERO` → `non_mid_flee`/`homing` 的"接近自机"判定永不成立。
- **修复**：新增公开 `BulletManager.refresh_kernel_player()`；组合根在自机就绪后调用——`GameScene._setup_player()`、`workbench._setup_world()`、`bench_base.build_world()`。
- **回归测试**：`test_composition_root:test_game_scene_refreshes_kernel_player`（断言 `behavior_ctx.get_player_position()` == 场景自机位置）。
- **教训**：strangler 的"翻默认"会把**原本只在手动开关时才满足的前置条件**（这里是"自机已存在"）暴露成 bug。翻默认后必须跑**真实场景**冒烟——单测（显式 `setup_behaviors(player)`）覆盖不到 autoload 早于场景的时序。

### 2026-09-11 — W4a-1：内核弹幕后端转正（默认 true，旧池回滚）

- **目标**：把 Track A 装好的内核从"开关后备选"变成**默认**，完成 strangler 的"翻开关"步（W4a-1；W4a-2 才删旧池）。
- **为什么**：`use_kernel` 的管道完全封闭在 `BulletManager` + `BulletMultiMesh._sync_kernel` + `test_kernel_swap`，翻默认是低成本的收敛验证；未映射内容的回归风险靠"保留旧池 + F2 回滚 + 试玩"兜住。
- **对照旧项目**：旧默认是旧节点池。若直接删旧池、未映射内容（`kernel_port()` 只有 7 处 vs 17 个内容 CoroutineScript 子类）会退化成直线；故先翻默认、后删。
- **新落点**：`bullet_manager.gd:use_kernel = true`；新增 `active_count()`（双后端统一计数）；旧池专属测试显式 `set_use_kernel(false)`（语义上它们本就测旧路）；bench/工作台统计迁 `active_count()`。
- **验收**：kernel 默认下全量 **63 套 / 337 测试 / 3341 断言全绿**。
- **坑预警**：`active_bullets` 是**旧池专属** API，内核路径恒空——统计/断言必须走 `active_count()`；`hitbox_overlay`/`debug_drawer` 的逐弹遍历在旧池删掉后需补内核遍历。
### 2026-09-11 — W3b：StageManager 去 autoload（StageRuntime 场景节点 + ctx.stage）

- **目标**：autoload 7 → 6（轨道 B / §12 W3b）。
- **为什么**：R9（autoload 只放真全局）+ R2（`add_enemy_to_scene` 全树找 `World`）+ R21（World 下声明式节点）。
- **对照旧项目**：旧 `StageManager` 是 autoload，`add_enemy_to_scene` 里 `get_tree().current_scene.get_node_or_null("World")` 全树找父级——依赖"当前场景恰好有 World"的隐式约定。新 `StageRuntime` 由组合根注入 `world`，不再找。
- **做法（strangler）**：W3b-1 先抽 `StageRuntime` + 薄门面（调用点零改动，commit `c3b4758`）；W3b-2 迁调用点（`ctx.stage`）并删 autoload。
- **新落点**：`scripts/stage/stage_runtime.gd`；`StageContext.stage`；`EnemyData.spawn`/`StageDirector` 走 `ctx.stage`；`game_scene.tscn`/`workbench.tscn` 的 `World` 下声明节点；组合台 `bench_base.ensure_stage_runtime()` 自备，`bookmark_panel.stage_runtime` 由 Workbench 注入。
- **验收**：autoload **7→6**；全量 **63 套 / 337 测试 / 3341 断言全绿**。
- **踩坑①**：`workbench._load_stage()` 的"清 World 残留"循环把新放进 `World` 的 `StageRuntime` 一起 `queue_free` → `_stage_runtime` 变 freed，触发 `previously freed`。**把结构性服务节点放 World 下时，任何"清 World"循环都要排除它。**
- **踩坑②**：`add_enemy_to_scene` 里 `world if is_instance_valid(world) else get_tree().root` → `Node2D` vs `Window` 两分支不兼容，编辑器报 `INCOMPATIBLE_TERNARY`（**warning，headless 测试不拦**）。改显式 `if/else`。**教训：大改后要跑 `godot --headless --editor --quit` 并看输出——之前把 editor 输出丢 `/dev/null` 才漏掉它。**
### 2026-09-11 — W3a：AssetRegistry 去 autoload（class_name 静态表）

- **目标**：autoload 8 → 7（轨道 B / §12 W3a）。
- **为什么**：R9（autoload 只放真全局）+ R8（共享数据/功能用 `class_name`/`static`）。`AssetRegistry` 是一张**只读资源表**，没有节点身份、没有信号、没有生命周期——正是 R8 的适用对象。
- **对照旧项目**：旧作为 autoload 实例，好处只是 `AssetRegistry.xxx` 访问，但代价是一个常驻 Node + 一次 autoload 注册。改 `class_name` 静态表后**访问语法完全一致**，调用点 0 改动。
- **新落点**：`scripts/asset_registry.gd`（`class_name AssetRegistry`）；`_bgm_cache` 改 `static var`，4 个方法改 `static func`。
- **验收**：`test/test_asset_registry.gd` + `test_composition_root.gd:test_removed_autoloads_stay_removed`；全量 **63 套 / 336 测试 / 3337 断言全绿**。
- **暂缓**：`bullet_configs`→`data/atlas/*.tres`（R17）随 S13 图集做。

### 2026-09-11 — W2：StageObjects 去 autoload / HitEffectPool → FxLayer 注入

- **目标**：再降两个"不是真全局"的 autoload，autoload 12 → 8（轨道 B / `NEW_KERNEL_REFACTOR_PLAN.md` §12 W2）。
- **为什么**：R9（autoload 只放真全局）+ R2（依赖向下注入）+ 全树找父级禁令。
- **对照旧项目**：
  - 旧 `HitEffectPool` 作为 autoload，`play()` 里 `Engine.get_main_loop().current_scene.get_node_or_null("World")` **全树找父级**——违反 R2/R9，且依赖"当前场景恰好有个 `World` 子节点"的隐式约定。新 `FxLayer` 由组合根创建、挂 `World` 下、注入到需要它的地方，`play()` 不再找父级。
  - 旧 `StageObjects` 作为 autoload 跨关存活——但它的语义本来就是"帧级作用域"（load_stage 注册、stop 清空）。改成 `StageContext.objects` 后生命周期与关卡对齐，不再有跨关残留。
- **新落点**：
  - `scripts/coroutine/services/stage_objects.gd`：`class_name StageObjects extends RefCounted`；`stage_context.gd:objects` 懒建；`stage_director.gd` 注册/清理；`boss_handle.gd` 持注册表（`_init` 第 4 参，默认 null → 兼容纯逻辑测试）。
  - `scripts/effect/fx_layer.gd`：`class_name FxLayer extends Node2D`；节点在 **`game_scene.tscn` 的 `World` 下声明**（R21 声明式建树，与 `ItemPool` 同规格），`game_scene.gd:_ready` 只做注入（`BulletManager.inject_fx_layer()` + `StageManager.fx_layer`）；`effect_service.gd:play_hit_effect` 走注入的 `fx_layer`。
  - 调用点（`bullet_physics.gd` / `death_clear.gd` / `kernel_bullet_physics.gd` / `bullet_manager.gd`）全部改为注入字段 + `fx == null` 静默守卫（单测/无场景安全）。
- **验收**：`test_composition_root.gd` 增 `test_game_scene_creates_and_injects_fx_layer`；`test_stage_director.gd` 改纯逻辑；新增 `test_fx_layer.gd`（3 用例，池化语义）；全量 GUT **62 套 / 333 测试 / 3327 断言全绿**。
- **踩坑（基线）**：初版 `FxLayer` 在 `game_scene.gd` 里 `FxLayer.new()+add_child` 命令式建树，违反 **R21**（`BEST_PRACTICES_BASELINE.md`）——已改为在 `game_scene.tscn` 的 `World` 下声明；同时把 W1 遗留的 `MissEffectManager`（同样 `new()+add_child`）一并改为 `Main` 下声明式节点。教训：**改前先通读基线**，别只 grep 用到的那一行。
- **踩坑（缓存）**：新增 `class_name` 再次踩缓存——headless 直接报 `Could not find type "StageObjects" / "FxLayer"`，连锁 81 个假失败（`Scripts 61→59`）。跑 `godot --headless --editor --quit` 重建 `.godot/global_script_class_cache.cfg` 即恢复（W1 用 `--import`，本次 `--editor --quit` 同样有效）。
- **边界**：`FxLayer` 是**宿主侧**节点，不是内核服务；`scripts/kernel/**` 零引用。`scripts/kernel_bridge/**` 桥接层允许持注入的 `fx`。
### 2026-09-11 — W1：LayerConfig 去 autoload / MissEffectManager 场景节点化

- **目标**：把两个"不是真全局"的 autoload 降级，autoload 12 → 10（轨道 B / `NEW_KERNEL_REFACTOR_PLAN.md` §12 W1）。
- **为什么**：R9（autoload 只放真全局）+ R8（共享功能用 `class_name` / `static`）+ R2（依赖向下注入）。
- **对照旧项目**：
  - 旧 `LayerConfig` 作为 autoload 只为提供常量——每个 `LayerConfig.XXX` 都要经一个常驻 Node 实例取值；纯常量本可用静态类。
  - 旧 `MissEffectManager` 作为 autoload CanvasLayer，被 `EffectService` 与 `BulletManager.clear_all()` 全局直呼——弹幕门面被迫知道一个 UI 特效存在，是典型 R9 违规。
- **新落点**：
  - `scripts/layer_config.gd`：`class_name LayerConfig`，去掉 `extends Node`。
  - `scripts/effect/miss_effect_manager.gd`：`class_name MissEffectManager`。
  - 注入链：`game_scene.gd:_ready` → `StageManager.miss_layer` → `stage_context.gd:effects` → `effect_service.gd:miss_layer`（空则静默跳过）。
  - `bullet_manager.gd` 删除 `MissEffectManager.clear_all()`。
- **验收**：`test/test_miss_effect.gd`（8 用例）+ `test/test_composition_root.gd`（组合根冒烟 1 用例）；全量 GUT **279/279**，3199 断言。
- **踩坑**：新增 `class_name` 后必须让 Godot 重建 `.godot/global_script_class_cache.cfg`（跑一次 `godot --headless --import`），否则 headless 报 `Identifier "LayerConfig" not declared`——不是代码错，是缓存没刷新。
- **顺带修**：`test_recent_mechanics.gd` 练习记录用例非幂等——历史遗留 `stage=99` 幽灵记录会让 `get_or_create` 命中旧值（实测 attempts=6/captures=3）继续累加造成假失败；已加起始清除并清掉本地 `.tres` 幽灵项。

### 2026-09-11 — S3d：死亡清弹接内核（后端分派收回 BulletManager）

- **目标**：修试玩唯一发现的行为缺失——内核路径下 Boss 击破 / Miss 的展开清弹圈不清弹。
- **为什么**：`DeathClear` 直接摸 `_pool.active_bullets` 是后端泄漏；内核路径下旧池恒空。正确落点是让 `DeathClear` 与后端解耦，双后端分派收回到 `BulletManager`（S3a 起约定）。
- **对照旧项目**：旧实现把“扩张半径”和“清旧池”耦合在一个类里。若整个搬到内核，要么复制一份清弹圈逻辑，要么让 `DeathClear` 认识两个池（两处都要改）。本次只抽一个 `Callable` 注入点，旧循环**一行未改**。
- **新落点**：
  - `scripts/autoload/bullet/death_clear.gd`：`setup()` 增 `p_kernel_sweep`；清弹步骤改 `if not handled:` 包旧循环。
  - `scripts/kernel_bridge/kernel_bullet_physics.gd:sweep_enemy_bullets()`：内核逐弹扫掠（颜色 + 消散特效 + on_clear）。
  - `scripts/autoload/bullet_manager.gd:_kernel_sweep_death_clear()`：按 `use_kernel` 分派。
- **验收**：全量 GUT **60 套 / 305 测试 / 3254 断言全绿**。
- **踩坑**：本想用内核现成 `cancel_bullets()` 驱动清弹圈，读实现后发现不合——(1) 它是一次性全清，死亡清弹是逐帧扩张；(2) 其消散特效发成内核纯特效行，而渲染桥只认 `BulletType` 行，画不出来。改回宿主逐弹扫掠 + `HitEffectPool`。

### 2026-09-11 — S4a：行为管道 + 内容端口契约

- **目标**：把内核 `Behavior` 注册表接到原项目——`use_kernel` 下 `coroutine_script` / `BulletData.accel` 不再一律直线。
- **为什么**：内核早有 `BehaviorProcessor` / `BehaviorContext` / `WorldQuery`，原项目从没装配。端口用 duck-typed `kernel_port()`，**映射留在 `data/**`**，`scripts/**` 不出现内容路径（命名边界）。
- **对照旧项目**：旧是**每弹一个 `CoroutineScript` 协程**；内核是**共享 `Behavior` 实例 + 行内状态**。移植后行为**只 `set_velocity`**，位置由系统积分——自己再 `+= pos` 会双倍。
- **新落点**：`scripts/kernel_bridge/behavior/world_accel_behavior.gd`；`kernel_bullet_backend.gd` 的 `setup_behaviors` / `_port_for` / `shoot`；`bullet_manager.gd:_enable_kernel` 装配；`data/stages/stage01/bullet/gravity_bullet.gd:kernel_port()`。
- **验收**：全量 GUT **61 套 / 312 测试 / 3269 断言全绿**（新 `test_kernel_behavior` 5 用例 + swap 管道用例）。
- **踩坑**：① `_enable_kernel` 原来 `if _kernel != null: return` 早退——首次 enable 若在 `setup_behaviors` 抛异常，后续 enable 全跳过 cull_rect / 行为装配，级联崩 4 个测试；改为「创建块 + 每次刷新行为管道」。② `GameState.player` 在 GUT 里常是上一测试的 **freed 引用**，直接传给 `Node2D` 形参会报 “previously freed”，必须 `is_instance_valid` 守卫。

### 2026-09-11 — S4b：`homing` 行为（灵梦 opt1）

- **目标**：`move_homing` 不再直线——内核路径下追最近敌人。
- **做法**：桥接 `HomingBehavior` 移植旧逻辑（转向限制 + `lerp(min_speed, top_speed, elapsed/accel_time)` + `homing_duration`）；目标查询走内核现成 `WorldQuery`，时符 / 未开战 Boss 的跳过放桥接层（引用宿主 `Boss`）。
- **顺带**：`setup_behaviors` 的 provider 改为**可重复注入**；新增 `test/fixtures/no_port_behavior.gd`，让「未映射计数」测试不再绑定具体内容行为（避免 S4 每步都要改测试）。
- **对照旧项目**：旧 `_apply_homing` 算的 `speed_mult/alignment` 紧接着被 `normalize() * current_speed` 覆盖——**死代码**，复刻反而增乱，故不抄。
- **验收**：全量 GUT **61 套 / 314 测试 / 3274 断言全绿**。

### 2026-09-11 — S4c-1：radial_accel + 延后动作队列

- **目标**：`radial_accel_bullet` 在内核路径下不再直线——沿初方向加速、碰顶边换成向下弹。
- **关键约束**：内核 `BehaviorProcessor` 明确「行为只标记待回收，回收在循环后统一执行」；`swap-with-last` 让循环中途 `despawn/spawn` 会搬行错位。所以不能像旧 `re_fire` 那样就地增删。
- **做法**：新增 `KernelBehaviorHost` 延后队列——行为 `request_despawn(id)` + `queue_spawn(data,pos,dir)`；`KernelBulletBackend._physics_process`（优先级 **-4**，行为 -5 之后、宿主碰撞 0 之前）`flush()`。
- **边界**：行为是桥接层（可引 `GameConfig` / `AssetRegistry` / `AudioManager`），但**替换弹模板 + sfx key 由内容 `kernel_port()` 提供**，`scripts/**` 不出现内容路径。
- **对照旧项目**：旧 `re_fire` 复用同一 `Bullet` 节点（省池 churn）；内核等价 = 回收旧行 + 新发一行（S3 已接受的近似）。模板 `duplicate()` 后才改 `velocity`，不污染缓存。
- **验收**：全量 GUT **61 套 / 316 测试 / 3279 断言全绿**。

### 2026-09-11 — S4c-1 修复：`duplicate()` 丢贴图 → 隐藏弹

- **现象**：内核路径 `radial_accel` 到顶不换弹（看不见向下弹），但端口 / 行为打印正常。
- **根因**：替换弹用 `BulletData.duplicate()` 从模板复制，**`texture` 被丢成 null**；渲染桥 `_sync_kernel` 遇 `tex == null` 直接跳过 → 弹在物理上存在、但完全不画。
- **修法**：内容端口改提供 **`spawn_factory: Callable`**（每次造新 `BulletData`）；后端**保活**探测实例（Callable 绑在它身上，释放即失效）。
- **教训**：`Resource.duplicate()` 对 Resource 字段（`texture`）不可靠；「弹在但看不见」先查贴图旁表。诊断顺序：先确认「行为有没有跑」，再查「跑完之后画没画」。
- **验收**：全量 GUT **61 套 / 319 测试 / 3289 断言全绿**。

### 2026-09-11 — S4c-2：`bounce` 反弹弹

- **目标**：非符1 的反弹弹在内核路径下也能碰框换向。
- **做法**：桥接 `BounceBehavior` 1:1 移植（沿飞行方向加速 + 左/右/上碰框夹回 + 朝 Boss 转 `bounce_angle` + 换直线弹 + 音效）。替换弹走 §21.11 的 `spawn_factory`。
- **边界**：Boss 取 `GameState.get_boss()`（宿主），落在桥接层；内核不碰。
- **对照旧项目**：旧 `spawn_tex` / `spawn_color` 是**死变量**（`_re_fire` 硬编码米弹 / GOLD）——不抄「看起来能配其实没用」的参数。
- **验收**：全量 GUT **61 套 / 321 测试 / 3296 断言全绿**。

### 2026-09-11 — S4c-3：`non_mid01` 弹丸（逃跑 + 散圈）

- **目标**：中boss非符的弹丸在内核路径下也能「靠近自机逃跑、靠近 Boss 散圈消失」。
- **做法**：桥接 `NonMidFleeBehavior` 负责状态机 + 距离检测；**内容相关决策（难度 `diff_pick`、RNG、散圈形状）通过 `on_flee_burst(pos, boss_pos, has_boss, host)` 回调留在 `data/**`**。桥接把 `GameState.get_boss()` 的 `boss_pos / has_boss` 与延后队列 `host` 传给回调。
- **难点**：散圈一次多发，且内核禁止行为循环中途 spawn → 内容 `_kernel_spread` 只 `host.queue_spawn`（内核版 shoot_spread）。
- **边界**：`diff_pick` 原来挂在 `ctx.diff`，这里实测它其实只读全局 `GameState.selected_difficulty`——内容探测实例可直接用，不必假装有 ctx。
- **验收**：全量 GUT **61 套 / 323 测试 / 3302 断言全绿**。

### 2026-09-11 — S4c-4：魔理沙激光（漂移 + 整批渐隐）

- **目标**：内核路径下魔理沙非 focus 激光段能跟着子机漂移、松手整体淡出。
- **漂移**：直接复用内核现成 `LaserFollowBehavior`；内容端口把 `cs_marisa` 的 `anchor_id / drift_speed / angle` 映射过去。
- **渐隐**：新增桥接 `MarisaLaserFade`（= 重建版 `LaserShot` 的极简版）：按住满亮、松手整批 `set_render_fade(LASER, α)` 到 0 后清行；渲染桥 `_sync_kernel` 按 `bt.kind` 应用 fade。
- **为什么整批而不是逐弹 alpha**：内核 SoA 没有 `set_color`，逐弹 alpha 要改内核；整批 fade 是内核本就提供的 `set_render_fade`（重建版同款设计），守住 A 方案「内核零改动」。
- **踩坑**：渐隐控制器起初在「淡完 → 松手仍成立」时又重启一轮「淡出→复位」，测试值停在中途；加 `_spawned` 门（只有生成过激光才启动渐隐）后正确。
- **验收**：全量 GUT **61 套 / 324 测试 / 3306 断言全绿**。

### 2026-09-11 — S4c-4 修复：子机锚点 `global_position`

- **现象**：魔理沙激光不跟子机，跑到屏幕边。
- **根因**：原项目子机是**玩家的兄弟节点**（`leader.get_parent().add_child(opt)`），`position` 相对 World；内核 `LaserFollowBehavior` 读 `node.position` 当作「玩家子节点偏移」→ `玩家 + 子机世界位` 翻倍。
- **修法**：桥接 `MarisaLaserBehavior` 用 `global_position`（旧语义），端口 `move=&"marisa_laser"`。
- **教训**：内核行为的**节点语义假设**（子节点 local）必须与宿主实际层级对齐，否则静默偏移——这类 bug 不报错，只画错。
- **顺带**：端口成员 `port_*` 命名，避开旧 lambda 局部变量 shadow 警告。
- **验收**：全量 GUT **61 套 / 325 测试 / 3308 断言全绿**。

### 2026-09-11 — S4d-1：自机弹记忆变红

- **做法**：旧 `Bullet.bind` 是在**绑定时**按 `memory_value` 把 `sprite.modulate` 往红 lerp 一次——不是每帧。内核桥接在 `shoot()` 里对 PLAYER 弹算同一个 tint 即可，**内核零改动**。
- **教训**：先读旧实现确认「一次性 vs 每帧」，能省掉一整套逐帧调制机制。
- **验收**：全量 GUT **61 套 / 327 测试 / 3310 断言全绿**。

### 2026-09-11 — S4d-2：bomb 宿主节点（B 方案）

- **决策**：bomb 不走内核池，改宿主节点 `KernelBomb`（Node2D）。理由：bomb 需要 `out_grace`（轨道越界不被剔除），而 A 方案下内核 cull 是统一的、没有 per-type grace；bomb 只 8 颗、宿主动作（清弹 / 伤害 / 视觉）多。
- **实现**：1:1 移植 `bomb_behavior.gd`；`shoot_bomb_bullet` 内核分支 → `_kernel.spawn_bomb`；清场路径 `clear_bombs`。
- **踩坑**：`Node2D` **没有** `velocity` 属性（那是旧 `Bullet` 的自定义字段）——宿主节点要自己声明。
- **`out_grace` 决定**：暂缓；将来作为弹幕 / 弹型**属性**接入（正好是 GDExtension 数据属性之一）。出生雾同理暂缓。
- **验收**：全量 GUT **61 套 / 328 测试 / 3314 断言全绿**。

### 2026-09-11 — S4d-3：bomb 弹丸持续清弹

- **反馈**：bomb 原来只在爆炸时清；改成**每颗 bomb 弹丸自己周围持续清**。
- **做法**：`BulletManager.clear_enemy_bullets_in_circle`（双后端：内核 `sweep_enemy_bullets` / 旧池逐弹 `return_bullet`）；`KernelBomb` / `bomb_behavior` 每帧围绕自己清，`clear_radius = 90`（可覆盖），不节流。
- **为什么这个设计**：清弹中心是 bomb 自己 → bomb 在轨道/飞行中把路径上的敌弹一路清掉，比「以自机为中心的圈」更符合反馈，也让绕圈有实际意义。
- **验收**：全量 GUT **61 套 / 329 测试 / 3316 断言全绿**。

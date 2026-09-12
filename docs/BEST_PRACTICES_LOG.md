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

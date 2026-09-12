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
- **踩坑**：本想用内核现成 `cancel_bullets()` 驱动清弹圈，读实现后发现不合——(1) 它是一次性全清，死亡清弹是逐帧扩张；(2) 其消散特效发成内核纯特效行，而渲染桥只认 `BulletType` 行，画不出来。改回宿主逐弹扫掠 + `HitEffectPool`。

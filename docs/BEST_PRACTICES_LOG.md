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

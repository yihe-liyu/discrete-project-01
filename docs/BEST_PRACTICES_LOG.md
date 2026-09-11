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

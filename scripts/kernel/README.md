# scripts/kernel — 弹幕内核（vendored 子系统）

> **来源**：从重建版项目 vendored（起点 tag `kernel-v1` / commit `238507a`；现跟随重建版 `main`）。
> **同步方式**：`bash tools/vendor_kernel.sh [--check]`（M0b）—— 复制上游 + 两处规范化 + 「内核 0 宿主引用」守卫。
> **禁止手改本目录**：改动会被下次 vendor 覆盖（K1/K7/A10 三次本地改名都因此漂移过，见 M0）；改内核请在**重建版**改。
> **单一真相**：当前约定 = 重建版是内核**开发环境**（bench + 46 套测试），本目录是 vendor 快照；内核定型后再宣布原项目为唯一之家、重建版归档。
> **本目录是"内核边界"**：只放可脱离宿主运行的弹幕机制，不放任何原项目实体 / UI / 内容。

## 边界规则（必须守）

`scripts/kernel/**` **禁止**引用原项目的：

- **autoload**：`BulletManager / RNG / AudioManager / GameEvents / GameManager`（W1–W3 后 `LayerConfig`/`AssetRegistry` 改 class_name、`MissEffectManager`/`StageObjects`/`HitEffectPool`/`StageManager` 改组合根注入/场景节点；W4 后旧的全局存档状态去 autoload → `SaveData`（static）+ `EntityRegistry` / `PlayerResources`）
- **实体 / UI 层类型**：`Boss / Enemy / Player / Item / BulletData / PhaseData / BossData / EnemyData / PlayerData / GameConfig`
- 任何指向 `res://scripts/...` 的 `preload` / `load` 路径

唯一允许的宿主外部依赖 = `LayerConfig`（仅供适配/渲染层用；内核本体目前 **0 引用**）。

**理由**：内核要能被任意宿主驱动（原项目 / 重建版 demo）。决策备忘 `DECISION_DANMAKU_ARCHITECTURE.md` §10.2 已实测「内核不认识原项目全局」。

## 内容

| 文件 | 作用 |
|---|---|
| `bullet_system.gd` | SoA 弹池：spawn / despawn / 积分 / 宽相网格查询 / 确定性 RNG |
| `bullet_type.gd` / `effect_type.gd` | 弹型 / 特效型（Resource，R17） |
| `behavior/` | 行为注册表：accel / curve / laser_follow / avoid_player / world_query |
| `collision/` | 碰撞协调器 / 解算 / 命中几何 |

## Vendor 改动（相对重建版 upstream）

vendor = 复制上游 + **两处规范化**（由 `tools/vendor_kernel.sh` 执行）：

1. `bullet_system.gd`：**删除 `BulletRenderer` 注入**（`_ready` / `setup_renderers`）——内核本体不引用宿主渲染器类型；渲染由 adapter 负责。
2. **去行尾空白**：跟随宿主风格（原项目 A11 已全仓清理）。

> `.uid` 属**项目本地**（Godot 生成、`uid://` 指向本工程）→ 不参与 vendor；脚本只清理孤儿 `.uid`。
> **改了 `class_name` 或文件名**之后，原项目要跑一次 `godot --headless --editor --quit` 重建全局类缓存（K1 教训；M0a 的 `avoid_player` 改名正是踩了这个）。

## 不带（有意）

`bullet_renderer.gd` / `bullet_shapes.gd` / `atlas_layout.gd` / `layer_config.gd`：渲染走原项目已有的 `BulletMultiMesh`（它本就按「纹理 × region × faction × tint」分组、支持独立 PNG 与图集区域）——见决策备忘 §10.4 的 hybrid 方案。

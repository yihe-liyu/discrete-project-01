# 1st Touhou Star ~ Broadest and Narrowest

> 东方同人 STG 引擎 · Godot 4.7 · Discrete Project 第一作

[![Godot](https://img.shields.io/badge/Godot-4.7-%23478cbf)](https://godotengine.org)
[![Tests](https://img.shields.io/badge/GUT-723%20tests%20/%20114%20scripts-green)]()<!-- 手动徽章：数字口径见 docs/TEST_INDEX.md（改测试后同步这里） -->
[![CI](https://github.com/yihe-liyu/1st-touhou-star/actions/workflows/verify.yml/badge.svg)](https://github.com/yihe-liyu/1st-touhou-star/actions/workflows/verify.yml)
[![License](https://img.shields.io/badge/code-MIT-blue)](LICENSE)

<p align="center">
  <img src="东方星尘回封面.png" alt="东方星尘回封面" width="360">
</p>

---

## 🌙 这是什么

**「东方星尘回 ～ Broadest and Narrowest」** 是一个东方 Project 二次创作的同人弹幕射击（STG）引擎与游戏工程。

- 使用 **Godot 4.7** + GDScript 从零搭建
- 已实现完整的弹幕引擎：对象池、空间哈希碰撞、MultiMesh 批量渲染、激光系统、协程时间线
- 已有一个可玩的 **Stage 1**（道中 + Boss 卡摩瑞）
- 世界观与角色设定完整（共 9 位 Boss），见 [omake.txt](docs/omake.txt)
- 这是作者 **YiHe** 的 **Discrete Project（离散系列）** 第一作

> 本仓库是作者在 AI 辅助下设计、开发与维护的东方同人 STG 引擎。代码与工程文档均由作者最终验收负责。

---

## 📊 当前状态

| 类别 | 进度 |
|------|------|
| 引擎 | ████████████████████ 95% |
| 关卡（6 面） | ████ 20%（仅 Stage 1 可玩，设计已完整） |
| 美术 | ██████ 30% |
| 音效 | ██████ 30% |
| 叙事 | ██████████ 50% |
| 打磨/QoL | ██████████████ 70% |

已知待做：Stage 2~6 内容（面脚本 / Boss / 符卡）、Stage Practice、Replay 播放器、结算画面、各页面逐页核验。
待办逐条清单在 [docs/BEST_PRACTICES_BASELINE.md](docs/BEST_PRACTICES_BASELINE.md) 的「🔴 待改进」与本地 `TODO_TEMP.md`。

---

## 📖 文档索引

> 文档地图 —— 每件事找"该读的那一份"，避免到处翻。
>
> **分工（同一信息只有一处写权威版）**：规则与状态 = `BEST_PRACTICES_BASELINE.md` · 架构契约 = `ARCHITECTURE.md` ·
> 历史与"为什么" = `BEST_PRACTICES_LOG.md` + `docs/archive/` · 参考资料 = `DANMAKU_API.md` / `LIFECYCLE_MODEL.md` /
> `BULLET_PIPELINE.md` / `TEST_INDEX.md` / `CONTENT_GUIDE.md` · 内容原稿 = `DIALOGUE.md` / `docs/*.txt`（随实现走，非权威）。

| 文档 | 内容 | 适合 |
|------|------|------|
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | 架构契约 —— 分层 / 系统地图 / 所有权 / 边界铁律 / 债清单 / 命名禁令 | 开发者（首选） |
| **[docs/BEST_PRACTICES_BASELINE.md](docs/BEST_PRACTICES_BASELINE.md)** | 项目基线（**改动前必读，只留规则与状态**）—— 改动前 60 秒 + S1–S13 状态总表 + R1–R22 + 帧序/层序/命名/注入/会话契约；**证据与实测审计**在 [docs/BASELINE_EVIDENCE.md](docs/BASELINE_EVIDENCE.md) | 维护者 |
| **[docs/BEST_PRACTICES_LOG.md](docs/BEST_PRACTICES_LOG.md)** | 最佳实践日志 —— 每个改动的「为什么 / 踩坑 / 验收」（唯一历史记录）。**顶部索引**列全部条目，正文只留最近几天，更早在 `docs/archive/`（`python3 tools/log_archive.py` 维护） | 维护者 |
| **[docs/GDEXTENSION_KERNEL_DESIGN.md](docs/GDEXTENSION_KERNEL_DESIGN.md)** | 原生弹幕内核**北极星设计**（已落地；§5 通用 VM 部分**已被取代**，见文内横幅） | 内核/桥接 |
| **[docs/LIFECYCLE_MODEL.md](docs/LIFECYCLE_MODEL.md)** | 弹幕生命周期模型（已落地 L1–L4） | 行为/内容 |
| **[docs/DANMAKU_API.md](docs/DANMAKU_API.md)** | **弹幕内核 API 参考** —— BulletData / BulletLifecycle 全词汇 + 发射 + ctx 服务 + 素材表 + 陷阱 | 弹幕创作者 |
| **[docs/BULLET_PIPELINE.md](docs/BULLET_PIPELINE.md)** | **一颗弹的完整路径** —— 定义 → 发射 → 每物理帧 → 渲染 → 回收 + 边界职责（改链路前看） | 内核/渲染 |
| **[CONTENT_GUIDE.md](CONTENT_GUIDE.md)** | 内容制作流程 —— 怎么加关卡/敌人/Boss/符卡 | 关卡设计师 |
| **[docs/DIALOGUE_SYSTEM.md](docs/DIALOGUE_SYSTEM.md)** | 对话系统 —— 分层 / DSL / 播放器 / 预览与干跑 | 编剧 |
| **[docs/DIALOGUE.md](docs/DIALOGUE.md)** | 对白全集（**剧本原稿**）—— 已实现关卡（Stage 1）以 `data/dialogue/stage/*.gd` 为准 | 编剧 |
| **[docs/BACKGROUND_VISUAL_PLAN.md](docs/BACKGROUND_VISUAL_PLAN.md)** | 背景视觉计划（未做项 + 已完成记录） | 维护者 |
| **[docs/TEST_INDEX.md](docs/TEST_INDEX.md)** | **测试索引** —— 114 个测试文件「改哪里 → 看哪条」+ 分层 + D3 白盒债清单 + 已知门禁坑（计数口径以本文为准） | 维护者 |
| `docs/*.txt` | 原始设定资料：[omake.txt](docs/omake.txt)（附言 / Extra Story / 全角色设定）· [music.txt](docs/music.txt)（曲目）· [SpellCard.txt](docs/SpellCard.txt)（符卡名）· [FrontData.txt](docs/FrontData.txt) | 玩家/作者 |
| `TODO_TEMP.md` | 作者**本地**临时待办（`.gitignore` 忽略、**不进 Git**、非权威） | 作者本人 |
| **[docs/archive/](docs/archive/)** | 已归档（**一句话价值见 [ARCHIVE_INDEX.md](docs/archive/ARCHIVE_INDEX.md)**）：SPEC / ROADMAP / REFACTORING / STAGE_FLOW / SPELL_SYSTEM / CREATION_STATION / NEW_KERNEL_REFACTOR_PLAN / **N2 接入与拆除记录** / M3_TEXTURE / REBUILD_REPO_STATUS / 旧审计 / 按月日志 | 历史 |

### 我在做什么？看哪份？

| 你的问题 | 打开哪份 |
|---------|---------|
| 「这项目怎么组织 / 谁归谁管 / 怎么改对」 | docs/ARCHITECTURE.md |
| 「项目现在什么状态 / 还差什么」 | docs/BEST_PRACTICES_BASELINE.md |
| 「为什么当初这么改 / 踩过什么坑」 | docs/BEST_PRACTICES_LOG.md |
| 「原生内核接入到哪了 / 怎么拆的（已完成的历史）」 | [docs/archive/N2_NATIVE_INTEGRATION_PLAN.md](docs/archive/N2_NATIVE_INTEGRATION_PLAN.md) + docs/GDEXTENSION_KERNEL_DESIGN.md |
| 「archive 里那一堆是什么 / 哪篇值得看」 | docs/archive/ARCHIVE_INDEX.md |
| 「怎么写一颗弹 / 一套弹幕」 | docs/DANMAKU_API.md（参考）+ CONTENT_GUIDE.md §六（教学） |
| 「这颗弹从定义到画出来走了哪些步 / 谁负责」 | docs/BULLET_PIPELINE.md |
| 「怎么加一个新敌人 / 符卡」 | CONTENT_GUIDE.md |
| 「某面角色说什么台词 / 台词和代码不一致找谁」 | docs/DIALOGUE.md（原稿）→ 已实现面看 data/dialogue/stage/*.gd |
| 「对话怎么写 / 怎么预览与干跑」 | docs/DIALOGUE_SYSTEM.md + `scenes/ui/dialogue_preview.tscn` |
| 「改了某处，哪条测试在保护它 / 重构会不会踩到测试」 | docs/TEST_INDEX.md |
| 「我自己记的临时待办」 | TODO_TEMP.md（本地，不进 Git） |
| 「这些文档各自什么性质 / 哪份是权威」 | README.md 本表 + docs/ARCHITECTURE.md §7 |
| 「怎么跑 / 怎么测 / 快捷键」 | README.md（本页） |

---

## ⚡ 快速开始

0. **先构建原生内核扩展（必需）** —— 未构建 = 无扩展 = 游戏无法启动（L3.5-4f 起扩展为必需）：
   ```bash
   git submodule update --init --recursive   # 首次：拉 godot-cpp
   ./tools/build_gdextension.sh              # 需 SCons + C++ 工具链
   ```
   > 玩家侧不受影响：导出的包内含 `.so` / `.dll` / `.dylib`，玩家从不编译。
1. 用 Godot 4.7 打开 `project.godot`
2. 按 F5 运行 → 主菜单
3. 选 Start → 选难度 → 选角色 → 进入 Stage 1

### 跑测试（重构/改动后的安全带）

```bash
# 一键运行全部测试（GUT）
./test/run_tests.sh
```

### 一键验证（文档哨兵 + 语法 + 命名 + 结构 + 启动 + 测试 + 所有权）

```bash
./tools/verify.sh
```

> 第 1 步是**文档哨兵**（`tools/check_docs.py`）：TEST_INDEX 的测试清单 / 抬头数字 / **各层小节小计** /
> README 徽章 / `DANMAKU_API` 的弹型与音效 key 表 / README 链接 / 滚动日志，全部对着代码与数据机械核对
> —— 文档数字再也不会静默腐烂。
>
> 第 4 步是**结构契约**（`tools/check_structure.sh`）：组合台必须有同名场景壳 · **测试白盒预算只减不增** ·
> **唯一来源常量**（抄第二遍就红）· **舞台接线唯一**（`.inject_*` 只许在 `stage_host.gd`）。

### 开发常用

```bash
# 查找代码
grep -rn "关键词" --include="*.gd" scripts/ data/

# 添加新敌人 → 见 CONTENT_GUIDE.md 第二章
# 添加新符卡/Boss → 见 CONTENT_GUIDE.md 第四章
```

### 内容工作台（预览/调试沙盒）

```bash
# F6 运行 scenes/workbench.tscn —— 跑真实关卡看弹幕效果
```

- 真实运行时沙盒：跑的就是游戏代码（`StageRuntime` / `BulletManager` / 协程），非模拟
- **写代码在 Godot 编辑器**：关卡编排 = stage01.gd（Timeline API）；Boss 弹幕 = PhaseData.tres 显式引用脚本
- **调参工具**：固定种子（可复现）· 命中框 · 逐帧（F）· 12x 快进跳转 · 书签（静态提取 + 人工打点）
- 幽灵玩家提供自机狙目标；静音/背景开关/事件日志/实时状态；改完脚本重启工作台生效
- 创作流程见 [CONTENT_GUIDE.md](CONTENT_GUIDE.md)；架构决策见 [docs/archive/ARCHITECTURE_ROADMAP.md](docs/archive/ARCHITECTURE_ROADMAP.md)「内容工作台演进」专节（已归档）

---

## 🎮 操作

| 键 | 功能 |
|----|------|
| Z | 射击 / 确认 |
| X | Bomb（未实装） |
| C | 释放记忆 |
| Shift | 低速移动 |
| Esc | 暂停 |
| 方向键 / WASD | 移动 |

> 输入映射在 `project.godot` 的 `[input]` 节（可改键，勿在代码里注入）

---

## 🏗️ 技术栈

- **引擎**: Godot 4.7
- **测试**: GUT 9.7.1（`test/` 目录；`./tools/verify.sh` 全量门禁）
- **协程框架**: CoroutineScript + Timeline（游戏逻辑） / await（UI 过渡，见 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)）
- **服务层**: StageContext（clock/bullets/player/dialogue/items/audio/effects）
- **弹幕**: 原生内核 GDExtension `DanmakuStore`（**唯一存储**：积分/行为/判定/宽相）+ MultiMesh 渲染（`KernelNativeSystem` 桥接 + 每帧只读快照）
- **激光**: 生长/直线/固定路径 三种模式
- **UI**: NavPage + MenuNav 页面栈（场景化 Overlay/PageHost）
- **数据**: .tres Resource 文件（EnemyData 构造链模板 / SpellRecordBook / MusicRegistry）
- **常量**: GameConfig（东方框边界）/ LayerConfig（z_index）
- **Replay**: ReplayRecorder 已就绪（RNG 种子 + 输入录制），回放播放器待接入

---

## 🧭 架构速览（2026-09 内核迁移后）

```
project.godot(输入)
      │
      ▼
组合根 GameScene ──声明式装配 + 向下注入──▶ StageRuntime / BulletManager(内核 SoA) / FxPool / MissCircleLayer
      │                                          │
      │                                          └──▶ 实体（Player / Enemy / Boss）经 StageContext 服务 ctx.*
      ▼
UI / 菜单 ◀── 信号 GameEvents    ◀── 存档 SaveData（纯 static）
```

- 依赖单向：父级/组合根向下注入（R2）；数据类不持有场景，实体经 `ctx.*` 服务访问系统
- autoload 只剩 4 个真全局：`GameEvents / GameManager / RNG / AudioManager`；场景 `_exit_tree` 统一断开信号
- 协程约定：游戏逻辑用 CoroutineScript + Timeline（可暂停/可复现），UI 用 await
- 测试保护：核心数学（碰撞/掉落/符卡判定/时间线/RNG）有回归测试

---

## ⚖️ 二次创作与版权

- 《东方 Project》系列的角色、世界观与相关设定版权归 **ZUN / 上海爱丽丝幻乐团** 所有。
- 本仓库是**非商业**同人二次创作作品。
- 仓库内代码采用 **MIT License** 授权（见 [LICENSE](LICENSE)）。
- 美术、音乐、立绘等**素材资源不包含在 MIT 授权范围内**，其版权归原作者或作者本人所有；请勿用于商业用途。
- 详细说明见 [NOTICE.md](NOTICE.md)。

---

## 🤖 AI 辅助声明

本项目由作者 **YiHe** 设计、决策与维护，代码和文档在 AI 辅助下完成。所有 AI 生成内容均经过作者审阅、测试与验收。

# 1st Touhou Star ~ Broadest and Narrowest

> 东方同人 STG 引擎 · Godot 4.7 · Discrete Project 第一作

[![Godot](https://img.shields.io/badge/Godot-4.7-%23478cbf)](https://godotengine.org)
[![Tests](https://img.shields.io/badge/GUT-184%20tests%20/%2032%20scripts-green)]()
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

已知待做：Bomb 系统、Stage 2~6、Stage Practice、Replay 播放器、结算画面。

---

## 📖 文档索引

> 文档地图 —— 每件事找"该读的那一份"，避免到处翻。

| 文档 | 内容 | 适合 |
|------|------|------|
| **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** | 架构契约 —— 分层 / 系统地图 / 所有权 / 边界铁律 / 债清单 / 命名禁令 | 开发者（首选） |
| **[docs/STAGE_FLOW_PLAN.md](docs/STAGE_FLOW_PLAN.md)** | 改进路线 —— 对象自治 / 身份归位 / 记录服务 / 命令化 七步 | 维护者 |
| **[CONTENT_GUIDE.md](CONTENT_GUIDE.md)** | 内容制作流程 —— 怎么加关卡/敌人/Boss/符卡 | 关卡设计师 |
| **[docs/DIALOGUE.md](docs/DIALOGUE.md)** | 对话系统 | 编剧 |
| **[docs/SPELL_SYSTEM_TARGET.md](docs/SPELL_SYSTEM_TARGET.md)** | 符卡系统目标 | 维护者 |
| **[docs/BACKGROUND_VISUAL_PLAN.md](docs/BACKGROUND_VISUAL_PLAN.md)** | 背景视觉计划 | 维护者 |
| **[docs/archive/SPEC.md](docs/archive/SPEC.md)** | 系统规格书（**已归档**，原"代码现状"，精华已并入 ARCHITECTURE §8） | 已归档 |
| **[docs/omake.txt](docs/omake.txt)** | 附言、Extra Story、全角色设定 | 玩家/读者 |

### 我在做什么？看哪份？

| 你的问题 | 打开哪份 |
|---------|---------|
| 「这项目怎么组织 / 谁归谁管 / 怎么改对」 | docs/ARCHITECTURE.md |
| 「接下来要修什么架构问题」 | docs/STAGE_FLOW_PLAN.md |
| 「怎么加一个新敌人 / 符卡」 | CONTENT_GUIDE.md |
| 「某面角色说什么台词」 | docs/DIALOGUE.md |
| 「怎么跑 / 怎么测 / 快捷键」 | README.md（本页） |

---

## ⚡ 快速开始

1. 用 Godot 4.7 打开 `project.godot`
2. 按 F5 运行 → 主菜单
3. 选 Start → 选难度 → 选角色 → 进入 Stage 1

### 跑测试（重构/改动后的安全带）

```bash
# 一键运行全部测试（184 个用例 / 32 个脚本，GUT 框架）
./test/run_tests.sh
```

### 一键验证（语法 + 启动 + 测试）

```bash
./tools/verify.sh
```

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

- 真实运行时沙盒：跑的就是游戏代码（StageManager/BulletManager/协程），非模拟
- **写代码在 Godot 编辑器**：关卡编排 = stage01.gd（Timeline API）；Boss 弹幕 = PhaseData.tres 显式引用脚本
- **调参工具**：固定种子（可复现）· 命中框 · 逐帧（F）· 12x 快进跳转 · 书签（静态提取 + 人工打点）
- 幽灵玩家提供自机狙目标；静音/背景开关/事件日志/实时状态；改完脚本重启工作台生效
- 创作流程见 [CONTENT_GUIDE.md](CONTENT_GUIDE.md)；架构决策见 ARCHITECTURE_ROADMAP.md「内容工作台演进」专节

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
- **测试**: GUT 9.7.1（`test/` 目录，184 个用例 / 32 个脚本覆盖核心系统）
- **协程框架**: CoroutineScript + Timeline（游戏逻辑） / await（UI 过渡，见 SPEC §10）
- **服务层**: StageContext（clock/bullets/player/dialogue/items/audio/effects）
- **弹幕**: BulletPool (4000) + MultiMesh
- **激光**: 生长/直线/固定路径 三种模式
- **UI**: NavPage + MenuNav 页面栈（场景化 Overlay/PageHost）
- **数据**: .tres Resource 文件（EnemyData 构造链模板 / SpellRecordBook / MusicRegistry）
- **常量**: GameConfig（东方框边界）/ LayerConfig（z_index）
- **Replay**: ReplayRecorder 已就绪（RNG 种子 + 输入录制），回放播放器待接入

---

## 🧭 架构速览（2026-07 重构后）

```
输入(project.godot) → Autoload 系统 → StageContext 服务 → 实体
        ↑                  ↓                 ↓
       UI  ←── 事件(GameEvents) ←── 数据(GameState) ←── 物理
```

- 依赖单向：数据类不持有场景，实体通过服务访问系统
- 信号生命周期：场景 `_exit_tree` 统一断开 autoload 连接
- 协程约定：游戏逻辑用 CoroutineRunner（可暂停/可复现），UI 用 await
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

# 创作台 v2 设计稿

> 状态：设计稿（2026-10-22），不绑定当前四页签实现。
> 目标：把「创作台」从四个小应用拼成的 launcher，升级成 **一个 workspace + 一条工具链**。
> 前置阅读：[内容创作流程审查](CONTENT_PIPELINE_AUDIT.md)。

## 0. 结论

**要做 v2，但不是现在全量重写。**

- 设计时不受现状束缚：按「一个内容工作区」设计，而不是在四个页签上继续加面板。
- 落地时用 strangler：先做工具链和只读 workspace，再逐个迁移现有 bench。
- **UI 不是第一层**。先有 manifest / 校验 / 内容图，再有创作台；否则新 UI 只是把错误藏得更漂亮。
- 预览继续跑真实 `StageRuntime`，不另写一套“编辑器模拟”。

一句话：

> **工具链是底座，创作台是它的图形前端；不是反过来。**

---

## 1. 为什么需要 v2

当前创作台是：

```text
四个页签 = 四个小应用
整关预览 | 弹幕台 | 敌人台 | 阶段台
```

它已经能工作，但结构上的问题是：

| 问题 | 后果 |
|---|---|
| 选择状态分散在四个页面 / workspace store | 切换模式时上下文断裂 |
| 目录是后来贴上去的全局抽屉 | 不是原生导航 |
| 三个组合台有热更新，整关没有 | 最需要反复试的整关反馈最慢 |
| 背景只在整关预览里有 | 调弹幕 / 敌人时看不到真实画面 |
| 每个台各自装配 UI / 世界 | 再加一条内容线 = 再加一个应用 |
| 没有统一 manifest / 校验 | UI 无法解释“为什么这面不在菜单里” |

v2 要解决的不是“页面不好看”，而是：

**内容发现、选择、预览、校验、编辑，五件事没有共享同一个上下文。**

---

## 2. 三种形态与取舍

| 形态 | 优点 | 代价 | 结论 |
|---|---|---|---|
| **Runtime v2**（单窗口 workspace） | 预览最真实；一个窗口完成 | 工作量大；容易长成第二套编辑器 | **采用为外壳** |
| **Godot EditorPlugin** | 原生 Inspector / Undo / 资源选择 | 预览与运行时不如现在自然；编辑器 API 风险 | **后续可选** |
| **Hybrid** | 运行时预览 + 编辑器侧目录/校验 | 两个入口，职责要划清 | **过渡期采用** |

**推荐路线：Runtime v2 外壳 + headless 工具链；EditorPlugin 只作为将来的可选前端。**

原因：

- 这个项目的核心价值是「真实运行时预览」，不是“再做一个 Godot Inspector”；
- 数据编辑可以逐步做，但预览 / 校验 / 内容图必须一开始就共享；
- EditorPlugin 适合做资源字段编辑，不适合替代整关时间线预览。

---

## 3. 分层架构

```text
┌──────────────────────────────────────────────┐
│ UI：Creation Workspace v2                    │
│  Content Browser · Preview · Inspector       │
│  Timeline · Console                          │
├──────────────────────────────────────────────┤
│ Domain：ContentSelection / PreviewSession     │
│  CommandBus（后续） / ValidationIssue         │
├──────────────────────────────────────────────┤
│ Toolchain（headless，可被 UI 和 verify 共用） │
│  Manifest · Validator · Graph · Scaffold      │
├──────────────────────────────────────────────┤
│ Runtime：StageRuntime / BulletManager / ...   │
└──────────────────────────────────────────────┘
```

硬规则：

1. **UI 不直接扫描 `res://data`**，只消费 manifest。
2. **UI 不直接写 `.tres`**，写入走 CommandBus（后期）。
3. **工具链不依赖 UI**，必须能 headless 跑。
4. **运行时只有一份**：预览 / 游戏 / 组合台都走同一套 `StageRuntime`。

---

## 4. 工具链契约

### 4.1 ContentManifest

扫描 `data/**` 得到只读清单，至少包含：

```json
{
  "version": 1,
  "stages": [
    {
      "stage_id": 1,
      "path": "res://data/stages/stage01/stage_data/stage01.tres",
      "display_name": "Stage１",
      "playable": true,
      "script": "res://.../stage01.gd",
      "background": "res://.../stage01_background.tscn",
      "bgm_key": "stage1",
      "difficulties": [0, 1, 2, 3]
    }
  ],
  "bosses": [],
  "phases": [],
  "issues": []
}
```

manifest 是 **派生缓存**，不是第二套真相；源仍是 `data/**` + 注册表。

### 4.2 Validator

第一版只查“会静默坏”的：

- Stage：id 唯一、`create_script` 存在、背景根是 `StageBackground`、BGM 可解析
- StageVariant：难度唯一、文件位置正确、脚本可实例化
- Boss：阶段引用、各难度列表、练习 BGM、符卡 UID 唯一
- Phase：`time_limit > 0`、`hp > 0`、脚本引用
- 内容图：悬空引用、孤儿 Stage / Boss / Phase

输出统一为：

```text
severity | code | path | field | message
```

UI 的 Console 和 `verify.sh` 消费同一份 issue 列表。

### 4.3 Graph

只读依赖图：

```text
Stage → Boss → Phase → Script → Bullet / Background
```

先回答三个问题：

- 改一个 lifecycle 原语影响哪些 phase？
- 删一个弹型 / 背景哪些引用会断？
- 哪些内容没有被任何关卡引用？

不要求数据库；扫描生成的 JSON 就够。

### 4.4 Scaffold

```bash
./tools/new_content.sh stage 3B
./tools/new_content.sh boss 3 stage03B
./tools/new_content.sh phase stage03B spell057
```

生成目录、`.tres` 骨架、脚本骨架、注册表占位、最小检查项。

### 4.5 接进 verify

`tools/check_content.sh --fail` 成为 `verify.sh` 的一步：

```text
[1] docs
[2] syntax
[3] naming
[4] structure
[5] content（新）
[6] startup / native API
[7] GUT
```

---

## 5. Workspace v2 信息架构

```text
┌──────────────────────────────────────────────────────────┐
│ Top: 当前内容 / 难度 / 播放状态 / 保存状态              │
├───────────────┬──────────────────────┬───────────────────┤
│ Content       │ Preview              │ Inspector         │
│ Browser       │ 真实运行时 + 背景     │ schema 驱动       │
│               │                      │                   │
│ Stage         │                      │ 选中对象的字段     │
│ Boss / Phase  │                      │ 校验 / 引用        │
│ Bullet/Enemy  │                      │                   │
├───────────────┴──────────────────────┴───────────────────┤
│ Timeline / Bookmarks / Console                           │
└──────────────────────────────────────────────────────────┘
```

### 5.1 单一选择上下文

```text
ContentSelection {
  kind: stage | boss | phase | bullet | enemy | background
  id
  path
  difficulty
}
```

- 所有面板共享同一个 selection；
- 切换模式只换 inspector，不重建世界；
- 点击 Console 的 issue → 直接选中对应内容。

### 5.2 单一预览宿主

`PreviewSession` 负责：

- 当前 stage / difficulty / variant
- 播放 / 暂停 / 速度 / 逐帧
- 书签 / 跳转
- 快照 / 重进（后期）
- 背景始终存在

三个 bench 不再是独立应用，而是 **同一 PreviewSession 的检查器模式**。

### 5.3 模式不是应用

```text
Mode = Stage | Boss | Phase | Bullet | Enemy
Panel = Browser | Inspector | Timeline | Console
```

切换 Mode 只改变：

- Browser 的筛选 / 层级
- Inspector 的表单
- Timeline 的可见轨道

不改变 PreviewSession，不重建 `StageRuntime`。

### 5.4 Inspector 由 schema 驱动

manifest 给字段定义：

```text
field | type | default | required | ref_kind | validator
```

Inspector 只渲染 schema；不再为每个台手写一套表单。

### 5.5 Console 是一等公民

- 校验 issue
- 运行时警告
- 内容图问题
- “为什么不可见 / 不可玩”的解释

每条 issue 带 `path + field + 修复建议`，可点击定位。

---

## 6. 迁移路线

### Phase 0：设计与底座（现在）

1. 本设计稿。
2. `check_content` + manifest 最小版。
3. 不改变现有创作台默认入口。

验收：`verify` 能红在漏注册、断引用、重复 UID、错放 StageVariant。

### Phase 1：v2 外壳

1. `CreationWorkspace`：Browser + Preview + Inspector + Console。
2. 先接 **整关预览**，复用现有 `Workbench` / `PreviewStageLoader`。
3. 旧四页签仍保留，作为回退。

验收：同一 stage / 难度 / 时间在 v2 与旧工作台一致。

### Phase 2：迁移三个 bench

1. 弹幕台 → Bullet Inspector / Composer 面板。
2. 敌人台 → Enemy Inspector。
3. 阶段台 → Phase Inspector。
4. 旧 bench 先保留为“专门模式”，A/B 通过后删除。

验收：切换模式保留选择 / 时间；背景在三个模式都可见。

### Phase 3：写入与 Undo

1. CommandBus：create / edit / delete / move。
2. 只允许通过 manifest + schema 写入。
3. Undo / Redo 只记 command，不记 UI 状态。

### Phase 4：可选 EditorPlugin

如果资源字段编辑仍然笨重，再做 Godot EditorPlugin：

- 只做 Browser / Inspector / Validation；
- 预览仍回 Runtime v2；
- 不复制 manifest 逻辑。

---

## 7. 不做什么

- **不做全量 big-bang 重写**：旧 bench 在新路径 A/B 通过前保留。
- **不做第二套内容真相**：manifest 是派生缓存，源仍是 `data/**`。
- **不做每个模式一套运行时**：只有一个 PreviewSession。
- **不做没有校验的写入式编辑器**：先只读，再写入。
- **不做通用节点图 / 通用引擎**：只解决这个项目的内容线。
- **不强迫数据化**：Timeline / 协程 / lifecycle 仍以代码为主。

---

## 8. 验收指标

v2 是否成功，不看“页面多不多”，看：

| 指标 | 目标 |
|---|---|
| 漏注册 / 断引用 | `verify` 阶段红，不靠人打开菜单发现 |
| 新增一条内容 | 有脚手架，触点数量可数 |
| 改完到看见 | 整关 ≤ 5 秒（快照重进后） |
| 模式切换 | 选择 / 时间不丢 |
| 背景 | 三个模式都能看到真实背景 |
| 内容回归 | 同种子事件序列 / 固定帧截图可比较 |
| 现有门禁 | 全绿，测试数量不倒退 |

---

## 9. 第一批实现建议

按依赖顺序：

1. `tools/check_content.gd` + `tools/check_content.sh`
2. `ContentManifest`（只读 JSON）
3. `ContentGraph`（只读）
4. `CreationWorkspace` v2 壳（Browser + Preview + Console）
5. 迁移整关预览
6. 再迁三个 bench

**不要先写 Inspector 表单。** 没有 manifest / schema，表单只会把字段再抄一遍。

---

## 10. 一句话

> **v2 不是“更漂亮的四页签”，而是“一个内容工作区 + 一条可被 UI 和 CI 共用的工具链”。**

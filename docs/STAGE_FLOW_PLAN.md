# Stage Flow Plan —— 时间线编排 · 对象自治 · 身份归位

> 路线规划文档（草案 v0.1，2026）。
> 覆盖：游戏流程编排（时间线）、运行时对象(Entity/Resource)、身份(identity)、记录(spell records)、
> 注入服务(service)、可观察属性(observable property)、工作台(workbench) 编辑能力。
> 本文是"往哪走 + 怎么走"的总纲；具体实现以各 Step 的验收为准。

---

## 0. 一次看懂（TL;DR）

当前项目：**内容在 `.tres`、运行时状态在节点 var、身份由 BossCatalog 派生、记录在 GameState —— 四个世界互不相通**。
所以对象"不像好的对象"、时间线"控制不了流程对象"、Boss 改名只能靠 UI 轮询、数据关卡编辑器因"复刻会漂移"而亡。

本文目标：把四个世界合并成一套模型 —— **命令(Command) + 稳定身份(Identity) + 可观察属性(Observable Property) + 注入服务(Injected Service)**。三条铁律：

1. **命令，不伸手**：时间线只能发命令（走公开接口），不能写对象内部状态。
2. **编排 = 命令，仿真 = 协程**：稀疏的"何时/哪个对象/做什么"是命令；每帧的"子弹怎么飞/敌人怎么动"是协程，永不进时间线。
3. **对象自治，状态可观察**：对象收到命令后自己改自己的状态，状态一变发信号；UI/记录/时间线订阅，绝不轮询。

一句话：**把"何时、哪个对象、做什么"从暗的闭包，变成明的命令——让每一份责任各归其主。**

> **关于 cmd 的一个关键澄清**：cmd 是**结果记录层**，不是**替代 .gd 的流程控制**。
> 循环/条件/函数/分支**仍在 .gd 里**——.gd 就是用来**构建**命令表的。命令格式保持极简，最多加 `guard`(条件守卫) 和 `custom`(逃生舱) 两个来自 .gd 的轻量口子。**绝不把"脚本逻辑"做进命令数据**（那会重蹈"平行模型漂移"覆辙）。详见 §2.3。

---

## 1. 背景与诊断

### 1.1 病根
- **无统一、可观察、身份稳定的对象面**。对象属性散在四处，无法枚举/订阅/按稳定 ID 引用。
- 由此派生的六类裂缝（详见 `§1.4`）：GameState 混三种生命周期、实体自注册、ctx vs 全局双路、params 反射、身份冗余、时间分片。

### 1.2 现状盘点（写进本文的时刻的真实状态）

| 系统 | 现状 | 在 (b) 里的角色 |
|---|---|---|
| **时间线** `scripts/coroutine/timeline/timeline.gd` | 单位是 `do(闭包)` 黑盒；支持 at/every/times/wait/seek/pause/loop | → 改成**命令表**（见 §4.1） |
| **Boss** `scripts/enemy/boss.gd` | 自己从 BossCatalog 算身份(`_locate_phase`/`_spell_count`/`_non_count`/`_pid`/重复 `boss_index`)；摸 GameState 记录；UI 靠轮询 | → **薄 host**（见 §5.1） |
| **EnemyData** `scripts/data/enemy_data.gd` | `.new()...param(...).spawn(ctx)` 描述与生成糊死；`_script/_pos/_params` 非导出 → **不可序列化** | → **描述/生成拆分**（见 §5.4） |
| **身份** `scripts/data/boss_catalog.gd` | 已做 C 规范序（`stage_phase_order`/`phase_at`/`boss_of_phase`） | → 身份知识**归它**（见 §5.3） |
| **记录** `scripts/data/spell_record_book.gd` | 主键 (stage, phase_index, char, diff)；`boss_index` 非键 | → **记录服务**收口（见 §5.2） |
| **背景** `scripts/background/*` | 内容已数据化(`BackgroundEnvPreset`/`DecorLayer`)；但 `StageBackground` 的 camera/sun/fog 命令**零调用点**、`PhaseData.background` 是**死数据钩子** | → **易接入**：`ctx.background` + 数据映射（见 §5.5） |
| **工作台** `scripts/workbench/workbench.gd` | 纯预览沙盒；书签靠 `bookmark_extractor.gd` **正则扫 `tl.at()` 源码**；数据关卡编辑已移除 | → 书签原生 + 可选编辑器（见 §5.6） |
| **对话** `scripts/coroutine/services/dialogue/*` | 已是"纯逻辑层 + DSX screen 数组编排 + 命名事件(event)" | → (b) 的**命令/事件**已有一半（`d.event("boss_fight")`） |

### 1.3 关键历史教训
- **v1 数据关卡编辑器死于"用平行模型复刻运行时"→ 会漂移**。所以任何"编辑器"都必须是**编辑 == 运行同一份数据**，绝不能再造一套平行模型。
- **对话已示范 (b) 的一半**：`d.event("boss_enter"/"boss_fight")` 是命名事件 + 外部 handler——这就是"命令"的雏形。时间线还是 (a)（黑盒闭包）。**两套编排模型抢着管 Boss，正是 Boss 问题集中爆发的原因。**

### 1.4 六条裂缝（C1~C6）—— 为什么是现在

这六条是整套 (b) 方案的**诊断依据**（每条都对应"现实代码里的裂缝 → 由哪个 Step 根治"）：

| # | 症结 | 关键证据（文件:行） | 由哪个 Step 根治 |
|---|---|---|---|
| **C1** | **GameState 混三种生命周期**（持久进度/单局状态/场景身份），且有两份几乎重复的 reset | `game_state.gd:24` `active_enemies`(身份)；`:351` `reset_all` 与 `:364` `reset_practice` 只差 power/lives/bomb/is_practice_mode；`reset_all` 不清 `active_enemies` | Step 4 收口状态/记录（记录服务） |
| **C2** | **实体自注册进全局注册表**，注册逻辑分散三处，`get_boss` 靠比较脚本类 | `enemy.gd:27` append/`:29` erase；`boss.gd` `start_boss` append；`player.gd` `GameState.player=self`；`game_state.gd:394` `get_script()==BossScript` | Step 3 稳定身份（`StageObjects` 槽位） |
| **C3** | **ctx vs 全局双路访问**，规则不统一（系统走注入、状态摸全局） | `player.gd:309/316/324` 三处 `if ctx:...else Global`；`:170/191/200/203` 直摸 `GameState`/`BulletManager`；`enemy.gd:84` 同款 | Step 4/6 注入服务（记录服务/背景服务） |
| **C4** | **`PhaseData.params` 反射注入**，是内容校验的唯一漏洞（静默失败） | `phase_data.gd:22` `params` Dict；`boss.gd:358-361` `if k in script: script.set(...)`——打错键名/撞名均静默，`validate()` 查不了 | Step 5（命令化时一并类型化/校验） |
| **C5** | **身份冗余 / 重复推导**（C 重构留下的死重） | `boss.gd:75` `_locate_phase` 算身份；`:87` 与 `:190` 两次 `boss_index_of_phase`；`PhaseIdentity.boss_index` 非键却仍串链路 | Step 4（`RecordService` 收口，删 `boss_index`） |
| **C6** | **时间分片 / 暂停缝**（各系统各有驱动源，无统一时间所有权） | 背景 tween 全 `TWEEN_PROCESS_PHYSICS`；`dialogue_box.gd:42/68/262/275` 手动判 `GameManager PAUSED`；Boss `_process`、Player `_physics_process`、协程 runner 各不相干 | §6 R3（命令化时统一暂停语义） |

> **共同点**：这六条都指向同一个病根——**没有统一、可观察、身份稳定的对象面**（不是六件事，是同一道裂缝的六个侧面）。所以 (b) 不是逐一修补丁，而是用一个模型（命令+身份+可观察+注入）把它们**一起**解决。

---

## 2. 目标与边界

### 2.1 目标模型
```
    时间线（指挥）
  ├─ 下发类型化命令 cmd(slot_id, action, args)
  ├─ 挂可观察事件（boss_spawned / phase_cleared / phase_started / 属性变更）
  └─ 只控制"何时发生"，不控制"对象内部是什么"
            │
            ▼
    对象（自治）
  ├─ 收到命令 → 自己改自己的状态
  ├─ 状态一变 → 发信号（可观察性）
  └─ 内容/派生/物理结果 由 目录/结算/模拟 各自拥有
```

### 2.2 边界清单（绝不越过）

| 边界 | 该做什么 | 绝不做什么 |
|---|---|---|
| **编排 vs 仿真** | 何时刷波/出 Boss/进阶段/改名/对话/BGM/背景转场 = 编排 = **命令** | 子弹轨迹/敌人移动/环境持续运动 = 仿真 = **协程**，不进时间线 |
| **命令 vs 伸手** | `cmd("boss_mid","set_name","卡摩瑞")` = 命令 | `boss._display_name = ...` / `ui.label.text=...` = 伸手 |
| **可编辑 vs 不可编辑** | 编排命令可枚举/编辑/保存/回放 | 仿真协程内容不可也不必编辑 |
| **数据 vs 代码** | 敌人预设/阶段映射/背景预设 = 数据(`.tres`) | 不把"弹幕 pattern 编辑器"混进来（那是独立工具） |
| **派生/触发值** | 只读/只观察 | 绝不 set `phase_index`/`boss_index`/`hp`/`captured` |
| **cmd vs .gd 流程控制** | 调度(何时/刷什么) = cmd 数据；循环/条件/分支 = .gd | 不把脚本逻辑(loop/if)做进命令数据；不做"数据里的脚本语言" |
| **作者面 vs 存储面** | 作者写**类型化方法**（`spawn_boss`/`set_name`）；存的是**命令记录** | 不让作者直接写裸 `cmd(slot, action, args)` 字符串+dict |

### 2.3 cmd 与 .gd：流程控制去哪了（重要）

**cmd 不替代 .gd，它是一层"结果记录层"。** 循环/条件/函数/分支**仍然在 .gd 里**——.gd 就是用来**构建**命令表的。所以流程控制优势**没有丢**。

```gdscript
# 循环 + 条件仍在 .gd（你没丢），变的是"到点发可枚举命令"而非"跑黑盒闭包"
for i in 9:
    tl.at(52.0 + i).cmd("wave", "spawn", {enemy: ENEMY03, side: i % 2})
        .guard(func(ctx): return GameState.get_boss() == null)   # 条件 = .gd 谓词
```

**但要诚实接受一点**：可枚举的是**结果**（命令表），不是**生成它的 .gd 代码**。你的 .gd 循环本身仍是黑盒。这是"命令化"无法抹掉的。

**两个轻量逃生口**（都来自 .gd，不是数据语法）——解决"特殊逻辑"：
- `guard`（条件守卫：一个 .gd 谓词）→ "if boss 死了才刷增援"
- `custom`（自定义动作：一个 .gd 函数/闭包）→ "这一处就是这么特殊"

```gdscript
tl.at(7.0).cmd("logo", "custom", {fn: _show_logo})
```

> **绝不做**：把 loop/if/分支做进命令数据本身。那等于在数据里重写一套脚本语言——工程量大爆炸，且**重蹈"平行模型会漂移"的覆辙**（旧编辑器死因）。

---

## 3. 责任地图（谁——管什么）

| 系统 | 现在 (a) 谁在扛 | (b) 之后由谁扛 |
|---|---|---|
| 何时/对谁/做什么 | 时间线闭包，还要摸 `GameState.get_boss()` | **时间线**（只发命令） |
| 阶段/符卡/属于哪个 Boss | Boss 自己从 BossCatalog 算(`_locate_phase`)，存 `_spell_count`/`_non_count` | **身份层**（BossCatalog + 记录键）|
| 属性一变 | UI `_process` 轮询 + `_last_name` cache-diff | **可观察属性**（信号），UI 只订阅 |
| 记录/得分/练习 flag | Boss 摸 `GameState.record_*`/`add_score` | **注入的记录服务**（`RecordService`） |
| 每帧行为 | 被塞进 `tl.every(0).do` | **协程**（独立于时间线） |
| 背景转场 | 无（命令闲置） | **`ctx.background` 命令 + 阶段→背景数据映射** |
| 工作台书签 | 正则扫 `tl.at()` 源码 | **读运行命令表**（原生） |

---

## 4. 四个核心件

### 4.1 命令表 `TimelineCommand`（替代 `do(cb)` 的编排单位）
```gdscript
class TimelineCommand:
    var time: float          # 绝对时刻，或 wait(相对)
    var slot: String         # 稳定标识：如 "boss_mid" / "boss_final" / "wave_03" / "bg" / "stage"
    var action: String       # "spawn" / "start_phase" / "set_name" / "die" / "dialogue" / "play_bgm" / "tween_env_fog"
    var args: Dictionary     # {phase:"non_1", name:"卡摩瑞", enemy:"ENEMY01", count:7, ...}
```
- 命令表**本身就是数据** → 可枚举(查)、可编辑(改)、可保存、可回放。
- 命令表**同时是资产** → 运行时执行它、编辑器编辑它，是**同一份** → 编辑器零漂移。
- **极简 + 逃生口**：命令 = `time + slot + action + args`；需要条件/特例时用 `guard`(谓词) / `custom`(函数)，**都是 .gd 提供的**，不把脚本逻辑写进数据。
- **作者书写面**：作者不写裸 `cmd(slot, action, args)` 字符串+dict，而是写**类型化方法**（`spawn_boss`/`set_name`/`custom`）——见 §4.5。

### 4.2 稳定身份 `StageObjects`（槽位注册表）
```gdscript
# 把"字符串槽位"解析成"活对象"
func register(slot: String, node: Node)
func resolve(slot: String) -> Node      # 找不到返回 null（命令可跳过）
func clear()                            # 关卡结束清空
```
- 根治"身份耦合到 Boss 拆分/存储"：命令只认 `"boss_mid"`，不认 `boss_holder[0]`/`func():return boss_holder[0]`/`_kamorui.phases[0]`。

### 4.3 可观察属性 `ObservableProperty`
信号 + 访问器：
```gdscript
signal display_name_changed(name: String)
var _display_name := ""
func set_boss_name(n: String) -> void:
    if _display_name == n: return
    _display_name = n
    display_name_changed.emit(n)          # 变化即通知
```
- UI/记录/时间线**订阅**，绝不轮询。范围仅限"显示/状态类"属性（显示名、HP、阶段标题、是否收取）。

### 4.4 注入服务 `RecordService` + `BackgroundService`
- `RecordService`：**唯一**掌握"怎么从 (stage, phase, char, diff) 得到记录键/第几张/哪个 boss"。`record_phase(stage, phase, char, diff, captured, bonus, elapsed)`。
- `BackgroundService`（ctx.background）：转发 `StageBackground` 的 camera/sun/fog 命令。
- 原则：**系统走注入，不再摸全局**（C3 根治）。

### 4.5 作者 DX：类型化方法面 + action schema（创作者怎么知道能填什么）

**诚实问题**：裸写 `cmd(slot, action, args)` 会丢自动补全 + 类型检查——`action` 是魔法字符串、`args` 是无类型字典，创作者没法靠工具知道能填什么。

**解法：作者面 = 类型化方法；存储面 = 数据；schema 把两者焊住。** 作者写类型化的便捷方法（有参数提示/类型检查），系统落成可枚举的命令记录——**type-safe 在作者侧，data 在存储侧**。

```gdscript
# 作者看到（自动补全 + 类型检查）
tl.at(38.0).spawn_boss("boss_mid", "non_1")
tl.at(60.0).set_name("boss_final", "卡摩瑞")
tl.at(7.0).  custom(_show_logo)

# 内部落到命令表（工作台枚举/编辑）
{ time:38.0, slot:"boss_mid",   action:"start_phase", args:{phase:"non_1"} }
{ time:60.0, slot:"boss_final", action:"set_name",    args:{name:"卡摩瑞"} }
{ time:7.0,  slot:"stage",      action:"custom",      args:{fn:show_logo} }
```

**action schema = 单一真源**，同时喂三处：

| 谁 | 从 schema 拿到什么 |
|---|---|
| 作者 | **类型化方法**（`spawn_boss`/`set_name`…按 schema 包出来）→ 自动补全 + 类型检查 |
| 编辑器 | **渲染成表单**（"这个 action 需要 asset+pos+count"）→ 不是裸 dict |
| 校验 | **按 schema 校验**（缺键/类型错 → 响亮报错）→ 顺带治 C4 的 params 静默填错 |

```gdscript
# action 目录：action 名 → {参数 schema, 默认}
"spawn":       {asset:String, pos:Vector2, count:int=1}
"start_phase": {phase:String}          # phase 名来自 BossCatalog
"set_name":    {name:String}
"play_bgm":    {bgm:String}
"custom":      {fn:Callable}
```

**内容值去哪查**（不是随便写）：

| 填什么 | 去哪查 |
|---|---|
| `slot`（boss_mid / boss_final） | 该关自身的 `StageObjects` 槽位 |
| `phase`（non_1 / spell_1） | `BossCatalog`（`stage_phase_order`/`phase_at`） |
| boss / 敌人预设名 | `BossCatalog` / 敌人资产注册表 |
| 背景 / 演出资产 | 资产管理 (.tres) |

> **硬规矩**：**永远不让作者直接写裸 `cmd(slot, action, args)` 字符串 + dict。** 一律给**类型化方法面**（`spawn_boss`/`set_name`/`custom`…），内部由 **action schema** 落到命令记录。作者拿自动补全，工具拿可枚举，校验拿 schema——三者用同一份 schema 对齐。这也正是项目已有先例（`Timeline.spawn_boss`/`play_bgm`/`dialogue_steps`/`spawn_wave` = 类型化便捷方法叠加调度器）的推广。

---

## 5. 分阶段路线图（增量落地）

> 每个 Step 可独立提交、可回滚、有明确验收。**顺序设计成"低风险先行、大重构殿后"。**
> **重要**：**Step 1~4 都不依赖 cmd（Step 5）**——它们只是把现状理顺（对象变干净、少耦合、身份归位），可以**保留 `do(cb)`** 走完。cmd 只有在你要"编辑/枚举/回放编排"的收益时才做（可推迟，甚至不做）。详见 §7。
>
> **进度（2026）**：✅ **Step 1 / Step 3 / Step 4 已完成**（第 1 层对象/身份模型落地）。**第 2 层（typed params / C4）** 已做到「校验 + 响亮」（`ParamValidator`，尚未全 typed 资源）。Step 2 / 5 / 6 / 7 待做。

### Step 1 —— 可观察属性 ✅ **已完成**（零风险，立即见效）
- **目标**：Boss 改名信号化，UI 从轮询变订阅；删掉 `_last_name`/`_process` 轮询。
- **文件**：`scripts/enemy/boss.gd`（加 `display_name_changed` 信号），`scripts/scenes/boss_ui.gd`（订阅，删 `_last_name` + `_process` 里的 get_boss_name 比对），`test/test_boss_name.gd`（补信号断言）。
- **验收**：`set_boss_name` 触发一次信号；UI 无轮询；改名即时同步；测试通过。
- **风险**：极低。

### Step 2 —— 书签原生（工作台受益，不碰大重构）
- **目标**：时间线暴露命令表元信息；工作台书签从"正则扫源码"改成"读运行命令表"。
- **文件**：`timeline.gd`（`get_commands()` 返回可枚举命令，哪怕仍用闭包先把元信息暴露），`workbench.gd` `_static_extract`/`bookmark_extractor.gd`（改成读运行），`test` 补。
- **验收**：工作台书签不再依赖正则；能显示每个时刻的命令（对象+动作）。
- **风险**：中低（涉及 time 提取逻辑）。

### Step 3 —— 身份硬化 ✅ **已完成**（命令可持久化的前提）
- **目标**：引入 `StageObjects` 槽位注册表；stage01 的 Boss 引用从 `boss_holder[0]`/闭包改成 `register("boss_mid", b)` + 槽位引用。
- **文件**：新增 `scripts/data/stage_objects.gd`（或 autoload）；`stage01.gd`（`_boss_holder` 改 `StageObjects`）；`timeline.gd` `start_phase(boss_getter)` 改 `start_phase(slot, phase_id)`。
- **验收**：命令表能持久化/编辑（slot 稳定）；Boss 拆分/存储改动不再破坏引用。
- **险**：中。

### Step 4 —— 记录服务 ✅ **已完成**（Boss 瘦身，身份归位）
- **目标**：`Boss` 迁走 `record_*`/`_pid`/`_spell_count`/`_non_count`/`_stage_id`；身份解析收口到 `RecordService`(经 BossCatalog)；`PhaseIdentity.boss_index` 退场。
- **文件**：新增 `scripts/data/record_service.gd`；`boss.gd`（删身份计算/记录调用）；`spell_record_book.gd`/相关（去掉对 `_pid` 的依赖）；`stage_context.gd`（挂 `_records` 服务）；`test` 改。
- **验收**：Boss 不再摸 GameState 记录；身份只由目录/记录服务解析；无 `boss_index` 冗余。
- **风险**：中高（C5 根治，但触到记录链路）。

### Step 5 —— 命令化时间线（**可选 / 可推迟**）
> **这是唯一"可做可不做"的步骤**；前面 1~4 的收益**不依赖它**。只有在确认要"编辑/枚举/回放编排"时才做；否则保留 `do(cb)` 即可。
- **目标**：`TimelineEvent` 从"闭包"升级为"命令"，**只针对编排类**（spawn/start_phase/set_name/die/dialogue/bgm/背景转场）；行为类（`move_homing`/`marisa_laser_follow` 的 `every(0).do`）拆回协程。
- **文件**：`timeline.gd`/`timeline_event.gd`（`cmd(slot,action,args)` + `guard`/`custom`），`stage01.gd`（重写为 `cmd`，循环/条件留在 .gd），`coroutine_script.gd`（拆 `start_timeline` → 编排 + 行为分开）。
- **验收**：编排可枚举；仿真不进时间线；阶段/改名/背景转场全走命令；条件用 `guard` 而非数据语法。
- **风险**：高（工作量大，触及 stage01 + Timeline 核心）。

### Step 6 —— 注入服务（背景等系统走 ctx）
- **目标**：加 `ctx.background`（转发 StageBackground 命令）；`PhaseData.background` 改成"数据驱动的阶段→背景时刻"映射。
- **文件**：新增 `background_service.gd`（或并入 stage_context）；`phase_data.gd`（`background` 字段 → env-preset/雾/相机配置，或 `bg_moment` 引用）；`stage_context.gd`。
- **验收**：背景转场走 `ctx.background`；阶段可数据化指定背景时刻。
- **风险**：中低。

### Step 7 —— 工作台命令编辑器（数据关卡编辑回归）
- **目标**：工作台显示/编辑命令表，恢复"波次表格 + 详情表单 + 增删复制保存 + 出生点拖放"，零漂移。
- **文件**：`workbench.gd`/新增命令表 UI；`StageObjects`/`command` 表序列化。
- **验收**：编辑命令表即时生效；保存后运行一致（同一份数据）。
- **风险**：高（大量 UI 工作）。
- **注意**：这是**可选项**——(b) 让编辑器"可做"，但要不要做是产品决定（见 §7）。

---

## 6. 风险与诚实取舍

| # | 风险/取舍 | 说明 |
|---|---|---|
| R1 | **(b) 不是性能优化**，可能略慢（命令 dispatch） | 它优化的是"构建游戏的过程"（可作者/可发现/可维护），不是运行速度。别期待 FPS 提升 |
| R2 | **大投入**且**逆着一次主动决定**（workbench 明确"收窄为纯预览沙盒"） | (b) 给的是"钥匙"，要不要重开编辑器是产品决定；最理想是让"脚本作者"和"编辑器作者"共存 |
| R3 | **时间分片 / 暂停缝**（C6） | 背景 tween 全是 `TWEEN_PROCESS_PHYSICS`、DialogueBox 手动判 AppState、Boss/Player 走 `_process`/`_physics_process`。命令化后必须统一"暂停时每系统怎么动" |
| R4 | **仿真混进编排** | 若 `every(0).do` 不拆出协程，命令化会把仿真也拖进可枚举模型——必须守住边界 |
| R5 | **params 反射洞**（C4） | `EnemyData.param`/`PhaseData.params` 静默注入；命令化时应一并类型化/校验 |
| R6 | **把脚本逻辑做进命令数据** | 在数据里表达 loop/if 等于重写脚本语言：工程量大 + 重蹈"平行模型漂移"覆辙（旧编辑器死因）。命令格式必须极简，条件用 .gd 的 `guard`/`custom` |
| R7 | **可枚举的是结果，不是生成器** | 命令化后能枚举的是"命令表"（编排排出来的清单），**不是写它的 .gd 流程控制代码**。要接受这一步"无法全透明" |
| R8 | **裸 cmd 丢失可发现性** | 若作者直接写 `cmd(slot, action, args)` 字符串+dict，会丢自动补全/类型检查，内容值靠背。**必须走类型化方法面 + action schema**（§4.5），否则宁可保留 `do(cb)` |

---

## 7. 明确不做 / 待你拍板

- **不做"弹幕/移动 pattern 编辑器"**：那是独立工具，不属于本路线。
- **待拍板 A：时间线是否"数据化成资产"？**（命令表序列化成 .tres/JSON，关卡=资产）——重开编辑器的前提；若只要"运行时能查"，可更轻。
- **待拍板 B：作者走哪条路？** 保持 `.gd` 为主（程序员友好）+ 可选编辑器，还是让编辑器成为第一作者工具（内容作者友好）？决定 Step 5/7 的投入倾斜。
- **待拍板 C：是否真的重开数据关卡编辑器？** 这是产品决定，不是技术前提；(b) 只是让它"可行"。
- **待拍板 D：cmd 到底值不值？** 建议：**先做不依赖 cmd 的 Step 1~4**（保留 `do(cb)`），等确认要"编辑/枚举/回放编排"的收益再决定要不要上 Step 5。**不必现在就为 cmd 下决心**。

---

## 8. 附录

### 8.1 文件清单（本路线涉及的）
- 核心：`scripts/coroutine/timeline/timeline.gd` `timeline_event.gd`；`scripts/coroutine/base/coroutine_script.gd`
- 对象：`scripts/enemy/boss.gd`；`scripts/data/enemy_data.gd`；`scripts/enemy/enemy.gd`
- 身份/记录：`scripts/data/boss_catalog.gd`；`scripts/data/spell_record_book.gd`；`scripts/data/phase_data.gd`
- 服务：`scripts/coroutine/services/stage_context.gd`；新增 `record_service.gd`/`background_service.gd`
- 背景：`scripts/background/stage_background.gd` `env_preset.gd` `decor_layer.gd`
- 工作台：`scripts/workbench/workbench.gd` `bookmark_extractor.gd` 等
- 关卡：`data/stages/stage01/stage_script/stage01.gd`
- UI：`scripts/scenes/boss_ui.gd`
- 测试：`test/test_boss_name.gd` `test_boss_catalog.gd` `test_boss_phase.gd` `test_dialogue_steps.gd` + 新增 `test_timeline_command.gd`/`test_stage_objects.gd`/`test_record_service.gd`

### 8.2 测试策略
- 每个 Step 补齐对应 GUT 测试（`./test/run_tests.sh`）。
- 关键回归点：Boss 名称同步、记录身份（stage/index/char/diff）、命令表可枚举、`StageObjects` 槽位解析、背景转场命令、书签原生。
- 命令表/StageObjects/RecordService 为**纯逻辑**，可单独单测；UI 同步走信号断言。

### 8.3 概念索引
- **(a)** 现状：闭包调度器（黑盒、靠捕获身份、已伸手全局、与对话事件两套并存）
- **(b)** 目标：类型化命令 + 可观察属性 + 稳定身份 + 注入服务
- **编排**：稀疏的"何时/哪个对象/做什么"，= 命令
- **仿真**：连续的"每帧怎么飞/怎么动"，= 协程
- **命令**：`cmd(slot, action, args)`，走公开接口
- **guard**：命令的条件守卫，一个 .gd 谓词，在触发时求值
- **custom**：特殊逻辑的逃生舱，一个 .gd 函数/闭包
- **伸手**：直接写对象内部状态（`boss.hp=50` / `_display_name=...`），禁止

---

*本文随实现推进更新；完成一个 Step 后把对应 §5 条目标绿并补验收。*

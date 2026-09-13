# 🎮 全系统图景 + 改进路线 v5

> 2026-07-31 · 架构重构（阶段 0-3 完成）更新
> 重构专项记录见 **[REFACTORING_PLAN.md](REFACTORING_PLAN.md)**

---

## 核心设计

**所有协程脚本 = CoroutineScript。Boss = .tres。默认弹 = _physics_process 直线。**

**2026-07 新增核心原则**：
- 依赖单向：数据类不持有场景（spawn 归 StageManager），实体走服务（ctx 注入）
- 信号生命周期：场景 `_exit_tree` 统一断开 autoload 连接
- 协程约定：游戏逻辑用 CoroutineRunner（可暂停/可复现），UI 用 await（SPEC §10）
- 常量集中：GameConfig（东方框边界）+ LayerConfig（z_index）
- 测试保护：GUT 163 个用例 / 29 个脚本覆盖碰撞/掉落/符卡/时间线/RNG

---

## 资源层

```
AssetRegistry (autoload)
├── enemy_visuals, bullet_configs, sounds, ui_textures, enemies
BossData / PhaseData / StageData / PlayerData  ← .tres
CardDef / CardRegistry / SpellRecordBook        ← 练习/记录
```

## 运行时层

```
StageContext — 协程唯一入口
├── clock / bullets / player / dialogue / items / audio / decor

BulletManager
├── BulletPool (4000) / BulletPhysics / LaserSystem (32) / DeathClear
```

---

## ✅ 已完成的架构演进

| 变更 | 状态 |
|------|------|
| SPEC.md v2.0 系统规格文档化 | ✅ |
| CoroutineScript 统一协程脚本 | ✅ |
| BulletData 构造链 | ✅ |
| Laser 激光系统 | ✅ |
| MenuNav 统一菜单导航 | ✅ |
| Memory 值系统 + 释放记忆 | ✅ |
| 子弹池 POOL_SIZE=4000 | ✅ |
| 练习模式（符卡/关卡） | ✅ |
| BubblePanel 独立分离 | ✅ |
| Boss phase 防双重掉落 | ✅ |
| 激光子节点泄漏修复 (laser.gd) | ✅ |
| 默认弹去掉多余协程（仅 \_physics\_process） | ✅ |
| MissEffect fade_out 支持 | ✅ |
| DeathClear on_clear 回调 | ✅ |
| 暂停/GameOver 重开（含符卡练习适配） | ✅ |
| 主菜单跳过 logo/入场动画 | ✅ |
| Manual 页面（help01~06） | ✅ |
| 2026-07 重构阶段 0：GUT 测试框架 + 34 用例 | ✅ |
| 2026-07 重构阶段 1：静态 ctx 消除 / 私有封装 / 信号生命周期 / pause-resume | ✅ |
| 2026-07 重构阶段 2：输入映射入 project.godot / GameConfig / 服务层 / 数据解耦 / GameState 拆分 | ✅ |
| 2026-07 重构阶段 3：%UniqueName / SceneTransition 健壮化 / BGM 懒加载 / 协程约定 / 菜单场景化 | ✅ |
| 2026-08 工作台 v2 关卡沙盒（真实运行时预览）—— 见下方专节 | ✅ |
| 2026-08 六项技术债清理（RNG 规约 / 基准断言 / queued 防护 / Timeline loop / layout_mode / RefCounted 环） | ✅ |

---

## 🛠️ 内容工作台演进（2026-08）

> 目标：弹幕的"剪辑软件"——以时间轴为总谱，预览/调试/设计关卡。

### v1 → v2 的架构转变

| | v1 模型沙盒 | v2 关卡沙盒（当前） |
|---|---|---|
| 预览方式 | LifecycleNode 纯逻辑模型**复刻**实体公式 | **直接跑真实关卡**（StageManager + BulletManager + 真实协程） |
| 一致性 | 靠"复刻"，会漂移 | 跑的就是游戏代码，100% 一致 |
| 玩家 | 无 | 幽灵玩家（GhostPlayer，固定路径 + 无敌，给自机狙当目标） |
| 运行方式 | @tool 编辑器内 | F6 运行（依赖 autoload），窗口 1600×1000 |

### 核心能力（F6 运行 `scenes/workbench.tscn`）

- 播放/暂停/重跑（真实引擎时钟，UI 独立存活）
- **跳转**：12x 快进到目标时刻（真实关卡无任意 seek）
- 难度切换（Easy~Lunatic）/ 静音 / 背景开关 / 实时状态（时间/子弹数/敌人/Boss/FPS）+ 事件日志

### 2026-08 收窄（纯预览沙盒——脚本页/编排页/数据关卡移除）

> 2026-08 决策（YiHe）：弹幕核心是逻辑不是数据；AI 时代代码直写成本 < 编辑器中间层税。
> **工作台从"编辑器"收回为"预览/调试沙盒"**：脚本一律在 Godot 编辑器写，改完重启工作台生效。

- **保留的调参工具**：固定种子（重跑弹幕可复现）· 命中框 · 逐帧（F）· 书签（静态提取 + 人工打点）· 12x 快进跳转
- **布局**：顶部常驻（关卡/播放/状态）+ 页签（书签/日志）
- **移除**：编排页（波次表/表单/Boss 表单/演出事件/单波/出生点拖放）、脚本页（CodeEdit/热重载/F5）、数据关卡系统（StageTimeline/wave_stage/stage_demo/stage1_data）、符卡注册按钮
- **快捷键**：Space 暂停/继续 · R 重跑 · F 逐帧 · 1~7 速度 · ←/→ 跳 ±1s（Ctrl ±5s）· B 书签 · Home 回开头
- **书签缓存修复（2026-08 v5）**：script_hash 超 2^53 存 JSON 数字丢精度 → 缓存永不命中，每次加载都重跑 40x 静默收集；改为存字符串后一次收集、永久命中

### 关键决策与教训

1. **任意 seek 对协程关卡是反实际的**（自机狙依赖玩家路径、状态机依赖交互历史、音效无法倒带）——编辑器核心价值是"改参数→重跑→看"的循环，不是拖拽。
2. **快进同步**：游戏内 Tween 统一 `TWEEN_PROCESS_PHYSICS`（默认 IDLE 与协同时钟不同源，time_scale≠1 时演出 Tween 会落后）。所有游戏世界演出 Tween（背景/敌人/Boss）已统一。
3. **共享状态手雷**（重跑累积 bug 的根源）：
   - 场景 SubResource（Environment/ShaderMaterial）跨实例共享 → `duplicate()` 实例私有
   - 共享 Camera3D 被旧背景 tween 移走且不复位 → 逐次漂移画面变暗
   - **根解法：所有权随生命周期**——相机改由背景实例自建（`StageBackground._own_camera()`），重跑 = 旧相机随背景销毁、新背景拿初始相机，结构上不可能残留，零复位代码。
4. **出屏回收按东方框**（不是窗口）：工作台 1600 宽窗口下活动子弹 ↓93%（1401→101），真游戏右侧死区同样受益。
5. MultiMesh 分组 key 从字符串改 int（纹理 RID + region + faction + tint），去掉每帧每弹字符串分配。
6. 协同时钟/子弹移动/激光统一走 `get_physics_process_delta_time()`（time_scale 生效，为未来子弹时间/Replay 铺路）。
7. **stretch viewport 布局坑（2026-08 面板盖住游戏框 4 轮排查）**：project.godot 是 `stretch/mode="viewport"`（视口 1280x960 拉伸到窗口 1600x1000）——**Control 布局坐标 = 视口，不是窗口！** `get_window().size` 返回窗口宽（1600），用它算 offset 会让面板在视口坐标 x=528 盖住东方框（64~832）。**布局一律用 `GameConfig.VIEW_WIDTH/HEIGHT`（或视口可见矩形），禁用 get_window().size**。headless 下视口=窗口，测不出此问题（真机才现形）。
8. **工作台 UI 调试经验**：
   - 命中框等覆盖层要**独立 CanvasLayer + 高 z**（敌弹 z=10，画在 root z=0 会被实心贴图盖住）
   - 可开关绘制的节点：`enabled` setter 里必须 `set_process(v)`（否则只画开启帧，_ready 时 set_process(false) 已永久关闭）
   - 面板拖拽：**初始校正一次即可，别每帧 clamp**（会把用户拖拽值弹回 → 拖不动）
   - 滚轮也是 `InputEventMouseButton`（WHEEL_UP/DOWN），跳转类交互要显式排除

### 下一步（候选）

- ~~书签数据化~~ → ✅ 已完成（2026-08：BookmarkExtractor + 运行时收集缓存 + 人工编辑；v5 修复哈希精度缓存永不命中）
- ~~命中框~~ → ✅ 已完成（2026-08）
- ~~数据化编辑器~~ → ✅ 已完成（2026-08，见下方专节）
- 形态走廊（多时刻叠影）—— 后续（未启动）
- ~~Boss 脚本（move/shoot/enter/exit）热重载~~ → ❌ 已移除（2026-08：脚本页/热重载随编辑器收窄删除；BossScriptRegistry 已随注册表层整体删除）

### 🎛️ 数据化编辑器（2026-08 已实现 → 同月已移除，记录保留）

> ⚠️ **2026-08 终局：本路线整体放弃**——数据关卡系统（StageTimeline/wave_stage/编排页/脚本页）已全部移除，
> 工作台收回纯预览沙盒；关卡/Boss/弹幕一律代码直写（stage01.gd Timeline + data/boss_scripts/ 目录）。
> 以下为设计过程记录，仅作历史参考。

**核心：两级编辑 + 统一注册表 + 代码逃逸口**

1. **编排层（关卡节奏，优先做）**：波次表 StageTimeline
   ```
   [{t, name, enemy, params:{...}}]   # 表格为主，时间轴可视化辅助
   ```
   - **表格编辑**：每行一波次（t/名称/模板/参数摘要）——精确、重叠天然支持
   - **时间轴**：条带轨道可视化（重叠自动分行），点条带 = 定位表格行（拖拽后置）
   - 重叠编排 = 正常（高级关卡：杂兵+中怪+Boss 同时），表格每行独立时刻

2. ~~**个体层（后置 S5+）**：敌人行为表（move_to/ring/aim/fan/die 等标准件）~~ —— ❌ 已放弃（2026-08 决策：行为直接写协程 .gd，不拆标准件；"敌人内部行为"用脚本层表达，自由度高、维护成本低）

3. **统一注册表（预设 + 脚本一视同仁）**：
   ```
   EnemyRegistry:   "red_fairy"→preset  /  "custom_boss_a"→{kind:"script", script, params}
   PatternRegistry: "ring/aim/fan"→内置 /  "my_spiral"→{kind:"script", script, params}
   ```
   - 自定义敌人/弹幕 = 写 .gd（@export 参数）→ 注册一行 → 工作台下拉框出现，
     详情面板反射 @export 自动生成表单（同预设 schema 表单）
   - 复用 = 注册表按名引用，多波次各传不同参数

4. **详情面板（自定义参数的家）**：表格只放通用列，点行展开详情
   - 预设：模板 schema（int→SpinBox/enum→下拉/颜色→Picker）
   - 脚本：反射 @export 变量生成表单
   - params 是字典 → 任意模板任意自定义参数，异构无压力

5. **三层内容系统**：
   ```
   ① 预设层：纯数据（波次模板/ring/aim/fan）——编辑器全可编，占 90%
   ② 脚本层：注册的 .gd（带 @export）——写一次、注册、到处复用
   ③ 内联层：关卡内一次性特殊逻辑（可先不做）
   ```
   - 分工：Godot 编辑器 = 写代码；工作台 = 挂载/调参/排节奏
   - 协程脚本：保存 = .gd（现有 coroutine_script/ 结构）；挂载 = 注册表引用；
     编写 = Godot 编辑器（工作台提供「在编辑器中打开」入口）

6. **运行时零新机制**：现有 `EnemyData.script()+param()` / `StageManager.spawn_enemy_data`
   已经是"脚本+参数"模式——编辑器只是把代码写死改成数据描述，解释器读表调现有入口

**落地路线（已全部完成 2026-08，随后整体移除）**：
- ✅ S1 定义 StageTimeline（波次表）+ wave_stage.gd 解释器 → 已随数据关卡系统移除
- ✅ S2 工作台编排表格 → 已移除（编排页）
- ✅ S3 详情面板（schema/反射动态表单）→ 已移除
- ✅ S4 [💾 保存] .tres + 增删/复制波次 → 已移除（数据关卡不再保存）
- ~~S5+ 个体行为表（敌人内部）~~ —— ❌ 已放弃：敌人行为 = 写协程 .gd 注册 BEHAVIORS，不拆标准件

**终局形态（2026-08 收窄后）**：Stage 1 = 协程版（stage01.gd Timeline）；测试符卡已搬入
（stage03B/phase/spell03/spell053~056.tres + 阶段链）；练习模式记录不受影响（CardDef 随双驱动一并移除）；
GUT 现为 163 用例 / 29 脚本全绿。

**清理标记（更新）**：
- [x] 书签"运行时收集 + 缓存" → 静默收集已随数据关卡移除；BookmarkCache 保留（人工打点持久化）
- [x] BookmarkExtractor（静态提取）→ **保留**：协程关卡书签唯一来源
- [x] stage01.gd 编排层代码（tl.at 链）→ **协程关卡即主力**（数据关卡已删）
- [x] CONTENT_GUIDE.md 制作流程 → 已重写为协程代码版（2026-08）

### 协程成本模型（2026-08 · 子弹协程优化后）

**总成本 = 调度 + 节点 + 逻辑**：

| 成本 | 状态 | 说明 |
|------|------|------|
| 调度成本（Task/Callable/唤醒） | ✅ 免费 | 子弹协程自动走 `start_fast`/`tick_fast`（直接调 `_tick`，绕过调度层） |
| 节点成本（引擎回调） | ✅ 已消除 | 子弹协程不再 add_child；敌人/舞台协程数量少非热点 |
| 逻辑成本（每颗弹每帧做什么） | ⚠️ 设计选择 | 距离检测/RNG/字符串等真实工作，框架管不了 → 跳帧/预计算 |

**基准**（1500 协程弹）：节点模式 2.36ms → 无节点 1.96ms → tick_fast **1.56ms**；无协程直线弹基线 1.81~2.34ms → **协程弹已与直线弹持平**。

**写协程的规则**：
- 同屏实例 >100（弹丸个体行为）→ 自动 fast 路径，随便写；**别用 `run_parallel`**（fast 模式只驱动单 `_tick`）；别让单颗弹每帧做太重的事
- 实例少（敌人/Boss/舞台）→ 节点模式，所有功能（run_parallel/await/pause）随便用
- **已知坑**：`start()` 里别用 `get_dt()`（启动时 `_last_dt` 未初始化 = 0）；也别用 `get_physics_process_delta_time()`（物理循环外 = 0）。启动期取步长用 `1.0 / Engine.physics_ticks_per_second`
- **快速路径会调用子类覆写的 `start()`**（start_fast → start → run 跳过 Task）——用 `start_timeline()` 的子弹协程（如 move_homing）正常工作

**性能回归工具**：`test/perf_stress/`（1500 协程弹压力 + 子机/诱导弹功能验证）

### 性能优化专项（2026-08 · NON01 L 卡顿排查记录）

> 背景：卡摩瑞**面非符1（NON01）L 难度 60 帧明显卡顿**。用临时 autoload `scripts/debug/perf_diag.gd` 写 `res://perf_diag.log`（FPS/渲染帧/物理帧耗时）定位。
> 排查结论：**两类尖峰**——渲染侧（22~97ms，物理闲着）+ 物理侧（8~14ms，弹幕密集时）。
> 已修复两处渲染侧；剩两处物理侧**结构性成本**待专项优化。

#### 已修复（本次）

| 问题 | 根因 | 修复 | 效果 |
|------|------|------|------|
| 雾效贵 | `bullet_fog.gd` 每颗弹 `create_tween` + 每帧 `set_shader_parameter("fog_tint:a")`（GPU 材质上传） | 淡出改用普通属性 `modulate:a`（`tween_property`），`bullet_fog_blend.gdshader` 乘 `COLOR.a`；`fog_tint` 只设一次 | 视觉不变，去每帧材质上传，便宜约 10× |
| MultiMesh 缓冲抖动 | `bullet_multi_mesh.gd` `instance_count` 从 64 起随子弹涨跌反复 grow/shrink → GPU 缓冲重分配 → 渲染尖峰 | 预分配 `instance_count = max(min_size, 2048)`（只增不减）+ 绘制数改用 `visible_instance_count` | 渲染尖峰 7 次 → 3 次，70ms 那次消失 |

> ⚠️ 注意：雾效**要保留**（不能靠关雾效省性能）。上面的做法是"让雾效变便宜"而非关闭。

#### 剩余待做：物理尖峰 8~14ms（已精确定位）

NON01 L 期间物理帧从 ~0.5ms 飙到 8~14ms。用计时拆分（`process_collisions` + `TIME_PHYSICS_PROCESS`）实测后**推翻早期估算**：

> 关键证据：同样 600+ 颗弹，某帧 total=3.45ms、另一帧 total=12.88ms——差在那帧**是否在同帧分裂**。碰撞（col）700 颗仅 **0.4~1ms**，几乎不花钱。

| 构成 | 实测 | 结论 |
|------|------|------|
| 碰撞（空间哈希重建 + 判定） | **0.4~1ms** | ~~早期估 3-5ms~~ ❌ 虚警，**不值得优化** |
| 协程稳态 tick（360 颗弹） | ~1-2ms | 非主因 |
| **重新发射回收**（同帧多颗撞墙 → `return_bullet` + `BulletData.new` + 新弹 spawn/雾 Tween） | **~9ms 尖峰** | **主犯** |

> 术语修正：不是"分裂"，是**重新发射一颗新弹**（旧弹回收 + 新弹出射）。机制跟 `radial_accel_bullet` / `non_mid01_bullet` **完全共用**（`BulletData.new().enemy()` → `shoot_spread` → `return_bullet`）——差异仅"发什么/方向/触发"。故优化应打在**共享路径**，三家 + 以后所有重新发射全受益。

#### 优化"重新发射回收"（✅ 部分落地 / 剩余待做）

- **✅ 已完成**：`BulletManager.re_fire(bullet, data, dir, at)`（内部 `bullet.bind(...)` 复用原弹，不回收不新建）。NON01（`bounce_bullet._re_fire`）+ radial（`_spawn_downward`）已接线。单颗重发射省掉 `_request_bullet` + `_return_to_pool`（子节点遍历/is_connected 查询/入池）。
- **剩余**：
  - 圈弹（non_mid01 1→N）：重绑定 1 颗 + 只新建 N-1 颗。
  - `_return_to_pool` 去掉每颗 `get_children()` 遍历 + `is_connected` 查询（雾无信号需断时跳过）。
  - 雾 Tween 只在确有雾时 `create_tween`。
- **预期**：尖峰 12ms → ~6ms（re_fire 砍一半；全量在下面的数据驱动）。

#### 备选（内容层，非重构，可即时缓解）

- 降 L 密度：`non01_shoot.gd` `_burst_count=[3,6,9,12]` → `[3,6,8,10]`；`diff_pick([15,20,25,30])` → `[15,20,25,27]`。
- 直接减少同帧重新发射颗数，物理尖峰立降。

### AoS（数据驱动子弹）改造路线（2026-08 定稿）

> 边界：**只动"高频率、纯逐帧"的子弹行为**（`bounce`/`radial`/`aim_flee`）；**协程系统（关卡时间线/敌人/Boss/玩家射击）完整保留**——它们真用 await/timeline/pause，且是"低数量、复杂"场景。不是"把协程系统拆了"，是"纠正用协程壳子跑简单子弹行为"。

1. **边界**：子弹行为从 `extends CoroutineScript(Node)` → `extends RefCounted`；系统循环调 `behavior.tick(b, dt)`。（注：子弹行为本就走 `tick_fast` 快速路径，从未用 await/timeline/parallel，摘壳子零损失。）
2. **分发方式**：推荐 **行为对象（③）**——脚本改 RefCounted 即可，逻辑照搬、手感几乎不变、迁移成本最低；或 **注册表（②）**——Callable 表分发，加行为零改 match。（不用手写巨型 match。）
3. **重新发射**：配合已落地的 `re_fire`，从"拆房重建"→ **改数据**（behavior/参数/方向赋值）。
4. **迁移顺序**：①试点——先只转 `bounce` 一个行为（③），跑通 + 基准对比；②验证后再铺 `radial`/`aim_flee`/圈弹。

**未定岔路：子弹本体走到哪一层**

| 层级 | 子弹本体 | 改动量 | 收益 |
|---|---|---|---|
| **Tier 1（轻）** | 保持 `Bullet` Node，只把行为搬出去 | 中 | 中等 |
| **Tier 2（重）** | 弹 = 纯数据（无 Node），系统算移动/碰撞/渲染 | 大 | 全量（12ms→~2ms） |

> 建议：先走 **Tier 1 试点**（行为搬出、验证思路），**再定要不要冲 Tier 2**（纯数据）。Tier 2 才是全量收益，但动整条子弹管线（bullet.gd/BulletData/池/渲染/碰撞），试点后看值不值。

---

## 🔮 计划中的改进

| 优先级 | 改进 | 说明 |
|--------|------|------|
| 🔴 P0 | ~~共享 StageContext~~ | 已由阶段 2 服务层落地（Enemy/Boss/Player 注入 ctx） |
| 🟡 P1 | ~~Replay 录输入基础设施~~ | ✅ 已完成（`ReplayRecorder` + `test_replay_recorder` 就绪；仍缺 gameplay 接线 + 回放播放器） |
| 🟡 P1 | **高频路径禁 RefCounted 规则** | bullet.bind() / _physics_process 碰撞 / return_bullet 禁止 new() |
| 🟡 P1 | **性能优化专项：优化"重新发射回收"（实测主因）** | 见「性能优化专项（2026-08 · NON01 卡顿排查）」专节：实测碰撞仅 0.4-1ms（虚警），12ms 尖峰来自**同帧大量重新发射**（`return_bullet`+`BulletData.new`+雾 Tween）；与 radial/non_mid01 共用，改共享路径；碰撞增量方向已否决。`BulletManager.re_fire()` 已落地（✅） |
| 🟡 P1 | **子弹数据驱动系统（AoS，ECS 近亲）** | 见「性能优化专项」节的 **AoS 改造路线**：只动高频率逐帧子弹行为（`bounce`/`radial`/`aim_flee`），**协程系统完整保留**；行为改 `RefCounted` + 系统 loop（行为对象/注册表分发）；先 Tier 1 试点再决定 Tier 2 纯数据。全量红利但**大改造**。`re_fire` 已作增量踏板 ✅ |
| 🟢 P2 | **MenuLogic 拆分** | NavPage 逻辑与视觉分离（等第三个需要大量覆写 NavPage 的菜单出现时） |
| 🟢 P2 | ~~配置校验层~~ | ✅ 已完成（PhaseData `validate()` 含 time_limit 防除零，已接线多个加载点） |
| ⚪ P3 | ~~批量子弹渲染优化~~ | ~~利用 MultiMesh 减少 draw call~~（use_multi_mesh 已启用） |
| ⚪ P3 | **PauseMenu/GameOverMenu 去重** | 抽 OverlayPage 基类 |
| ⚪ P3 | **对话多语言（远期可选）** | 台词已代码化（`DialogueSteps` 内联）；如未来做多语言，用台词查表 `DialogueL10n.tr(key, fallback)` 包装，不引 id 中间层（2026-08 决策：当前无需求，不落地） |
| ⚪ P3 | **手机做内容 + 关卡热重载（方向，未启动）** | 手机当代码编辑器改 GDScript（git push）→ PC 跑着的游戏自动重载 `.gd`/`.tres` 实时预览。前提：①内容统一 `load()` 不 `preload()` ②加载前 `remove_from_cache` ③文件 mtime 轮询 / 快捷键触发重载。甜区：阶段式加载（`start_phase` 读 PhaseData）+ 短命子弹协程，天生适合。救不了"在手机上看效果"（需 mobile build + 远端同步）。 |

---

## 🐛 已知技术债务

### 代码层面

| 问题 | 位置 | 严重度 | 状态 |
|------|------|--------|------|
| ~~激光池 clear() queue_free 池对象~~ | laser_engine.gd | 高 | ✅ fixed |
| ~~Boss phase 同帧双掉落~~ | boss.gd | 高 | ✅ fixed |
| ~~默认弹双倍速~~ | bullet.gd | 高 | ✅ fixed |
| ~~SpatialHash（P-10 全量碰撞）~~ | bullet_physics.gd | 中 | ✅ 已启用（O(n×m)→O(n+k)，spatial_hash.gd）|
| ~~StageContext 每弹创建~~ | bullet.gd | 中 | ✅ fixed（2026-08 共享 `get_bullet_ctx()`）|
| ~~关卡退出时 RefCounted 残留~~ | 全局 | 低 | ✅ 已修复（StageContext 服务环改为 WeakRef；新增生命周期回归测试）|
| ~~Enemy take_damage 缺 negative guard~~ | enemy.gd | 低 | ✅ 已修复（hp<=0 判定） |
| ~~is_queued_for_deletion 检查不全~~ | 多处 | 低 | ✅ 已补全（active_enemies/active_bullets 遍历点全部覆盖）|
| ~~Timeline loop 重置时间戳精度~~ | timeline.gd | 低 | ✅ 已修复（按 _loop_start 重排 + 恢复 repeat 配置 + 去每帧 lambda）|
| DifficultyScreen 覆写 NavPage 90% | difficulty_screen.gd | 设计 | P2 |
| ~~layout_mode 混用 0/1/3~~ | 部分 UI .tscn | 低 | ✅ 已规范化（0=position/1=anchors/2=container/3=uncontrolled）|

### 数据层面

| 问题 | 位置 | 状态 |
|------|------|------|
| ~~.tres 配置无校验（time_limit=0 会除零）~~ | PhaseData 等 | ✅ fixed（`validate()`）|
| ~~SpellRecord @export 字段缺注释~~ | spell_record.gd | ✅ fixed（已补 ## 注释）|
| ARCHITECTURE_ROADMAP 文档残留 EnemyService（已移除） | 本文档 | ✅ 正文已清（本条为技术债自述）|

---

## 🚧 缺失功能

| 功能 | 优先级 | 说明 |
|------|--------|------|
| **Bomb 系统** | 🔴 高 | FACTION_BOMB / bomb_count 已有，X 键输入未接读取，无释放 |
| **Stage 2~6** | 🔴 高 | 只有 Stage 1（stage03B 是测试符卡资源，未接入主流程）|
| **Stage Practice** | 🟡 中 | 菜单是占位（仅设 is_stage_practice + 标题渐显）|
| **Replay 播放器** | 🟡 中 | 录制器 ReplayRecorder 已写好（未接 gameplay），缺回放播放器 |
| **Continue 系统** | 🟢 低 | GameOver 只有 Retry/Title |
| **Result 结算画面** | 🟢 低 | 通关直接回菜单 |
| ~~Option 音量~~ | 🟢 低 | ✅ 已绑定（Option 菜单 ←/→ 键调 value → AudioManager.bgm/sfx_volume）|

---

## 📊 内容完成度

| 类别 | 进度 |
|------|------|
| 引擎 | ████████████████████ 95% |
| 关卡 (6面) | ████ 20% (仅 Stage 1) |
| 美术 | ██████ 30% |
| 音效 | ██████ 30% |
| 叙事 | ██████████ 50% |
| 打磨/QoL | ██████████████ 70% |

---

## 代码风格规则

- **文件名**：核心实体可短名（boss/bullet），其余 `snake_case.gd`
- **class_name**：永远 PascalCase
- **注释**：`## 类描述` + `@export` 行内 `##`
- **章节分割**：>50 行加 `# ═══`
- **随机数**：必须走 `RNG`，禁止全局 `randf()`
- **GameState**：通过方法读写，不直接改属性
- **高频路径禁 new()**：bullet.bind() / _physics_process / return_bullet 等每弹/每帧路径禁止分配对象（StageContext 已懒加载服务）

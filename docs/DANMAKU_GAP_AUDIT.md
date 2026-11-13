# 弹幕表现力差距审计

> **状态**：AI 生成，未经人工逐条复核；结论基于 2026-11-12 的代码快照，代码变更后可能失效。
> **引用**：文中 `C:` / `B:` 指两份未入库的外部研究（理论天花板设计 / 8 个标杆实现调研），仅作对照，不是项目文档。

**更新记录**
- 2026-11-12：D1（扫掠碰撞）已修复：内核新增上一帧位置、`hit_test_swept`、宽相按最大帧位移外扩；宿主命中/擦弹/自机弹改走扫掠；新增回归测试（851 用例）。
- 2026-11-13：**修正状态**：D1 已完成；D2 当时只完成「扫掠检测」，`_grazed` 仍是**终生一次**。原文的「D1/D2 均已修复」是误记。
- 2026-11-13：D2 已实现：`_graze_tick` 按 tick 记录，`is_grazed` 只在当前 tick 为真；新增跨 tick 擦弹回归（852 用例）。
- 2026-11-12 起：本审计作为 `TODO_TEMP.md` Z 段「下一阶段大方向」的依据；执行项只提炼到 TODO，不在此处维护清单。

**被审计项目**：`/home/cirno/Projects/DiscreteProject/1-st-touhou-star-~-broadest-and-narrowest`（Godot 4.7 + GDScript + GDExtension `DanmakuStore`）
**对照文档**：`ceiling-design.md`（理论天花板，下称 C）、`benchmark-survey.md`（标杆测绘，下称 B）
**审计日期**：2026-11-12
**方法**：读 `docs/ARCHITECTURE.md` / `DANMAKU_API.md` / `CONTENT_AUTHORING_CONTRACT.md` / `BEST_PRACTICES_BASELINE.md`，再按需读 `scripts/**`、`gdextension/src/**`、`data/**`、`tools/**`；本机 headless 实跑 `tools/bench_danmaku.tscn` 与 `tools/bench_native.tscn`（Godot 4.7.2.stable.arch_linux）。

**证据与状态口径**

- 证据一律写 `相对路径:行号`；路径相对项目根。
- 状态只有四种：**已有**（有实现证据） / **部分**（骨架在、链路缺环） / **缺失**（找不到实现） / **未验证**（需实测，代码读不出结论）。
- 本报告不含正面评价；只写事实、差距、代价、风险。
- 人日 = 1 名熟悉本项目的程序员 1 个工作日；区间下限=只做最小可验证闭环，上限=含迁移既有内容与回归。

---

## 0. 必须实机验证的项（先列：代码读不出结论）

| # | 项 | 为什么代码判断不了 | 验证方法 | 需要的条件 |
|---|---|---|---|---|
| V1 | 满载 60 fps 是否成立（S9 标 🚧） | 项目无 GPU 计时，bench 是 headless（`tools/bench_danmaku.gd:11`「GPU 绘制不计」）；`BEST_PRACTICES_BASELINE.md:30` 自标「满载 60fps 待实机确认」 | 真实 Boss 战/符卡练习里用 `FlightRecorder`（`scripts/debug/flight_recorder.gd:1-6`）采 `active_count` 峰值 + `Performance.get_monitor(TIME_PROCESS/TIME_FPS)` + GPU timestamp；同一张卡跑 3 次 | 有 GPU 的机器，至少 3 张密度最高的卡 |
| V2 | 高速弹是否真的穿透 | 离散判定下是否漏检，取决于实际内容的速度/半径组合，代码只给出机制（见 D1） | 对每张卡统计 `speed * dt` 与 `2*(r_hit + r_player)` 的比值；构造 speed ≥ 1200 px/s 的弹型，人眼 + 慢放录屏比对「贴脸被穿过」 | 可改内容的运行环境 |
| V3 | 擦弹手感（40 px 擦弹圈、每弹终生一次） | `player.gd:72` 的 40 与 `danmaku_store.cpp:158` 的「终生一次」是否构成「贴脸不擦、隔远才擦」，只能人手判断 | 固定一波弹，用 `ParamTrace`/自建探针记录每次擦弹的最近距离分布；与 C:134-135 的「每 tick 路径擦弹」对照 | 人手试玩 ≥1 小时 |
| V4 | 回放是否逐帧一致 | 播放器不存在（见 F4），无输入回放→状态比对链路 | 先实现播放器（F4），再录 10 分钟同种子跑两遍比对哈希 | 需先补 F3/F4 |
| V5 | 跨平台一致性 | 无 CI 真机、无状态哈希（F3/F5）；浮点内核（`danmaku_store.h:30-49`）在 ARM64 上是否逐位一致无从判断 | GitHub Actions 上 x86-64 与 ARM64 各跑同一 bench + 同种子 5000 tick，比对 pos/vel 位模式 | CI 双架构 runner |
| V6 | 卡顿/断点下的处理落 | `integrate` 把 dt 钳到 0.4 s（`danmaku_store.h:58`），一帧最多走 0.4 s 位移；实际卡顿时是「跳一段」还是「匀速补帧」需实测 | 人为 `Engine.time_scale`/sleep 注入 200 ms 卡顿，录屏看弹幕是否瞬移 | 运行环境 |
| V7 | 1024 初始容量扩容时的抖动 | 容量倍增在 GDScript 侧（`kernel_native_system.gd:19,100-116`），扩容会重分配 GPU 缓冲（`bullet_multi_mesh.gd:246-248`） | 打一张弹数跨越 1024/2048/4096 的卡，采帧时间尖峰 | 运行环境 + 探针 |
| V8 | 判定与视觉的偏差是否可感知 | 多个弹型判定带 offset（`DANMAKU_API.md:495-507`，如箭弹 x+20、火弹 x+11），且 `follow_dir` 时判定随速度旋转（`danmaku_store.cpp:1303-1307`） | 打开 `scripts/debug/hitbox_visualizer.gd` 叠判定圈，逐弹型截图比对 | 运行环境 |
| V9 | 每张卡的实际弹数峰值 | 内容脚本没有声明弹数；`active_count` 含纯特效行（`bullet_manager.gd:68-69`） | 用 `FlightRecorder` 跑完 26 张卡（`data/**/phase/**.gd` 计数 = 26），输出每卡峰值 | 26 张卡可跑 |
| V10 | 激光「24 点折线」在长弯激光上的判定误差 | 段数固定 24（`laser_beam.gd:136`），误差随曲率×长度增大，代码不报错 | 构造 600 px 长、90° 弯的激光，测点到折线距离与解析曲线的最大偏差 | 运行环境 |
| V11 | 音效密度压制在满载下的表现 | `SFX` 有密度压制/驱逐（`DANMAKU_API.md:537`），满载时是否吞掉关键音效需听 | 满载卡 + 命中音效密集段，录声并统计实际播放次数 | 人手试听 |

> 除 V4/V5 依赖未实现功能外，V1/V2/V3/V6/V7/V8/V9/V10/V11 均可在当前代码上直接测；未测之前，本报告涉及这些项的结论一律标 **未验证** 或 **估算**。

---

## 1. 差距总表

> 「标杆做法」列括号内为来源行号：C = `ceiling-design.md`，B = `benchmark-survey.md`。
> 迁移成本只算到「能被内容用上并可验证」；不含美术与内容重写。

| # | 维度 | 现状（证据） | 状态 | 标杆做法（来源） | 差距本质 | 成本(人日) | 风险 | 优先级 |
|---|---|---|---|---|---|---|---|---|
| A1 | pattern 组合层（mirror/rotate/repeat/delay） | 单弹层有 11 Move / 8 Until / 10 Action 可拼（`docs/DANMAKU_API.md:116-176`）；波次层只有 1 个 pattern：`data/patterns/ring.gd`（`data/patterns/` 仅 `ring.gd` + `presets/ring_default.tres`），54 个内容 `.gd` 中仅 1 个引用 `BulletPattern`（`data/stages/stage01/phase/卡摩瑞一非/卡摩瑞一非.gd`）；`BulletPattern.fire()` 是一次性发射签名（`scripts/patterns/bullet_pattern.gd:14`），无修饰子 | 部分 | 8 种 Op 可 include、可被修饰子包裹（C:47）；`mirror×2 / rotate(k)×k / repeat(n)×n`（C:74） | 缺「组合层」这一整层；单弹可叠加、波次不可组合，作者只能用 `for` + `wait` 手写 | 6–10 | 组合子若落在 GDScript 每帧路径，会把逻辑从内核拉回脚本，密度下降；26 张手写卡与组合层并存会形成第二套写法 | **P0** |
| A2 | 模板复用 / include | `BulletData` 实例复用有约束（`DANMAKU_API.md:95-99`、陷阱 1 `:584`）；`PatternParams.template` 按引用共享（`scripts/patterns/pattern_params.gd:10-14`）；无 include、无参数化模板库；一卡一脚本，54 个内容文件共 2475 行，靠复制 | 部分 | 文本模板 + 表格/节点图三视图同一 CST（C:76） | 复用粒度停在「对象实例」，没有「模板」这个可参数化单位 | 2–4（并入 A1） | 与 A1 同批；单独做会变成又一套 `preload` 约定 | P1 |
| A3 | 组合阶（E3 增长阶） | 每波 = 一次 `shoot_spread`/`for` 循环（`data/stages/stage03B/phase/哆来咪三符/哆来咪三符.gd:150-156`），重复靠 `_tick` + `return p_ctx.clock.wait(...)`（同文件 `:161`）；无「一个模板展开出 N 个独立 spawn」的计数与量尺 | 缺失 | 6 行模板展开 ≥150 个独立 spawn 作为 E3 量尺（C:87） | 组合是线性的：内容行数 ∝ 波次数；乘性组合不存在 | 2–3（只加展开计数测试） | 无展开器时该指标只能当文档口径，不产生行为 | P1 |
| B1 | 每弹状态机（飞行中改行为） | 相位链 + `until` + `on_end` 构成有限状态机（`DANMAKU_API.md:105-114`），Action 可 `emit`/`emit_variant`/`despawn`/改朝向（`:157-176`）；状态槽上限 8 且作者不可见（`:207-211`）；无逐帧回调、无分支（`chance_toward` 只有 0/1 两支，`:592`）；`on_end_call` 每相位一次、宿主侧、非热路径（`:170,598`） | 部分 | 每颗子弹挂逐帧 `yield` 的 task、运行时改写自身并再生成（B:23）；对象 frame 回调 + 协程（B:24,174-178） | 有「记忆」但无「判断」：行为是发射前写死的相位表，不是运行时按状态分支的程序 | 3–5（扩固定词汇） / 15–30（做任意每弹脚本） | 任意脚本会让解释开销压密度（C:257 估 3–5 万上限）；现有固定词汇已覆盖 26 张卡，扩词汇的边际收益需用内容缺口证明 | P1（扩词汇） |
| B2 | 每弹任意逻辑（VM/字节码） | 不存在；`register_program` 只接受白名单 opcode（`gdextension/src/danmaku_store.h:59-74`），未知 op 由 `lifecycle_compiler.gd` 拒绝编码 | 缺失 | 子弹即程序、pc/stack/locals、每 tick ≤64 指令（C:252-258） | 架构选择而非疏漏：当前选了固定词汇，代价是「条件行为」只能靠相位表近似 | 15–30 | 见 §3：现阶段收益低 | P2 |
| C1 | 时间模型（整数 tick / 可回溯） | `Timeline._elapsed: float`（`scripts/coroutine/timeline/timeline.gd:36`），事件是 `Callable` 闭包（`:33,69`），`tick(delta)` 浮点累加（`:162`）；内核 `integrate(double p_delta)` 直接吃浮点秒（`danmaku_store.cpp:325-327`） | 缺失 | `Clock(tick) → Timeline → Segment → Wave → Emitter → SpawnRecord`，全由整数 tick 驱动（C:96-101） | 没有 tick 这个一等公民：pause/scrub/回溯/确定性回放都缺锚点 | 5–8 | 重写编排层牵动 26 张卡 + 全部 stage 脚本；`Callable` 闭包无法序列化，回溯仍需整段快照 | P1 |
| C2 | 阶段转移是否纯函数 | 转移 = `boss.phase_cleared.emit(...)`（`scripts/enemy/boss.gd:451`）+ `get_tree().create_timer(...)`（`:473`）+ 回调里改 `_cursor`/`next_at`（`timeline.gd:87-101,113-129`） | 部分 | 转移条件 `(hp, tick, events) -> next`，禁副作用（C:104） | 转移是副作用集合，回放无法「只凭初始状态重算阶段序列」 | 3–5 | 依赖 C1；改完与现有 `BossData.phases_*`（`docs/CONTENT_AUTHORING_CONTRACT.md:25`）语义要对齐 | P2 |
| C3 | 编译期事件表 | 只有 per-bullet packed program（`lifecycle_compiler.gd:1-8`；`danmaku_store.h:75-77` 的 `_p_ops/_p_args` 偏移表）；无 `tick → SpawnRecord[]`，无 32B 布局，句柄是 int64 uid（`danmaku_store.h:80`）而非 (index20,gen12) | 缺失 | 事件表编译期展开 + 游标摊销 O(1)（C:108-110）；32B SpawnRecord（C:110） | 批量生成是「每帧 GDScript 调 spawn」，不是「编译期展开 + 游标扫过」 | 10–20 | 需要先有 C1 的整数 tick 与内容 IR；否则表无从生成 | P2 |
| D1 | 碰撞是否扫掠（防高速穿透） | 已有 `hit_test_swept`（`gdextension/src/danmaku_store.cpp:1345`）与上一帧位置；宿主命中 / 自机弹已改走 swept（`scripts/kernel_bridge/kernel_bullet_physics.gd:61,94`）；回归见 `test/test_kernel_physics.gd:82-93` | **已有（2026-11-12）** | 线段 A→B 到点 P 的最近距离，退化点-点（C:134） | 机制已补；剩余风险是高速/大判定的内容平衡，不是实现缺失 | 0 | 有效判定变大 → 玩家体感变严，需实机调参 | 已完成 |
| D2 | 擦弹是否按 tick 扫过的路径 | 检测走 swept（`kernel_bullet_physics.gd:64`）；内核 `_graze_tick` 记录当前 tick，`is_grazed` 只判当前 tick（`danmaku_store.cpp:1513`）；跨 tick 回归见 `test/test_kernel_physics.gd` | **已有（2026-11-13）** | 同扫掠公式换 `r_graze`，每颗每 tick 只记一次 `lastGrazeTick`（C:135） | 已实现；剩余是内容侧擦弹经济重调 | 0 | 擦弹数变化会影响计分/记忆经济 | 已完成 |
| D3 | 判定/视觉解耦 | `hitbox_radius/size/offset` 独立于贴图（`DANMAKU_API.md:57-60`），数值在 `data/bullets/*.tres`（`:489-516`），`follow_dir` 时判定随速度旋转（`danmaku_store.cpp:1303-1307`）；调试只有 `scripts/debug/hitbox_visualizer.gd` 单一层 | 部分 | 强制解耦 + 调试层同时画 hit/graze/swept 三色（C:137） | 判定半径可独立设，但视觉→判定的推导链仍是「图集坐标手抄到 tres」，无自动校验 | 1–2 | 主要是加可视层；改数据要重跑 26 张卡 | P1 |
| D4 | 激光处理 | 激光不进弹池，是 `LaserBeam` 节点；`distance_to(pos, count=24)` 固定 24 点折线求点到段距离（`scripts/laser/laser_beam.gd:136-147,282-284`）；判定/擦弹在 `scripts/laser/laser_engine.gd:97-104`，擦弹有全局 3 帧冷却（`:7,100-101`）；死亡清弹圈单独持有 laser_engine（`bullet_manager.gd:95`） | 部分 | 胶囊（线段+半径），弯曲按 曲率×长度/0.5 自适应 12–24 段（C:136） | 段数固定，长弯激光判定误差随曲率增长；激光与弹池两套判定路径 | 2–3 | 自适应分段会改命中判定，已有激光卡需复核 | P1 |
| E1 | 批处理方式 | MultiMesh 按 `tex × faction × tint_mode` 分组（`danmaku_render_bridge.cpp:47-90`），分组/旋转/fill 在原生（`:189-203`）；但每帧从内核拉 8 个快照数组（`bullet_multi_mesh.gd:83-100`），NK6 记「稳态每帧分配」未关（`TODO_TEMP.md` NK6） | 部分 | CPU 写 instance buffer + 1 次 instanced draw（C:167） | 批次维度是「贴图×阵营×tint」，但「每帧全量拷贝 + 每帧分配」使批次只省了 draw call，省不掉拷贝 | 5–8 | 改成持久 buffer/双缓冲要动快照契约（`danmaku_store.h:132-139` 的只读快照），波及渲染/物理/调试三个消费者 | P1 |
| E2 | per-instance 属性 | 每实例只有 `Transform2D(rot, scale=1, pos)` + `Color`（`danmaku_render_bridge.cpp:199-200`）；无 size/hue/glow/typeId/flags 通道；shader 只用 UV/COLOR（`gdshader/bullet_batch.gdshader` 全文） | 缺失 | 16B/实例：pos s16×2 + size u8 + rot s8 + hue u8 + glow u8 + typeId u8 + flags u8（C:176） | E2（单弹维度）被批处理结构锁死：同弹型只能换色/换朝向，不能逐弹变大小/发光 | 4–6 | 需自写 `INSTANCE_CUSTOM` 通道；批次 key 增加维度后 draw call 上升 | P1 |
| E3 | overdraw 预算 / HDR | `project.godot` 无 `[rendering]` 段、无 Environment glow；子弹走 alpha 混合（`bullet_multi_mesh.gd:295-306` 只设 ShaderMaterial），激光可选加色（`laser_beam.gd:219-222`）；无 overdraw 预算/热力图 | 缺失 | HDR+bloom 保留亮核；overdraw 平均 ≤8×、峰值 ≤20×（C:178-180） | 无预算也没有测量，密度上限只能靠「跑起来卡不卡」判断 | 3–5 | 开 HDR/bloom 会改全部子弹观感与填充率，需重测 V1 | P1 |
| E4 | 10 万颗量级可行性 | 容量 1024 起倍增（`kernel_native_system.gd:19,100-116`），溢出 `push_error`（`:177`）；本机实测 8000 弹 CPU 合计 1.957 ms（积分 0.187 / 宽相 0.023 / 渲染同步 1.747），线性外推 10 万 ≈ 21.8 ms > 16.67 ms（**估算，未实测**） | 未验证 | 20–30 万 @60 Hz（C:237）；10 万颗 GPU 2–5 ms（C:186） | 未到 10 万就已在 CPU 侧超预算，且瓶颈是渲染同步而非积分 | 8–15 | 外推基于 8000 的线性假设；真实 10 万要重测；改 E1 前先改会把预算浪费在错误位置 | P2 |
| F1 | 定点数 | 位置/速度全 `float`（`danmaku_store.h:30-32`），数学用 `std::atan2`/`std::sqrt`（`danmaku_store.cpp:1294-1318` 等） | 缺失 | Q16.16 + 自实现 sin/cos 查表 + 禁平台 libm（C:200-202） | 逐位可复现没有基础，replay 只能靠「同机器同构建」 | 15–25 | 全内核重写 + 与 Godot `Vector2` 边界转换；性能会变；收益要等 F4 存在才可验证 | P2 |
| F2 | RNG 分流 | 内核单通道 `_rng_state`（`danmaku_store.h:51-52`），抽取顺序 = 弹行遍历顺序（`DANMAKU_API.md:597` 陷阱 14）；宿主也单通道（`scripts/autoload/rng.gd:9`） | 缺失 | 每消费者一条流，流 ID 由 (patternHash, emitterId, spawnIndex) 派生（C:203） | 增删一个 `random_dir` 会平移后续全部随机序列；内容改动无法局部验证 | 3–5 | 换分流会改所有历史随机结果，现有卡的「手感」全变 | P1 |
| F3 | 状态哈希 | 全仓无 pos/vel/type/flags 的 xxHash；只有内容签名/缓存 hash（`lifecycle_compiler.gd:163-169`、`lifecycle_host_table.gd:40-44`） | 缺失 | 每 30 tick xxHash3，定位首个分歧 tick（C:205） | 无法回答「两次运行是否同一状态」 | 2–3 | 需要先固定参与哈希的字段集合，否则哈希口径会漂 | P1 |
| F4 | replay 是否存在 | `ReplayRecorder` 全仓只出现在自身与 `test/test_replay_recorder.gd`（`grep -rn ReplayRecorder` 无生产接线）；主菜单只打开占位页（`scripts/scenes/replay_menu.gd:1` 注释「占位」，只有淡入淡出 `:6-24`） | 缺失 | 输入录制 2 B/tick + 版本头 + 逐段比对（C:204-206） | 连「录」都没接线；`ARCHITECTURE.md:229` 写「只录不放」高估了现状 | 5–8 | 依赖 F3 才有「一致」的判据；`Callable` 编排不可序列化时 replay 只能重跑同一场景 | P1 |
| F5 | 跨平台一致性测试 | 无 CI 真机；`test/test_kernel_random.gd:41-42` 只断言同进程同种子近似相等 | 缺失 | x86-64 与 ARM64 同输入哈希一致率 100%（C:222） | 一致性是「没有测试」而不是「测过不一致」 | 3–5（CI + 双架构） | 依赖 F3；ARM 上 Godot 浮点差异可能直接红，需先有结论再决定是否上 F1 | P2 |
| G1 | 热重载 | 无 reload 路径（全仓 `reload` 只命中 `GameManager.reload_current_scene()`，`scripts/scenes/game_scene.gd:321`）；创作台/工作台 2026-10-24 退役（`docs/CONTENT_PIPELINE_AUDIT.md:424`），其「热更新约 1–2 秒」随之下线（`:20` 与 `:424` 自相矛盾） | 缺失 | 内容哈希版本化 IR，新 spawn 用新版本、旧弹留旧版本（C:78）；改一行 → 画面 P50 <100 ms（C:84） | 反馈回路 = 改脚本 → 重启场景 → 重打到那张卡 | 8–20 | 内容就是 GDScript（`AGENTS.md`「内容 code-first」），GDScript 热替换带状态恢复在 Godot 里没有官方路径；做不成就是「快照+重进关」 | P2 |
| G2 | 实时预览 | `LifecyclePreview.evaluate_phase/evaluate_chain` 只支持确定性 move，`steer`/目标相关标 `approximate`（`DANMAKU_API.md:280-309`）；telegraph 是路径预测、不是时间预览（`docs/TELEGRAPH_PREVIEW.md:5-15`） | 部分 | 内嵌运行窗口 + 参数面板 + 时间轴（C:210-212） | 只有「这条弹往哪飞」的静态预测，没有「这一秒画面是什么」 | 3–6 | 预测与真实弹道两套实现，`DANMAKU_API.md:309` 已写明不可替代 | P2 |
| G3 | 时间轴 scrub / 单步 | 无；无整数 tick（C1），暂停菜单只有音效（`scripts/scenes/pause_menu.gd:21`） | 缺失 | 拖到任意 tick、单步、回退 300 tick（C:211） | 参数只能靠反复重开卡对比 | 5–10 | 依赖 C1 + 可快照状态；`CoroutineScript` 的 GDScript 栈不可快照 | P2 |
| G4 | 参数面板 | 无（创作台退役，`docs/CONTENT_PIPELINE_AUDIT.md:424`）；现在靠 `.tres` inspector + `diff_pick`（`DANMAKU_API.md:438-445`） | 缺失 | 从 IR 类型自动生成 slider（C:210） | 改一个数要回编辑器/重开场景 | 3–5 | 与「内容 code-first」冲突：参数在 GDScript 变量里，无 schema 可生成 UI | P2 |
| H1 | rank/资源/周目改写弹幕 | 内容直接读 `SaveData.selected_difficulty`（`data/stages/stage03B/phase/哆来咪三符/哆来咪三符.gd:52`）；全局 memory 值直接决定随机清弹（`kernel_bullet_physics.gd:65-71`）；无 rank/周目状态（`grep -rn "rank"` 只命中音频驱逐与难度图片） | 部分 | TERRA/STELLA 式系统直接改弹量/弹速/分支（B:26-27,200-202）；rank 改 Boss 图案分支（B:27） | 全局状态能影响弹幕，但只能靠内容脚本里手写 `if`，不是引擎提供的输入通道 | 1–2（引擎侧只读输入） + 3–5（内容侧分支） | 引擎侧输入很便宜，但内容侧多套 pattern 是内容成本，不是引擎成本 | P2 |
| I1 | 可复现压力测试 | 有 `tools/bench_*.gd`，上限 8000（`tools/bench_danmaku.gd:15`、`tools/bench_native.gd:6`）；`bench_danmaku.gd:57` 引用已删除的 `backend.behavior`，本机实跑 7 次 `SCRIPT ERROR`，行为路径完全没测到；`test/perf_stress/stress.gd:1-15` 只生成 1500 弹、不度量；headless 无 GPU（`bench_danmaku.gd:11`） | 部分 | 每 tick CPU / GPU 帧时间 / 峰值内存基准（C:214） | 压测脚本存在但与实现漂移，覆盖不到主路径（behavior）与 GPU | 1–2 | 修 bench 会立刻暴露 8000 以上的真实数字，可能推翻现有密度假设 | **P0** |
| I2 | 帧预算声明 | 全仓无「帧预算」表（在 `docs/*.md` 搜「帧预算 / 16.67 / 预算」只命中白盒与孤儿节点预算）；S9 标 🚧「满载 60fps 待实机确认」（`BEST_PRACTICES_BASELINE.md:30`、`docs/archive/BASELINE_EVIDENCE.md:116`） | 缺失 | 设计期声明每段 CPU/GPU/overdraw 预算（C:118-120,224） | 没有预算就没有「超了」判据；优化没有靶 | 1–2 | 预算数字若来自不可复现的机器，会变成新的「跑起来不卡」 | **P0** |

### 1.1 逐维度展开（补充证据）

**A. 描述层**

- 单弹层词汇共 11 个 `Move` / 8 个 `Until` / 10 个 `Action`，且有 `then()` 串相位（`DANMAKU_API.md:109-176`）。`LifecycleCompiler` 把 builder 编译成 `ops/args` 偏移表（`scripts/kernel_bridge/lifecycle/lifecycle_compiler.gd:1-8`），这是「组合」的底座。
- 波次层没有组合子：`data/patterns/` 只有 `ring.gd`；`BulletPattern` 只有一个 `fire(ctx, params, origin, direction)` 虚方法（`scripts/patterns/bullet_pattern.gd:14`），`PatternParams` 参数项是 count/speed/spread/interval/duration/aim（`scripts/patterns/pattern_params.gd:24-36`），没有「子 pattern 列表」这一项。
- 代表性内容写法是**手写发射器**：`哆来咪三符.gd:120-156` 在 `_tick` 里逐帧算公转角度/半径/扩张，然后用 `for i in 个数: shoot_spread(...)` 铺一圈，`return p_ctx.clock.wait(发弹间隔)` 控制节奏。换言之「pattern」= for 循环 + 计时器，不在可复用的库里。
- 26 个阶段脚本 / 54 个 `data/**/*.gd` / 15 个调用 `shoot_spread|shoot_directions` 的文件，全部是这种写法（唯一例外是 `卡摩瑞一非.gd` 引用了 `RING`）。

**B. 每弹可编程性**

- 能力边界写在文档里：`on_end_call` 是「逃逸口：每相位最多一次、宿主侧、非热路径；别当 per-frame 逻辑或状态存储」（`DANMAKU_API.md:598`）。这句话本身就是「没有逐帧每弹回调」的证据。
- 状态槽作者不可见、上限 8（`DANMAKU_API.md:207-211`）；超出内核拒绝注册，该弹退化为直线（`:211`、陷阱 13 `:596`）。也就是说「有状态」的表达配额是硬上限 8 个浮点。
- 「条件」只有 `chance_toward` 的 0/1 两支（`DANMAKU_API.md:189,592`），没有 `if x > y` 这种每弹分支。
- 对标：`task` + 逐帧 `yield` 改写自身（B:23）、对象 `frame` 回调 + 协程（B:24）；BulletML 同样没有条件分支（B:133）。固定词汇路线在「单弹条件行为」这一项上低于 B:23-24 的路线。

**C. 调度**

- `Timeline` 自称「纯排程器（零服务层依赖）」（`ARCHITECTURE.md:98`），但它的「纯」只到「不依赖服务」；事件是 `Callable`（`timeline.gd:33,69`），`tick(delta)` 用 float 累加（`:162`），`loop()` 重排依赖 `_original_time`（`:234-243`）。闭包捕获 `ctx`，无法序列化成可回溯事件表。
- 阶段转移：`sequence_phases` 在回调里改 `seq.next_at`（`timeline.gd:113-129`），`Boss` 侧用 `create_timer` 做 hitstop（`boss.gd:473`）。整套转移是「信号 + 计时器 + 可变字典」，不是 `(hp,tick,events) -> next`。
- 编译期事件表：不存在。内核有 per-bullet program（`register_program` → `_p_ops` 偏移表，`danmaku_store.h:75-77,217-222`），语义是「每颗弹每帧跑自己的 ops」，不是「编译期把一波弹展开成 tick→记录」。两者在密度上的差别是「每帧 N 次 GDScript spawn」vs「游标扫过预生成数组」。

**D. 碰撞**

- D1 已有扫掠：`hit_test_swept` 用上一帧位置到当前位置的线段（`danmaku_store.cpp:1345`）；宿主命中 / 擦弹 / 自机弹已接入（`kernel_bullet_physics.gd:61,64,94`）。
- 漏检量级可直接算：单帧位移 = `speed/60`。内容里 `往返弹初速度 175`（`哆来咪三符.gd:44`）→ 2.9 px/帧，小于小玉判定 8（`DANMAKU_API.md:492`），不穿透；当单帧位移 > `2×(r_hit + r_player)`（即 `speed > 120×(r_hit + r_player)`）时，正对穿越必然漏检。自机弹打敌人是同一套 `hit_test`（`kernel_bullet_physics.gd:93`），自机弹速度更高，穿透风险在这一侧。
- D2 仍不完整：检测已走 swept，但 `_grazed` 仅在 spawn 置 0（`danmaku_store.cpp:158`），`mark_grazed` 只置 1（`:1510-1511`），同一颗弹跨 tick 再次贴近不会重新计擦弹。`KernelBulletPhysics` 的 `not system.is_grazed(id)` 仍把它锁成终生一次（`:64`）。
- 擦弹半径 40 / 命中 5（`player.gd:70,72`），比值 8×；C 的口径是 3–5×（C:135）。
- 激光是第二套判定：`LaserBeam.distance_to` 固定 24 点采样（`laser_beam.gd:136-147`），`is_hitting` 用 `hitbox_width=6`（`:15,149-150`），`is_grazing` 用 `graze_width=22`（`:17,154-155`），并且擦弹有全局 3 帧冷却（`laser_engine.gd:7,100-101`）——即多根激光共用一次擦弹配额。

**E. 渲染**

- 批次 key = `tex_base * 16 + host_faction * 2 + tint_mode`（`danmaku_render_bridge.cpp:83`），批次数 = 贴图种类 × 阵营 × tint 模式；但每帧仍要 `get_positions/get_velocities/get_render_rots/get_colors/get_type_indices/get_factions/get_fx_phases/get_fx_type_indices` 共 8 次全量快照（`bullet_multi_mesh.gd:83-100`），每次返回新 `Packed*Array`。
- 每实例写入只有 `set_instance_transform_2d` + `set_instance_color`（`danmaku_render_bridge.cpp:199-200`），scale 恒为 `(1,1)`（特效行例外，`:207-213`）。E2 的 10 个参数里，逐弹可变的只有「位置、旋转、染色、alpha」。
- 无 HDR/bloom：`project.godot` 只有 `[application]/[audio]/[autoload]/[debug]/[display]/[gui]/[input]/[layer_names]/[physics]`，无 `[rendering]` 段，无 Environment；子弹材质只设 `ShaderMaterial`（`bullet_multi_mesh.gd:295-306`），混合模式为默认 alpha。加色只出现在激光（`laser_beam.gd:219-222`）。
- 分辨率：`window/size/viewport_width=1280`、`height=960`、`stretch/mode="viewport"`（`project.godot:72-74`）；场地 768×896（`game_config.gd:10-13`）。C 的逻辑分辨率口径是 480×640（C:12），本项目的逻辑单位与 C 不同，跨文档比较弹数时要按像素面积换算。

**实测数字（本机，headless，2026-11-12，仅供参考，非 GPU）**

| N | 模式 | 积分 ms | 行为 ms | 宽相 ms | 渲染 ms | 合计 ms | 占 16.67ms |
|---:|---|---:|---:|---:|---:|---:|---:|
| 500 | 直线 | 0.019 | 0.000 | 0.002 | 0.118 | 0.139 | 1% |
| 1000 | 直线 | 0.028 | 0.000 | 0.003 | 0.220 | 0.251 | 2% |
| 2000 | 直线 | 0.051 | 0.000 | 0.006 | 0.436 | 0.493 | 3% |
| 3000 | 直线 | 0.067 | 0.000 | 0.009 | 0.634 | 0.710 | 4% |
| 4000 | 直线 | 0.102 | 0.000 | 0.012 | 0.991 | 1.105 | 7% |
| 6000 | 直线 | 0.129 | 0.000 | 0.017 | 1.252 | 1.398 | 8% |
| 8000 | 直线 | 0.187 | 0.000 | 0.023 | 1.747 | 1.957 | 12% |

- 「行为」列全 0 且每次运行 7 条 `SCRIPT ERROR: Invalid access to property or key 'behavior'`（`tools/bench_danmaku.gd:57`）：**带 lifecycle 的路径没有被测到**。
- 对照 `tools/bench_native.tscn`：8000 弹积分 0.020 ms、`fill_multimesh` 0.195 ms → 内核本身不是瓶颈，GDScript 侧快照 + 分组 fill 是（1.747 ms 里绝大部分）。
- 线性外推 10 万弹：渲染同步 ≈ 21.8 ms/帧，超 60 Hz 预算。**这是外推，不是实测**。

**F. 确定性/回放**

- 全 float：`std::vector<float> _x,_y,_vx,_vy`（`danmaku_store.h:30-32`），无定点、无自定义数学库。
- RNG 单通道：内核 `uint32_t _rng_state`（`danmaku_store.h:51-52`），`DANMAKU_API.md:597` 自己写明「加/删/重排 random_dir 会平移后续随机序列」；宿主 `RNG` 也是单 `RandomNumberGenerator`（`rng.gd:9`）。
- replay：录制器是死代码（无生产接线），`replay_menu.gd` 是占位页。所以「回放一致率」这项没有任何可测对象。
- 跨平台：无测试。

**G. 工作流**

- 迭代闭环：改内容 → `GameManager.reload_current_scene()`（`game_scene.gd:321`，暂停/重开走同一路径）→ 重新进关 → 打到那张卡。符卡练习可缩短到「选卡→开打」，但没有脚本级热替换。
- 曾有「组合台热更新 1–2 秒、固定种子、逐帧、书签」（`CONTENT_PIPELINE_AUDIT.md:20`），2026-10-24 全部退役（`:424`）；`TODO_TEMP.md:6` 记「不再做图形编辑器；反馈回路 = 游戏内符卡练习 + 无头检查」。因此 G1/G3/G4 的现状是**缺失**，不是**部分**。
- 预览：`LifecyclePreview` 可算单 phase/chain 的点列（`DANMAKU_API.md:284-298`），但 `steer`/目标相关被跳过并标 `approximate`（`:302`），`position` 锚点直接 `ok=false`（`:303`）。

**H. 系统耦合**

- 内容直接读全局难度：`var 难度为Hard以上: bool = SaveData.selected_difficulty >= Difficulty.HARD`（`哆来咪三符.gd:52`），且注释写明「脚本实例化时读取一次；中途改难度不会重新分派」。
- 全局资源反向改弹幕：`memory_value >= 50` 时按 `remap(...)` 的概率 `RNG.randf()` 随机清弹（`kernel_bullet_physics.gd:65-71`）。这条逻辑在宿主碰撞层，不在 lifecycle 描述符里，内容与内核都看不到它。
- 无 rank/周目：`grep -rn "rank"` 只命中 `audio_manager.gd:494` 的音频驱逐和 `character_screen.gd:11-14` 的难度图片路径。

**I. 性能预算**

- 有压测脚本、有「60fps 预算 16.67ms」的字面常量（`bench_danmaku.gd:19`），但没有「哪张卡允许超多少」的声明，也没有把数字写进文档的预算表。
- `BEST_PRACTICES_BASELINE.md:30`（S9 🚧）+ `docs/archive/BASELINE_EVIDENCE.md:116`（「需实机确认」）是项目自己的结论。
- 压测脚本与实现漂移（I1），导致「有 bench」不等于「能回归」。

---

## 2. 最值得做的 3 件事

### 2.1 tick 级擦弹（D2，已完成）

2026-11-13 已落地：`_graze_tick` 按 tick 记录，`is_grazed` 只在当前 tick 为真；新增「同一颗弹连续两个 tick 贴近 → 计两次」回归。剩余风险只有内容侧：擦弹数会变化，26 张卡的计分/记忆经济需要复核（见 S13）。

### 2.2 修好压测 + 写死帧预算（I1 + I2）

**为什么是它**：E4/E3/E1 的所有结论都依赖「10 万颗到底几毫秒」，而现在 bench 的行为分支直接 `SCRIPT ERROR`（本机实测 7 条），量程只到 8000，且无 GPU 计时。这件事成本最低、解锁最多后续判断；不做，2.1 和 2.3 的效果都无法验收。

**具体步骤（文件级）**

1. `tools/bench_danmaku.gd:33-70`：删掉 `backend.behavior`（属性已不存在，`KernelBulletHost` 只有 `system`），改为直接给弹绑定 lifecycle program（`KernelNativeSystem.spawn` + `set_program`，参考 `test/test_kernel_random.gd:27-31` 的 `_reg` 形态）。
2. `tools/bench_danmaku.gd:15`：`COUNTS` 改为 `[8000, 20000, 50000, 100000]`；每档先 `reserve()` 再 spawn，避免把扩容算进稳态。
3. 新增 `tools/bench_budget.gd`（或给现有 bench 加 `--assert`）：读 `tools/bench_budget.json`（每档 CPU 积分/宽相/渲染同步/总计上限），超预算 `quit(1)`。
4. GPU 侧：在场景里加 `RenderingServer` 的 frame time 采样或 viewport `get_frame_time`，输出「几何/填充/UI」近似分段；标注「非 timestamp query，仅参考」。
5. `docs/BEST_PRACTICES_BASELINE.md`：新增「帧预算」小节（每档上限 + 测量命令 + 机器型号），并把 S9 的证据列改指向该小节；同步 `docs/archive/BASELINE_EVIDENCE.md`。
6. `test/perf_stress/stress.gd:1-15`：加 `active_count` 峰值与每帧 ms 打印，或直接删掉（避免「有压测」的错觉）。

**验收指标（可测量）**

- 10 万弹场景能跑完并输出三段 ms；连续 3 次运行的合计 ms 方差 < 10%。
- `bench --assert` 在超预算时退出码 ≠ 0。
- 文档里每个密度档都有「上限 ms」与「实测 ms」两列，且实测列有机器型号与日期。
- 「行为」列不再全 0（至少 8000 档有非零值）。

**人日**：2–4。
**风险**：实测一到 10 万就会暴露 CPU 侧超预算（外推 21.8 ms），可能迫使 E1 提前；headless 的 GPU 数字不可信，写进文档时必须标「CPU-only」。

### 2.3 pattern 组合子层（A1 + A2 + A3）

**为什么是它**：26 张卡、54 个内容脚本里，除 1 个引用 `RING` 的脚本外全部用 `for` + `wait` 手写（`哆来咪三符.gd:120-161`）；`data/patterns/` 只有 1 个 pattern。内容产能是当前唯一随卡数线性增长的成本，而 C 的口径是「6 行模板展开 200+ 弹」（C:74）。这是 P0 里唯一直接提高「单位人力能写出多少弹幕」的项。

**具体步骤（文件级）**

1. `scripts/patterns/pattern_op.gd`（新增）：`Op` 树节点 `{kind: SPAWN|MIRROR|ROTATE|REPEAT|DELAY, children, args}`；`expand() -> Array[Emit]`，`Emit = {dir, speed_delta, delay, bullet}`。
2. `scripts/patterns/bullet_pattern.gd:14`：把 `fire()` 改为 `compose(ctx, params, origin, dir) -> Array[Emit]`（保留 `fire()` 作为 `compose` + 立即发射的默认实现，防 26 张卡一次性迁移）。
3. `scripts/coroutine/services/bullet_service.gd`：新增 `shoot_emits(emits)`，把 `delay` 编成 lifecycle 的相位而不是 `await`（否则又把逻辑拉回 GDScript）。
4. `data/patterns/`：新增 `fan.gd`、`aimed.gd`、`arc.gd`、`laser_fan.gd`；`ring.gd` 迁到 `compose`（其 `spread_directions` 逻辑保留，`data/patterns/ring.gd:14-33`）。
5. `data/patterns/presets/`：每个 pattern 一份 `.tres`（`PatternParams`），供 inspector 调参。
6. 选 3 张卡重写（建议 `哆来咪三符`、`卡摩瑞二符`、`卡摩瑞一符`），对照弹数与手感。
7. 新增 `test/test_pattern_compose.gd`：断言 `mirror(ring(16))` 展开 32 个 emit；`repeat(3, 0.35s)` 展开 3 组且 delay 单调；`rotate(k)` 展开 k 份。

**验收指标（可测量）**

- 一个 6 行模板（含 mirror + rotate + delay）展开的独立 spawn 数 ≥ 150（C:87 的量尺）。
- 3 张重写卡的「弹数 / 总波次 / 脚本行数」三个数字进报告，脚本行数下降且弹数不下降。
- `test_pattern_compose` 全绿；`check_content.sh` + `content_preflight.sh` 不新增违规。
- 展开不产生每帧 GDScript 调用（delay 走 lifecycle 相位，可用 `get_phase(id)` 断言）。

**人日**：6–10。
**风险**：组合子若把执行留在 GDScript，会把弹幕逻辑从内核拉回脚本，与「GDScript 不进每帧每弹路径」（`DANMAKU_API.md:22`）冲突；26 张卡迁移不彻底会长期存在两套写法，而 `CONTENT_AUTHORING_CONTRACT.md:54` 已经把「同一脚本×同一张卡×只差几个数」定为 `params` 的场景，组合层要避免与 `params` 争夺同一职责。

---

## 3. 不建议做的事

1. **GPU compute 积分 / 常驻 GPU 弹池（架构 B）**。理由：当前实测 8000 弹内核积分 0.020 ms（`bench_native`），瓶颈在 GDScript 快照与渲染同步（1.747 ms），不在积分；C 也把 B 的收益判为「20 万颗之后趋近于 0」（C:280）。引入 GPU 回读会直接冲击擦弹的 tick 精度（C:248），而 D2 的 tick 级擦弹还没做。等工作量落在「E1 已做到 10 万且仍在 CPU 侧卡」时再评估。
2. **每弹任意字节码 VM（架构 C / B2）**。理由：固定词汇（11 Move / 8 Until / 10 Action）已覆盖 26 张卡；VM 的解释开销按 C 的估算是 3–5 万颗上限（C:257），会把密度主动压到当前实测量级以下。真正缺的是「条件分支」这一项能力，扩 2–3 个 opcode（如带条件的 `on_end`、按 `until` 结果二选一的 `emit`）比上 VM 便宜一个数量级。
3. **重建图形编辑器 / 创作台**。理由：2026-10-24 已退役并留下理由（`docs/CONTENT_PIPELINE_AUDIT.md:424`、`TODO_TEMP.md:6`）；`CONTENT_AUTHORING_CONTRACT.md:77` 也写了「先不要做编辑器」。当前内容层还在变（`params` 反射未全 typed、注册表两套真相），编辑器会把未稳定的抽象固化成 UI。真正缺的「改完到看见」应该用 G1 的整卡重载或 G3 的单步解决，不是 UI。
4. **全套定点数 + 跨平台哈希（F1 + F5 一起上）**。理由：15–25 人日重写内核浮点，而 replay 播放器（F4）还不存在，改完没有验证对象；先把 F3（状态哈希）+ F4（播放器）做出来，用同平台 replay 拿到「一致率」数字，再决定是否需要跨平台；跨平台 CI 若一开始就红，会变成长期红灯而不是信息。
5. **在 1280×960 现有管道上直接冲 10 万颗渲染**。理由：E2（per-instance 属性）与 E1（每帧全量快照）没改之前，10 万颗的 CPU 渲染同步外推已超预算（21.8 ms），先加量只会把预算花在拷贝上；顺序应是 E1 → E2 → 再谈 E4。

---

## 4. 存疑

| # | 存疑项 | 为什么存疑 | 验证方法 |
|---|---|---|---|
| S1 | 「Replay 只录不放」（`ARCHITECTURE.md:229`） | 实际连录都没接线：`ReplayRecorder` 无生产引用，`replay_menu.gd:1` 是占位 | `grep -rn "ReplayRecorder"`（已做）；查 `replay_menu.tscn` 绑定（已做，只有淡入淡出） |
| S2 | `CONTENT_PIPELINE_AUDIT.md:20` 说组合台支持热更新/固定种子/逐帧/书签 | 同文件 `:424` 说组合台已退役；两处冲突 | 读 `:424-437`（已做）；`ls scenes/` 无 `workbench` 目录（已做） |
| S3 | 8000 弹以上是否仍线性 | 外推基于 8000 的线性假设，未测 2 万/5 万/10 万 | 跑修好的 bench（2.2） |
| S4 | 10 万弹 GPU 填充时间 | 无 GPU 计时，headless 不计绘制 | 实机 + GPU timestamp（V1） |
| S5 | 高速弹穿透是否已在线上出现 | 代码给出机制，实际是否发生取决于内容速度；`往返弹初速度 175` 不穿透，自机弹侧未算 | 对每张卡算 `speed*dt / (2*(r_hit+r_player))`；人眼慢放（V2） |
| S6 | 擦弹半径 40 的设计意图 | 8× 命中半径（`player.gd:70,72`）与 C 的 3–5× 不同，是刻意还是历史值无法从代码判断 | 查 `BEST_PRACTICES_LOG.md` / git blame；实机手感（V3） |
| S7 | `_grazed` 终生一次是否刻意 | 代码无注释说明；`DANMAKU_API.md` 未列为陷阱 | 查 git log；`test` 里是否有断言（`grep -rn "is_grazed" test/`） |
| S8 | dt 钳 0.4 s 是否覆盖真实卡顿 | `danmaku_store.h:56-58` 注释「能覆盖常见 2~3 帧卡顿」，但 0.4 s = 24 帧 | 注入卡顿实测（V6） |
| S9 | 26 张卡的实际弹数峰值 | 无统计；`active_count` 含特效行 | FlightRecorder（V9） |
| S10 | `hitbox_size`/`offset` 与图集的手抄是否一致 | 数值在 `data/bullets/*.tres`，来源是图集（`DANMAKU_API.md:489-516`），无自动校验 | 写一个「图集 region 尺寸 vs hitbox 尺寸」的一致性测试，先证明它会红 |
| S11 | 跨平台一致性 | 无 CI 真机、无哈希 | CI 双架构（V5） |
| S12 | 8000 档的「渲染 1.747 ms」里有多少是 GDScript 快照、多少是 fill | 未拆；`bench_render` 可拆但只到 8000 | 跑 `tools/bench_render.tscn`（原生 vs GDScript 对照）并延伸到 10 万 |
| S13 | 内容层 26 张卡是否有卡已经依赖「擦弹终生一次」的计数 | 若依赖，D2 改动会改分数与记忆经济 | 逐卡读 `graze` 相关逻辑 + 存档记录字段 |
| S14 | 热重载在 GDScript + 有状态协程下是否可达 100 ms（C:84） | 无实现；Godot 无官方脚本热替换 | 先做「整卡快照重进」测出基线，再判断是否需要 IR |
| S15 | 8000 弹以上 `MultiMesh` 的 `instance_count` 增长是否会一次性卡顿 | `bullet_multi_mesh.gd:246-248` 是 `max(n*2, 2048)` 倍增，未测尖峰 | 压测跨越 2048/4096/8192 边界（V7） |

---

## 5. 一句话结论

当前项目在「单弹描述符（Move/Until/Action）+ 原生 SoA 内核 + MultiMesh 批次」这条路上有实现，但**擦弹仍是终生一次、时间轴是浮点闭包、replay 未接线、压测与实现漂移**这四项，使得「密度上限」和「迭代速率」两个乘数都没有可测的基线；D2 已完成；下一优先是 I（预算/压测），再决定 A（组合层）与 E（渲染通道）的投入顺序，是这个阶段唯一有证据支撑的排序。

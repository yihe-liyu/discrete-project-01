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

### 2026-09-14 — L3.5-4b-pre ✅：原生宽相 uniform grid

- **背景**：原生 `query_circle` 是线性扫描，而 GDScript `BulletSystem` 早有 uniform grid（`BROADPHASE_MIN_COUNT=64`）→
  不补网格就切判定必倒退。
- **产出**：原生 `DanmakuStore` 加宽相网格（与 GDScript 同参数/同语义）：惰性重建（`_grid_dirty`）、
  cull 有面积用 cull 否则活跃包围盒、cell=64 / min=64 / max_cells=8192、超限回退线性；
  `query_circle` 命中时走桶链表 + `hit_test`。新增只读诊断 `is_broadphase_active()`。
- **验证**：`test_native_broadphase` **3/3（129 断言）**：circle/offset/rect × 多中心/半径，
  ① 原生网格 ↔ GDScript 网格；② **原生网格 ↔ 暴力逐行**（证明不漏/不重）；③ 场地 cull+96 弹启用网格、
  <64 弹 / cull 过大回退线性。
- **实测**（6000 弹 / query 半径 24 / 3000 次）：原生网格 `1.44 µs/query` vs 原生线性 `13.93 µs/query` → **9.7×**。
- **未做**：`overlap_pairs` 仍线性（多目标网格化另议）；4b 判定切原生须先解决「原生持有碰撞元数据」。

### 2026-09-14 — L3.5-4a ✅：原生批量重叠 `overlap_pairs`

- **背景**：方案 A（原生权威）下判定层若逐弹调原生 `hit_test`，按边界铁律（110ns vs 13ns）会比现在更慢；
  `_player_bullets_vs_enemies` 是 `O(玩家弹×敌人)`。
- **产出**：原生 `overlap_pairs(faction, targets, radii) -> [bullet, target, ...]`（`faction<0` = 不限；跳过未出生/纯特效行；
  几何复用 `hit_test`）。一次跨界返回全部命中对。
- **验证**：`test_native_overlap_pairs` **3/3（24 断言）** —— circle / offset / rect 三种判定 × 阵营（含 -1）× 单点双阈值；
  **非空洞**断言（至少产生命中对），防止 `0==0` 假过。
- **下一步**：4b 判定层改走 `overlap_pairs`（GDScript 只算伤害/RNG/音效）。

### 2026-09-14 — L3.5-3b 修复②：锚定漂移（魔理沙激光）锚点解析 + batch 首帧状态

- **症状**：魔理沙非 focus 激光段全部粘在自机身上（子机锚点被整个忽略）。
- **根因**：
  1. 原生 `anchor_drift`（case 9）`base = player + offset`，**完全没读 `anchor_id` / `use_global`**；而 GDScript 参考解释器 `_anchor_pos` 的 `use_global` 分支又丢了 offset → 旧行为 / 参考 / 原生三套语义互不一致。且测试只覆盖 `anchor_id = 0`，真机非 0 时全错。
  2. `behavior_batch` 没有 `set_program` 那步 → **新弹首帧的内部状态（`_pfresh/_pnext/_phasend/_pendx/_pendy`）残留上一颗弹的值**，激光首帧漂移错。
- **修复**：
  - 新增**唯一真相** `BulletLifecycle.anchor_base(id, offset, use_global, player)`：`id=0 → player+offset`；`global → 锚点 global+offset`（marisa 子机是 World 兄弟）；`local → player+锚点局部 position`（focus 子机，不读 global，避免父级移动滞后一帧）。参考解释器与桥接统一走它。
  - 原生 `behavior_batch` / `behavior_tick` 增参 `anchor_base`（`DEFVAL`，旧调用不回归）：桥接每帧把每个 program 的锚点解析成 base 传入，原生 case 9 直接用 `anchor_base[prog]`。
  - `behavior_batch` 在 `tick==0 && phase==0`（新弹首帧）初始化上述五个内部状态。
- **双向证明**：
  - `test_native_marisa_laser` 改用**非 0 anchor_id**（子机在 (340,560)，与自机 (300,600) 不同）：传空 base（= 旧原生行为）时 **FAIL**，偏差恰好 = 锚点−自机 = (40,−40)；传正确 base 时 PASS。
  - 新增 `test_batch_anchor_drift_first_frame_uses_initial`（首帧用 `initial_drift`，不是 `0+speed·dt`）。
  - 新增 `test_native_laser_anchor`：端到端走真实 `BulletManager → KernelNativeSystem`，断言段 x 贴锚点 340（旧原生会是 player.x=0）。
- **验证**：`./tools/verify.sh` 全绿；**364 / 3970**。

### 2026-09-14 — L3.5-3b 修复：行为事件按「事件自己的 program」派发

- **症状**：真实舞台（stage01 非符1）约 27s 报两类错：
  - `_drain_events` sfx 分支 `Invalid access of index '0' on Array[StringName]`；
  - emit 分支把内容回调当工厂调：`_kernel_on_flee_burst (Callable). Expected 4 argument(s)`。
- **定位**：`_drain_events` 用 `res.program[bullet[k]]`（per-bullet 快照）反查事件 program。原生 `get_program(35)=1`（bounce），但**同一次调用**返回的快照读回 `0`。
  根因：**快照数组与宿主 `_program` 成员共享底层缓冲**；`_program = res.program` 之后先跑 despawn 的 swap 镜像写，把「刚发射事件的那颗弹」的 program 槽覆盖了，事件才 drain → 派发到错误 program（sfx 越界 / emit 调成 call）。
- **修复**：
  - C++ `_events_dict` 增加独立键 `eprog`（事件自带发射 program）；
  - `behavior_batch` 的 per-bullet 输出改键 `oprogram`（保留 `program` 别名兼容既有测试）；
  - GDScript `_drain_events` 改用 `res.eprog[k]`；`_program = res.oprogram`。
- **证据**：workbench headless 70s 复现 → 修复后零错误；新增 `test_native_event_dispatch`（13 断言）锁定契约：**事件 program == 发射弹 program == 原生 `_program[弹]`，且 `eprog` 不被 per-bullet 写污染**；新增原生 `get_program(id)` 访问器。
- **附带**：`bullet_lifecycle.gd` 三处 SHADOWED_VARIABLE 消除（`bounce(accel_rate)`；`compile()/_args_act` 的 `sfx_keys`）。
- **验证**：`./tools/verify.sh` 全绿；**362 / 3962**。
- **教训**：**别把「原生返回的快照数组」与「之后会被就地改写的宿主数组成员」当同一个东西**；事件应在产生时携带自身全部身份（program），而不是 drain 时反查可能已变形的 per-bullet 状态。

### 2026-09-14 — L3.5-3b ✅：bridge 接入原生行为执行（替 BehaviorProcessor）

- **改动**：`KernelNativeSystem` 维护 per-bullet `program/phase/tick/elapsed/slots`（随 spawn/despawn swap 同步），每帧 `integrate_batch` + `behavior_batch`（数组进/出）→ 回写 → **降序重放 dead** → drain 事件（emit→queue_spawn / sfx→AudioManager / call→内容回调）。`KernelBulletBackend.setup_behaviors` 原生可用时**不创建 BehaviorProcessor**。
- **验证**：全量 **361 / 3951 全绿**（原生行为 ON）。
- **三个真 bug（都是接入才暴露的）**：
  1. **原生 store 的场域常量从没注入** → 游戏里 `_field_*`=0，`at_wall` 判定错。修：创建 store 时 `set_field(GameConfig...)`。
  2. **原生 store 从没 `setup()`** → `_capacity=0` → `behavior_batch` 返回**空数组** → base OOB（`_life_left[0]`）。`integrate_batch` 无状态所以从未暴露。修：原生 `_ensure_capacity` 按需扩容。
  3. 测试侧：`test_kernel_behavior` 改 `use_native=false`（它测 GDScript 行为）；`test_kernel_swap::test_behavior_pipeline_wired` 兼容原生路径。
- **验收**：verify.sh 全绿。

### 2026-09-14 — L3.5-3a：原生无状态行为批 behavior_batch + 扩展加载守卫

- **目标**：让原生执行器能跑在 GDScript 存储的数组上（接入 3b 的前置）。
- **产出**：
  - `behavior_tick` 核心抽成 `_run_behavior_pass` + `_events_dict`。
  - 新 `behavior_batch(count, pos, vel, life, fx, program, phase, tick, elapsed, slots, dt, world) -> {pos, vel, ..., dead, events}`：**数组进 / 出、不做 swap**，回收由调用方按 `dead` 重放（与 `integrate_batch` 同款）。
  - 数组 getter：`get_colors / get_type_indices / get_factions`。
- **验证**：`test_native_behavior_batch` **2/2（244 断言）** —— curve batch ↔ tick 120 帧一致；bounce batch 返回 dead + 重放清空。
- **踩坑（重要，已加守卫）**：重构 `behavior_tick` 时用 `slice(start,end)` 替换到构造函数前，**把 L3.5-1 的判定函数整段删了** → `.so` 含未定义符号 `hit_test` → **扩展加载失败**（`ClassDB.class_exists` false）。而所有原生测试只会 `pending`、门禁全绿也发现不了（只有真实加载时才报）。
  - **教训**：C++ 大段替换必须核对删掉了什么；**扩展加载失败是静默的**。
  - **处置**：新增 `test_native_extension_loads` —— 扩展已构建时断言类真的注册 + 关键 API 存在；之前那类失败会**变红**。
- **验收**：verify.sh 全绿。

### 2026-09-14 — L3.5-2 ✅：LifecycleCatalog（move+params → preset）+ 签名缓存

- **目标**：内容 `kernel_port()` 的 `{move, params}` → `BulletLifecycle`（L3.5-3 接入的前置）。
- **产出**：`scripts/kernel_bridge/lifecycle/lifecycle_catalog.gd` —— `build(move, params)` 纯映射 + `signature()/get_lifecycle()` 缓存（**难度入签名**，因 non_mid 半径随难度）。
- **映射 10 个 move**：world_accel / accel / curve / homing / radial_accel / bounce / avoid_player / non_mid_flee / marisa_laser / laser_follow。
- **内容零改动**：仍写 `kernel_port() -> {move, params}`；`sfx` 的 String → StringName。
- **验证**：`test_lifecycle_catalog` **5/5（35 断言）**：10 个 move 全映射、结构正确、未知 move → null、缓存按签名命中、空 sfx 不加动作。
- **验收**：verify.sh 全绿。

### 2026-09-14 — L3.5-1 ✅：原生判定（hit_test / query_circle / grazed）与 GDScript 1:1

- **产出**：原生 `set_hitbox / hit_test / query_circle / is_grazed / mark_grazed`；per-row hitbox（radius / offset / size + follow_dir / dir_offset + grazed）；`_circle_rect` 与 `HitGeometry` 1:1。
- **实现**：`query_circle` 用**线性扫描**（与 GDScript 的 plain/linear 路径**同序**）；语义对齐 `_narrow_hit`（fx 相位跳过 / 偏移随朝向旋转 / 矩形分支 / 半径相加）。
- **验证**：`test_native_collision` **4/4（293 断言）** —— 圆 / 偏移 / 矩形三种 hitbox 下 `query_circle` + `hit_test` + `grazed` 全部一致。
- **注**：宽相 uniform grid **暂未移植**；线性扫描在 C++ 下先量收益再决定（沿用「量到收益再说」）。
- **验收**：verify.sh 全绿。

### 2026-09-14 — L3 ✅：原生行为执行器（packed program）与参考解释器 parity

- **目标**：把描述符执行搬到原生（行为 4.25ms 那块）。
- **产出**：
  - `BulletLifecycle.compile()`：描述符 → **packed program**（ops / args / 相位偏移 / 槽）；Callable / SFX 留**程序级表**（事件回传 local_id，Callable 永不进原生）。
  - 原生 `DanmakuStore`：per-bullet program/phase/tick/elapsed/slots + `register_program / set_program / behavior_tick(dt, player, boss, has_boss, enemies) → events`。执行全部 9 move / 5 condition / 6 action；emit / sfx / call 走**事件**。
- **验证**：`test_native_executor` **9/9（55 断言）** —— curve / accel / world_accel / bounce / avoid / homing / radial / non_mid / marisa 原生 ↔ GDScript 参考解释器位置 / 速度 / 发射事件一致。
- **两个关键发现**：
  1. **32↔64 位浮点**：GDScript 标量 64 位、原生 32 位 → 三角函数类累积漂移，需容差（2e-3）。N2.2 积分（纯加法）能逐位是特例。
  2. **steer 是反馈环**：转向→位置→角度→放大；浮点差会被放大成方向翻转。故 homing 只在「加速未饱和、反馈未放大」的地平线内对照。**原生成为唯一实现后这不再是问题**（确定性在原生内部自洽）——这是过渡期对照的限制。
- **踩坑**：原生 emit 读错参数下标（`speed=a[5] / at_end=a[7]`，应为 `a[4] / a[5]`）→ 全部发射位置 / 方向错。测试自身也踩过「参考 host 与原生 host 共用」。
- **验收**：verify.sh 全绿。

### 2026-09-14 — N2 存储段（核心）：原生 SoA 存储 + 积分 + 回收；与 GDScript 1:1

- **背景**：N2 存储段**单独做**会掉进 110ns 的坑（GDScript 行为逐弹 get/set 原生存储）。所以按**融合形态**推进：原生持有 SoA，并将由原生**直接执行描述符**（L3）。本步先落**存储核心**。
- **产出**：`DanmakuStore` 扩为真实存储：加 `life / fx / timer` + `_swap_remove` + `despawn / clear` + `set_* / get_*` 快照；`integrate` 做成与 `bullet_system._physics_process` **1:1 的完整循环**（寿命 / 出生相位 / 位移 / 计时 / 剔除）。
- **验证**：`test_native_storage` **2/2（9 断言）** —— 100 弹 × 180 帧，位置 / 速度 / 寿命 / 相位 / 计时与 GDScript **逐位一致**；`despawn` swap 语义一致。
- **未做（后续）**：原生宽相 `query_circle`（需 per-row hitbox 一并原生）、原生**行为执行器**（L3）、接入游戏。
- **验收**：verify.sh 全绿。

### 2026-09-13 — L2 ✅：其余 8 个 preset 逐位 parity；描述符覆盖面补齐

- **目标**：`LIFECYCLE_MODEL` 的正交 unit 能否覆盖全部 10 个行为。
- **产出**：preset `homing / radial_accel / avoid_player / non_mid_flee / laser_follow / marisa_laser / accel / world_accel` + `test_lifecycle_presets`。
- **结果**：**8/8（10 断言）逐位 parity**（位置 / 速度 / 发射 pos·dir·vel）。加 L1 的 bounce/curve → **10 个行为全覆盖**。
- **为 parity 加的 unit 细节（都保持语义化）**：
  - `steer` 融合速度（`speed_from/speed_to`）：参考 homing 是「unit 方向旋转 + 赋速度」**一步**；拆成 `steer+speed_lerp` 会因多一次 `normalize` 累积到 2e-4。
  - `steer` 的 `steer_until`：duration 是「转向多久」而**非**相位结束（弹体继续飞）。
  - `near` 的 `every_ticks`：non_mid 的 `skip % 3` 帧门控 1:1。
  - `on_end_call(fn)`：内容散圈回调（一次性、低频）。
  - `T_NEAREST_ENEMY` 跳过时符 Boss（与 `homing_behavior` 1:1）。
- **踩坑**：`WorldQuery.get_nearest_enemy` 返回 **Node2D**，不是 Vector2 —— 我直接拿它做减法，报 `Invalid operands 'Object' and 'Vector2'`。
- **验收**：verify.sh 全绿。

### 2026-09-13 — L1.5：状态显式化（按相位自动分配槽）+ unit 正交化

- **动机**：L1 用 flat Dictionary 存状态（`turned` / `hit_pos` / `drift` / `elapsed`）是**隐藏通道** —— 两个相位都 rotate 会共用 `turned`，unit 无法自由组合。
- **改 ① 状态显式化**：builder 为每个有状态 unit **自动分配 slot**，**相位切换清零**；descriptor 里是显式 slot 索引（已接近原生 schema）。创作者仍看不到槽。
- **改 ② unit 正交化**：`aim`→`steer(toward(target))`；`anchor`+`drift`→语义单元 `anchor_drift`；`emit` 收 **dir 表达式**（`toward / away / heading`）；`top_edge`→`at_wall(TOP)`；`near_player/near_boss`→`near(target, r, every)`；`timeout`→`elapsed`；`turned`→`state(slot, cmp, v)`。
- **验证**：`test_lifecycle_model` **3/3（35 断言）** —— bounce/curve parity 不变；新增**组合性测试**（两段各自 rotate 独立槽，相位切换清零 → 第二段不会「以为已转满」）。
- **踩坑**：`then()` 会生成一个 `until=never` 的新相位；在其上挂 `on_end` 动作**永不触发**（测试里多写一个 `then()` 导致 despawn 不执行）。
- **验收**：verify.sh 全绿。

### 2026-09-13 — 修引擎 bug：despawn drain 改降序（升序会丢大 id）

- **来源**：L1 生命周期 parity 时挖出。
- **bug**：`BehaviorProcessor.process()` 升序 `for id in take_despawn_requests(): despawn(id)`。despawn 是 swap-with-last —— 先回收小 id 会搬走大 id 行并缩小 `_active_count` → 大 id 越界**静默丢弃**。
- **症状**：多弹同帧回收丢一个 → bounce **重复发射**（diag `spawns=8`）、行为弹残留 / 晚一帧回收。**会咬现游戏。**
- **修**：按 id **降序**回收（`requests.sort(); requests.reverse()`）。降序时当前 id 恒 ≤ 尾行，被搬的行必是幸存行 → 回收集合精确等于请求集。
- **落点（重建版单一真相）**：先改 `1-st-touhou-star-rebuild/scripts/behavior/behavior_processor.gd`（commit `2466a93`）→ `bash tools/vendor_kernel.sh` 同步（0 漂移 / 0 宿主引用）。
- **双向证明**：`test_kernel_despawn_drain` —— 修复后 **2/2 pass**；临时 `git checkout` 回退旧实现 → **0/2 fail**（5 弹全请求残留 2；3 弹回收 #0/#2 剩 2 而非 1）；re-vendor 恢复 → pass。
- **教训**：swap-with-last 的**批量删除必须降序**。升序的 bug 会被「下帧再 request」自愈掩盖，只有**同帧多删**才暴露 —— 生命周期描述符（推进 phase、不重请求）把它放大成永久残留，反而**帮我们抓到了它**。
- **验收**：verify.sh 全绿。

### 2026-09-13 — L1 ✅：BulletLifecycle 描述符 + 参考解释器；bounce/curve parity 逐位通过

- **目标**：验证 `docs/LIFECYCLE_MODEL.md` 的 per-bullet 描述符能否表达现有行为。
- **产出**：`scripts/kernel_bridge/lifecycle/bullet_lifecycle.gd`（fluent builder + preset：bounce/curve/world_accel/accel）+ `lifecycle_behavior.gd`（GDScript 参考解释器，Behavior tenant）。创作者只调高层方法，无 opcode。
- **验证**：`test_lifecycle_model` **2/2（33 断言）** —— `bounce`（碰框换弹，条件性最强）与 `curve`（状态机 + 钳位）与现有 GDScript 行为**逐位 parity**（位置 / 速度 / 替换弹 pos/dir/vel）。
- **踩坑 1（builder 引用陷阱）**：`until_*` 起初**重新赋值** `_until`，但 `phases[0].until` 持旧引用 → 条件永远停在 `never`。curve 侥幸过（move 自停），bounce 露馅。修：条件**原地 clear + 写**。
- **踩坑 2（引擎真 bug，重要）**：`BehaviorProcessor` 的 despawn drain 是**升序**（`behavior_processor.gd:60`）。swap-with-last 下先 despawn 小 id 会搬走大 id 行、缩小 `_active_count` → **大 id 静默丢失**。
  - 参考引擎靠「下帧再 request」自愈，代价是 bounce **重复发射**（diag 实测 `spawns=8 > 期望 7`）；生命周期解释器推进了 phase → **永久丢失**（`phase=1` 却 y=25.7 越过 FIELD_TOP 仍活着）。
  - **L1 处置**：测试 harness 改**降序** drain → parity 通过。**待办**：引擎 drain 应改降序（vendored → 需重建版改 + re-vendor）；**这是个会影响现游戏的 bug**。
- **验收**：verify.sh 全绿。

### 2026-09-13 — 决策：扩展为必需，GDScript 内核降为「过渡脚手架」

- **决定（用户拍板）**：接受「跑源码必须构建扩展」。GDScript `BulletSystem` / 重建版从「永久 fallback」
  降为**过渡**：**N2 存储段 + N3 行为**完成后删；`use_native` 回退分支随之移除。
- **澄清（重要）**：**玩家从不编译** —— Godot 导出把 `.so` 打进包。此决定只影响**从源码跑的开发者 / 创作者**；
  玩家侧要补的是**多平台构建**（现仅 linux x86_64）。
- **创作者方便是硬目标**：从源码跑需一次构建；便利路线（一键 setup / 内置预编译 / 带扩展编辑器）**待拍板**。
  **内容接口（`kernel_port` / 工作台 / 内容脚本）保持高层 GDScript**，原语不泄漏进创作面。
- **对 N2.2 的定性**：`KernelNativeSystem` 继承 vendored `BulletSystem` 是**过渡 scaffold**，非终局；
  终局 = 原生系统直接当内核、`BulletSystem` 删除。

### 2026-09-13 — N2.2（积分段）✅ 原生 integrate_batch 5.9×；边界实测 110ns/次 → 必须批量

- **目标**：把内核积分循环搬原生（积分 / 寿命 / 出生相位 / 剔除），桥接以下 API 不变。
- **先量边界（决策依据，`tools/bench_boundary.gd`）**：GDScript `Packed[i]` **13ns** vs 原生 `get_position(i)` 逐次 **110ns**（8×），而 `get_positions()` 批量快照 **15ns**。→ **逐次跨界必亏；搬存储必须配套批量快照/写回**（原计划的 N2.3 不能等）。
- **落点（不碰 vendor 内核）**：`scripts/kernel_bridge/kernel_native_system.gd` **继承** vendored `BulletSystem`，只覆写 `_physics_process`；原生 `DanmakuStore.integrate_batch` **无状态**、数组按值进出、只回 `dead` 列表，子类**同序重放 despawn**（与内核 swap-with-last 逐位一致）。→ 内核 0 改动、不触发 re-vendor；行为 / 碰撞 / 渲染看到的仍是 `BulletSystem`。
- **实测**（`tools/bench_native_system.gd`，6000 弹，同进程类路径）：GDScript **0.699ms** → 原生 **0.118ms** = **5.9×（−0.58ms/帧）**；原生裸调用 0.117。
- **踩坑 1（字典键）**：GDScript 读 `res.life_lefts` / `res.fx_phases`，原生给的是 `life_left` / `fx_phase` → 读到 null。**bench 抓出**（类路径反而 1.88ms）。
- **踩坑 2（空断言，重要）**：我加了尺寸守卫 `res.positions.size() != _active_count`，但原生按 SoA 约定返回**容量大小**（8192）≠ 活跃数（6000）→ **每帧静默退回 `super()`**，原生从未运行；parity 测试于是「两边都走 GDScript」而**空过**。修法 + 加**覆盖计数器 `native_frames`**，断言 >100 才证明真跑过。
- **教训**：**SoA 的 `size()` ≠ 活跃数**（N4-real 已踩过，这次是我自己的 guard 踩）。**「新旧一致」的测试若两边都走了旧路，就是自欺**——替换类改动必须加覆盖证据。
- **未做（N2.2 存储段）**：spawn/despawn/宽相仍 GDScript。churn 实测（`tools/bench_churn.gd`）：6000 发 **8.2ms/波** GDScript vs 原生 ~1.1（含复位）→ 原生存储仍有空间。
- **验收**：`test_native_integrate` 2/2（11 断言，逐位 parity）；`verify.sh` 全绿。

### 2026-09-13 — N4-real 人类试玩验收 ✅：原生渲染视觉完全正确

- **背景**：N4-real 后 `use_native_sync` 默认开 —— **只要扩展构建了，游戏就走原生渲染**。`verify.sh` 只能证「不崩、批次数对」；headless 读不到 MultiMesh 变换，**视觉是唯一自动化盲区**。
- **验收方式**：**真人试玩**（非自动化）—— 这是这条风险的唯一出口。
- **结果**：弹**朝向** / **激光淡出** / **图集弹** 全部正确；无串图、无错向。**N4-real 渲染路径风险关闭。**
- **教训**：跨语言替换渲染，**自动化能测「结构」（分组键、批次数、活跃数），测不了「长相」** —— 「画错不报错」类 bug 只有人眼能兜。凡替换真实绘制路径，**必须留一次人工验收**。

### 2026-09-13 — N4-real：原生整段渲染同步 ✅ ~6.5×（6000 弹 7.19ms → 1.10ms）

- **做法**：原生 `DanmakuRenderBridge` —— 类型表（`tex_key_base/tint_mode/kind/follow_dir/dir_offset`）+ `group(count, SoA, fade) -> {keys,starts,rows,rots,alphas}` + `fill(mm,...)`。**分组 + 每弹旋转/fade + 填充全在原生**；GDScript 只按组（O(groups)）取/建 MultiMesh。
- **接入**：`BulletMultiMesh` 加 `use_native_sync` + 类型表（类型数变化时重建）+ GDScript `_sync_kernel` 回退。
- **实测**（同进程对照，`tools/bench_render.gd`）：3000/6000/8000 → **6.53× / 6.54× / 6.57×**（6000: 7.193 → **1.101ms**）。
- **踩坑（重要）**：内核 SoA 快照数组是**容量大小**，只有前 `count` 条活跃。原生一开始按 `array.size()` 迭代 → 把整个池都分组了。`test_kernel_snapshot_renders_one_batch` 用 `visible_instance_count = 1024 ≠ 3` 抓出。**修法**：`group(count, ...)` 显式传活跃数。
- **教训**：**SoA 的 `size()` ≠ 活跃数。** 跨语言桥接时，"数组长度"和"有效长度"是两回事；GDScript 的 `for i in count` 里那个 `count` 必须显式过边界。
- **验收**：`verify.sh` 全绿（322 测试 / 3247 断言）；`test_kernel_render` 5/5。

### 2026-09-13 — N2.2 探路：只搬「渲染填充」无效（1.14×），已回退 + 记录教训

- **尝试**：原生 `DanmakuBatch.fill_group` 接进 `BulletMultiMesh._sync_kernel`（分组 / 旋转 / fade 仍留 GDScript）。
- **同进程对照**（`tools/bench_render.gd`，6000 弹）：原生 **8.19ms** vs GDScript **9.31ms** = **1.14×** —— 远低于独立探针的 ~50×。
- **根因**：开销在 **GDScript 的分组（Dictionary + 每弹 append）+ 每弹 `rotation_for` / `get_render_fade`**，**不在** `set_instance_*` 调用本身；只搬填充还多了 Array→Packed 转换。
- **处置**：**回退** `BulletMultiMesh`，移除 `DanmakuBatch`；新增 `tools/bench_render.gd`（整段渲染对照）。
- **教训**：**"最大单项"要说清楚是哪一段。** 独立探针里"渲染 ~50×"是「无分组、直接写缓冲」的理想值；接进真实路径后，分组才是大头。搬错了段 = 白干。
- **顺带修**：`bench_danmaku.gd` 用 `queue_free()` —— 同步 `_ready` 里从不执行 → 后端累积，是之前数据噪音的来源；改 `free()`。
- **验收**：`verify.sh` 全绿（322 测试 / 3247 断言）。

### 2026-09-13 — N2.1：原生 DanmakuStore 扩为真实弹数据 + 批量 API（~55× 保持）

- **扩了什么**：per-bullet `type` / `faction` / `color`；**`spawn_batch`**（Packed 数组一次跨界）避免逐弹跨语言开销；`fill_multimesh(mm)` 按每弹色写入。
- **实测（真实数据 + 批量 spawn）**：3000/6000/8000 弹原生合计 **0.078 / 0.156 / 0.200 ms**；同档 GDScript（直线）4.25 / 8.39 / 11.20 ms → **~54–56×**。
- **接入计划**：新增 `docs/N2_NATIVE_INTEGRATION_PLAN.md`（N2.2 原生 DanmakuSystem 补 API 子集 + `use_native` 开关；N2.3 批量行为桥；N3 VM；N4-real 图集）。
- **新增**：`tools/bench_native.gd`（动态用 `ClassDB.instantiate("DanmakuStore")`，未构建也能跑并友好提示）。
- **验收**：原生基准跑通；`verify.sh` 仍绿（本次未改游戏运行时路径）。

### 2026-09-13 — N2-real 开工：`gdextension/` 骨架（方案 A）

- **结构**：主 repo 新增 `gdextension/`（源码 + `SConstruct` + godot-cpp 子模块 + README + 加载冒烟）。`.so` 与 `.gdextension` **都是构建产物、不入库** —— **未构建 = 无扩展 = 游戏照跑 GDScript（零报错）**；构建后才加载原生。
- **godot-cpp**：git 子模块，pin 在 `6cceaf6`（master / v10）。`git clone` 的 SSL 不稳 → `-c http.version=HTTP/1.1` 解决（curl/tarball 仅探针期用过）。
- **构建**：`./tools/build_gdextension.sh`（默认 debug + release；编完自动生成 `.gdextension`）。
- **加载**：`.gdextension` 需编辑器导入一次 → `ClassDB.class_exists("DanmakuStore") = true`。
- **CI**：`verify.yml` 加 `submodules: recursive` + `pip install scons` + 构建原生内核，再跑原验证。
- **验收**：`verify.sh` 五步绿（322 测试 / 3247 断言）；game_scene 启动零错误（扩展已加载）。

### 2026-09-13 — N2/N4 原生探针：✅ 脚本侧热路径快 ~60×（6000 弹 8.9ms → 0.15ms）

- **做法**：在 `_gdext_spike/` 加原生 `DanmakuStore`（SoA 存储 + 积分 + 剔除 + `fill_multimesh` 写 MultiMesh），godot-cpp 绑定，同一 N 档位对比 GDScript `BulletSystem` + `BulletMultiMesh`。
- **结果（ms/帧）**：6000 弹 —— GDScript 积分 0.78 / 渲染 7.40 / 合计 8.90；**原生 0.008 / 0.142 / 0.150** → **~59×**。8000 弹原生合计 **0.199**（vs 11.46）。
- **结论**：对 6000+ 弹的目标，**GDExtension 是必需，不是奢侈**。N2(存储) + N4(渲染) 的收益被实测坐实；且最大头正是本地 GDScript 最丑的那块（每帧 Dictionary 分组）。
- **边界**：探针是简化版（单 MultiMesh / 单色 / 无行为 / 无碰撞 / 无图集）；真实版还需 N3(行为 VM) + 图集 + 纹理句柄（M3 ③ 插座正好接上）。
- **产物**：`_gdext_spike/src/danmaku_store.{h,cpp}` + `testproj/native_bench.gd`（工作区外）。

### 2026-09-13 — 量 Trigger：`tools/bench_danmaku.gd`（渲染同步才是最大头）

- **动机**：N1 工具链通过后，上不上原生只剩"性能 Trigger"一票。此前只有"3000 弹 ≈ 2.5ms"的旧数字，且 `tools/bench_danmaku.gd` 根本不存在。
- **做法**：新写基准，逐档 N（500…8000）测**脚本侧热路径**四段：内核积分 `system._physics_process` / 行为 `behavior.process` / 宽相 `CollisionResolver.overlap_ids` / **渲染 CPU 同步 `BulletMultiMesh._sync_kernel`**（headless，GPU 绘制不计）。
- **实测（ms/帧，带行为）**：3000 → **6.43**（39% 预算）；6000 → **12.80**（77%）；8000 → **16.99**（102%）。
- **关键发现**：**渲染 CPU 同步是最大单项**（≈1.2µs/弹；6000 弹 7.4ms），**行为**次之（≈0.7µs/弹；4.3ms）；内核积分 + 宽相各 <1ms。**旧"2.5ms"只算了物理、漏了渲染同步**（3000 弹实际 ≈ 6.4ms）。
- **对路线的影响**：Trigger 比想象中近（6000 弹带行为已 77%）。若上原生，**N3(VM) + N4(渲染) 是大头，N2(存储) 只值 ~0.8ms**。
- **更便宜的中间步**：先在 GDScript 内优化 `_sync_kernel` 的每帧分组/分配（TODO H1）—— 那是最大且最容易的一块，可能不用原生就先舒服了。
- **顺带**：修了自己写的单位 bug（多除 1000），重跑确认（第一次数是微秒）。

### 2026-09-13 — N1 工具链 spike：✅ 通过（godot-cpp v10 api_version=4.7 → Godot 4.7.2 加载成功）

- **目标**：验证 GDExtension 在这套环境能否跑通（设计文档 §10 N1，原文"唯一可能卡住的一步"）。
- **环境**：SCons 4.11.1 / g++ 16.2.1 / Python 3.14.7 / **Godot 4.7.2.stable**。
- **做法**：codeload 拉 **godot-cpp v10（master）**（git clone SSL 不稳，改用 tarball）→ `SConscript("godot-cpp/SConstruct", {"api_version": "4.7"})` → 最小 `Hello : RefCounted` + `register_types` → `scons target=template_debug` → 独立测试工程加载。
- **结果**：**通过**。`ClassDB.class_exists("Hello") = true`；`greet() = "Hello from GDExtension (api 4.7)"`。godot-cpp `supported_api_versions` 官方含 **4.7**。
- **踩坑**：`.gdextension` **必须经编辑器导入一次**（`godot --editor --quit` 写 `.godot/extension_list.cfg`）才会被加载；直接 `--headless --path` 跑项目不扫描新扩展 → 首次 `Hello exists: false`，导入后 `true`。
- **结论**：**工具链不再是 GDExtension 的门**（§12 风险 1 关闭）；剩余门只有**性能 Trigger**（≥6000 弹 / 实打实卡顿）。原生 VM 仍是"到触发才上"，不是现在。
- **产物**：spike 在 `_gdext_spike/`（工作区父目录、不进游戏 repo）：`src/` · `SConstruct` · `godot-cpp/` · `testproj/`。

### 2026-09-13 — D1：拆 SaveData（240 → 128 行；抽出 StageCatalog / PracticeSession / UiTheme）

- **动机**：`SaveData` 240 行 / 6 职责（全局选择 · 关卡目录 · 存档 · 练习 session · 启动装配 · 会话复位），是 38 个文件引用的 god object。
- **拆出**：
  - `StageCatalog`（58 行）：`stage_registry` 加载 + `find` / `scan` / `all` / `background`。
  - `PracticeSession`（43 行）：`is_practice_mode` + 练习载荷（phase / boss_scene / boss_name / stage_id / phase_index / background）+ `start` / `finish` / `clear`。
  - `UiTheme`（24 行）：`apply_ui_theme` → `UiTheme.apply()`（主题不是存档）。
- **保留在 SaveData**：全局选择（难度 / 角色 / 关卡进度）、会话标志（`is_stage_practice` / `restarting`）、存档 / 符卡簿 / 高分、`reset_session` 编排、`apply_settings`。
- **语义保持（关键）**：`reset_all`（每次 load_stage）**只清练习载荷、不碰 `is_stage_practice`** —— 否则 stage 练习中途 `load_stage` 会误清玩法标志；只有 `reset_session` 清 `is_stage_practice`。`PracticeSession.start` 仍先经 `SaveData.reset_session()`。
- **调用点**：脚本化替换 9 个文件（含 4 个测试）；`grep 'SaveData.practice_*' scripts/ data/ test/` = **0**。
- **踩坑（老坑）**：新增 3 个 `class_name` → 必须先 `godot --headless --editor --quit` 重建 `.godot/global_script_class_cache.cfg`，否则 `check_syntax` 报 `Identifier not found`。
- **验收**：check_syntax **194/0**；GUT **322 测试 / 3247 断言**全绿。

### 2026-09-13 — 更正：godot-cpp 的 4.7 前置（实测 GitHub）

- **原判断**（§0.2 / §12）：`godot-cpp` 有无匹配 Godot 4.7 的 branch「未确认」+ 本机缺 `scons`。
- **实测（fetch godot-cpp README / releases）**：godot-cpp **v10（master，Beta）**起版本号与 Godot 独立，README 明确 `api_version` 可选，示例即 `api_version="4.7"`，并写「v10 可 target Godot 4.3+（含 4.6）」。稳定分支/tag 仍停在 `godot-4.5-stable`，最新 release 是 `10.0.0-rc2`（2026-08-25）。
- **结论**：**「支持未确认」不成立** —— v10 可定位 4.7；唯一实际风险变成 **v10 仍 Beta、无 stable 分支**。本机缺的 `scons` 可 `pip install scons`。
- **验收**：纯文档更正；未动代码。

### 2026-09-13 — 桥接收口审计：924 行构成 + 更正「≤300」不可达目标

- **背景**：计划 §16.5 的「融合完成」判据写着 `scripts/kernel_bridge/` **≤ 300 行**。动手"收桥接"前先实测。
- **测量**：总计 **924 行** = 适配器 `kernel_bullet_backend` **236** + 宿主耦合 **688**（行为桥 273 / bomb 160 / 碰撞·擦弹 165 / laser fade 53 / 延后队列 37）。判据**自己要求保留**这 688 行 → **300 不可达**（是写出来时没量过的目标）。
- **剩余"翻译 / 侧表"只剩一处**：`_port_by_sig`（`kernel_port()` duck-typing 的行为绑定缓存）+ 6 处 `kernel_port()`。它是 **VM（N3）的前身** —— `_type_by_sig` / `_damage_by_index` / `_hit_sfx_by_index` 已随 M1/M2 删除；`_texture_by_index` 是 M3 ③ 的渲染插座。**在不上 N3 的前提下，桥接没有可删的行。**
- **更正**：§16.5 去掉行数上限，判据改为结构性（0 类型映射 / 0 内容签名侧表 / 内核 0 宿主引用），行数只作观测；基线同步。
- **教训**：**判据要在写下的当天就量。** 一个从没量过的行数目标，会让人误以为"还有一大坨可删"，实际是一堆判据要求保留的宿主耦合。
- **验收**：纯文档更正。

### 2026-09-13 — M3 拍板：③ 纹理句柄（渲染插座正式化）

- **决定**：M3 走 ③。宿主 `_texture_by_index` / `texture_for_index()` 正式定为**渲染插座（render socket）**；内核 `BulletType.type_index` = **纹理句柄**。**这不是债，是设计好的 seam。**
- **否决**：① 会让 §16.5 的 `_by_index = 0` 判据永不达标；② 提前把渲染塞回内核（触发条件未到，且破坏「内核 0 渲染」的克制）。
- **零内核改动**：不回重建版、不 vendor、不 tag。
- **落点**：plan §16.1 侧表行 / §16.3 M3 段 / §16.5 判据（`_by_index = 0` 收窄为「类型 / 端口 / 伤害侧表」；纹理句柄表按设计保留，N4 原生替换）；`KernelBulletBackend` 注释；基线融合 bullet；决策页 `docs/M3_TEXTURE_OWNERSHIP_DECISION.md`。
- **验收**：check_syntax 191/0；GUT 全绿（纯注释 / 文档，无行为变更）。

### 2026-09-13 — Tier A 收尾：A1 导出阻塞 + A2 测试卫生 + A3–A5 文档失真

- **A1（导出阻塞）**：内容侧 4 处 `ResourceSaver.save` 直接写 `res://`（`spell_book_manager.gd` / `asset_registry.gd` / `music_room_menu.gd:35,150`）→ 导出包只读必失败。改为「**res:// 出厂默认 + user:// 覆盖**」：`SpellBookManager` 加 `SPELL_BOOK_USER_PATH`；`AssetRegistry` 加 `MUSIC_REGISTRY_USER_PATH` + `load_music_registry()` / `save_music_registry()`（音乐档**以出厂目录为基准叠加 user 解锁**，新曲目不会被旧档吞掉）；`music_room_menu` 改走这两个 helper；顺带删 `audio_manager` 里从未使用的重复常量。
- **A1 守卫**：新增 `test/test_persistence_paths.gd` —— 扫 `res://scripts` + `res://data`，断言没有任何 `ResourceSaver.save` 行含 `res://`（`tools/` 是编辑器工具，豁免）。
- **A2（测试卫生）**：`test_boss_encapsulation` 3 + `test_param_validator` 7 个孤儿 Node 未释放 → 加 `autofree`。**orphans 10 → 0**。
- **A3/A4/A5（文档失真）**：基线 R5 `get_node` 计数更正为 **29 个调用点**（生产 14 / 测试 15，原记 19 漏了测试）；基线 R14 更正——`SaveManager` 走 user:// 不代表内容侧不写 res://（A1 那 4 处就是漏报）；`CONTENT_GUIDE` §八的 `StageManager` / `GameState` → `StageRuntime` / `SaveData`。
- **教训**：**"某处达标"不等于"整类达标"** —— R14 只查了 `SaveManager` 就写「0 处」，把内容侧 4 处漏了。审计要按"类"扫，不是按"记得的那个文件"扫。
- **验收**：verify.sh 五步全绿（322 测试 / 3247 断言，orphans 0）。
- **附带**：M3 决策页 `docs/M3_TEXTURE_OWNERSHIP_DECISION.md`（推荐 ③ 纹理句柄，待拍板）。

### 2026-09-13 — 会话状态收口：SaveData.reset_session()（唯一复位入口）

- **背景**：连续两条试玩 bug（练习载荷泄漏、门面误改）都属「跨局 / 跨场景状态没清干净」。做了一次全量 `static var` 审计（谁置位 / 谁复位）。
- **审计结论**：多数平衡（`.current` 各自 `_ready`/`_enter_tree` 置位、`_exit_tree` 清；缓存进程级）；**漏一个**——`current_stage_id` 从不复位。
- **`current_stage_id` 漏**：默认 1，`game_scene._on_stage_cleared` 通关时 `+= 1`，但 `main_menu._start_game_flow` 从不改回 1 → 清关后回标题、再开新游戏会从 stale 关卡号开始。且 `stage_registry` 只有 stage01（`find(2)` 为 null），`+= 1` 后会 `push_error` 卡死（stage01 有结局时触发）。
- **修法（结构性）**：新增 **`SaveData.reset_session()`** —— 唯一复位入口，清 练习载荷 + `current_stage_id` + `restarting` + `is_stage_practice`。`main_menu._start_game_flow` 与 `SaveData.start_practice`（以及 `stage_practice_menu.on_enter`）都先经过它；`_on_stage_cleared` 改为**仅当下一关存在**才 +1，否则视作通关回标题并复位会话。
- **契约**：基线新增「**会话状态契约（per-run static）**」——每个跨场景 static 列出 owner / 置位 / 复位，并规定必经 `reset_session`。
- **回归**：新增 `test/test_session_state.gd`（复位清全部 / 进练习隐含复位 / 幂等）；双向验证 `start_practice` 那条——去掉复位 2/3，恢复 3/3。
- **教训**：**「模式标志」与「模式载荷」要一起清，而且复位点要唯一。** 散落的「各自清一点」迟早漏；把它收成一个入口，测试才有地方钉。
- **验收**：verify.sh 五步全绿（320 测试 / 3244 断言）。

### 2026-09-13 — 修复：练习载荷未清空（先练习、再普通流程会告警 / 误判）

- **现象**：先打一次练习，再进普通流程 → `game_scene.gd:48` 告警「practice_phase 已设置但 is_practice_mode=false —— 练习标志被提前清除，误走普通关卡」。
- **根因**：`SaveData.end_practice()` 只把 `is_practice_mode` 置 false，`practice_phase / practice_boss_scene / practice_name / practice_stage_id / practice_phase_index / practice_background` 六个载荷原封不动；`reset_all()` 同样只清标志。下一局普通开局前就会看到残留，且任何按 `practice_*` 判断的路径都可能误判。
- **修法**：新增 `SaveData._clear_practice()`（清 6 个载荷 + 模式标志），`end_practice()` 与 `reset_all()` 都调它；`end_practice` 仍尊重 `restarting`（重开练习要保留状态）。
- **回归**：`test_practice_mode.test_end_practice_clears_payload` + `test_reset_all_clears_practice_payload`；**双向验证** —— 旧代码 1/3（`practice_phase` / `practice_background` 残留），新代码 3/3。
- **教训**：**「模式标志」和「模式载荷」必须一起清。** 只复位布尔标志，留下的载荷就是下一次进入别的流程时的定时炸弹。静态 `var` 在 GUT 同进程内还会跨用例串味——`test_practice_mode` 原测试就靠 `end_practice()` 收尾。
- **验收**：verify.sh 五步全绿（317 测试 / 3232 断言）。

### 2026-09-13 — 修复：ctx 门面误改（boss.clear_phase 访问 ctx.bullet_manager）

- **现象**：试玩中 Boss 击破报 `Invalid access to property or key 'bullet_manager' on ... StageContext`（boss.gd:298，栈：take_damage → clear_phase）。
- **根因**：A2b 命名收敛把「BulletManager 实例字段」`world`/`bullets` → `bullet_manager`，却**误伤了 `ctx.*` 意图门面** —— StageContext 的门面是 `bullets`，没有 `bullet_manager`。test 没抓到是因为 test_boss_phase 里 `clear_phase` 从不带非 null ctx（`if _stage_context:` 直接跳过）。
- **修法**：`_stage_context.bullets.death_clear(...)`（BulletService 门面；其 `death_clear` 本身 null-safe）。
- **回归**：`test_boss_phase.test_clear_phase_death_clear_via_bullets_facade` 用 `BulletSpy` 记录 `death_clear`；**已双向验证** —— 旧代码 15/16（且打同一条错误），新代码 16/16。
- **全仓排查**：`grep -rn '\.bullet_manager'` 其余 8 处接收者都是 StageRuntime / BulletManager / HitboxOverlay / KernelBomb，合法；仅 boss.gd:298 把 StageContext 当成了 BulletManager。
- **教训**：「`ctx.*` 门面豁免改名」光写文档不够 —— **批量改名必须显式排除门面访问**；且 tests 对「非 null ctx + 门面调用」有覆盖洞（之前全靠 `ctx = null` 的早退分支蒙过）。
- **验收**：verify.sh 五步全绿（315 测试 / 3222 断言）。

### 2026-09-13 — 修复：延后发射队列未快照 per-shot 状态（non_mid01 红弹速度梯度消失）

- **现象**：`non_mid01_bullet.gd:45` 的 `_red_bullet_data.speed(RING_SPEED + i * 50)` 不生效 —— 红弹全按最后一档速度飞。
- **根因**：内核行为循环中途禁止 spawn，故走 `KernelBehaviorHost.queue_spawn` 延后到 flush。旧 `queue_spawn` 存的是 `{data = data}` **活引用**；M2 起内容复用同一 `BulletData` 实例（正是 M2 要求的写法），于是同一帧多次入队全指向同一实例，flush 时才读 `data.velocity` → 被最后一次写入覆盖。`radial_accel_behavior.gd:43` / `bounce_behavior.gd:61` 的 `b.velocity = …` 同样中招（工厂返回缓存实例）。
- **修法（在队列，不在内容）**：`KernelBulletBackend` 拆出 `prepare_shot()`（解析类型 / 速度 / 行为 / 染色 / 贴图，不写池）与 `spawn_prepared()`（写池）；`queue_spawn` 改为**入队瞬间** `prepare_shot` 快照，`flush` 只 `spawn_prepared`。`shoot()` = 两者立即串接，签名不变；`_sync_host_tables` 改收 `texture`。
- **为什么改队列**：`queue_spawn` 原注释要求「传副本」，但 M2 的全部意义就是别每发造新 `BulletData`（否则弹型表膨胀）。把不变量放回队列：内容尽管复用实例、每发改速度，延后机制自己保证正确。
- **回归测试**：`test_queue_spawn_snapshots_per_shot_speed`（通用：同一模板两次不同速度入队，flush 后各保留）+ `test_non_mid_red_ring_keeps_speed_gradient`（内容：Hard 下速度集合 = 400/450/500/550）。
- **教训**：**延后 / 异步机制一旦存引用，就必须在入队瞬间快照「所有 per-shot 字段」**，否则「复用实例」这个性能优化会变成静默串味。断言数 3217 → 3220。
- **验收**：`verify.sh` 五步全绿（313 测试 / 3220 断言）。

### 2026-09-13 — 修复：形参遮蔽成员（4 处，其中一个是静默 no-op）

- **现象**：编辑器脚本 reload 报 4 条 `SHADOWED_VARIABLE` / `CONFUSABLE_LOCAL_USAGE`：`bullet_manager.gd:181/218`、`game_manager.gd:87`、`boss_ui.gd:92`。
- **不是纯警告**：`game_manager.gd:89` 的 `entity_registry = entity_registry` 两侧都解析为**形参** → 自赋值 no-op，`GameManager.entity_registry` 永远是 `null`，`_clear_world()` 从不 `entity_registry.clear()`（切场不清实体）。警告背后是真 bug。
- **修法**（按基线「形参遮蔽成员 → `p_`」）：`inject_entity_registry(p_entity_registry)` / `register_world(..., p_entity_registry)`；`bullet_manager.gd:218` 的 `var entity_registry := entity_registry` 删局部改读属性；`boss_ui._on_boss_defeated(_defeated_boss)`（真不用 → 单 `_` 前缀且不撞成员）。
- **为什么 lint 没抓到**：`check_syntax` 只认 `SCRIPT ERROR`、`verify` 的启动段只 grep `ERROR`——**W 级警告不在门禁里**；而 headless `load()` 走编译缓存，连警告都不打印。只有编辑器 reload 路径才吐。
- **补门禁**：`tools/check_naming.sh` 新增 **⑤ 形参/局部/循环变量遮蔽类成员**（静态扫描，不依赖 Godot reload）；`tools/verify.sh` 升为 5 步，第 2 步跑 `check_naming.sh --fail`，CI 沿用 `verify.sh` 故自动生效。正向 0、负向探针 `--fail` = 1，均实测。
- **回归测试**：`test_composition_root.test_game_scene_binds_stage_runtime` 增断言 `GameManager.entity_registry == rt.entity_registry`——旧代码必失败（断言数 3216→3217）。
- **教训**：编辑器 reload 的 W 级输出要有人看；`x = x` 这种「看起来在赋值」的自赋值只能靠 warning 暴露，且常被当噪音忽略。**可 lint 的规则不要只写进文档。**
- **验收**：`verify.sh` 五步全绿（312 测试 / 3217 断言）；`check_naming` 0（含新 ⑤）。

### 2026-09-13 — M2：词汇合一（BulletData → BulletType，删 type_for/signature_of/_type_by_sig）

- **决定**：走方向 (b) —— `BulletData` 退化成**构造助手**，`to_bullet_type()` 产出并缓存 `BulletType`。
- **删**：`type_for()` / `signature_of()` / `_type_by_sig` 全删；字段映射从桥接搬进 `BulletData._build_bullet_type()`（宿主→内核仍是单向）。桥接 964 → **906** 行。
- **契约收紧（最重要）**：内核弹型缓存在 **BulletData 实例**上 → 内容**必须复用实例**。旧代码靠"内容签名缓存"兜底，所以 `enemy01` 同一实例换贴图、`reimu_shoot` 每发 new 都能跑；现在不行了。改了 13 个内容文件：
  - 每发 new → 成员缓存（`_main_bullet_data` / `_plain_bullet_data` / …）；类型级字段建一次，速度 / params 每发写。
  - `enemy01/02/03` 原用**同一个** BulletData 交替当"普通弹 / 强化弹"（还改 `coroutine_script`）→ 拆成**两个实例**。
  - `radial_accel` / `bounce` 的 `spawn_factory` 原每次返回新对象 → 改为返回缓存实例。
  - `marisa_shoot` 激光段**逐帧换贴图** → 按帧缓存 `Array[BulletData]`。
  - `BulletShell`（工作台）按配置 key 缓存，配置变才换实例。
- **踩坑**：test 锁着旧契约「工厂每次应是新对象」→ 改为「复用同一缓存实例」。
- **命名合同步**：新增私有字段按 `_<限定词>_<类型snake>` → `_main_bullet_data` 等（`check_naming` 仍 0）。
- **验收**：`grep type_for\|signature_of scripts/` = 0；`verify.sh` 全绿（312 测试 / 3216 断言）；`check_naming` 0。
- **文档**：`CONTENT_GUIDE` 增「弹型实例复用」规则；plan §16.1 度量与 M2 段标记完成；基线融合 bullet 更新为「余 M3」。
- **没做**：`_texture_by_index`（M3）+ `_port_by_sig`（端口收口）仍在；桥接仍认识 `BulletData`（理想 0 属后续）。

### 2026-09-13 — 减法批次 A2c：局部极短名收敛（N19）+ ctx 门面拍板保留

- **拍板**：`ctx.*` 意图门面**不动**（契约 §3 的动词域）；N19 的局部极短名**要清**，但工作台自身本地名不动。
- **改名（非工作台）**：`sd`→`stage_data`；`st`→`stage`（关卡号）/ `behavior_state`（内核行为状态）；`bm`→`bullet_manager` / `bookmarks` / `manager`；`bg`→`background` / `stage_background`；`tl`→`timeline`。
- **隐藏契约**：`tl` 是书签提取器 `bookmark_extractor.gd` 正则 `tl\.at(` 的被扫描对象 —— 内容改名必须**连带把正则改为 `timeline\.at(`**，否则书签静默失效。这是唯一必须碰工作台的一处（2 行正则），其余工作台本地名未动。
- **踩坑**：正则替换 `\btl\b` 漏掉了转义字符串里的 `\ttl.at(`（`tl` 前一个字符是 `t`，无词边界）→ `test_bookmark_extractor` 的 fixture 源码没改到，测试失败。**字符串字面量里的标识符要单独处理。**
- **验收**：`check_naming` 0 条；`check_syntax` 191/0；GUT 311 测试 / 3216 断言全绿。
- **写给未来**：用户指出终局是用 GDExtension 实现系统内核 + 弹幕机制 VM —— 届时现在这些宿主侧的改名/适配成本会大幅消失。

### 2026-09-13 — 减法批次 A2b：公开状态字段也不豁免缩写（拍板）

- **决定**：命名契约的缩写白名单**对公开字段同样生效**，不再走「公开字段允许角色名」的旧豁免。
- **改名**：`refs`（所有 EntityRegistry 字段/属性）→ `entity_registry`；`BulletService.world` / `KernelBomb.world` / `KernelBulletBackend.world` → `bullet_manager`；`StageRuntime.bullets` → `bullet_manager`；`BulletManager.world_refs` → `entity_registry`；`inject_world_refs()` → `inject_entity_registry()`（连带 `HitboxOverlay` / `DebugDrawer` 的 `bullets` 字段）。
- **唯一豁免**：`ctx.*` 意图门面（`ctx.bullets` / `ctx.player` / `ctx.audio`…）—— 契约 §3 定义的动词域，不是随手缩写，本批**故意不动**。
- **踩坑**：`.bullets` 的调用点改名后，忘了改声明方（`HitboxOverlay.bullets`）→ 运行期 `Invalid assignment ... on HitboxOverlay`。**全局 replacement 后必须复查"声明方 vs 调用方"配对。**
- **验收**：`check_syntax` 191/0；GUT 311 测试 / 3216 断言全绿。
- **剩余**：局部极短名 `sd`/`st`/`bm`/`bg`/`tl`（TODO N19）——其中 `tl` 与书签提取器正则 `tl\.at(` 有隐藏契约，改名要连带。

### 2026-09-13 — 减法批次 A2：命名收敛（check_naming 91 → 0）

- **动机**：读代码时同一个东西要在脑内查映射表 —— `_refs`/`_world_refs`、`_bullets`/`_kernel`、`p_ctx`/`_ctx`、`hitpoint_display`、`$UI`/`_game_ui`。这是「不明晰」的物理来源。
- **做法**：按基线《标识符命名契约》机械改（一次性脚本 + 占位符，避免 A→B 再被 B→C 连锁替换）：
  - 私有字段 → `_<类型snake>`；同类型多实例用 `_<限定词>_<类型snake>`（`_move_coroutine_runner` / `_final_boss_data`）。
  - `@onready` → `_`+节点名 snake；节点名太弱（`UI`）则改节点为 `GameUI`；非 PascalCase 节点 `logo`/`roll`/`roll2` → `Logo`/`Roll`/`Roll2`。
  - 参数 `sys` → `system`（宿主侧）。
- **修正 linter**（否则契约自相矛盾）：`tools/check_naming.sh` 现在 ① 排除 `scripts/kernel/**`（vendor 快照）；② 接受「限定词_类型snake」；③ 同类型多名称组仅在存在非类型名时报错。
- **踩坑（必须记）**：脚本化重命名**不能只改声明文件** —— `_tl` 被协程子类 `enemy04.gd` 与 `perf_stress/verify_fix.gd` 直接读；`_current_phase`/`_ctx`/`_shoot_script`/`_runner` 被测试白盒访问；`$UI` 的 tscn 子节点 `parent="UI/..."` 漏了一处 → `Memory/OutlineRect` 找不到。**改名 = 改声明 + 全仓 grep 外部私有访问 + tscn NodePath。**
- **验收**：`check_naming` **0 条**（原 91）；`check_syntax` 191/0；`verify.sh` 全绿（311 测试 / 3216 断言）；`main_menu` + `red_YY_jade` 场景 headless 启动零错误。
- **没做（有意）**：公开角色名（`ctx.refs` / `BulletService.world`）按契约保留；内核内部命名（`behavior_processor._system` 等）随重建版走，不在宿主改。

### 2026-09-13 — 减法批次 A1：清考古注释（188 行 / 77 文件）

- **动机**：指标全绿，但读感不干净 —— 代码里写满 `W4a-2 / K4 / S4c-1 / §21.17 / Track A / Strangler` 这类改动史标签，读起来像考古报告，不像「它本来就是这样」。
- **做法**：一次性 Python 脚本，只动 `#` 注释（跳过字符串与 `code span`），删历史 tag / 日期 / § 引用并清残留标点；`scripts/kernel/**`（vendor 快照）**不动**，否则 `vendor_kernel.sh --check` 会报漂移。再人工修 10 处残留（`bullet_multi_mesh` 头注释、`game_scene` 的 `/R21`、`kernel_bullet_backend` 的 `见 docs`、若干测试断言消息里的 tag）。
- **量化**：188 行注释 / 77 文件；非内核脚本历史 tag 归零；`bullet_multi_mesh` 头注释不再描述已删除的第二条数据路径（关闭 TODO N18）。
- **原则**：**注释只描述「现在是什么、为什么」，「改了什么」归本 LOG。** 代码文件不该承担 changelog。
- **验收**：`check_syntax` 191/0；GUT 全绿；未改任何代码行（纯注释）。

### 2026-09-13 — P2：三个 `static var current` 生产侧收口 + 内核 RNG 跟随宿主 seed

- **目标**：让 `BulletManager` / `StageRuntime` / `EntityRegistry` 的 `.current` 静态不再被**游戏运行时**读取，把「当前世界」从隐式全局改为组合根显式登记 / 注入。
- **为什么**：R8 允许 `static var` 替代部分单例，但运行时跨模块读全局会隐藏依赖，并制造「双世界静默抢登记」（C4）；R2 的正确形态是组合根注入（`ctx.stage`）。
- **落点**：
  - `StageContext`：`bullets` / `effects` / `refs` 三个 getter 去掉 `.current` 回退，只认绑定的 `stage`；无 stage 的 ctx（自机射击 / 共享子弹 ctx）改由宿主显式绑 stage。
  - `SaveData.reset_all/reset_practice(refs)`：注册表由组合根显式传入（`PlayerResources` 仍是唯一 owner）。
  - `SceneTransition.change_scene()`：改收 `on_pause_world` / `on_clear_world` / `on_resume_world` 回调；`GameManager` 新增 `register_world/unregister_world` 显式登记 `world_bullets/world_refs`，不再读 `.current`。
  - `StageRuntime._enter_tree`：**首个赢**（`is_instance_valid` 判定，不无条件覆盖）；`_exit_tree` 对称清 `EntityRegistry.current`。
  - **C5**：`RNG` 增 `seed_changed` 信号，成为**唯一随机真源**；`BulletManager` 监听并把 seed 同步给内核 `BulletSystem`（内核自带 RNG = 同 seed 的派生镜像，宿主侧无人调用它）。
- **工作台 / 调试**：benches 改用自己的 `_bullets`；`creation_station` 从 `_view` 取 `_bullets/_stage_runtime`；`hitbox_overlay` / `debug_drawer` 改注入 `bullets/refs`。`.current` 只剩「写 + 工具/测试」用途（注释已标明）。
- **新接口**：`Player.bind_ctx()`、`BulletManager.inject_stage_runtime()`、`GameManager.register_world/unregister_world()`、`RNG.seed_changed`。
- **验收**：`check_syntax` 191/0；GUT **全绿**（新增 `test_kernel_rng_follows_host_seed`）；`vendor_kernel.sh --check` 漂移 0；`game_scene` + 5 个 workbench 场景 headless 启动零错误；`check_naming` 仍 91（无新增）。
- **没做 / 有意保留**：`static var current` 未物理删除 —— 测试（`test_kernel_swap` / `test_creation_station` / `test_laser` …）与工作台仍以它为便捷入口；生产路径已清零。彻底删除需先让这些用例显式持有实例，属后续纯清理。

### 2026-09-13 — M1：内核认数据（damage / hit_sfx 进 BulletType，tag kernel-v2）

- **做了什么**：内核 `BulletType` 增 `Host payload` 组：`damage: float` / `hit_sfx: StringName`（**只存不解释**，规则仍归宿主）→ 原项目删掉 `_damage_by_index` / `_hit_sfx_by_index` 两张侧表与 `damage_for_index()` / `hit_sfx_for_index()`，`KernelBulletPhysics` 改读 `bt.damage` / `bt.hit_sfx`。
- **流程（M 线首次走通）**：重建版改 + `tests/` **46 套 / 689 断言全绿** → tag `kernel-v2`（`4f49df1`）→ `bash tools/vendor_kernel.sh` 同步（只有 `bullet_type.gd` +7 行）→ 原项目适配层改 → `check_syntax` 191/0 + GUT **57 / 310 / 3215 全绿**。
- **踩坑（必须记）**：`signature_of()` 是**「内容签名 → 弹型」的缓存键** —— `damage` / `hit_sfx` 既已成为弹型字段，就**必须进签名**，否则"同贴图同判定、只有伤害不同"的弹会共用同一个缓存弹型 → **伤害串味**。已补 `hash(data.damage)` / `hash(data.hit_sfx)`。
- **量**：内核 1212 → **1219** 行；桥接 979 → **964** 行；`scripts/kernel_bridge/` 里 `_by_index` 只剩 `_texture_by_index`（属 M3）。
- **测试口径同步**：`test_player_bullet_damages_enemy_via_damage_side_table` → `..._via_bullet_type`，断言消息改「伤害应来自 BulletType.damage」——不留与实现不符的测试名。
- **没做**：`out_grace` 仍暂缓（bomb 走宿主节点，用不到）；纹理旁表留到 M3。

### 2026-09-13 — M0：修 vendor 漂移 + 立 vendor 脚本（融合前置）


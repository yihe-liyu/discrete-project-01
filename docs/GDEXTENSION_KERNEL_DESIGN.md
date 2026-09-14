# GDExtension 弹幕内核 —— 北极星设计（已落地）

> **性质**：终局形态设计（北极星）。本文写"要长成什么样"，好让**每一步都朝它对齐**。
> **状态（2026-09-14 刷新）**：触发条件**已达成**；N1 工具链 ✅、N2.2 原生积分 ✅、N4-real 原生渲染 ✅、
> **L3.5 全落地 ✅**（原生行为/判定/宽相 + 存储翻转：`KernelNativeSystem` 为唯一存储），**`scripts/kernel/**` 已从生产删除**
> 冻结参照移入 `test/reference/`（见 `BEST_PRACTICES_LOG.md` 4e/4f）。**扩展为必需**。
> **已拍板**：① 扩展成为**必需**（**GDScript 内核已从生产删除**，见 `N2_NATIVE_INTEGRATION_PLAN.md` 终局决策 / 4f）；
> ② 实现**不走通用 opcode VM** —— 采用更精简的**「生命周期描述符」**（`BulletLifecycle` → `compile()` 成 packed program → 原生 `behavior_tick`）；
> 本文 §5.7 的「通用 Danmaku VM」为**早期设想，已被取代**。
> **前置阅读**：`docs/archive/NEW_KERNEL_REFACTOR_PLAN.md` §15.6/§16；`docs/N2_NATIVE_INTEGRATION_PLAN.md`（终局决策 + 拆除清单）；`test/reference/`（冻结的 GDScript 参照实现）。

---

## 0. 一句话与前提

**原生层只做"每帧每颗"的机制（积分 / 行为 VM / 宽相 / 精确判定 / 渲染实例缓冲）；GDScript 继续做"每关每波"的内容与外壳；两者之间用批量命令 + 事件队列过边界，绝不逐弹跨边界。**

### 0.1 为什么原生能消掉现在的"乱"

| 现在的痛 | 根因 | 原生如何消失 |
|---|---|---|
| `kernel_bridge` 964 行 | `BulletData` ⇄ `BulletType` 两套词汇翻译 | 一套原生 `DanmakuType`，翻译层不存在 |
| `_texture_by_index`（M3 ③：宿主渲染插座）/ `_port_by_sig`（`signature_of` / `_type_by_sig` 已随 M2 删除） | GDScript 侧表 / 插座 | 原生 `type_id` / `program_id` + 列式表；渲染由 N4 接管 |
| 每弹 `Behavior.process()` + Variant 哈希 | GDScript 调度 | 原生 VM 直跑寄存器 |
| `sys` / `tl` / `refs` 命名纠结 | 手写 GDScript 宿主 | 原生命名，契约不再管宿主内部 |
| 工作台正则扫源码 | 没有程序模型 | 程序是数据，可列举 / 可校验 |

### 0.2 触发条件（没到就别开工）

- 同屏目标 ≥ **6000 弹**；或
- 行为热点成为**实打实卡顿**；或
- 要借原生做**并行 / 大规模数据**。
- **前置 ✅ 已实测通过（N1，2026-09-13）**：`godot-cpp` **v10（master / Beta）用 `api_version=4.7`** 编译 + **Godot 4.7.2 成功加载**（`Hello` 类注册 + 调用成功）。godot-cpp `supported_api_versions` 官方含 **4.7**。环境齐：SCons 4.11.1 / g++ 16.2.1 / Python 3.14.7。**唯一注意**：`.gdextension` 要编辑器导入一次。**剩余门 = 性能 Trigger（≥6000 弹 / 实打实卡顿）；v10 仍 Beta 是长期风险。**

> **实测 Trigger 距离（2026-09-13，`tools/bench_danmaku.gd`；headless 脚本侧热路径，GPU 绘制不计）**
> 合计 ms/帧 = 内核积分 + 行为(world_accel) + 宽相 + **渲染 CPU 同步**。
>
> | N | 直线 ms | 行为 ms | 占 60fps 预算（行为） |
> |---|---|---|---|
> | 3000 | 4.30 | 6.43 | 39% |
> | 4000 | 5.82 | 8.57 | 51% |
> | **6000** | 8.90 | **12.80** | **77%** |
> | 8000 | 11.46 | 16.99 | **102%** |
>
> **关键发现**：单项最大是**渲染 CPU 同步**（`BulletMultiMesh._sync_kernel`，≈1.2µs/弹 → 6000 弹 7.4ms），其次**行为**（≈0.7µs/弹 → 6000 弹 4.3ms）；内核积分 + 宽相各 <1ms。
> 旧数字「3000 弹 ≈ 2.5ms」**只算了物理、漏了渲染同步**（实际脚本侧 ≈ 6.4ms）。
> **结论**：Trigger 比想象中近（6000 弹带行为已占 77% 帧预算）。若上原生，**N3(VM) + N4(渲染) 才是收益大头**，N2(存储) 只值 ~0.8ms。
> **原生探针结果（2026-09-13，`_gdext_spike/src/danmaku_store.{h,cpp}`：SoA 存储 + 积分 + 剔除 + MultiMesh 写入）**
>
> | N | 原生积分 | 原生渲染 | **原生合计** | GDScript 合计(直线) | 倍数 |
> |---|---|---|---|---|---|
> | 3000 | 0.004 | 0.072 | **0.076** | 4.30 | ~57× |
> | 6000 | 0.008 | 0.142 | **0.150** | 8.90 | **~59×** |
> | 8000 | 0.011 | 0.188 | **0.199** | 11.46 | ~58× |
>
> **结论**：脚本侧热路径（积分 + 实例缓冲写入）原生快 **~60×** —— 6000 弹原生合计 **0.15ms**（GDScript 8.9–12.8ms）。
> **对 6000+ 弹的目标，GDExtension 是必需，不是奢侈。** N2(存储) + N4(渲染) 收益被坐实。
> 探针是简化版（单 MultiMesh / 单色 / 无行为 / 无碰撞 / 无图集），但覆盖了每帧每颗的主成本；真实版还需 N3(行为 VM) + 图集 + 纹理句柄。
>
> **更新（2026-09-13，N2.2 积分段 + N4-real 后，真实拆分）**
>
> | 6000 弹 | ms/帧 | 归属 |
> |---|---|---|
> | 积分 | **0.12** | 原生 ✅（N2.2，5.9×） |
> | 行为 | **4.25** | GDScript（**N3 目标**） |
> | 宽相 | 0.33 | GDScript（N2 存储段） |
> | 渲染同步 | **1.10** | 原生 ✅（N4-real，6.5×） |
> | **合计** | **≈5.8（35% 预算）** | 原 12.80（77%） |
>
> **边界铁律（实测）**：原生逐次访问 **110ns/次** vs GDScript `Packed[i]` **13ns**；批量快照 15ns。→ **跨边界必须批量**（命令 + 事件），逐弹 / 逐次转发必亏。
> **剩余大头 = 行为（4.25ms）→ N3。**

---

## 1. 分层与边界（频率分层，决策备忘 §2）

| 频率 | 归属 | 例子 |
|---|---|---|
| **每帧每颗** | **原生 C++** | 积分、VM 指令、宽相、精确判定、实例缓冲写 |
| 每次发射 | 边界（批量命令） | spawn / emit / despawn |
| 每关每波（人写） | GDScript 内容 | `stage01.gd`、Boss 阶段、敌人 AI |
| 外壳 / UI | GDScript | 菜单、对话、存档、音频 |

> **铁律：GDScript 不允许出现在每帧每弹路径里。** 内容是"每波一次"的调度者，不是"每颗一次"的执行者。

---

## 2. 原生层模块图

```
DanmakuWorld (Node)            # 组合根注入的宿主节点；唯一公开入口
├─ TypeRegistry                # DanmakuType（Resource）→ type_id；列式类型表
├─ ProgramRegistry             # DanmakuProgram（Resource）→ program_id；编译缓存
├─ BulletStore                 # 单一 archetype 列式 SoA；容量/自由表/回收
├─ BehaviorVm                  # 字节码 VM（§5）；也是 `Behavior` 注册表的 VM tenant
├─ Broadphase                  # 固定 uniform grid + 行链表桶（复用现有设计）
├─ CollisionPipeline           # 宽相→精确；产出事件，不写规则
├─ RenderBridge                # 原生写实例缓冲 → MultiMesh/RenderingServer 批量提交
├─ CommandBuffer               # 发射/回收/生成，帧首 drain
├─ EventBuffer                 # 命中/擦弹/消弹/离散特效，帧末 drain 给 GDScript
├─ TargetCache                 # 每帧一次的敌/Boss/自机位置+半径 Packed 快照
└─ DeterministicClock/Rng      # 整数 tick + 单 RNG 通道（种子 = RunConfig.seed）
```

**边界规则**：原生层零 `res://`、零 `class_name` 依赖、零 autoload；它只认自己的类型与 Packed 数组。这正是原 `scripts/kernel/` 的 R2/R9 契约；换成原生后**依旧成立**（该内核已从生产删除，冻结参照在 `test/reference/`）。

---

## 3. 数据模型：列式 SoA（单一 archetype）

每一颗弹 = **一行**；热字段各自一条连续 `Packed`/C++ 数组：

```
pos[N] vel[N] accel[N] rot[N] angvel[N] dmg[N] color[N] frame[N]
flags[N] type_id[N] program_id[N] pc[N] wait_ticks[N] state[STRIDE*N]
```

- `state`：每弹寄存器块（§5.4），默认 8 float + 4 vec2 + 2 int。
- 回收用 **swap-remove**（与现池一致）；自由表 + 几何增长。
- `type_id` 指向 native 类型表（一次编译 `DanmakuType` 得到，之后运行期只读整数）。
- **热字段绝不进对象**（决策备忘 §3.5/§5.5 实测：对象数组退化）。

---

## 4. 执行模型：帧序 + 命令缓冲

沿用今天已经验证过的帧序契约，把它变成原生常量：

| 优先级 | 模块 | 做什么 |
|---|---|---|
| `FrameOrder.INTEGRATE` | BulletStore | 位置积分、计时/相位递减、剔除 |
| `FrameOrder.BEHAVIOR` | BehaviorVm | 跑程序：设速度 / 瞄准 / 标记回收 |
| `FrameOrder.FLUSH` | CommandBuffer | 执行 VM 中途入队的 emit/despawn |
| `FrameOrder.COLLISION` | CollisionPipeline | 宽相 + 精确，产出事件 |

- **发射/生成走命令缓冲**：调用方（含 VM）在帧中途只入队，帧末统一 drain —— 避免"边遍历边改池"。
- **跨边界只在两端**：帧首一次性 `set_targets(PackedArrays)`；帧末一次性 `drain_events()`。

---

## 5. Danmaku VM（核心）

### 5.1 为什么 VM 是终局答案（而不是继续手写 Behavior）

- 手写 `Behavior` 会随弹幕种类线性增长且互相重复；VM 让**弹幕 = 数据**。
- 程序可**热重载、可列举、可校验、可跨宿主复用**（本工程 / 重建版 / 未来 demo）。
- 书签 / 工作台不再"正则扫源码"——程序本身就是可遍历的事件表。
- **VM 不是特例**：它只是 `Behavior` 注册表里的第 N 个 tenant，和手写的原生 `Behavior` 平级；复杂/宿主耦合的行为仍可手写。

### 5.2 程序 = 数据

```
DanmakuProgram (Resource)          # 作者友好：ops + 常量池 + 元数据
  ├─ ops: Array[String/字典]        # 或 PackedByteArray（编译后）
  ├─ consts: PackedFloat32Array
  └─ labels / subprograms
        │ 加载时编译一次
        ▼
native program_id                  # 结构数组 / 字节码；运行期零哈希
```

- 程序定义**共享常量块**（type 级）与**每弹状态块**（row 级，§5.4）。
- 定时统一到 **60Hz 物理 tick**：`wait(0.3)` 编译成 `wait_ticks=18`。

### 5.3 指令集草案（先小后大，够用即止）

| 类别 | op | 参数 | 语义 |
|---|---|---|---|
| 控制 | `wait` | t | 暂停 t 秒（tick 累加） |
| | `every` | interval, times | 每 interval 触发后续块，最多 times |
| | `until` | cond | 满足条件才继续（如"到顶边"） |
| | `goto` / `label` | | 跳转 |
| | `call` / `ret` | program_id | 子程序 |
| | `halt` | | 结束 |
| 运动 | `set` | dst, src/const | 赋值 |
| | `accel` | dst, vec | 世界/本地方向加速 |
| | `scale` | dst, f | 缩放（减速/加速） |
| | `rotate` | ang, speed | 角速度 |
| | `aim` | target_kind, spread | 朝目标（自机/敌/Boss） |
| | `anchor` | ref, offset | 锚定（子机/宿主） |
| 生成 | `emit` | program_id, count, spread, dir, speed | 生成子弹（走命令缓冲） |
| | `fork` | program_id | 绑定并行子程序 |
| 随机 | `rand` | dst, min, max | 确定性 RNG（单通道） |
| 判定 | `collision` | flags | can_be_canceled / out_grace / faction |
| 表现 | `fx` / `sfx` | key | 事件输出（帧末 drain） |

> 第一批只需覆盖现在 **2 个** `kernel_port()` 内容（`move_homing` / `marisa_laser_follow`；2026-09-13 grep 实测，原稿写 6 —— 已过时）。但**行为集共 10 个**（含 `BulletData.accel` 派生的 world_accel 等，见 §5.7）。VM 的**触发条件**仍是计划 §15.6：行为种类/复杂度爆炸，或解释器成为热点 —— **现按路径 B 主动推进**。

### 5.4 寄存器模型

- **Program const 块**（只读、共享）：`gravity`、`speed`、`spread`…
- **Row state 块**（每弹可写）：`r0..r7`（float）、`v0..v3`（vec2）、`i0..i1`（int），加隐式 `pc` / `wait_ticks`。
- 指令只读写自己那一行的 state；**跨弹不共享可变状态**（VM 无全局写）。

### 5.5 目标查询（aim / homing 的宿主输入）

- 宿主每帧调用一次 `world.set_targets(...)`：把敌机/Boss/自机的位置与半径打成 Packed 数组。
- 原生 `TargetCache` 缓存；VM 的 `aim` 只查缓存，**不跨边界**。
- 这也是今天 `WorldQuery` + `BehaviorContext` 的原生版。

### 5.6 事件输出（规则归宿主）

- 原生只产出**紧凑事件**：`HitEvent`（弹↔目标、位置、伤害）、`GrazeEvent`、`CancelEvent`、`DespawnEvent`、`FxEvent` / `SfxEvent`。
- GDScript 帧末一次性 `drain_events()`，在宿主侧结算 **擦弹 / 记忆加成 / 音效 / 特效 / 分数**。
- **规则永不进原生** —— 保住今天"内核不认识宿主规则"的边界（也是 M1 的既定决策）。

### 5.7 与 `kernel_port()` 的关系 / 迁移兼容

| 阶段 | 内容脚本写什么 | 谁来跑 |
|---|---|---|
| 今天 | `kernel_port()` → `{move, params}` | GDScript `Behavior` |
| 过渡（**已选路径 B**，先做） | `kernel_port()` → `{program: [op...]}` | **GDScript 参考解释器**（同一份数据） |
| 终局 | 同上（或 `DanmakuProgram` .tres） | 原生 VM |

**先迁数据、后换实现**：程序 schema 一旦定下，内容可以先改成数据形态，GDScript 解释器先跑通并写进测试；等原生 VM 就位，换执行器即可，内容零改动。这条能把"上原生"的风险砍掉一大半。

> **实际落地（2026-09-14，取代本节的「通用 VM」设想）**：数据形态 = **`BulletLifecycle` 描述符**（Phase / Move / Until / Action 词汇），
> `compile()` 成 packed program；执行器 = 原生 `DanmakuStore.behavior_tick`；内容仍写 `kernel_port() → {move, params}`，
> 由 `LifecycleCatalog` 映射成描述符（**创作者接口零改**）。见 `docs/LIFECYCLE_MODEL.md` 与 LOG 的 4e/4f 条目。

### 5.8 确定性

- 整数 tick 驱动；不读 wall clock。
- **单 RNG 通道**（种子 = `RunConfig.seed`），VM 的 `rand` 与宿主 RNG 同源，回放可复现。
- 指令顺序稳定、常量池稳定；float 运算固定顺序（避免并行归约打乱）。

### 5.9 作者体验

- **两种写法都要能跑**：① `.tres` Inspector 可视化编辑；② `kernel_port()` 代码直写（DSL → program）。
- 保留 `BulletData` 风格的构造链作为**糖**，编译到 program，而不是运行时类型。

---

## 6. 渲染归属（M3 终局）

- 原生 `RenderBridge` 每帧把实例变换/颜色写进**预分配缓冲**，每批一次 `MultiMesh` / `RenderingServer` 批量调用（符合 godot-cpp#1063："自包含 + 批量 API"，绝不逐弹跨边界）。
- 图集 + Ubershader；**纹理句柄抽象**同时支持独立 PNG 与 `AtlasTexture`（今天的 `BulletMultiMesh` 已能做，原生化后保留这个能力）。
- 解决今天 `instance_color.a` 被染色模式位占用的问题：模式位挪到 `instance_custom`，`a` 让给逐弹透明度（决策备忘 §5.3）。

---

## 7. 碰撞与"规则归宿主"

- 原生 uniform grid 宽相（复用今天的设计与测试）+ 精确 `hit_geometry`。
- 产出事件（§5.6）；宿主订阅结算。
- 激光：保留"独立批 + 整批 fade"的既有设计，或按 VM 的 `fork` 分段。

---

## 8. GDScript 面 API 草图（终局）

```gdscript
# 组合根：只做装配
var world := DanmakuWorld.new()
world.configure(GameConfig.field_rect(), run_seed)
world.set_targets(Callable(self, "_packed_targets"))   # 每帧一次

var tid := world.register_type(type_res)        # DanmakuType -> int
var pid := world.register_program(prog_res)     # DanmakuProgram -> int

world.spawn(tid, pid, pos, vel, params)         # 每次发射一次
world.cancel(pos, radius)                       # 消弹

for e in world.drain_events():                  # 帧末一次
    match e.kind:
        HIT: ...
        GRAZE: ...
```

对比今天：`ctx.bullets.shoot_spread` → `BulletManager` → `KernelBulletBackend` → `KernelNativeSystem`（原生 store）的链路（宿主 rules + 原生机制，不再是两个内核）。

---

## 9. 工程 / 工具链 / 测试

| 项 | 要求 |
|---|---|
| 产物 | `.gdextension` + **debug/release 两套库**（缺 release → 正式导出原生类型不存在） |
| 版本 | 锁 Godot 次版本；升级 = 重编扩展 + 可能改绑定（写进 baseline） |
| CI | 加 "编译扩展" 步骤；headless 测试跑在扩展已编译的环境 |
| 调试 | 不能用 Godot 脚本调试器；LLDB/GDB attach + `-fsanitize=address,undefined` |
| 热重载 | `reloadable=true`，仅 debug；正式关闭 |
| 测试 | 原生 headless 套件（积分/VM/宽相/判定）+ GUT 只测边界（命令/事件） |
| 内存 | `memnew/memdelete` 成对；泄漏 = ObjectDB 泄漏（本项目已亲历，必须进 CI） |

---

## 10. 迁移路线（从现状出发，每步可停可退）

- **N0 边界冻结**（已完成）：`scripts/kernel/` 0 宿主引用、vendor 流程、FrameOrder 契约。
- **N1 工具链验证 ✅ 已实测通过（2026-09-13）**：godot-cpp **v10（master）** + `api_version=4.7` → `scons target=template_debug` 编译最小 extension → **Godot 4.7.2 成功加载并注册类**（`ClassDB.class_exists("Hello") = true`）。环境：SCons 4.11.1 / g++ 16.2.1 / Python 3.14.7。**注意**：`.gdextension` 需编辑器导入一次（写 `.godot/extension_list.cfg`）才会被加载。**工具链已不是门。**
- **N2.1 ✅（2026-09-13）** 原生 `DanmakuStore`：SoA + per-bullet type/faction/color + `spawn_batch`（~55×）。
- **N2.2 积分段 ✅（2026-09-13）** 原生积分（**5.9×**）；**L3.5-4e ✅（2026-09-14）** 改为原生**有状态** `integrate`/`behavior_tick`，`KernelNativeSystem` 为唯一存储（standalone，不再 extends `BulletSystem`）。
- **N2 存储段（待做）** 原生接管 spawn / despawn / 宽相，消除 GDScript SoA。
- **N3 行为 VM（待做，路径 B）**：按 §5.7 —— **先定 program schema + GDScript 参考解释器**，内容 `kernel_port()` → `{program:[...]}`，测试锁定；再换原生 VM 执行器。§5.1 的**手写原生 tenant** 留给宿主耦合行为。
- **N4-real ✅（2026-09-13）** 原生 `DanmakuRenderBridge` 整段渲染同步（**6.5×**，6000 弹 7.19→1.10ms）；余图集资源（S13）按需。
- **N5 收口**：GDScript 只剩内容 / 外壳 / 宿主规则；`kernel_bridge` **行数不是目标** —— 改**结构性判据**（0 类型映射 / 0 内容签名侧表 / 内核 0 宿主引用，见 `docs/archive/NEW_KERNEL_REFACTOR_PLAN.md` §16.5）。

---

## 11. 能删掉什么（对现工程的清算）

- `scripts/kernel_bridge/`：**翻译层已删**（4f）；**宿主耦合永久保留**（伤害/擦弹/bomb/Boss + 原生 store 快照桥 + 行为 program 装配）。
- `BulletData` ⇄ `BulletType` **双词汇 → 一套**（M2 的终局答案）。
- 5 张侧表 → 0（`type_id` / `program_id` 取代）。
- `ctx.bullets` 五跳 → 一跳。
- 工作台"正则扫源码取书签" → 列举 program。
- 宿主内部命名的所有纠结（`sys`/`tl`/`refs`）——原生有自己的命名，不进命名契约。

---

## 12. 风险与开放问题

1. **工具链 ✅ 已实测通过（N1，2026-09-13）**：v10 + `api_version=4.7` 编译成功，Godot 4.7.2 加载成功 —— 此风险**关闭**。剩余：v10 仍 Beta（无 stable 分支）；GDExtension 语义 target 早期版本可在后期 minor 跑、反之不行。
2. **命名撞车**：原生类与 GDScript `class_name` 同一张全局表 → 原生类需前缀/命名空间，或删除同名 GDScript 类。
3. **编辑器工作流**：原生自定义 Resource 要在 Inspector 显示与序列化，需 `ClassDB` 注册 + `_bind_methods`。
4. **确定性跨平台**：float 舍入 / SIMD 可能分歧；并行化要固定归约顺序。
5. **调试成本**：从"存盘即跑"变成"等编译 + attach 调试"。
6. **内容迁移**：`BulletData` 构造链要不要保留为糖？保留了就多一层编译，不保留就动所有内容。
7. **别过早开工**：未到 §0.2 触发条件就上原生 = 用复杂度换不存在的性能（决策备忘的结论）。

---

## 13. 现在的建议（不现在开工，但先对齐）

1. **先做 M2（词汇合一）**：VM 的 `type` 模型 = 一套类型；M2 做完，N3 才不需要再翻译。
2. **把 `program` schema 先写成 Resource 草案**（可以不实现执行器）：这样内容里 `kernel_port()` 可以先往数据形态靠。
3. **只做便宜的内优化**（决策备忘 §8 的 E/F）：批量行为接口 + 参数定长数组，量到收益再说。
4. **到触发条件**再走 N1 → N2 spike；**spike 不过就不上**。

> 一句话：**先把"宿主期能删的噪音"删干净（M2/M3），让将来的原生边界更清楚；原生 VM 是终局，不是当下的 KPI。**

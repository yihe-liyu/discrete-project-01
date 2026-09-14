# 弹幕生命周期模型（LIFECYCLE MODEL）—— 已落地（L1–L4）

> **状态**：**已落地（2026-09-14，L1–L4）**。B 路线（N3）的形态 = **一套词汇，三种 runtime**
> （低频 GDScript / 高频 per-bullet 固定描述符 / 原生执行）。
> **相关**：`docs/GDEXTENSION_KERNEL_DESIGN.md` §1/§5/§5.7；`docs/N2_NATIVE_INTEGRATION_PLAN.md`。
> **由来（2026-09-13 决策）**：放弃「通用 opcode VM」，改为「频率分层 + 固定 schema 相位描述符」。理由见 §8。

---

## 0. 一句话

**按频率分层：低频（关卡 / 敌人 / Boss / spawn 编排）用时间线写（GDScript，方便）；高频（per-bullet）用「相位 + 数学原语 + 条件」的固定描述符（原生，便宜）。两者共用同一套生命周期词汇。**

**铁律**：
1. **GDScript 不进每帧每弹路径**（§1 分层）。
2. **不引入通用 opcode VM**：无 `pc` / `goto` / 表达式 / 任意循环。描述符是**固定 schema**，可静态校验。
3. **统一的是「词汇 + 创作面」，不是「引擎」**：三种 runtime 本来就不同，硬合成一个会变成 leaky abstraction，**反而更难追溯**。

---

## 1. 生命周期词汇（唯一一套）

| 词 | 含义 | 三处都用 |
|---|---|---|
| **Phase 相位** | 生命周期的一段：进入时一次，之后每 tick 跑 moves，直到 until 成立 | ✅ |
| **Move 原语** | 每 tick 施加的**数学**变换 | per-bullet（低频层用时间线事件替代） |
| **Until 条件** | 结束当前相位的判据（时间 / 位置 / 距离 / 事件） | ✅ |
| **Action 动作** | 相位结束（或时刻到）时的**一次性**动作：emit / sfx / transform / despawn | ✅ |
| **Timer 计时** | 秒或 tick 倒计时 | ✅ |
| **Emit 发射** | 生成子弹（低频=直接 spawn；高频=入延后队列） | ✅ |

**刻意不在词汇里的**：任意表达式、任意循环、跨弹共享可变状态、跳转表。
> 需要这些 → 说明它是**低频**逻辑，用 GDScript 时间线写。

---

## 2. 三种 runtime（按频率分层）

| 层 | 频率 | 生命周期形态 | runtime | 位置 |
|---|---|---|---|---|
| 关卡 / Boss 阶段 / 敌人 AI | 每波 / 每事件 | 时间线（`at` / `every` / `wait` + 条件） | `Timeline`（**已有**） | `scripts/coroutine/timeline/` |
| 弹幕 **spawn 编排** | 每波 | 时间线 + pattern builder（ring / fan / spiral / wall / aimed） | `Timeline` + `StageDirector` / `BulletService` | `scripts/coroutine/` |
| **per-bullet 行为** | 每帧每颗 | **相位 + 数学原语 + 条件** | **原生描述符执行器（待建）** | `gdextension/src/` |

> 现有 `CoroutineScript` 的**快速模式**（`coroutine_script.gd:44`，"子弹协程专用，快 2-3 倍"）是**per-bullet 时间线的尝试** —— 仍不够快，才搬到原生 behavior。**这条历史结论就是本模型分层的依据。**

---

## 3. per-bullet 描述符（固定 schema，可原生执行）

```
BulletLifecycle {
  phases: [ Phase ]              # 有序，不跳转
}
Phase {
  moves:  [ Move ]               # 每 tick 顺序施加
  until:  Condition              # 缺省 = 永续
  on_end: [ Action ]             # 相位结束的一次性动作
}
Move      = { kind, f0..f3 }             # 纯数值参数
Condition = { kind, f0..f3 }
Action    = { kind, action_id, f0..f3 }  # action_id → 宿主表（工厂 / sfx / 内容回调）

每弹另有：phase_index(PackedInt32) + state 行块
```

- **状态槽静态分配**：每个 Move 声明所需行状态（`rotate`→`turned`、`aim`→`elapsed`、`anchor`→`drift`）；编译期算好总 stride，运行期零分配、零哈希。
- **per-shot 参数**（弹速 / 反弹角 / 难度值）在发射时绑定到描述符实例的数值槽；**结构**（phases）是共享只读的。
- **Callable 不进原生**：`spawn_factory` / 内容回调注册成 `action_id`，原生只回传 id（沿用 N2.2 的事件思路）。

> **关键原则（让描述符封闭）**：**Move 与 Condition 必须原生**（每帧每颗）；**Action / Emit 是一次性（低频）→ 可以回调 GDScript 内容**。
> 所以「复杂散圈 / 难度 / RNG / 多弹型」全部落在 Action，**天然不进热路径** —— 这是本模型能既封闭又精简的原因。

### Move 首批（覆盖现有 10 行为）

| Move | 参数 | 行状态 |
|---|---|---|
| `accel_world` | vec | — |
| `accel_along_vel` | a | — |
| `rotate` | w | turned |
| `aim` | target_kind, max_turn/s, dist_weight | elapsed |
| `anchor` | anchor_id / offset, drift_speed, angle | drift |
| `speed_ramp` | min, top, time | elapsed |
| `set_vel` | dir, speed | — |
| `scale` | f | — |

### Condition 首批

| Condition | 参数 | 用于 |
|---|---|---|
| `never` | — | accel / 直线 |
| `timeout` | t | homing_duration / avoid flee_time |
| `top_edge` | — | radial_accel |
| `wall_hit` | sides mask | bounce（碰框时位置夹到框上） |
| `near_player` | r | avoid / non_mid travel |
| `near_boss` | r | non_mid flee（**待验证**，见 §5.2） |
| `turned` | limit | curve |

### Action 首批
`emit` / `sfx` / `transform` / `despawn` / `set_vel`。

---

## 4. 创作者面

**内容创作者实际写的是「端口」**（`move + params`）—— 权威表见 `CONTENT_GUIDE.md`「弹幕行为接口」：
```gdscript
func kernel_port() -> Dictionary:
    return {"move": &"bounce", "params": {&"accel": 120.0, &"bounce_angle": 0.3}}
```

**引擎侧**（`LifecycleCatalog` 的 preset 实现）用 fluent builder → 描述符（真实方法名）：
```gdscript
BulletLifecycle.new()\
    .accel_heading(100.0)                                   # Move\
    .until_at_wall(WALL_LEFT | WALL_RIGHT | WALL_TOP)       # Until\
    .sfx(&"kira", -8.0).emit(factory, toward(T_BOSS, 0.3), 0.0, true).despawn()   # Action
```
- **Move**：`accel_world` `accel_heading` `rotate` `steer` `speed_lerp` `scale_speed` `set_heading` `set_speed` `anchor_drift`
- **Until**：`until_never` `until_elapsed` `until_near` `until_at_wall` `until_state` `until_turned`；`then()` 开新相位
- **Action**：`sfx` `emit` `despawn` `on_end_heading` `on_end_call`
- **方向糖**：`heading(angle)` `toward(target, angle)` `away(target, angle)`

**Canned preset**（10 个 `move` 的实现）：
```gdscript
BulletLifecycle.bounce(accel_rate, bounce_angle, spawn_speed, factory, sfx_key := &"kira", sfx_db := -8.0)
BulletLifecycle.homing(angle_per_sec, accel_time, min_speed, max_speed, duration, proximity_boost)
BulletLifecycle.curve(w, limit)
BulletLifecycle.radial_accel(accel_rate, factory, sfx_key := &"", sfx_db := 0.0)
BulletLifecycle.non_mid_flee(proximity, boss_radius, burst)
BulletLifecycle.avoid_player(proximity, jump, flee_time)
BulletLifecycle.world_accel(v)   /   BulletLifecycle.accel(a)
BulletLifecycle.laser_follow(anchor_id, offset, angle, drift_speed, initial_drift)
BulletLifecycle.marisa_laser(anchor_id, offset, angle, drift_speed, initial_drift)
```

> **创作者只写 `move + params`**，不碰 opcode —— 没有原语泄漏（满足"创作者方便"硬约束）。

---

## 5. 表达力试金石

### 5.1 `bounce`（最有条件性的一个）

现有 `bounce_behavior.gd` 逐条 → 描述符：

| 现有步骤 | 描述符落点 |
|---|---|
| `v += v.normalized() * accel * dt` | `moves: [accel_along_vel(accel)]` |
| 碰左/右/上框（下墙穿出） | `until: wall_hit(LEFT\|RIGHT\|TOP)` |
| 碰框时把 pos 夹到框上 | `wall_hit` 语义内含（原生在触发帧夹位） |
| `speed = v.length()`；`spawn_speed>0` 则替换 | 数值槽（发射时绑定） |
| `aim = (boss - at).normalized()`，无 Boss 退 DOWN | `aim_boss(angle, fallback := DOWN)` |
| `dir = aim.rotated(bounce_angle)` | 同上（角度入参） |
| 播 `kira` sfx | `sfx("kira", -8.0)` |
| `host.queue_spawn(b, at, dir)` + `request_despawn` | `emit_action(factory)` + `despawn` |

```
bounce → phases: [
  { moves: [accel_along_vel(accel)],
    until: wall_hit(LEFT|RIGHT|TOP),
    on_end: [ sfx("kira", -8.0),
              emit(action_id=factory, target=boss, angle=bounce_angle, fallback=DOWN, speed=spawn_speed),
              despawn ] }
]
```
**一相位 + 一条件 + 三动作，全部可表达。** ✅

> **✅ 已验闭合（2026-09-13，读 `non_mid01_bullet.gd`）**：它的 burst 条件确实是 `pos.distance_to(boss) < diff_pick([175,150,125,100])` → 就是 `near_boss(r)`（r 随难度）。散圈本身（难度 / RNG / 小玉+红棱）是**一次性内容逻辑** → `emit_action(burst_action_id)` 回调宿主即可。**描述符在最有条件性的两条上都封闭。**

| 行为 | 描述符 |
|---|---|
| `accel` | `[{moves:[accel_along_vel(a)], until:never}]` |
| `curve` | `[{moves:[rotate(w)], until:turned(limit)}]` → `[{moves:[]}]` |
| `world_accel` | `[{moves:[accel_world(v)], until:never}]` |
| `radial_accel` | `[{moves:[accel_along_vel(rate)], until:top_edge, on_end:[sfx, emit(dir=DOWN), despawn]}]` |
| `homing` | `[{moves:[aim(nearest, angle_per_sec, dist_weight), speed_ramp(min,top,accel_time)], until:timeout(duration)}]` |
| `avoid_player` | `[{until:near_player(r), on_end:[set_vel(away)]}, {until:timeout(flee_time), on_end:[despawn]}]` |
| `laser_follow` / `marisa_laser` | `[{moves:[anchor(ref, offset, drift, angle)], until:never}]`（`use_global` 区分两者） |
| `non_mid_flee` | `[{until:near_player(r), on_end:[set_vel(away)]}, {until:near_boss(r), on_end:[emit_action(burst), despawn]}]` |

> **⚠ 开放项（L2 验证）**：`non_mid_flee` 现在的"散圈"条件写在**内容回调** `on_flee_burst` 里（`non_mid01_bullet.gd`）。要么抽象成 `near_boss(r)` 条件 + `emit`，要么保留一个**罕见的 content-predicate 事件**。**必须在 L2 定死，否则描述符在这条上不封闭。**

---

## 6. 追溯指南（"我要改 X → 看哪"）

| 我要改… | 看 |
|---|---|
| 某关的波次时序 / BGM / 对话 / Boss 进出 | `data/stages/<stage>/stage_script/*.gd` + `Timeline` |
| 某种 spawn 形状（环 / 扇 / 螺旋 / 墙） | pattern builder（`StageDirector` / `BulletService`） |
| 某颗弹的**生命周期** | `BulletLifecycle` 描述符 / preset |
| 敌机 AI / 移动 | `data/stages/<stage>/enemy/*.gd`（`CoroutineScript`） |
| Boss 阶段时长 / 血量 / 掉落 / 脚本 | `PhaseData`（`.tres`） |
| 内核执行 / 性能 / 判定几何 | `gdextension/src/` |

**这张表就是"快追溯"的承诺**：任何一处都能落到"频率 → 词汇 → 文件"三格。

---

## 7. 与现有代码的映射（保留 / 迁移 / 删）

| 现有 | 处置 |
|---|---|
| `Timeline` / `TimelineEvent` | **保留**（低频 runtime 主体） |
| `CoroutineScript` / `StageDirector` / `PhaseData` | **保留**（低频） |
| `*_shoot.gd`（波编排） | **保留** + 加 pattern builder |
| `kernel_bridge/behavior/*.gd`（10 个） | → **描述符 preset**（L2）→ 删 GDScript 实现（L4） |
| `*_bullet.gd`（`kernel_port` 参数翻译） | → **builder sugar** |
| `CoroutineScript` 快速模式（子弹协程） | 已废，随 GDScript 内核拆除 |

---

## 8. 与 §5 通用 VM 的关系（为什么改）

| §5.3 原案 | 本模型 |
|---|---|
| 通用 opcode：`wait/goto/call/fx/sfx/emit/rotate/aim/...` + pc + 表达式 | **固定 schema 相位描述符**：无 pc / goto / 表达式 |
| 试图用一份 VM 同时跑 spawn 与 per-bullet | **频率分层**：低频 `Timeline`、高频描述符 |
| op 集欠定、混层、无带参子程序 | **词汇正交**（Phase/Move/Until/Action）+ preset 复用 |
| 序列化 `Array[String/字典]` | **纯数值结构**（可校验、可紧打包） |

§5.7「**先迁数据、后换实现**」**仍成立** —— 只是"数据"从"程序"变成"生命周期描述符"。

---

## 9. 落地步骤

| 步 | 做什么 | 产出 |
|---|---|---|
| **L0** | 本文档评审定稿 | 词汇 + schema 冻结 |
| **L1 ✅（2026-09-13）** | `BulletLifecycle` builder（GDScript）+ **参考解释器**（跑描述符；现冻结在 `test/reference/lifecycle_behavior.gd`） | 2/2 parity：bounce/curve 逐位 |
| **L2 ✅（2026-09-13）** | 10 行为写成 preset，**parity** vs 现有 GDScript 行为 | 10/10 逐位 parity（bounce/curve + 8 个） |
| **L3 ✅（2026-09-14）** | **原生描述符执行器**（C++ `behavior_tick`），换执行器；parity vs 参考解释器 | `test_native_executor` 9/9 |
| **L4 ✅（2026-09-14，4f）** | 拆 GDScript 行为 + GDScript 内核（按拆除清单） | `scripts/kernel/**` 1225 行从生产删除；oracle 冻结进 `test/reference/` |

> 依赖：L3 需要 **N2 存储段**（原生 SoA）—— 否则重演 110ns 的坑。

---

## 10. L1 实测记录（2026-09-13）

- ✅ **通过**：`bounce` + `curve` 与现有行为**逐位 parity**（`test_lifecycle_model` 2/2 / 33 断言）。
- **结论**：描述符 schema + Phase/Move/Until/Action 词汇**足以表达**条件性最强的行为 —— 模型成立。
- **暴露的引擎 bug**：`BehaviorProcessor` **升序** drain despawn → 多弹同帧回收**丢一个**（详见 `BEST_PRACTICES_LOG.md`）。**已修**（2026-09-13 降序 drain：重建版 `2466a93` / 主工程 `16645d0`）；`BehaviorProcessor` 本身已随 L3.5-4f 删除。
- **待办（L2）**：其余 8 个 preset + parity（homing / radial / non_mid / laser / avoid / world_accel / accel）。

---

## 11. L1.5：正交 unit 集（实现，2026-09-13）

> §3 的 Move/Condition 表是初稿；L1.5 按「**状态显式 + unit 正交**」定型为下表。**状态由 builder 按相位自动分配槽，相位切换清零**；创作者看不到槽。

| 类 | unit | 说明 |
|---|---|---|
| Move | `accel_world(v)` | v += v_world·dt |
| | `accel_heading(a)` | 沿航向加速 |
| | `rotate(w, limit=0)` | 角速度；limit>0 钳到累计转角（自带槽） |
| | `steer(target, max_turn, ramp=0, dist_weight=0, speed_from, speed_to, steer_until=0)` | 朝目标转向；可融合速度（homing 1:1）/ 限时转向 |
| | `speed_lerp(from, to, ramp)` | 速度按相位 elapsed 插值 |
| | `scale_speed(f)` / `set_speed(s)` / `set_heading(dir)` | 原语 |
| | `anchor_drift(anchor_id, offset, angle, speed, use_global)` | 锚定 + 线性漂移（自带槽） |
| Condition | `never` / `elapsed(t)` | — |
| | `near(target, r, every=0, every_ticks=0)` | every>0 秒；every_ticks>0 帧门控（non_mid 的 skip%3） |
| | `at_wall(mask)` | 夹位并输出落点（供 `emit(at_end)`） |
| | `state(slot, cmp, v)` | 读槽（`until_turned()` 是便利封装） |
| Action | `emit(factory, dir, speed, at_end)` | dir 表达式；at_end 用条件落点 |
| | `sfx(key, db)` / `despawn` / `on_end_heading(dir)` / `on_end_call(fn)` | 内容回调（散圈）用 call |
| 方向表达式 | `toward(t, angle)` / `away(t, angle)` / `heading(angle)` | t = player / nearest_enemy / boss |

**边界**：unit 停在**语义**层（上表 ~15 个）；不下沉到微 op（否则变回 §5 大 VM）。

**踩坑**：`then()` 生成的新相位 `until=never`；在其上挂 `on_end` 动作**永不触发**。

**L2 实测（2026-09-13）**：10 个行为全部逐位 parity（`test_lifecycle_model` + `test_lifecycle_presets`）。为 parity 追加的语义化 unit 细节：`steer` 的 `speed_from/speed_to`（融合速度）与 `steer_until`（限时转向）、`near` 的 `every_ticks`（帧门控）、`on_end_call`（内容回调）、`T_NEAREST_ENEMY` 跳过时符 Boss。

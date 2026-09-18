# 弹幕内核接口（DANMAKU API）

> **一句话**：给一颗弹写飞行规律 = `BulletData.trajectory(BulletLifecycle)`；发射 = `ctx.bullets.shoot_spread(...)`。
> 本文是弹幕创作的**唯一权威参考**：BulletData / BulletLifecycle 全词汇 + 原生语义 + 发射 API + ctx 服务 + 素材表 + 文件接线 + 陷阱。
> 由浅入深的教学路径见 `CONTENT_GUIDE.md` `六·弹幕行为`；本文是它的**完整字典**。
> 原生执行器：`gdextension/src/danmaku_store.cpp`（唯一存储/执行）；桥接：`scripts/kernel_bridge/`。

---

## 0. 心智模型（三层）

```
内容脚本 (CoroutineScript, GDScript 低频)
   │  构造 BulletData（贴图/判定/阵营）+ trajectory(BulletLifecycle)
   ▼
描述符 (BulletLifecycle, 固定 schema)
   │  compile() → packed program（ops/args/phases）
   ▼
原生执行 (DanmakuStore, C++ 每帧每弹)
     位置积分 / 条件 / 动作 / 命中 / 渲染缓冲
```

三条不变量：
1. **内容不碰 opcode**：只写 `BulletData` / `BulletLifecycle` / `ctx.*`。
2. **BulletData 实例必须复用**（弹型缓存在实例上）—— 见 `9。
3. **GDScript 不进每帧每弹路径**：per-bullet 逻辑一律描述符；一次性/低频才用回调（`on_end_call`）。

---

## 1. 最小可跑示例

```gdscript
extends CoroutineScript
## 从上往下，每 0.4 秒放一扇 5 连小玉

var _bullet: BulletData          # 成员：建一次、复用（铁律）

func _tick(p_ctx: StageContext) -> Variant:
	if _bullet == null:
		_bullet = BulletData.new().tex("小玉").speed(220).color(Color.AQUA).enemy()
	_bullet.trajectory(BulletLifecycle.new().until_never())
	p_ctx.bullets.shoot_spread(_bullet, 5, deg_to_rad(40.0), Vector2.DOWN, target.global_position)
	return p_ctx.clock.wait(0.4)
```

- `target` = 宿主注入的节点（敌人 / Boss 自己）。
- 返回值语义见 `5.1。
- `shoot_spread` 的 `base_dir` 定方向，`data.velocity.length()` 定速度（见 `4.1）。

---

## 2. BulletData（弹型 + 构造链）

`scripts/data/bullet_data.gd` ｜ `extends Resource, class_name BulletData`

### 2.1 字段

| 字段 | 类型 | 默认 | 说明 |
|---|---|---|---|
| texture | Texture2D | null | 贴图（用 `tex(key)` 设，别手写） |
| tint_mode | TintMode | MULTIPLY | MULTIPLY=贴图×tint；BLEND=取贴图亮度混 tint（敌弹换色） |
| tint | Color | WHITE | 染色 |
| damage | float | 10.0 | 基础伤害（支持小数，累积到整才扣血） |
| velocity | Vector2 | (0,-1) | **只取长度当速度**；方向由发射时的 direction 决定 |
| faction | Faction | PLAYER | PLAYER / ENEMY / BOMB |
| can_be_canceled | bool | false | 是否可被 Bomb 清 |
| hitbox_shape | HitboxShape | CIRCLE | CIRCLE / RECTANGLE |
| hitbox_radius | float | 4.0 | 圆判定半径 |
| hitbox_size | Vector2 | (8,8) | 矩形判定尺寸（shape=RECTANGLE 才用） |
| hitbox_offset | Vector2 | ZERO | 判定偏移 |
| hitbox_rotation | float | 0.0 | 矩形判定旋转（弧度） |
| hit_effect | PackedScene | null | 命中特效场景 |
| hit_sfx | String | "" | 命中音效 key（`AssetRegistry.sounds`；空=normal_damage） |
| is_spawn_fog | bool | false | 是否播弹雾 |
| fog_texture | Texture2D | null | 弹雾贴图（`tex()` 自动填） |
| out_grace | float | 0.0 | 出界宽限秒（出界后仍活这么久；0=立即回收） |
| lifecycle | BulletLifecycle | null | 弹道描述符（**推荐主路**） |
| lifecycle_anchor | Variant | null | per-shot 锚点 `{id, offset, use_global}`（激光用） |
| coroutine_script | Script | null | **已弃用**：旧端口载体 |
| params | Dictionary | {} | **已弃用**：旧端口参数 |

> `faction` 用 `enemy()` / `player()` / `bomb()` 设；`damage` / `hit_sfx` 直接赋值。

### 2.2 构造链方法

| 方法 | 作用 |
|---|---|
| `.tex(key)` | 设贴图 + **自动按 `bullet_configs` 配判定** + 弹雾贴图。**key 必须来自 `7.1 表** |
| `.speed(v)` | 速度大小（`velocity.y = v`，长度 = v） |
| `.dir(x, y)` | 直接设 velocity（方向+速度）—— 只在 `shoot_spread` 传 `ZERO` 方向时才用得上 |
| `.color(c)` | 染色 |
| `.blend(true)` | 用 BLEND 混合（敌弹换色用；默认 MULTIPLY） |
| `.enemy()` | 敌弹：faction=ENEMY、可被清、出弹雾 |
| `.player()` | 自机弹：faction=PLAYER、damage=10 |
| `.bomb()` | 炸弹弹（走宿主节点） |
| `.trajectory(lc, anchor)` | **挂描述符**（主路） |
| `.grace(v)` | out_grace |
| `.behavior(script)` | **已弃用** |

> **未知 tex key 是静默的**：`get_bullet_tex("typo") → null`，判定退回默认 4px。务必查 `7.1 表。

### 2.3 弹型缓存（实例复用铁律）

- `to_bullet_type()` 在**首次发射**时把类型级字段（贴图 / 阵营 / 判定 / 伤害 / 命中特效 / 命中音效）快照到内核弹型，缓存挂在 **BulletData 实例**上。
- 所以：**同一实例反复发射 = 共用同一弹型**；每发 `BulletData.new()` 会让内核弹型表每发膨胀。
- 速度 / tint **不属弹型**，每发可改。
- 运行期改类型级字段 → 必须 `invalidate_bullet_type()`。

---

## 3. BulletLifecycle（弹道描述符）

`scripts/kernel_bridge/lifecycle/bullet_lifecycle.gd` ｜ `extends RefCounted, class_name BulletLifecycle`

### 3.1 相位（Phase）模型

```
BulletLifecycle = [ Phase, Phase, ... ]     # 有序，不可跳转
Phase = { moves: [Move...], until: Until, on_end: [Action...] }
```

- 每帧按顺序跑 moves，直到 `until` 成立 → 执行 `on_end` → 进下一相位。
- `then()` 开新相位（线性，只能往下）。
- 相位切换会**清零所有状态槽**。
- **最后一个相位结束后**：弹不再受 program 驱动，按当前速度自由积分（出界由 cull 回收）。
- **陷阱**：`then()` 生成的新相位 `until = never`；在它上面挂 `on_end` 永不触发。

### 3.2 Move（每帧施加，9 个 op；`anchor_drift` / `drift` 是 `position` 的糖）

| Move | 签名 | 语义 |
|---|---|---|
| accel_world | `accel_world(v: Vector2)` | `velocity += v * dt`（世界坐标恒定加速度） |
| accel_heading | `accel_heading(a: float)` | 沿**自身朝向**加速：`velocity += heading * a * dt`（与速度解耦，v=0 也有效 → 可减速/反向） |
| rotate | `rotate(w, limit=0)` | **同时**转速度与朝向；limit>0 时累计转角钳到 limit（自带槽，`until_turned()` 用） |
| rotate_velocity | `rotate_velocity(w, limit=0)` | **只转速度**（朝向不变，V12） |
| rotate_heading | `rotate_heading(w, limit=0)` | **只转朝向**（速度不变，V12） |
| steer | `steer(target, max_turn, ramp=0, dist_weight=0, steer_until=0)` | 朝目标**只转向、不改速度**；ramp 秒内爬满转向权；dist_weight>0 时近距离转得更快；steer_until>0 时只在前 N 秒转。变速另配 `speed_lerp` |
| speed_lerp | `speed_lerp(from, to, ramp)` | 方向不变，速度按 elapsed/ramp 从 from 插值到 to |
| speed_mul | `speed_mul(f: float)` | 每帧 `velocity *= f`（**复利/指数算子**，不是瞬时设定；线性变速用 `speed_lerp`、瞬时用 `set_speed`） |
| set_heading | `set_heading(dir: Dictionary)` | 设速度方向（保速度大小）**并同步朝向** |
| set_speed | `set_speed(speed: float)` | 设速度大小；方向不变，**v=0 时用「朝向」定方向**（V15，不再静默 no-op） |
| anchor_drift | `anchor_drift(anchor_id, offset, angle, speed, use_global=true, initial=0, render_heading=false)` | **`position`(mode=ANCHOR) 的糖**：`pos = anchor_base + dir(angle)·drift`；drift 首帧=initial，之后 += speed·dt；render_heading=true 时设置**独立渲染朝向**（逐弹 `render_rot` 通道，不写 velocity）。**需 `trajectory(lc, anchor)` 提供锚点** |
| drift | `drift(angle, speed, initial=0)` | **`position`(mode=PHASE_START) 的糖**：从**本弹相位起点**沿 dir(angle) 匀速平移（不锚定外部对象）；不改速度/朝向 → 整圈可刚性平移后自由飞出 |

> `heading`（朝向）出生时取自初速；`rotate` / `set_heading` 会更新它；`accel_heading` / `forward` / `random_dir` / `chance_toward` 读它。
>
> **⚠ 位置来源（V18「模式派」）**：位置由**一个** `position` op 设置的**来源模式**决定 —— `ANCHOR`（外部节点，激光）或 `PHASE_START`（本弹相位起点，刚性平移）；缺省 `FREE`（自由积分）。`anchor_drift(...)` / `drift(...)` 是两种模式的 builder 糖。
> - **进入 / 切换模式**：首帧 `pos = base + dir(angle)·initial`（位置立即由模式接管），之后每帧 `drift += speed·dt`。
> - **模式只写 `pos`**：`v` / `h` 完全不受影响；`render_heading=true` 走**独立的逐弹渲染朝向通道**（V19，不再写 velocity）。
> - **离开模式**（相位结束、下一相位无 position op）：`pos` 留在模式最后一次结果，积分从该点接力；弹按速度轴的状态自由飞（所以 `drift` 后能按出生方向飞出）。
> - **同相位多个 position op**：按顺序执行、**最后一个写 `pos`（last-wins）** —— 这是「模式切换」，不是叠加。位置模式与速度 op 混用会让速度变化在位置上看不见（见 §9.13）。

### 3.3 Until（相位结束条件，4 + until_turned 糖 + 通用节流）

| Until | 签名 | 语义 |
|---|---|---|
| never | `until_never()` | 永不结束（靠 emit/despawn 手动结束） |
| elapsed | `until_elapsed(t)` | 相位经过 t 秒 |
| near | `until_near(target, r)` | 距 target < r |
| at_wall | `until_at_wall(mask)` | 越界检测（左 1 / 右 2 / 上 4）；**纯谓词**：只输出「相位结束落点」（不改弹自身位置），供 `emit(..., at=AT_PHASE_END)` |
| turned（糖） | `until_turned()` | 当前相位 `rotate` 的累计转角 ≥ 其 limit；**必须跟在同相位 rotate 之后**（否则 warn + 退化 never） |

> **通用节流（V6）**：任何 Until 都可链式 `.every(sec)` / `.every_ticks(n)`，例如 `until_near(T_PLAYER, r).every(0.05)`、`until_elapsed(2.0).every_ticks(3)`。
> **state 条件不再公开（V8）**：状态槽对创作者不可见，裸 slot 的 `until_state(slot, ...)` 已移除；读取状态只经 `until_turned()`。

### 3.4 Action（相位结束时一次性，6 个）

| Action | 签名 | 语义 |
|---|---|---|
| sfx | `sfx(key: StringName, db: float = 0)` | 播音效（key 见 `7.2） |
| emit | `emit(spawn, dir, speed=0, at=AT_CURRENT)` | 生成替换弹；`spawn` = BulletData / Callable()->BulletData / 数组；`at` 是**位置操作数**（`AT_CURRENT` / `AT_PHASE_END`） |
| emit_variant | `emit_variant(spawns: Array, dir, speed=0, at=AT_CURRENT)` | **变体发射**：内核**显式抽一次 RNG**定分支（0=未中→spawns[0]，1=命中→spawns[1]）；`dir` 必须是 `chance_toward(...)` |
| despawn | `despawn()` | 回收自己 |
| on_end_heading | `on_end_heading(dir)` | 转向（保速度大小） |
| on_end_call | `on_end_call(hook)` | **逃逸口（V13）**：每相位结束最多一次、宿主侧、非热路径。`hook` = StringName（注册表名，推荐）或 Callable；`host` 只暴露 `queue_spawn`。用了它描述符就不再是唯一行为来源 |

**emit 细则**：
- `speed <= 0` → 继承当前速度大小；`speed > 0` → 用该速度。
- `at=AT_PHASE_END` → 用 until（at_wall）输出的相位结束落点；`AT_CURRENT`（默认）→ 当前弹位置。
- 事件回传 (program, local) 给宿主，宿主把模板实例化成新弹 —— **Callable / BulletData 永不进原生**。
- **变体发射（V9）**：独立 op，内核显式抽一次 RNG 定分支、只回传分支号；模板永远留宿主 → 可换色 / 换贴图 / 换大小。方向不再借隐藏通道：命中走 `toward(target)`、未命中走 `forward(spread)`，由 op 参数直接携带。例：
  ```gdscript
  lc.emit_variant([_青玉, _红玉], BulletLifecycle.chance_toward(T_PLAYER, 0.1, a), 60.0)
  ```

### 3.5 方向表达式（静态构造；供 steer / emit / set_heading / on_end_heading 用）

| 表达式 | 签名 | 语义 |
|---|---|---|
| heading | `heading(angle)` | 世界角：0=上，正=顺时针（屏幕 y 向下）；`(sin a, -cos a)` |
| toward | `toward(target, angle=0)` | 朝 target 方向再转 angle；**target 不可用时退化为向下 (0,1)** 再转 angle |
| away | `away(target, angle=0)` | 背对 target 再转 angle |
| forward | `forward(angle=0)` | 沿**自身朝向**再转 angle（与速度解耦） |
| random_dir | `random_dir(spread)` | 沿自身朝向 ±spread 内随机（内核确定性 RNG；**每次求值抽 1 次**，V10） |
| chance_toward | `chance_toward(target, p, spread=0)` | p 概率**精确朝** target（angle 被忽略）；否则沿自身朝向转 spread。**仅作 `emit_variant` 的 dir**（V9：分支由该 op 显式抽） |

> **RNG**：内核单通道 PRNG，种子由宿主 `RNG` 派生；抽取顺序 = 弹行遍历顺序 → 回放可复现。

### 3.6 常量

```gdscript
BulletLifecycle.T_PLAYER          # 0  自机
BulletLifecycle.T_NEAREST_ENEMY   # 1  宿主候选集里最近的一个（targetability 由宿主决定，V14）
BulletLifecycle.T_BOSS            # 2  Boss
```

> **目标契约（V14）**：target 是固定枚举（自机 / Boss / 宿主候选集最近）。`T_NEAREST_ENEMY` 只在**宿主提供的候选集**里取最近；targetability 策略归宿主：`EntityRegistry.get_targetable_enemies()` → `Enemy.is_targetable()`（未开战 / 对话中的 Boss 不是目标）。内核不内嵌过滤。

```gdscript
BulletLifecycle.WALL_LEFT   # 1
BulletLifecycle.WALL_RIGHT  # 2
BulletLifecycle.WALL_TOP    # 4   # at_wall 只支持 左/右/上（无下墙，故无 WALL_BOTTOM）

BulletLifecycle.AT_CURRENT    # 0  emit 用当前弹位置（默认）
BulletLifecycle.AT_PHASE_END  # 1  emit 用 until 输出的相位结束落点

BulletLifecycle.ROT_BOTH      # 0  rotate：同时转速度与朝向
BulletLifecycle.ROT_VELOCITY  # 1  rotate：只转速度
BulletLifecycle.ROT_HEADING   # 2  rotate：只转朝向

BulletLifecycle.CMP_GE  # 0  槽 >= value
BulletLifecycle.CMP_LE  # 1  槽 <= value
```

### 3.7 状态槽（slots）

- 有状态 unit 自动分配槽：`rotate`→turned、`position`(ANCHOR)→drift（1 槽）、`position`(PHASE_START)→起点+位移（3 槽）；`steer` 读相位 elapsed（**不占独立槽**）。
- 相位切换清零；只有 `until_turned` 读它（`state` 条件不公开，V8）。
- 创作者**看不到槽**（builder 自动分配）。
- **同相位状态槽上限 = 8**（内核 `SLOT_STRIDE`）：`position`(PHASE_START) 占 3，`position`(ANCHOR) / `rotate` 各占 1。**超过上限的 program 会被内核拒绝注册**（该弹退化为直线，不执行行为）。

### 3.8 preset（10 个类型化薄包装；组合定义在 `LifecycleCatalog.build()`）

```gdscript
BulletLifecycle.world_accel(v: Vector2)
BulletLifecycle.accel(a: float)
BulletLifecycle.curve(w: float, limit: float)                         # rotate + until_turned + then
BulletLifecycle.homing(angle_per_sec=720°, accel_time=2, min_speed=500, max_speed=2000, duration=2, proximity_boost=150)
BulletLifecycle.bounce(accel_rate, bounce_angle, spawn_speed, spawn, sfx_key=&"kira", sfx_db=-8.0)
BulletLifecycle.radial_accel(accel_rate, spawn, sfx_key=&"", sfx_db=0.0)
BulletLifecycle.avoid_player(proximity, jump, flee_time)
BulletLifecycle.non_mid_flee(proximity, boss_radius, burst)
BulletLifecycle.laser_follow(anchor_id, offset, angle, drift_speed, initial_drift)
BulletLifecycle.marisa_laser(anchor_id, offset, angle, drift_speed, initial_drift)
```

各 preset 的展开（= `LifecycleCatalog.build()`）：

| preset | 展开 |
|---|---|
| world_accel | `[accel_world(v)]`，until never |
| accel | `[accel_heading(a)]`，until never |
| curve | 相位1 `[rotate(w, limit)]` until turned → 相位2 空 |
| homing | `[steer(T_NEAREST_ENEMY, angle_per_sec, accel_time, proximity_boost, duration), speed_lerp(min_speed, max_speed, accel_time)]`，until never |
| bounce | `[accel_heading(accel)]`，until at_wall(LEFT\|RIGHT\|TOP)，on_end [sfx(kira,-8), emit(spawn, toward(T_BOSS, bounce_angle), spawn_speed, at=AT_PHASE_END), despawn] |
| radial_accel | `[accel_heading(rate)]`，until at_wall(TOP)，on_end [sfx?, emit(spawn, heading(PI), 0, at=AT_PHASE_END)（向下）, despawn] |
| avoid_player | 相位1 until near(T_PLAYER, proximity, every=jump)，on_end 背对自机 → 相位2 until elapsed(flee_time)，despawn |
| non_mid_flee | 相位1 until near(T_PLAYER, proximity, every_ticks=3)，on_end 背对自机 → 相位2 until near(T_BOSS, boss_radius, every_ticks=3)，on_end [call(hook), despawn] |
| laser_follow | `[anchor_drift(..., use_global=false, render_heading=false)]`，until never |
| marisa_laser | `[anchor_drift(..., use_global=true, render_heading=true)]`，until never |

> **新增 preset** = 在 `lifecycle_catalog.gd` 的 `build()` 加分支，用已有原语拼，**不用改 C++**。

### 3.9 编译与共享

- `compile()` → `{ops, args, move_start, move_count, until_idx, act_start, act_count, phase_count, slots, actions, sfx}`。
- `content_signature()` = 结构哈希（内容相同 → 共用同一原生 program）。
- **同结构才共享**：`chance_toward` 的 p、`accel` 的值都进签名。

### 3.10 锚点（激光）

```gdscript
b.trajectory(lc, {&"id": node.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true})
```

- `id=0` → 自机 + offset
- `use_global=true` → 锚点 global_position + offset（子机是 World 兄弟）
- `use_global=false` → player + 锚点局部 position（focus 子机是 player 子节点）

---

## 4. 发射 API（`ctx.bullets`）

`scripts/coroutine/services/bullet_service.gd`

### 4.1 shoot_spread（唯一弹幕发射入口）

```gdscript
ctx.bullets.shoot_spread(bullet_data: BulletData, count: int, spread_angle: float, base_dir: Vector2, at: Vector2, sfx: AudioStream = null) -> void
```

- `count == 1`：打一发，方向 = base_dir，**忽略 spread_angle**。
- `count > 1`：
  - `spread_angle >= TAU` → 铺满一圈，step = spread/count（base_dir 是起点）。
  - 否则 → 以 base_dir 为中心左右展开，step = spread/(count-1)。
- 每发的速度 = `bullet_data.velocity.length()`（**方向来自这里，不是 data.velocity 的方向**）。

> 想"逐发不同速度/颜色"：复用实例、每发改 `velocity` / `tint` 后再 `shoot_spread`（入队瞬间快照，安全）。

### 4.2 激光

```gdscript
ctx.bullets.spawn_laser(skeleton: LaserSkeleton, color: Color, opts := {}) -> LaserBeam
ctx.bullets.fire_growing_laser(curve: Curve2D, color, speed=600, tail=300, lifetime=8, tex=null) -> LaserBeam
ctx.bullets.fire_line_laser(a: Vector2, b: Vector2, color, lifetime=3, tex=null) -> LaserBeam
ctx.bullets.fire_fixed_laser(curve: Curve2D, color, lifetime=3, tex=null) -> LaserBeam
ctx.bullets.fire_homing_laser(origin, player_pos, color, bend=100, length=500, lifetime=5) -> LaserBeam
ctx.bullets.clear_all_lasers()
```

### 4.3 清弹 / 炸弹

```gdscript
ctx.bullets.death_clear(pos, max_radius, duration, start_radius=30, on_clear=Callable())
ctx.bullets.shoot_bomb(data: BombData, pos, direction, tint=Color.WHITE, spawn_delay=0.0)
```

---

## 5. 内容脚本契约（CoroutineScript）

`scripts/coroutine/base/coroutine_script.gd` ｜ `extends CoroutineRunner, class_name CoroutineScript`

### 5.1 _tick 返回值（每物理帧调用）

| 返回 | 含义 |
|---|---|
| `ctx.clock.wait(sec)`（>0 的 float/int） | 等 sec 秒后再调 |
| `true` | 下一物理帧立即再调 |
| `false` / `null` | 协程结束 |

### 5.2 启动 / 属性

```gdscript
s.auto_stop = true/false     # true: _tick 返回 false 即止；false: 持续运行
s.target: Node2D             # 宿主注入（敌人 / Boss 自己）
s.ctx: StageContext
s.start(ctx)                 # 由宿主调用
s.get_dt() -> float          # 当前物理帧步长（**别用 get_physics_process_delta_time()**）
s.start_timeline() -> Timeline
```

- `dt` 只在物理帧累加，暂停自动冻结；`get_dt()` 在无节点 / 树外模式也正确。

### 5.3 难度

```gdscript
diff_pick(arr)               # arr[SaveData.selected_difficulty]
diff_get(dict, key, default) # dict[difficulty][key]
ctx.diff.picked()            # 当前难度索引
ctx.diff.pick(arr)
ctx.diff.at_least(n)         # 当前难度 >= n
```

难度索引：**0=Easy 1=Normal 2=Hard 3=Lunatic 4=Extra**。

### 5.4 Timeline（低频排程）

```gdscript
var tl := start_timeline()
tl.at(0.0).do(func(): ...)
tl.at(2.0).every(1.5).times(4).do(_wave)
tl.wait(0.0).do(func(): ...)          # 等上一个阻塞事件（如 Boss 击破）后 N 秒
tl.start_phase(func(): return _boss, phase_data)
tl.loop()
# 在 _tick 里： return tl.tick(get_dt())
```

---

## 6. ctx 服务总表

`scripts/coroutine/services/stage_context.gd`

| 服务 | 关键方法 |
|---|---|
| `ctx.clock` | `wait(sec)` / `wait_frames(n)` |
| `ctx.bullets` | `shoot_spread` / `fire_*_laser` / `death_clear` / `shoot_bomb` |
| `ctx.player` | `get_player() -> Player` / `get_position() -> Vector2` |
| `ctx.boss` | `current() -> Boss` / `exists() -> bool` |
| `ctx.enemies` | `spawn(data: EnemyData) -> Enemy` |
| `ctx.diff` | `picked()` / `pick(arr)` / `pick_from(dict, key, def)` / `at_least(n)` |
| `ctx.audio` | `play_bgm(stream, gap=0)` / `stop_bgm()` / `play_sfx(stream, db=0)` |
| `ctx.effects` | `add_miss_circle(...)` / `play_hit_effect(scene, pos)` |
| `ctx.items` | `spawn(type, position)` |
| `ctx.dialogue` | `play_steps(steps)`（经 `ctx.play_dialogue_steps` 更常用） |
| `ctx.objects` | `register(key, obj, type)` / `resolve_as(key, type)` / `clear()` |
| `ctx.stage` | `bullet_manager` / `entity_registry` / `item_pool` / `fx_pool` / `miss_layer`（机制，内容一般不用直接摸） |
| `ctx.entity_registry` | 自机 / 敌机 / Boss 的只读注册表（内容一般经上面的服务） |

> `ctx.*` 是**意图门面**：内容只说意图，机制在服务 / host。无 `stage` 绑定时多数方法静默 no-op（测试友好）。

### 场景导演（关卡编排，非弹幕）

`scripts/coroutine/director/stage_director.gd`：`bgm(key)` / `boss(key, data, from, to, hide)` / `dialogue(steps)` / `on(event, handler)` / `dispose()`

`scripts/coroutine/director/boss_handle.gd`（`boss()` 的返回值）：

| 动词 | 作用 |
|---|---|
| `enter(to, from, dur=1.5)` | 进场移动 |
| `phase(index=0, idle_only=false)` | 进入阶段 |
| `reveal(name)` | 改名 + 亮名字节点 |
| `set_name(name)` | 只改名（不动显隐） |
| `show_name() / hide_name()` | 只切名字节点显隐 |
| `show_phase_dots() / hide_phase_dots()` | 阶段进度点显隐（默认隐藏） |
| `retreat(to, dur=2.0)` | 退场 |
| `resolve() / exists()` | 解析当前 Boss |

> 名字节点 / 进度点**默认隐藏**（`BossHud`），关底想显示就 `reveal(name)` + `show_phase_dots()`。

---

## 7. 素材与常量表

### 7.1 子弹贴图 key（`BulletData.tex(key)` 唯一来源）

`scripts/asset_registry.gd` 的 `bullet_configs` —— **可用值如下（完整）**：

| key | 判定 | 备注 |
|---|---|---|
| 点弹 | circle 4 | 微型 |
| 点棱弹 | circle 4 | 微型 |
| 菌弹 | circle 4 | 微型 |
| 小玉 | circle 6 | 小型（最常用） |
| 星弹 | circle 6 | 小型 |
| 枪弹 | circle 6 | 小型 |
| 棱弹 | circle 6 | 小型 |
| 滴弹 | circle 6 | 小型 |
| 环玉 | circle 6 | 小型 |
| 符札 | circle 6 | 小型 |
| 米弹 | circle 6 | 小型 |
| 苦无 | circle 6 | 小型 |
| 长菌弹 | circle 6 | 小型 |
| 鳞弹 | circle 6 | 小型 |
| 小光玉 | circle 12 | 中型 |
| reimu_main / reimu_opt1 / reimu_opt2 | rect / circle / rect | 自机弹 |
| marisa_main / marisa_opt1 / marisa_opt2 | rect | 自机弹 |
| reimu_bomb01 | circle 45 | 自机炸弹 |
| laser | circle 0 | 激光贴图 |

> 未知 key → 静默 null + 默认 4px 判定。**新增贴图** = 往 `assets/Textures/bullet/` 放 PNG + 在 `bullet_configs` 加一行。

### 7.2 音效 key

`ctx.audio.play_sfx(AssetRegistry.sounds[key])` / `sfx()` / `hit_sfx` 可用：

`shoot` `player_shoot` `kira` `enemy_die` `player_die` `graze` `item` `card` `player_card` `select` `ok` `cancel` `pause` `lazer` `marisa_damage` `msl` `normal_damage`

### 7.3 阵营 / 混合

```gdscript
BulletData.Faction.PLAYER / ENEMY / BOMB
BulletData.TintMode.MULTIPLY   # rgb = 贴图 × tint（tint=白 = 原色）
BulletData.TintMode.BLEND      # rgb = mix(tint, 白, 贴图亮度)（敌弹换色）
```

---

## 8. 文件与接线

### 8.1 阶段目录布局

```
data/stages/<stage>/
  stage_script/*.gd        关卡编排（Timeline）
  enemy/*.gd               敌人行为（CoroutineScript）
  phase/<phase>/*.tres     PhaseData
  phase/<phase>/*_move.gd  Boss 移动脚本
  phase/<phase>/*_shoot.gd Boss 弹幕脚本
  phase/<phase>/*.gd       其它内容脚本（@role 覆写）
  background/ stage_data/
```

### 8.2 PhaseData（`scripts/data/phase_data.gd`）

| 字段 | 说明 |
|---|---|
| name | 符卡名（空 = 非符） |
| uid | 全局唯一符卡编号（0 = 非符不记） |
| bonus / time_limit / hp | 奖励 / 时限 / 血量 |
| is_timeout_only | 时符 |
| move_script / shoot_script | 挂的 Script（Boss 移动 / 弹幕） |
| params | 注入脚本同名属性 |
| background | 可选换背景 |
| item_* | 掉落 |
| open_reduce_time / open_reduce_ratio | 开局减伤 |

### 8.3 目录注解（创作台索引）

```gdscript
extends CoroutineScript
## 非符一：三向扇形
## @name: 非符一
## @desc: 扇开三向、每向 5 连
## @role: boss_shoot     # 角色覆盖（约定判错时才用）
```

角色约定：`*_move.gd`→Boss移动 · `*_shoot.gd`→弹幕发射 · `enemy/`→敌人行为 · `stage_script/`→关卡编排 · `background/`→背景演出。

---

## 9. 陷阱清单（必读）

1. **BulletData 必须复用实例**（弹型缓存在实例上）。每发 `new()` = 弹型表膨胀。
2. **tex key 拼错是静默的**（null + 默认 4px 判定）→ 只从 `7.1 表取。
3. **速度来自 `data.velocity.length()`，方向来自发射参数** —— 别指望 `data.velocity` 的方向。
4. **`then()` 的新相位 `until=never`**，挂 `on_end` 永不触发。
5. **`speed_mul` 是每帧乘**（复利/指数），想线性变速用 `speed_lerp`、瞬时设定用 `set_speed`。
6. **`at_wall` 只支持 左/右/上**（无下墙，`WALL_BOTTOM` 已移除）；`emit(..., at=AT_PHASE_END)` 用其输出的落点。
7. **`toward` / `away` 目标不可用时退化为向下**（不是不动）。
8. **`chance_toward` 命中时 angle 被忽略**（精确朝目标），angle 只服务 fallback。
9. **`on_end_call` 的 hook 名要先注册**：`LIFECYCLE_HOOKS_SCRIPT.register(&"名字", Callable(obj, "方法"))`；否则静默不调。
10. **变体发射的模板要与分支数对齐**：`chance_toward` 只有 0/1 两支。
11. **自机弹 tint 会被记忆值往红 lerp**（`prepare_shot`），内容设的 tint 只是基底。
12. **改类型级字段后要 `invalidate_bullet_type()`**，否则沿用旧弹型。
13. **位置来源是模式、不是可叠加项**：`position`（`anchor_drift` / `drift`）直接写 `pos`、覆盖积分；同相位与速度 op 混用会让速度变化在位置上看不见，多个 position op 是「模式切换、后写者胜」。要分段用 `then()`。模式只写 `pos`，`v` / `h` 保持（释放后按速度轴飞）。
14. **同相位状态槽 ≤ 8**（`position`(PHASE_START) 占 3，`position`(ANCHOR) / `rotate` 各占 1）；超出会被内核拒绝注册，该弹按直线飞。
15. **RNG 是单通道、按「op 顺序 + 弹行遍历顺序」消耗（V10：消耗点显式化）**：只有 `random_dir`（每求值抽 1）、`emit_variant`（每次抽 1 定分支）会消耗随机；`_resolve_dir` 本身不再抽。加/删/重排这些表达式、或改变弹的发射顺序，都会平移之后所有随机序列（回放仍可复现，但结果会变）。
16. **`on_end_call` 是逃逸口（V13）**：每相位结束最多一次、宿主侧、**非热路径**；回调拿 `(pos, boss_pos, has_boss, host)`，`host` 只暴露 `queue_spawn`。用了它，描述符不再是唯一行为来源——别把它当 per-frame 逻辑或状态存储。
17. **target 枚举固定、候选集由宿主给（V14）**：`T_NEAREST_ENEMY` = 宿主候选集最近；targetability（未开战 Boss 排除）在 `EntityRegistry.get_targetable_enemies` / `Enemy.is_targetable`，不在内核。

---

## 10. 完整例子

### 10.1 环形铺满（每 1.2 秒一圈）

```gdscript
extends CoroutineScript

var _b: BulletData

func _tick(p_ctx: StageContext) -> Variant:
	if _b == null:
		_b = BulletData.new().tex("小玉").speed(160).color(Color.AQUA).blend(true).enemy()
	_b.trajectory(BulletLifecycle.world_accel(Vector2(0, 60)))   # 缓慢下坠
	p_ctx.bullets.shoot_spread(_b, 12, TAU, Vector2.RIGHT, target.global_position)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -10.0)
	return p_ctx.clock.wait(1.2)
```

### 10.2 减速往返 → 回点分裂（orbit_probe 实录）

```gdscript
const DECEL := 150.0
var _青玉: BulletData
var _红玉: BulletData

func _probe_lifecycle(bullet_speed: float) -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.accel_heading(-DECEL)                          # 沿朝向匀减速 → 停 → 反向飞回
	lc.until_elapsed(2.0 * bullet_speed / DECEL)      # 位移过零 ≈ 回到出发点
	lc.sfx(&"kira", -8.0)
	for a in [TAU / 4.0, TAU / 8.0, TAU / 12.0, TAU / 20.0]:
		lc.emit_variant([_青玉, _红玉],
			BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, 0.1, a), 60.0)
	lc.despawn()
	return lc
```

### 10.3 自机狙变体颜色（最小）

```gdscript
lc.emit_variant([_青玉, _红玉],
	BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, 0.1, TAU / 6.0), 60.0)
```

---

## 11. 到这里之后

| 想干什么 | 去哪 |
|---|---|
| 教学 / 由浅入深 | `CONTENT_GUIDE.md` `六·弹幕行为` |
| 关卡 / 敌人 / Boss 编排 | `CONTENT_GUIDE.md` 二~四 |
| 描述符设计动机 / 边界 | `docs/LIFECYCLE_MODEL.md` |
| 原生执行细节（op / 事件 / 同步点） | `docs/GDEXTENSION_KERNEL_DESIGN.md` + `gdextension/src/danmaku_store.cpp` |
| 架构 / 命名契约 | `docs/ARCHITECTURE.md` + `docs/BEST_PRACTICES_BASELINE.md` |

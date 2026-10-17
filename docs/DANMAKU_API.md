# 弹幕内核接口（DANMAKU API）

> **一句话**：给一颗弹写飞行规律 = `BulletData.trajectory(BulletLifecycle)`；发射 = `ctx.bullets.shoot_spread(...)`。
> 发射后每一跳经过谁（宿主 ↔ 原生内核 ↔ 渲染）：见本文附录 B。
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
| hitbox_shape | HitboxShape | CIRCLE | CIRCLE / RECTANGLE |
| hitbox_radius | float | 4.0 | 圆判定半径 |
| hitbox_size | Vector2 | (8,8) | 矩形判定尺寸（shape=RECTANGLE 才用） |
| hitbox_offset | Vector2 | ZERO | 判定偏移 |
| follow_dir | bool | true | 贴图/判定随飞行方向旋转；圆弹设 false（省一次旋转，视觉不变） |
| dir_offset | float | 0.0 | 朝向补偿（弧度，仅 follow_dir 时生效；素材朝右=0、朝上=+PI/2） |
| hit_effect | PackedScene | null | 命中特效场景 |
| hit_sfx | String | "" | 命中音效 key（`AssetRegistry.sounds`；空=normal_damage） |
| is_spawn_fog | bool | true | 是否跟随阵营出生雾；`.no_spawn_fog()` 逐型关（与 `.enemy()` 顺序无关） |
| spawn_fx | EffectType | null | 这型的出生特效（null=用阵营默认） |
| out_grace | float | 0.0 | **逐弹出界宽限（秒）**：出界后仍活这么久；0 = 出界立即回收（默认）。走 `hitbox_*` 同规格：类型级 → 发射时推给内核逐行解释 |
| lifecycle | BulletLifecycle | null | 弹道描述符（**推荐主路**） |
| lifecycle_anchor | Variant | null | per-shot 锚点 `{id, offset, use_global}`（激光用） |
| coroutine_script | Script | null | **已弃用**：旧端口载体 |
| params | Dictionary | {} | **已弃用**：旧端口参数 |

> `faction` 用 `enemy()` / `player()` / `bomb()` 设；`damage` / `hit_sfx` 直接赋值。

### 2.2 构造链方法

| 方法 | 作用 |
|---|---|
| `.def(d)` | 直接传 `BulletDef`（如 `preload` 常量）载入**外观 + 碰撞 + 朝向**；对象版，无查找 |
| `.tex(key)` | 同 `.def`，但按字符串 key 查 `data/bullets/<key>.tres`（**当前内容主路**；key 来自 `7.1 表，拼错=运行时响亮告警） |
| `.speed(v)` | 速度大小（`velocity.y = v`，长度 = v） |
| `.dir(x, y)` | 直接设 velocity（方向+速度）—— 只在 `shoot_spread` 传 `ZERO` 方向时才用得上 |
| `.color(c)` | 染色 |
| `.blend(true)` | 用 BLEND 混合（敌弹换色用；默认 MULTIPLY） |
| `.enemy()` | 敌弹：faction=ENEMY、可被清（出生雾归阵营默认；`.no_spawn_fog()` 逐型关） |
| `.player()` | 自机弹：faction=PLAYER、damage=10 |
| `.with_spawn_fog(effect)` | 打开/换出生雾（effect 空 = 阵营默认） |
| `.no_spawn_fog()` | 关掉出生雾：这型弹直接出现 |
| `.bomb()` | 炸弹弹（走宿主节点） |
| `.trajectory(lc, anchor)` | **挂描述符**（主路） |
| `.grace(v)` | out_grace |
| `.behavior(script)` | **已弃用** |

> **未知 tex key 会响亮告警**：`BulletCatalog.find("typo")` → `push_warning` + null（**不静默回退**）；务必查 `7.1 表。

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

### 3.3 Until（相位结束条件，5 + until_turned 糖 + 通用节流）

| Until | 签名 | 语义 |
|---|---|---|
| never | `until_never()` | 永不结束（靠 emit/despawn 手动结束） |
| elapsed | `until_elapsed(t)` | 相位经过 t 秒 |
| near | `until_near(target, r)` | 距 target < r |
| at_wall | `until_at_wall(mask)` | 越界检测（左 1 / 右 2 / 上 4）；**纯谓词**：只输出「相位结束落点」（不改弹自身位置），供 `emit(..., at=AT_PHASE_END)` |
| speed | `until_speed(cmp, value)` | `|v|` 与 value 比较（cmp = `CMP_GE` / `CMP_LE`）——撞墙后减速到某速度等 |
| turned（糖） | `until_turned()` | 当前相位 `rotate` 的累计转角 ≥ 其 limit；**必须跟在同相位 rotate 之后**（否则 warn + 退化 never） |

> **通用节流（V6）**：任何 Until 都可链式 `.every(sec)` / `.every_ticks(n)`，例如 `until_near(T_PLAYER, r).every(0.05)`、`until_elapsed(2.0).every_ticks(3)`。
> **state 条件不再公开（V8）**：状态槽对创作者不可见，裸 slot 的 `until_state(slot, ...)` 已移除；读取状态只经 `until_turned()`。

### 3.4 Action（相位结束时一次性；8 个 op + `despawn_clear()` 组合糖）

| Action | 签名 | 语义 |
|---|---|---|
| sfx | `sfx(key: StringName, db: float = 0)` | 播音效（key 见 `7.2） |
| emit | `emit(spawn, dir, speed=0, at=AT_CURRENT)` | 生成替换弹；`spawn` = BulletData / Callable()->BulletData / 数组；`at` 是**位置操作数**（`AT_CURRENT` / `AT_PHASE_END`） |
| emit_variant | `emit_variant(spawns: Array, dir, speed=0, at=AT_CURRENT)` | **变体发射**：内核**显式抽一次 RNG**定分支（0=未中→spawns[0]，1=命中→spawns[1]）；`dir` 必须是 `chance_toward(...)` |
| despawn | `despawn()` | 回收自己。**静默**（不播特效）—— 多数 despawn 发生在屏外或做超时清理 |
| **clear_fx** | `clear_fx()` | **纯 action（op 47）**：在弹**此刻位置**播一次「消弹消散」特效（颜色 = 该弹当前色提亮 1.5×），**不改任何状态**，弹继续飞 |
| **despawn_clear** | `despawn_clear()` | `clear_fx().despawn()` —— 消散 + 回收。用于**显式**想让人看见「这颗弹消失了」的场合 |
| on_end_heading | `on_end_heading(dir)` | 转向（保速度大小） |
| on_end_call | `on_end_call(hook)` | **逃逸口（V13）**：每相位结束最多一次、宿主侧、非热路径。`hook` = StringName（注册表名，推荐）或 Callable；`host` 只暴露 `queue_spawn`。用了它描述符就不再是唯一行为来源 |

> **`despawn` vs `despawn_clear`（2026-09-22 立）**：默认用 `despawn()`。只有当你**确实想让人看见消散**时才用
> `despawn_clear()`。⚠️ 别无脑全换 —— `bounce` / `radial_accel` 在**撞墙**时回收、`avoid_player` 相位2 在
> **屏外**回收；那些地方播消散 = 屏外闪光 + 高强度弹幕下的特效风暴。
>
> 消散特效与死亡清弹圈扫掠**共用同一实现**（`KernelNativeSystem.play_clear_fx`，同色提亮 1.5×）。
> 原生侧由 op 47 发 `kind=3` 事件，**载荷自带该弹颜色** —— 因为事件 drain 时那些行已被 swap-remove，
> 宿主无法按行 id 回查颜色。

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
| reflect | `reflect(angle=0)` | **镜面**：把**当前速度**按发射点所在的场边翻分量 —— 左右边翻 x、上边翻 y，角落两边都翻（原路返回），再转 `angle`。需配 `at = AT_PHASE_END`；不在场边 → 退化为自身朝向 |

> **镜面反射（`reflect`）**：`at_wall` 只输出「夹到边上的相位结束落点」、**不改弹自身位置**，
> 所以 `reflect` 的判据是**发射点贴没贴场边** —— 必须走 `emit(..., at = AT_PHASE_END)`：
> ```gdscript
> lc.until_at_wall(BulletLifecycle.WALL_LEFT | BulletLifecycle.WALL_RIGHT | BulletLifecycle.WALL_TOP)
> lc.emit(反射弹, BulletLifecycle.reflect(), 150.0, BulletLifecycle.AT_PHASE_END)
> lc.despawn()
> ```
> **撞的是哪面墙不用你声明**（内核按落点自己判）→ 不会和 `at_wall` 的 mask 脱节。
> 「镜面 + 微散」用 `reflect(deg_to_rad(8.0))`。原生专属用例：`test/test_native_reflect.gd`。

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

### 3.8 preset（9 个类型化薄包装；组合定义在 `LifecycleCatalog.build()`）

```gdscript
BulletLifecycle.world_accel(v: Vector2)
BulletLifecycle.accel(a: float)
BulletLifecycle.curve(w: float, limit: float)                         # rotate + until_turned + then
BulletLifecycle.homing(angle_per_sec=720°, accel_time=2, min_speed=500, max_speed=2000, duration=2, proximity_boost=150)
BulletLifecycle.bounce(accel_rate, bounce_angle, spawn_speed, spawn, sfx_key=&"kira", sfx_db=-8.0)
BulletLifecycle.radial_accel(accel_rate, spawn, sfx_key=&"", sfx_db=0.0)
BulletLifecycle.avoid_player(proximity, jump, flee_time)
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

**数据源 = `data/bullets/<key>.tres`**（`BulletDef` 内容资源；`BulletCatalog` 扫目录建索引）。
`BulletDef` 只放**外观 + 碰撞 + 朝向**（共享、换发不换的那点）：`texture_key`（→ `data/atlas/bullet_shapes.tres` 图集格）
+ `hitbox_radius`/`hitbox_size`/`hitbox_offset` + `follow_dir`/`dir_offset`。其余一切（阵营 / 染色 / 特效 / 伤害 / 出生雾）
由 `BulletData` **构造链**按需给 —— 构造链的存在就是为了「只改一点不必新建资源」。`bullet_configs` 代码表已退役。
运行时类型是 **`BulletType`**（`BulletData.to_bullet_type()` 的产物，内核/渲染读它），**不是内容资源**。
贴图本体 = 1024² 图集 `assets/Textures/bullet/bullet.png`（`laser` 除外，见下）。

| key | texture_key | 判定 | 备注 |
|---|---|---|---|
| 点弹 | 点弹 | circle 5 | 微型 |
| 点棱弹 | 点棱弹 | circle 4 | 微型 |
| 菌弹 | 菌弹 | circle 5 | 微型 |
| 小玉 | 小玉 | circle 8 | 小型（最常用） |
| 星弹 | 星弹 | circle 6 + offset x−1 | 小型，判定随朝向 |
| 枪弹 | 枪弹 | circle 6 | 小型 |
| 棱弹 | 棱弹 | circle 6 | 小型 |
| 滴弹 | 滴弹 | circle 5 + offset x+4 | 小型，判定随朝向 |
| 环玉 | 环玉 | circle 8 | 小型 |
| 符札 | 符札 | circle 6 | 小型 |
| 米弹 | 米弹 | circle 6 | 小型 |
| 苦无 | 苦无 | circle 5 | 小型 |
| 长菌弹 | 长菌弹 | circle 6 | 小型 |
| 鳞弹 | 鳞弹 | circle 6 | 小型 |
| 刀弹 | 刀弹 | circle 6 | 小型（有向） |
| 箭弹 | 箭弹 | circle 6 + offset x+20 | 中型，判定随朝向 |
| 蝶弹 | 蝶弹 | circle 8 + offset x−3.5 | 中型，判定随朝向 |
| 火弹 | 火弹 | circle 8 + offset x+11 | 中型，判定随朝向 |
| 小光玉 | 小光玉 | circle 16 | 中型 |
| 椭弹 | 椭弹 | circle 12 | 中型（有向） |
| 大星弹 | 大星弹 | circle 16 + offset x−3 | 中型，判定随朝向 |
| 心弹 | 心弹 | circle 20 | 大型 |
| 矩弹 | 矩弹 | circle 20 | 大型（有向） |
| 中玉 | 中玉 | circle 24 | 中型 |
| 光玉 | 光玉 | circle 28 | 大型 |
| 大玉 | 大玉 | circle 36 | 大型 |
| reimu_main | 灵梦自机主弹 | rect 48×24 | 自机弹 |
| reimu_opt1 | 灵梦子机高速弹 | circle 12 | 自机弹 |
| reimu_opt2 | 灵梦子机低速弹 | rect 120×24 | 自机弹 |
| marisa_main | 魔理沙自机主弹 | rect 48×24 | 自机弹 |
| marisa_opt1 | 魔理沙子机高速弹 | rect 32×32 | 激光条（512×32 合体格） |
| marisa_opt2 | 魔理沙子机低速弹 | rect 48×24 | 自机弹 |
| reimu_bomb01 | 灵梦bomb | circle 45 | 自机炸弹 |

> 圆弹可标 `follow_dir=false`（如 `点弹` / `小玉` / `菌弹` / `环玉`）；也可构造后直接赋值 `data.follow_dir = false` 覆盖（类型级，须在首次发射前）。
> **未知 key 会响亮告警**（`BulletCatalog.find` → `push_warning` + null），不再静默。**新增弹型** = 图集加一格（`data/atlas/bullet_shapes.tres`）+ 新建 `data/bullets/<key>.tres`。
> `laser` **不是弹型**：`AssetRegistry.LASER_TEXTURE`（`assets/Textures/bullet/laser.png`）供 `LaserBeam` 兜底，未进图集。

### 7.2 音效 key

`ctx.audio.play_sfx(AssetRegistry.sounds[key])` / `sfx()` / `hit_sfx` 可用：

`shoot` `player_shoot` `kira` `enemy_die` `boss_die` `player_die` `graze` `item` `card` `get_card` `get_player` `player_card` `select` `ok` `cancel` `pause` `lazer` `marisa_damage` `msl` `normal_damage`

> 权威表 = `scripts/asset_registry.gd` 的 `sounds`（BGM 的 `music_*` 同在那一张表，但不走 `play_sfx`）；
> 每个 key 都要在 `SFX_DB` 有音量项（`test_sfx_mix` 会红）。**加 key 时顺手改上面这一行。**
> `get_card` = **正常流程干净收取一张符卡**的回报音（`Boss.CAPTURE_SFX`；非符 / 练习模式 / miss·bomb 作废都不播）。
> `get_player` = 拿到**完整残机**的回报音（`Item.EXTEND_SFX`；碎片集满 5 片 / 吃到整命道具，且**只在真的多了一条命时播** —— 已满 8 命不播）。
>
> **音量与护栏（2026-10-10）**：BGM 换曲 = **新曲满音量直入、旧曲淡出 0.6s**（`BGM_FADE_IN = 0`，作者拍板不要淡入；
> 想要渐入就把它设回 0.6）；同一首**永远只有一路**（重开复用那一路，不会自己叠自己）。音量一律走总线 `Master → BGM / SE / UI`（布局 `res://default_bus_layout.tres`；
> 缺总线**响亮告警**，见 `AudioManager._require_bus`）。SE 总线挂 `AudioEffectHardLimiter`（防多声叠加削波），
> 另有 `AudioManager` 里三道护栏：**密度压制**（`density_cut_db()`：同时响的声部 > `DENSITY_KNEE` 时压**新起**的密集音，
> 上限 `DENSITY_MAX_CUT_DB`，重要音不吃）、**优先级驱逐**（池满时踢最不重要而非最老）、
> **BGM 让位**（`BGM_DUCK_ON_SFX` 里的音响起时 BGM 自动压 6 dB 再回落）。
> 新音效要归类就去 `AudioManager.SFX_PRIORITY_HIGH` / `SFX_PRIORITY_LOW`（不写 = 一般，安全）。
> 想量「这一关到底多吵」：`godot --headless --path . res://tools/audio_density_probe.tscn -- --seconds 30`
> （默认**按住射击** —— headless 没有人类输入，不按会量到假低的数字）。

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
  stage_script/*.gd                关卡编排（Timeline）
  enemy/*.gd                       敌人行为（CoroutineScript）
  phase/<阶段名>/*.tres             PhaseData（一个 .tres = 一个阶段）
  phase/<阶段名>/<阶段名>.gd         Boss 弹幕脚本 ← 本仓库现行命名
  phase/<阶段名>/<阶段名>移动.gd     Boss 移动脚本 ← 本仓库现行命名
  background/ stage_data/
```

> **角色靠引用反推，不靠路径**：`data/stages/**/phase/**` 在 `ContentCatalog._convention_role()` 里
> **没有规则**（既不是 `enemy/` 也不是 `background/`…）。阶段脚本的「弹幕发射 / Boss 移动」角色，
> 来自目录扫描的第二遍 —— `PhaseData.shoot_script` / `move_script` **引用反推**
> （`_apply_reference_fixes()`）。⇒ **新建的脚本在接进 .tres 之前一律显示成「未分类」**
> （实例：`似新存道中二符.gd` 至今没被任何 .tres 引用）—— 这是正确结果，不是 bug。
> `*_shoot.gd` / `*_move.gd` 后缀是约定表里认的**另一种**写法（`_convention_role()` 第一优先级），
> 本仓库内容没用它。

> **新建阶段脚本的三步**：① 写 `<阶段名>.gd`（两行架子也行：`extends CoroutineScript` + `## <阶段名>`）；
> ② `godot --headless --import` 生成 `<阶段名>.gd.uid`（写 .tres 引用要用到里面的 uid）；
> ③ 在对应 `.tres` 里加 `[ext_resource type="Script" uid="…" path="…" id="2_shoot"]`
> 并填 `shoot_script = ExtResource("2_shoot")`（字段位置照同目录既有 .tres）。

### 8.2 PhaseData（`scripts/data/phase_data.gd`）

| 字段 | 说明 |
|---|---|
| name | 符卡名（空 = 非符） |
| uid | 全局唯一符卡编号（0 = 非符不记） |
| bonus / time_limit / hp | 奖励 / 时限 / 血量 |
| is_timeout_only | 时符 |
| move_script / shoot_script | 挂的 Script（Boss 移动 / 弹幕）。**两个槽都必须填**（`test_data_validity` 强制）——「本卡 Boss 不走位」不等于留空：留空与**漏接**在数据里无法区分，请显式挂 `data/boss_scripts/move/stay_still.gd`（「原地不动」）。 |
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
| 描述符设计动机 / 边界 | 本文附录 A |
| 原生执行细节（op / 事件 / 同步点） | `docs/archive/GDEXTENSION_KERNEL_DESIGN.md` + `gdextension/src/danmaku_store.cpp` |
| 架构 / 命名契约 | `docs/ARCHITECTURE.md` + `docs/BEST_PRACTICES_BASELINE.md` |


---

> **附录 A（2026-10-17 并入）**：以下为原 `LIFECYCLE_MODEL.md` 全文；小节编号沿用原文，与正文 §1–§11 无关。

# 附录 A · 弹幕生命周期模型（LIFECYCLE MODEL）—— 已落地（L1–L4）

> **状态**：**已落地（2026-09-14，L1–L4）**。B 路线（N3）的形态 = **一套词汇，三种 runtime**
> （低频 GDScript / 高频 per-bullet 固定描述符 / 原生执行）。
> **相关**：`docs/archive/GDEXTENSION_KERNEL_DESIGN.md` §1/§5/§5.7；`docs/archive/N2_NATIVE_INTEGRATION_PLAN.md`。
> **由来（2026-09-13 决策）**：放弃「通用 opcode VM」，改为「频率分层 + 固定 schema 相位描述符」。理由见 §8。
>
> **本文怎么读**：**当前模型（权威）= §0–§6 + §11 的 unit 表**；**决策理由（只增不改）= §7 映射 · §8 与 VM 的关系**；
> **历史记录（已完成，不再更新）= §9 落地步骤 · §10 L1 实测 · §11 末尾的 L2/更新脚注**。逐条状态与待办见基线 S 表。

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
| **Action 动作** | 相位结束（或时刻到）时的**一次性**动作：emit / emit_variant / sfx / on_end_heading / despawn | ✅ |
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
Action    = { kind, action_id, f0..f3 }  # action_id → 宿主表（模板 / sfx / 内容回调）

每弹另有：phase_index(PackedInt32) + state 行块
```

- **状态槽静态分配**：每个 Move 声明所需行状态（`rotate`→`turned`、`aim`→`elapsed`、`anchor`→`drift`）；编译期算好总 stride，运行期零分配、零哈希。
- **per-shot 参数**（弹速 / 反弹角 / 难度值）在发射时绑定到描述符实例的数值槽；**结构**（phases）是共享只读的。
- **Callable / BulletData 不进原生**：emit 模板 / 内容回调注册成 `action_id`，原生只回传 id；变体发射另回传概率分支号。

> **关键原则（让描述符封闭）**：**Move 与 Condition 必须原生**（每帧每颗）；**Action / Emit 是一次性（低频）→ 可以回调 GDScript 内容**。
> 所以「复杂散圈 / 难度 / RNG / 多弹型」全部落在 Action，**天然不进热路径** —— 这是本模型能既封闭又精简的原因。

### Move 首批（9 个 op）

| Move | 参数 | 行状态 |
|---|---|---|
| `accel_world` | vec | — |
| `accel_heading` | a | — |
| `rotate` / `rotate_velocity` / `rotate_heading` | w, limit, mode | turned |
| `steer` | target, max_turn/s, ramp, dist_weight, steer_until | elapsed |
| `position`(ANCHOR) | anchor_id, offset, angle, speed, use_global, initial | drift |
| `position`(PHASE_START) | angle, speed, initial | 起点 + 位移 |
| `speed_lerp` | from, to, ramp | elapsed |
| `set_heading` | dir | — |
| `set_speed` | speed | — |
| `speed_mul` | f | — |

> **状态槽上限 8**（原生 `SLOT_STRIDE`）：`_pslots` 固定 stride 分行；`slots > 8` 的 program 会被 `register_program` 拒绝。

### Condition 首批

| Condition | 参数 | 用于 |
|---|---|---|
| `never` | — | accel / 直线 |
| `elapsed` | t | homing_duration / avoid flee_time |
| `near` | target, r | bounce / avoid / non_mid（`near_boss(r)` 已闭合，见 §5.2） |
| `at_wall` | mask | radial_accel / bounce（纯谓词；输出相位结束落点） |
| `state` | slot, cmp, value | curve（不公开；`until_turned()` 是糖） |
| `speed` | cmp, value | V21：`|v|` 比较（撞墙后减速到某速度等） |
| （通用节流） | every / every_ticks | 任何 condition 可链式 `.every()` / `.every_ticks()`（V6） |

### Action 首批
`emit` / `emit_variant` / `sfx` / `on_end_heading` / `despawn` / `on_end_call` / `clear_fx` / `despawn_clear`。

> `clear_fx`（op 47）是**纯 action** —— 只回传「此刻位置 + 弹色」给宿主播消散特效，不改任何列式状态；
> `despawn_clear()` 只是 `clear_fx().despawn()` 的组合糖。`despawn()` 保持**静默**（默认语义）。

---

## 4. 创作者面

**内容创作者写的是 `BulletData.trajectory(lc)`** —— 直接挂 `BulletLifecycle`（builder），**不碰 opcode**。权威用法见 `CONTENT_GUIDE.md`「弹幕行为」：
```gdscript
# 现成 preset
_bullet.trajectory(BulletLifecycle.homing())

# 预设不够：自己拼相位
var lc := BulletLifecycle.new()
lc.rotate(2.0, 0.5).until_turned().then().accel_heading(300.0).until_elapsed(1.0).despawn()
_bullet.trajectory(lc)
```

**引擎侧**（`LifecycleCatalog.build()` **就地展开**）用 fluent builder → 描述符（真实方法名）：
```gdscript
BulletLifecycle.new()\
    .accel_heading(100.0)                                   # Move\
    .until_at_wall(WALL_LEFT | WALL_RIGHT | WALL_TOP)       # Until\
    .sfx(&"kira", -8.0).emit(_replacement, toward(T_BOSS, 0.3), 0.0, true).despawn()   # Action
```
- **Move**：`accel_world` `accel_heading` `rotate` / `rotate_velocity` / `rotate_heading` `steer` `speed_lerp` `speed_mul` `set_heading` `set_speed` `position`
- **Until**：`until_never` `until_elapsed` `until_near` `until_at_wall` `until_speed` `until_turned`（+ 通用 `.every` / `.every_ticks`）；`then()` 开新相位
- **Action**：`sfx` `emit` `emit_variant` `despawn` `on_end_heading` `on_end_call`
- **方向糖**：`heading(angle)` `toward(target, angle)` `away(target, angle)` `forward(angle)` `random_dir(spread)` `chance_toward(target, p, spread)` `reflect(angle)`

**Canned preset**（9 个 `move` 的**类型化薄包装**，组合在 `build()`）：
```gdscript
BulletLifecycle.bounce(accel_rate, bounce_angle, spawn_speed, spawn, sfx_key := &"kira", sfx_db := -8.0)
BulletLifecycle.homing(angle_per_sec, accel_time, min_speed, max_speed, duration, proximity_boost)
BulletLifecycle.curve(w, limit)
BulletLifecycle.radial_accel(accel_rate, spawn, sfx_key := &"", sfx_db := 0.0)
BulletLifecycle.avoid_player(proximity, jump, flee_time)
BulletLifecycle.world_accel(v)   /   BulletLifecycle.accel(a)
BulletLifecycle.laser_follow(anchor_id, offset, angle, drift_speed, initial_drift)
BulletLifecycle.marisa_laser(anchor_id, offset, angle, drift_speed, initial_drift)
```

> **创作者两条路**：现成 preset（`move` 的糖）或自定义相位组合（builder），都不碰 opcode —— 没有原语泄漏（满足"创作者方便"硬约束）。
> 旧 `kernel_port` 端口（`*_bullet.gd`）已弃用，仅测试夹具保留（见 §7）。

---

## 5. 表达力试金石

> **本节是设计期试金石（2026-09-13）**：用当时的草稿名（`accel_along_vel` / `wall_hit` / `near_player` / `set_vel`…）证明描述符能覆盖 10 个行为。**当前实现名以 §3 / §11 为准。**

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
| `kernel_bridge/behavior/*.gd`（10 个） | → **描述符 preset**（L2）→ 删 GDScript 实现（L4）✅ |
| `*_bullet.gd`（`kernel_port`：命名 `move` / 自定义 `{lifecycle}`） | **载体已删**：`data/**` 全部直接 `trajectory(lc)`；桥接端口仅测试夹具保留（待清 b2c） |
| `BulletData.lifecycle` / `.trajectory(lc, anchor)`（**b0/b1/b2a**：直接挂描述符，不经 port） | ✅ 全部迁移（gravity / homing / marisa_laser / world_accel / bounce / radial_accel）；`content_signature` 结构去重 |
| 内容回调 + 变体发射（**b2b / 变体**） | ✅ **hook 名注册表**（`LIFECYCLE_HOOKS_SCRIPT.register`）+ `emit_variant`（内核回传概率分支号，宿主按分支选模板） |
| 内核随机 / 朝向（**K1/K2**） | ✅ 原生 PRNG（`set_seed` 由宿主种子派生）+ per-bullet 朝向（`accel_heading` 与速度解耦） |
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
| | `rotate(w, limit=0)` / `rotate_velocity` / `rotate_heading` | 同时 / 只速度 / 只朝向转（V12）；limit>0 钳到累计转角（自带槽） |
| | `steer(target, max_turn, ramp=0, dist_weight=0, steer_until=0)` | 朝目标转向（只转向，速度另配 `speed_lerp`）；限时转向 |
| | `speed_lerp(from, to, ramp)` | 速度按相位 elapsed 插值 |
| | `speed_mul(f)` / `set_speed(s)` / `set_heading(dir)` | 速度三算子：每帧乘（复利）/ 瞬时设 / 设向 |
| | `position(mode, anchor_id, offset, angle, speed, use_global, initial)` | **位置来源模式**：ANCHOR（外部节点）/ PHASE_START（本弹相位起点）；只写 `pos` |
| Condition | `never` / `elapsed(t)` | — |
| | `near(target, r)` | 距离；节流走通用 `.every/.every_ticks` |
| | `at_wall(mask)` | 纯谓词；输出相位结束落点（供 `emit(at=AT_PHASE_END)`） |
| | `state(slot, cmp, v)` | 读槽（不公开；`until_turned()` 是糖） |
| | `speed(cmp, v)` | V21：`|v|` 比较（撞墙减速到某速） |
| Action | `emit(spawn, dir, speed, at)` | spawn = BulletData / Callable / 数组；at = AT_CURRENT / AT_PHASE_END |
| | `emit_variant([t0, t1], dir, speed, at)` | 概率分支（`chance_toward`）选模板：0=未命中 t0，1=命中 t1；内核只回传分支号 |
| | `sfx(key, db)` / `despawn` / `on_end_heading(dir)` / `on_end_call(fn)` | 内容回调（散圈）用 call |
| 方向表达式 | `toward(t, angle)` / `away(t, angle)` / `heading(angle)` | t = player / nearest_enemy / boss |

**边界**：unit 停在**语义**层（上表 ~15 个）；不下沉到微 op（否则变回 §5 大 VM）。
**位置来源是模式（V18）**：`position` 只写 `pos`（ANCHOR / PHASE_START 二选一），不与速度 op 叠加；多个 position op 是「后写者胜」的模式切换；模式只改 `pos`，`v`/`h` 保持（释放后按速度轴飞）。要分段用 `then()`。

**踩坑**：`then()` 生成的新相位 `until=never`；在其上挂 `on_end` 动作**永不触发**。

**L2 实测（2026-09-13）**：10 个行为全部逐位 parity（`test_lifecycle_model` + `test_lifecycle_presets`）。为 parity 追加的语义化 unit 细节：`steer` 的 `speed_from/speed_to`（融合速度）与 `steer_until`（限时转向）、`near` 的 `every_ticks`（帧门控）、`on_end_call`（内容回调）、`T_NEAREST_ENEMY` 跳过时符 Boss。
**更新（V2，2026-09-16）**：`speed_from/speed_to` 已从 `steer` 拆出，`homing` 改为 `steer + speed_lerp` 组合；`steer` 现在是纯角转向。


---

> **附录 B（2026-10-17 并入）**：以下为原 `BULLET_PIPELINE.md` 全文；小节编号沿用原文。

# 附录 B · 一颗弹幕的完整路径（内容 → 原生内核 → 渲染）

> 口径：**宿主（GDScript）负责内容 / 规则 / 渲染；内核（原生 `DanmakuStore`）负责存储 / 积分 / 行为 / 判定几何。**
> 行号会漂，**以函数名为准**。配套：`docs/archive/GDEXTENSION_KERNEL_DESIGN.md`、`docs/ARCHITECTURE.md`、`docs/DANMAKU_API.md`。

## 0. 总览

```
内容 .gd
 └ ctx.bullets.shoot_spread(data, count, spread, dir, at)   bullet_service.gd:12
    └ BulletManager.shoot_bullet                             bullet_manager.gd:100
       └ KernelBulletHost.shoot                              kernel_bullet_host.gd:162
          ├ prepare_shot → 快照(type/pos/vel/tint/move/params/texture)   :113
          └ spawn_prepared                                       :153
             ├ KernelNativeSystem.spawn(type, …)                 kernel_native_system.gd:141
             │   ├ 类型表去重 → ti                                  :142
             │   ├ 写 GDScript 只读快照行 + 出生雾                    :146-157
             │   └ 原生 store.spawn + set_hitbox/life/program/fx     :158-171
             └ _sync_host_tables(id, texture)                    kernel_bullet_host.gd:230

每物理帧（process_physics_priority）
 -10  KernelNativeSystem._physics_process   integrate → behavior_tick → pull 快照   kernel_native_system.gd:410
  -4  KernelBulletHost._physics_process      flush 延后行为（re_fire / 分裂）          kernel_bullet_host.gd:98
   0  BulletManager._physics_process         DeathClear / LaserEngine / 宿主碰撞       bullet_manager.gd:87
         └ KernelBulletPhysics.process       overlap_pairs + hit_test → 伤害/miss/擦弹  kernel_bullet_physics.gd:49

每渲染帧
 BulletMultiMesh._process → _sync → _sync_kernel → _sync_native   bullet_multi_mesh.gd:31 / 45 / 68
   └ DanmakuRenderBridge.group(...)                                danmaku_render_bridge.cpp:44
       → 分桶（tex_key_base<含图集 region> × 阵营 × tint_mode）+ 每弹 rot/alpha
   └ 每组 _get_or_create_group + fill                               bullet_multi_mesh.gd:258 / 111
```

## 1. 定义（发射之前）

| 步骤 | 位置 | 干什么 |
|---|---|---|
| 弹型定义 | `data/bullets/<key>.tres`（`BulletDef`） | **外观 + 碰撞 + 朝向**：`texture_key`（图集格）+ `hitbox_*` + `follow_dir`/`dir_offset` |
| 载入 | `BulletData.tex(key)` / `.def(d)`（`bullet_data.gd`） | 经 `BulletCatalog` 取 `BulletDef`，把外观/碰撞/朝向灌进 builder |
| 构造链 | `BulletData.speed/color/blend/enemy/player/trajectory/…` | per-shot（`velocity`/`tint`/`lifecycle`）与其余类型级（阵营/伤害/特效/出生雾） |
| 快照成内核类型 | `BulletData.to_bullet_type()` | 首次发射时把类型级字段快照成 `BulletType` 并**缓存在 BulletData 实例**上（复用实例 = 共用弹型） |

> 图集格坐标：`data/atlas/bullet_shapes.tres`（`AtlasLayout`）→ `BulletShapes.pixel_rect/atlas_texture`。

## 2. 发射（同一次调用内，同步）

1. **`BulletService.shoot_spread`**（`bullet_service.gd:12`）：`count==1` 直发；否则按 `spread_angle` 旋转 `base_dir` 逐发。
2. **`BulletManager.shoot_bullet`**（`bullet_manager.gd:100`）→ **`KernelBulletHost.shoot`**（`kernel_bullet_host.gd:162`）。
3. **`prepare_shot(data,pos,dir)`**（`:113`）—— **入队瞬间快照**（内容复用同一 `BulletData` 改速度再发时不会被后续写覆盖）：
   `type = data.to_bullet_type()`、`vel = direction.normalized() * data.velocity.length()`、`tint`（自机记忆 <50 时往红 lerp）、
   `move`（有 `lifecycle` → `MOVE_LIFECYCLE` + `{lifecycle, anchor}`；否则旧端口）、`texture = data.texture`。
4. **`KernelNativeSystem.spawn(type, pos, vel, tint, move, params)`**（`kernel_native_system.gd:141`）：
   - `_type_registry_index_of(type)`：按**同一 `BulletType` 实例**去重 → `ti`（所以内容必须复用 `BulletData`）；
   - 写 GDScript **只读快照行**（pos/vel/color/type/faction/life/fx/timer/render_rot）；
   - 出生雾：`is_spawn_fog ? (spawn_fx ?? 阵营默认) : 无`（`:155-157`）；
   - **原生权威行**：`_accel.spawn(...)`（`DanmakuStore`）+ `set_hitbox`（判定几何）/`set_life`/`set_program`（lifecycle program）/`set_fx`。
5. **回宿主**：`spawn_prepared` → **`_sync_host_tables(id, texture)`**（`:230`）把 `_texture_by_index[ti] = texture`（**渲染插座**，M3 ③）。

## 3. 每物理帧（按 `process_physics_priority` 定序）

- **-10 · 内核积分**（`kernel_native_system.gd:410`）：`_accel.integrate(delta)` 走原生 move（含 lifecycle 描述符）；`_run_native_behaviors` 调 `_accel.behavior_tick(...)` 执行 until/action 并 `_drain_events`（emit / sfx / call）。最后 `_pull_snapshot()` 把原生 SoA 拉成只读快照。
- **-4 · 行为宿主**（`kernel_bullet_host.gd:98`）：只在**非**原生行为模式下存在，`flush` 延后的 `re_fire` / 分裂（内核契约：行为循环中途禁止增删行）。
- **0 · 宿主碰撞 + 子系统**（`bullet_manager.gd:87`）：`DeathClear` / `LaserEngine` / `KernelBulletPhysics.process()`（`kernel_bullet_physics.gd:49`）。
  - `_enemy_bullets_vs_player`：`overlap_pairs`（宽相 + `hit_test`）→ 命中 `player.miss()`，否则擦弹（每弹一次）+ 记忆随机清弹；
  - `_player_bullets_vs_enemies`：命中读 `BulletType.damage` 结算、`add_memory`、`hit_sfx`、`hit_fx`、`despawn`。
  - 两处都**倒序**遍历：`despawn` 是 swap-with-last。

## 4. 渲染（每 `_process`）

`BulletMultiMesh._process → _sync → _sync_kernel → _sync_native`（`bullet_multi_mesh.gd:31/45/68`）：
1. `DanmakuRenderBridge.group(...)`（`danmaku_render_bridge.cpp:44`）在原生侧分组：
   - 键 = `tex_key_base`（宿主按纹理 RID + `AtlasTexture.region` hash 算，`bullet_multi_mesh.gd:156-159`）× 阵营 × `tint_mode`（`== tint_mode` 是 shader 模式位）；
   - 每弹 `rot`：`follow_dir ? (render_rot ?? atan2(vel)) + dir_offset : 0`（V19 render 朝向通道优先）；`alpha` 按 kind 淡出。
2. 回 GDScript 按组：`_get_or_create_group(key, texture_for_index(ti), …)`（`:258`，`AtlasTexture` 解包成「图集 + UV region」）→ `bridge.fill(mm, …)`（`:111`）写 MultiMesh 实例。

## 5. 回收

- **原生 cull**：`cull_rect`（场地 `(64,32,768,896)`）+ `cull_margin=90`（`bullet_manager.gd:219-222`）。
  逐弹 **`out_grace`（秒）> 0** 时改为「累计连续出界时长、超时才回收」，**回到界内即归零** ——
  这是「出界再回来」的弹（往返探针）能活下来的唯一机制。寿命 / 特效到期也由原生回收。
- **宿主 despawn**：命中 / 擦弹清弹 / 死亡清弹圈；swap-with-last（见上）。

## 6. 谁负责什么（边界）

| 层 | 负责 |
|---|---|
| 内容 `.gd`（`data/**`） | `BulletDef` + 构造链、`trajectory`、难度/时序 |
| 宿主 GDScript（`scripts/**`） | `BulletData → BulletType`、纹理插座、伤害 / miss / 擦弹 / 记忆、bomb 节点、渲染、清理 |
| 原生内核（`gdextension/src/**`） | SoA 存储、积分、lifecycle 行为、判定几何、cull、内核 RNG |

> 一句话：**内容给「这份配置 + 规律」，宿主把配置翻成内核弹型并把规则结算掉，内核只认列式数据和 program。**
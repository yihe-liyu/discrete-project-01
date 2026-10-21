# 弹幕内核接口（DANMAKU API）

> **一句话**：给一颗弹写飞行规律 = `BulletData.trajectory(BulletLifecycle)`；发射 = `ctx.bullets.shoot_spread(...)`。
> 本文是弹幕创作的**唯一权威参考**；教学路径见 `CONTENT_GUIDE.md` §六；原生执行器在 `gdextension/src/danmaku_store.cpp`。
> 读法：新建弹幕看 §1 + §3.8；查词汇看 §2/§3；发射看 §4；踩坑看 §9；设计动机看附录 A/B（全文在 archive）。

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

1. **内容不碰 opcode**：只写 `BulletData` / `BulletLifecycle` / `ctx.*`。
2. **BulletData 实例必须复用**（弹型缓存在实例上）→ §2.3。
3. **GDScript 不进每帧每弹路径**：per-bullet 逻辑一律描述符；一次性/低频才用 `on_end_call`。

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
- 返回值语义见 §5.1；`shoot_spread` 的 `base_dir` 定方向、`data.velocity.length()` 定速度（§4.1）。

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
| out_grace | float | 0.0 | **逐弹出界宽限（秒）**：出界后仍活这么久；0 = 出界立即回收 |
| lifecycle | BulletLifecycle | null | 弹道描述符（**推荐主路**） |
| lifecycle_anchor | Variant | null | per-shot 锚点 `{id, offset, use_global}`（激光用） |
| coroutine_script / params | — | — | **已弃用**：旧端口载体 |

> `faction` 用 `enemy()` / `player()` / `bomb()` 设；`damage` / `hit_sfx` 直接赋值。

### 2.2 构造链方法

| 方法 | 作用 |
|---|---|
| `.def(d)` | 直接传 `BulletDef` 载入**外观 + 碰撞 + 朝向** |
| `.tex(key)` | 按 key 查 `data/bullets/<key>.tres`（**当前内容主路**；key 来自 §7.1，拼错会告警但仍用默认判定） |
| `.speed(v)` | 速度大小（`velocity.y = v`，长度 = v） |
| `.dir(x, y)` | 直接设 velocity（方向+速度，仅 `shoot_spread` 传 `ZERO` 方向时用） |
| `.color(c)` / `.blend(true)` | 染色 / BLEND 换色（默认 MULTIPLY） |
| `.enemy()` / `.player()` / `.bomb()` | 阵营：敌弹 / 自机弹 / 炸弹 |
| `.with_spawn_fog(effect)` / `.no_spawn_fog()` | 打开/换出生雾 / 关掉出生雾 |
| `.trajectory(lc, anchor)` | **挂描述符**（主路） |
| `.grace(v)` | out_grace |
| `.behavior(script)` | **已弃用** |

> **未知 tex key 会 `push_warning` + 保持默认**（不静默回退，但弹仍会发出去）——只从 §7.1 表取 key。

### 2.3 弹型缓存（实例复用铁律）

- `to_bullet_type()` 在**首次发射**时把类型级字段（贴图/阵营/判定/伤害/命中特效/命中音效）快照到内核弹型，缓存挂在 **BulletData 实例**上。
- **同一实例反复发射 = 共用同一弹型**；每发 `BulletData.new()` 会让内核弹型表膨胀。
- 速度 / tint **不属弹型**，每发可改；运行期改类型级字段 → 必须 `invalidate_bullet_type()`。

## 3. BulletLifecycle（弹道描述符）

`scripts/kernel_bridge/lifecycle/bullet_lifecycle.gd` ｜ `extends RefCounted, class_name BulletLifecycle`

### 3.1 相位（Phase）模型

```
BulletLifecycle = [ Phase, Phase, ... ]     # 有序，不可跳转
Phase = { moves: [Move...], until: Until, on_end: [Action...] }
```

- 每帧按顺序跑 moves，直到 `until` 成立 → 执行 `on_end` → 进下一相位；`then()` 开新相位（线性）。
- 相位切换**清零所有状态槽**；最后一个相位结束后，弹按当前速度自由积分（出界 cull）。
- **陷阱**：`then()` 生成的新相位 `until = never`；在它上面挂 `on_end` 永不触发。

### 3.2 Move（每帧施加，9 个 op；`anchor_drift` / `drift` 是 `position` 的糖）

| Move | 签名 | 语义 |
|---|---|---|
| accel_world | `accel_world(v: Vector2)` | `velocity += v * dt`（世界坐标恒定加速度） |
| accel_heading | `accel_heading(a: float)` | 沿**自身朝向**加速：`velocity += heading * a * dt`（v=0 也有效 → 可减速/反向） |
| rotate | `rotate(w, limit=0)` | **同时**转速度与朝向；limit>0 时累计转角钳到 limit（`until_turned()` 用） |
| rotate_velocity / rotate_heading | `rotate_velocity(w, limit=0)` / `rotate_heading(...)` | 只转速度 / 只转朝向 |
| steer | `steer(target, max_turn, ramp=0, dist_weight=0, steer_until=0)` | 朝目标**只转向、不改速度**；变速另配 `speed_lerp` |
| speed_lerp | `speed_lerp(from, to, ramp)` | 方向不变，速度按 elapsed/ramp 插值 |
| speed_mul | `speed_mul(f)` | 每帧 `velocity *= f`（**复利/指数**，不是瞬时设定） |
| set_heading | `set_heading(dir)` | 设速度方向（保速度大小）**并同步朝向** |
| set_speed | `set_speed(speed)` | 设速度大小；方向不变，**v=0 时用「朝向」定方向** |
| anchor_drift | `anchor_drift(anchor_id, offset, angle, speed, use_global=true, initial=0, render_heading=false)` | `position`(ANCHOR) 的糖：`pos = anchor_base + dir(angle)·drift`；需 `trajectory(lc, anchor)` |
| drift | `drift(angle, speed, initial=0)` | `position`(PHASE_START) 的糖：从**本弹相位起点**平移，不改速度/朝向 |

> 位置来源（V18「模式派」）：位置由**一个** `position` op 的**来源模式**决定 —— `ANCHOR`（外部节点，激光）/ `PHASE_START`（本弹相位起点）/ 缺省 `FREE`（自由积分）。
> 模式只写 `pos`：`v` / `h` 不受影响；`render_heading=true` 走独立渲染朝向通道。
> 离开模式（相位结束、下一相位无 position op）：`pos` 留在最后结果，积分从该点接力 → 弹按速度轴自由飞。
> 同相位多个 position op = **模式切换（last-wins）**，不是叠加；位置模式与速度 op 混用会让速度变化在位置上看不见。

### 3.3 Until（相位结束条件）

| Until | 签名 | 语义 |
|---|---|---|
| never | `until_never()` | 永不结束（靠 emit/despawn 手动结束） |
| elapsed | `until_elapsed(t)` | 相位经过 t 秒 |
| near | `until_near(target, r)` | 距 target < r |
| at_wall | `until_at_wall(mask)` | 越界检测（左 1 / 右 2 / 上 4）；**纯谓词**：只输出相位结束落点（不改弹位置），供 `emit(..., at=AT_PHASE_END)` |
| speed | `until_speed(cmp, value)` | `|v|` 与 value 比较（`CMP_GE` / `CMP_LE`） |
| turned（糖） | `until_turned()` | 当前相位 `rotate` 累计转角 ≥ limit；**必须跟在同相位 rotate 之后** |

> 通用节流：任何 Until 都可链式 `.every(sec)` / `.every_ticks(n)`。
> 状态槽对创作者不可见；读取状态只经 `until_turned()`。

### 3.4 Action（相位结束时一次性）

| Action | 签名 | 语义 |
|---|---|---|
| sfx | `sfx(key, db=AudioManager.SFX_LEVEL_DB)` | 播音效（key 见 §7.2；默认是总电平，不是 0 dB） |
| emit | `emit(spawn, dir, speed=0, at=AT_CURRENT)` | 生成替换弹；`spawn` = BulletData / Callable / 数组；`at` = AT_CURRENT / AT_PHASE_END |
| emit_variant | `emit_variant(spawns, dir, speed=0, at=AT_CURRENT)` | 内核抽一次 RNG 定分支（0=未中→spawns[0]，1=命中→spawns[1]）；`dir` 必须是 `chance_toward(...)` |
| despawn | `despawn()` | 回收自己（静默，不播特效） |
| clear_fx | `clear_fx()` | 在弹**此刻位置**播一次消弹特效（颜色提亮 1.5×），不改状态，弹继续飞 |
| despawn_clear | `despawn_clear()` | `clear_fx().despawn()` —— 消散 + 回收 |
| on_end_heading | `on_end_heading(dir)` | 转向（保速度大小） |
| on_end_call | `on_end_call(hook)` | **逃逸口**：每相位结束最多一次、宿主侧、非热路径；`host` 只暴露 `queue_spawn` |

> **`despawn` vs `despawn_clear`**：默认 `despawn()`；只有**确实想让人看见消散**时才用 `despawn_clear()`。
> 撞墙/屏外回收别用（屏外闪光 + 特效风暴）；消散特效与死亡清弹圈共用同一实现。
> **`on_end` 按 append 顺序执行**；`on_end_heading` 即时改写朝向，`despawn` 后同一相位后续 action 不再有意义。
> `emit` 细则：`speed<=0` 继承当前速度；`at=AT_PHASE_END` 用 until 落点；模板永不进原生。
> `emit_speed_rel(spawn, dir, speed=0, spread=0.15, at=AT_CURRENT)`：每次 emit 在 base speed 上做 ±spread 逐发求值（宿主表执行，纯 program 只存 base speed）。

### 3.5 方向表达式（静态构造；供 steer / emit / set_heading / on_end_heading 用）

| 表达式 | 签名 | 语义 |
|---|---|---|
| heading | `heading(angle)` | 世界角（构造期常量）；`set_heading` 可用；**emit / on_end_heading 必须用 world_heading** |
| toward | `toward(target, angle=0)` | 朝 target 再转 angle；**target 不可用时退化为向下** |
| away | `away(target, angle=0)` | 背对 target 再转 angle |
| world_heading | `world_heading(angle)` | 显式世界角；emit / on_end_heading 专用（不随发射者变） |
| forward | `forward(angle=0)` | 沿**自身朝向**再转 angle |
| random_dir | `random_dir(spread)` | 沿自身朝向 ±spread 随机（确定性 RNG，每次求值抽 1 次） |
| chance_toward | `chance_toward(target, p, spread=0)` | p 概率精确朝 target；否则沿自身朝向转 spread；**仅作 `emit_variant` 的 dir** |
| reflect | `reflect(angle=0)` | 把**当前速度**按发射点所在场边翻分量，再转 angle；需配 `at=AT_PHASE_END` |

> 镜面反射示例：`lc.until_at_wall(WALL_LEFT|WALL_RIGHT|WALL_TOP)` → `lc.emit(反射弹, reflect(), 150, AT_PHASE_END)` → `lc.despawn()`。
> 撞哪面墙不用声明（内核按落点判）；「镜面 + 微散」用 `reflect(deg_to_rad(8.0))`。原生用例：`test/test_native_reflect.gd`。

### 3.6 常量

```gdscript
BulletLifecycle.T_PLAYER / T_NEAREST_ENEMY / T_BOSS   # 0 / 1 / 2
BulletLifecycle.WALL_LEFT / WALL_RIGHT / WALL_TOP     # 1 / 2 / 4（无下墙）
BulletLifecycle.AT_CURRENT / AT_PHASE_END             # 0 / 1
BulletLifecycle.ROT_BOTH / ROT_VELOCITY / ROT_HEADING # 0 / 1 / 2
BulletLifecycle.CMP_GE / CMP_LE                       # 0 / 1
```

> `T_NEAREST_ENEMY` 只在宿主候选集里取最近；targetability（未开战 Boss 排除）在 `EntityRegistry.get_targetable_enemies` / `Enemy.is_targetable`。

### 3.7 状态槽（slots）

- 有状态 unit 自动分配：`rotate`→turned、`position`(ANCHOR)→drift（1 槽）、`position`(PHASE_START)→起点+位移（3 槽）；`steer` 读相位 elapsed（不占槽）。
- 相位切换清零；创作者看不到槽。
- **同相位上限 8**：超出会被内核拒绝注册，该弹退化为直线。

### 3.8 弹道组合（preset 已删除，直接拼原语）

F10c 删掉了 9 个 typed preset；`BulletLifecycle` 只保留原语。工作台「弹幕台 → 拼装」生成同样的代码，可复制回内容。

```gdscript
var lc := BulletLifecycle.new()
lc.steer(BulletLifecycle.T_NEAREST_ENEMY, deg_to_rad(720.0), 2.0, 150.0, 2.0)
lc.speed_lerp(500.0, 2000.0, 2.0)
lc.until_never()
data.trajectory(lc)
```

| 想要 | 原语组合 |
|---|---|
| 世界加速 | `accel_world(v)` + `until_never()` |
| 沿朝向加速 | `accel_heading(a)` + `until_never()` |
| 弧线 | `rotate(w, limit)` + `until_turned()` + `then()` |
| 追踪 | `steer(T_NEAREST_ENEMY, angle, accel, prox, duration)` + `speed_lerp(min, max, accel)` + `until_never()` |
| 碰框换弹 | `accel_heading(accel)` + `until_at_wall(L\|R\|T)` + `sfx` + `emit(spawn, toward(T_BOSS, angle), speed, AT_PHASE_END)` + `despawn()` |
| 碰顶分裂 | `accel_heading(rate)` + `until_at_wall(TOP)` + `sfx` + `emit(spawn, heading(PI), 0, AT_PHASE_END)` + `despawn()` |
| 躲避自机 | `until_near(T_PLAYER, prox).every(jump)` + `on_end_heading(away(T_PLAYER))` + `then()` + `until_elapsed(flee)` + `despawn()` |
| 锚定激光 | `anchor_drift(anchor, offset, angle, speed, use_global, initial, render_heading)` + `until_never()` |

> 不再新增 preset：组合由内容直接写，或由工作台拼装器生成。拼装页的 `emit` / `emit_variant`
> 有 A/B 替换弹模板；生成的代码里 `_spawn` / `_spawn_a` / `_spawn_b` 是占位，填自己的 `BulletData`。
> `LifecycleCatalog` 只保留 `{lifecycle: BulletLifecycle}` 的兼容入口；旧 `{move: ...}` preset 名一律返回 null。

### 3.9 编译与共享

- `compile()` → `{ops, args, move_start, move_count, until_idx, act_start, act_count, phase_count, slots, actions, sfx}`。
- `content_signature()` = 结构哈希 + 宿主表身份（内容相同 → 共用同一原生 program）；同结构才共享。
  缓存键额外混入 phase_count / slots，命中后还会抽验 program 形状；hash 碰撞不会静默复用错误弹道。
- 内部编译拆成 **纯 program** 与 **宿主表**：`compile_program()` 只产出 ops/args/phase 索引，`host_table()` 只产出 spawn / Callable / sfx；`compile()` 仍合并两者供旧调用点使用。

### 3.10 锚点（激光）

```gdscript
b.trajectory(lc, {&"id": node.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true})
```

- `id=0` → 自机 + offset；`use_global=true` → 锚点 global_position + offset；`use_global=false` → 锚点局部 position（focus 子机）。

## 4. 发射 API（`ctx.bullets`）

`scripts/coroutine/services/bullet_service.gd`

### 4.1 shoot_spread（唯一弹幕发射入口）

```gdscript
ctx.bullets.shoot_spread(bullet_data: BulletData, count: int, spread_angle: float,
	base_dir: Vector2, at: Vector2, sfx: AudioStream = null) -> void
```

- `count == 1`：一发，方向 = base_dir，忽略 spread_angle。
- `count > 1`：`spread_angle >= TAU` → 铺满一圈，step = spread/count；否则以 base_dir 为中心左右展开，step = spread/(count-1)。
- 每发速度 = `bullet_data.velocity.length()`；方向来自这里，不是 data.velocity 的方向。
- 想逐发不同速度/颜色：复用实例、每发改 `velocity` / `tint` 后再发射（入队瞬间快照，安全）。

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

## 5. 内容脚本契约（CoroutineScript）

`scripts/coroutine/base/coroutine_script.gd`

### 5.1 _tick 返回值

| 返回 | 含义 |
|---|---|
| `ctx.clock.wait(sec)` | 等 sec 秒后再调 |
| `true` | 下一物理帧立即再调 |
| `false` / `null` | 协程结束 |

### 5.2 启动 / 属性

```gdscript
s.auto_stop = true/false     # true: _tick 返回 false 即止；false: 持续运行
s.target: Node2D             # 宿主注入（敌人 / Boss 自己）
s.ctx: StageContext
s.start(ctx)                 # 由宿主调用
s.get_dt() -> float          # 当前物理帧步长（别用 get_physics_process_delta_time()）
s.start_timeline() -> Timeline
```

### 5.3 难度

```gdscript
diff_pick(arr)               # Difficulty.pick(arr, SaveData.selected_difficulty)
diff_get(dict, key, default)  # 缺行 / 非法行走默认值
# 4 项数组只覆盖 Easy~Lunatic；Extra 需要第 5 项，否则报错并回落最后一项。
ctx.diff.picked() / pick(arr) / at_least(n)
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

## 6. ctx 服务总表

| 服务 | 关键方法 |
|---|---|
| `ctx.clock` | `wait(sec)` / `wait_frames(n)` |
| `ctx.bullets` | `shoot_spread` / `fire_*_laser` / `death_clear` / `shoot_bomb` / `clear_enemy_bullets` |
| `ctx.player` | `get_player()` / `get_position()` |
| `ctx.boss` | `current()` / `exists()` |
| `ctx.enemies` | `spawn(data)` / `despawn(enemy)` / `despawn_all()` / `despawn_clear(enemy)` |
| `ctx.diff` | `picked()` / `pick(arr)` / `pick_from(dict, key, def)` / `at_least(n)` |
| `ctx.audio` | `play_bgm(stream, gap=0)` / `stop_bgm()` / `play_sfx(stream, db=AudioManager.SFX_LEVEL_DB)` |
| `ctx.effects` | `add_miss_circle(...)` / `play_hit_effect(scene, pos)` |
| `ctx.items` | `spawn(type, position)` |
| `ctx.dialogue` | `play_steps(steps)`（经 `ctx.play_dialogue_steps` 更常用） |
| `ctx.objects` | `register(key, obj, type)` / `resolve_as(key, type)` / `clear()` |
| `ctx.stage` / `ctx.entity_registry` | 机制层：`bullet_manager` / `entity_registry` / `item_pool` / `fx_pool` / `miss_layer`（内容一般不用直接摸） |

> `ctx.*` 是**意图门面**：内容只说意图，机制在服务/host；无 `stage` 绑定时多数方法静默 no-op（测试友好）。

**场景导演**：`StageDirector`：`bgm(key)` / `boss(key, data, from, to, hide)` / `dialogue(steps)` / `on(event, handler)` / `dispose()`。
`BossHandle`：`enter(to, from, dur=1.5)` / `phase(index=0, idle_only=false)` / `reveal(name)` / `set_name(name)` / `show_name()/hide_name()` / `show_phase_dots()/hide_phase_dots()` / `retreat(to, dur=2.0)` / `resolve()/exists()`。
> 名字节点/进度点默认隐藏；关底想显示就 `reveal(name)` + `show_phase_dots()`。

## 7. 素材与常量表

### 7.1 子弹贴图 key（`BulletData.tex(key)` 唯一来源）

**数据源 = `data/bullets/<key>.tres`**（`BulletDef`：外观 + 碰撞 + 朝向；`BulletCatalog` 扫目录建索引）。
贴图本体 = 1024² 图集 `assets/Textures/bullet/bullet.png`（`laser` 除外）；运行时类型是 `BulletType`（不是内容资源）。

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

> 圆弹可标 `follow_dir=false`（点弹/小玉/菌弹/环玉）；也可构造后 `data.follow_dir = false` 覆盖（须在首次发射前）。
> **新增弹型** = 图集加一格（`data/atlas/bullet_shapes.tres`）+ 新建 `data/bullets/<key>.tres`。
> `laser` **不是弹型**：`AssetRegistry.LASER_TEXTURE`（`assets/Textures/bullet/laser.png`）供 `LaserBeam` 兜底。

### 7.2 音效 key

`ctx.audio.play_sfx(AssetRegistry.sounds[key])` / `sfx()` / `hit_sfx` 可用：

`shoot` `player_shoot` `kira` `enemy_die` `boss_die` `player_die` `graze` `item` `card` `get_card` `get_player` `player_card` `select` `ok` `cancel` `pause` `lazer` `marisa_damage` `msl` `normal_damage`

> 权威表 = `scripts/asset_registry.gd` 的 `sounds`；每个 key 都要在 `SFX_DB` 有音量项（`test_sfx_mix` 会红）。**加 key 时顺手改上面这一行。**
> `get_card` = 干净收取符卡的回报音；`get_player` = 拿到完整残机的回报音。
> 音量走总线 `Master → BGM / SE / UI`（`default_bus_layout.tres`）；SE 有限幅 + 密度压制 + 优先级驱逐；BGM 换曲新曲直入/旧曲淡出 0.6s、同曲只一路。

### 7.3 阵营 / 混合

```gdscript
BulletData.Faction.PLAYER / ENEMY / BOMB
BulletData.TintMode.MULTIPLY   # rgb = 贴图 × tint（tint=白 = 原色）
BulletData.TintMode.BLEND      # rgb = mix(tint, 白, 贴图亮度)（敌弹换色）
```

## 8. 文件与接线

### 8.1 阶段目录布局

```
data/stages/<stage>/
  stage_script/*.gd                关卡编排（Timeline）
  enemy/*.gd                       敌人行为（CoroutineScript）
  phase/<阶段名>/*.tres             PhaseData（一个 .tres = 一个阶段）
  phase/<阶段名>/<阶段名>.gd         Boss 弹幕脚本
  phase/<阶段名>/<阶段名>移动.gd     Boss 移动脚本
  background/ stage_data/
```

> 阶段脚本的角色靠 `PhaseData.shoot_script` / `move_script` **引用反推**；新建脚本接进 .tres 前显示「未分类」是正确结果。
> 新建阶段脚本三步：① 写 `<阶段名>.gd`；② `godot --headless --import` 生成 `.uid`；③ 在 `.tres` 加 `ext_resource` 并填 `shoot_script`。

### 8.2 PhaseData（`scripts/data/phase_data.gd`）

| 字段 | 说明 |
|---|---|
| name | 符卡名（空 = 非符） |
| uid | 全局唯一符卡编号（0 = 非符不记） |
| time_limit / hp | 时限 / 血量 |
| is_timeout_only | 时符 |
| move_script / shoot_script | **两个槽都必须填**（`test_data_validity` 强制）；「不走位」显式挂 `stay_still.gd`，别留空 |
| pre_move_script | 宣言前走位（会推迟宣言，必须能结束） |
| params | 注入脚本同名属性（`PhaseData.validate` 按三脚本并集查未知键） |
| item_* / open_reduce_* | 掉落 / 开局减伤 |

### 8.3 目录注解（创作台索引）

```gdscript
extends CoroutineScript
## 非符一：三向扇形
## @name: 非符一
## @desc: 扇开三向、每向 5 连
## @role: boss_shoot     # 角色覆盖（约定判错时才用）
```

角色约定：`*_move.gd`→Boss移动 · `*_shoot.gd`→弹幕发射 · `enemy/`→敌人行为 · `stage_script/`→关卡编排 · `background/`→背景演出。

## 9. 陷阱清单（必读）

1. **BulletData 必须复用实例**（弹型缓存在实例上）；每发 `new()` → 弹型表膨胀。
2. **tex key 拼错会告警，但仍用默认判定**（4px）→ 只从 §7.1 表取 key。
3. **速度来自 `data.velocity.length()`，方向来自发射参数**；别指望 `data.velocity` 的方向。
4. **`then()` 的新相位 `until=never`**，挂 `on_end` 永不触发。
5. **`speed_mul` 是每帧乘**（复利/指数）；线性用 `speed_lerp`、瞬时用 `set_speed`。
6. **`at_wall` 只支持 左/右/上**（无下墙）；`emit(..., at=AT_PHASE_END)` 用其输出落点。
7. **`toward` / `away` 目标不可用时退化为向下**；`chance_toward` 命中时 angle 被忽略。
8. **`on_end_call` 的 hook 名要先注册**；否则静默不调。
9. **变体发射的模板要与分支数对齐**：`chance_toward` 只有 0/1 两支。
10. **自机弹 tint 会被记忆值往红 lerp**（`prepare_shot`）；内容设的 tint 只是基底。
11. **改类型级字段后要 `invalidate_bullet_type()`**。
12. **位置来源是模式、不是可叠加项**：多个 `position` op = 模式切换、后写者胜；要分段用 `then()`。
13. **同相位状态槽 ≤ 8**；超出会被内核拒绝注册，该弹按直线飞。
14. **RNG 单通道、按「op 顺序 + 弹行遍历顺序」消耗**：加/删/重排 `random_dir` / `emit_variant` 会平移后续随机序列（回放仍可复现，但结果会变）。
15. **`on_end_call` 是逃逸口**：每相位最多一次、宿主侧、非热路径；别当 per-frame 逻辑或状态存储。
16. **`T_NEAREST_ENEMY` 只在宿主候选集里取**；targetability 在 `EntityRegistry` / `Enemy.is_targetable`，不在内核。

## 10. 完整例子

### 10.1 环形铺满（每 1.2 秒一圈）

```gdscript
extends CoroutineScript

var _b: BulletData

func _tick(p_ctx: StageContext) -> Variant:
	if _b == null:
		_b = BulletData.new().tex("小玉").speed(160).color(Color.AQUA).blend(true).enemy()
	var lc := BulletLifecycle.new()
	lc.accel_world(Vector2(0, 60))
	lc.until_never()
	_b.trajectory(lc)
	p_ctx.bullets.shoot_spread(_b, 12, TAU, Vector2.RIGHT, target.global_position)
	p_ctx.audio.play_sfx(AssetRegistry.sounds["shoot"], -10.0)
	return p_ctx.clock.wait(1.2)
```

### 10.2 减速往返 → 回点分裂（节选）

```gdscript
var lc := BulletLifecycle.new()
lc.accel_heading(-150.0)                         # 匀减速 → 停 → 反向飞回
lc.until_elapsed(2.0 * bullet_speed / 150.0)     # 位移过零 ≈ 回到出发点
lc.sfx(&"kira", -8.0)
lc.emit_variant([_青玉, _红玉],
	BulletLifecycle.chance_toward(BulletLifecycle.T_PLAYER, 0.1, TAU / 12.0), 60.0)
lc.despawn()
```

## 11. 到这里之后

| 想干什么 | 去哪 |
|---|---|
| 教学 / 由浅入深 | `CONTENT_GUIDE.md` §六 |
| 关卡 / 敌人 / Boss 编排 | `CONTENT_GUIDE.md` 二~四 |
| 描述符设计动机 / 边界 | 附录 A（速查；全文在 `archive/merged/LIFECYCLE_MODEL.md`） |
| 原生执行细节（op / 事件 / 同步点） | `docs/archive/GDEXTENSION_KERNEL_DESIGN.md` + `gdextension/src/danmaku_store.cpp` |
| 架构 / 命名契约 | `docs/ARCHITECTURE.md` + `docs/BEST_PRACTICES_BASELINE.md` |

---

## 附录 A · 弹幕生命周期模型（速查）

- 核心：**一套词汇**（Move / Until / Action）+ **三种 runtime**（低频 GDScript / 高频 per-bullet 描述符 / 原生执行）。
- 相位模型就是 §3.1；Move / Until / Action 见 §3.2–§3.4；组合配方见 §3.8。
- 设计动机：为什么放弃通用 opcode VM、固定 schema 的边界 —— 全文见 [`archive/merged/LIFECYCLE_MODEL.md`](archive/merged/LIFECYCLE_MODEL.md)（原 `LIFECYCLE_MODEL.md`）。
- 当前模型 = 原文 §0–§6 + §11 的 unit 表；决策理由 = §7–§8。

## 附录 B · 一颗弹的完整路径（速查）

```
BulletData（贴图/判定/阵营 + trajectory）
  → ctx.bullets.shoot_spread
  → KernelBulletHost.prepare_shot / KernelNativeSystem.spawn
  → DanmakuStore.integrate + behavior_tick（原生）
  → 只读快照 → BulletMultiMesh → MultiMesh
  → 判定 KernelBulletPhysics（原生宽相网格）
  → 出界/寿命/despawn 回收
```

- 边界：内容给配置 + 规律；宿主把配置翻成内核弹型并结算规则；内核只认列式数据和 program。
- 全文见 [`archive/merged/BULLET_PIPELINE.md`](archive/merged/BULLET_PIPELINE.md)（原 `BULLET_PIPELINE.md`）。

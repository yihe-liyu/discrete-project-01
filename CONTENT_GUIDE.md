# 🛠️ 东方星 STG 引擎 — 内容制作流程

> 版本：2026-09 · **原生内核版**（关卡/Boss/弹幕全在 Godot 里写代码；**弹幕飞行规律挂 `BulletData.trajectory(lc)`，原生执行**；工作台只做预览/调试）

---

## 0. 快速上手（加一个弹幕波次 / 一张符卡）

1. 在 Godot 编辑器里打开 `data/stages/stage01/stage_script/stage01.gd`（Timeline 编排）
2. 加 `timeline.at(时刻).do(func(): ctx.enemies.spawn(EnemyData.new().with_script(...).pos(...)))`
   或经 `_dir.boss(key, data, from, to)` 进 Boss（场景动词），阶段用 `timeline.start_phase(...)`（时轴驱动）或 `handle.phase(n)`（事件驱动）
3. F6 运行工作台 → 命中框/固定种子/逐帧看效果；改完代码**重启工作台**生效
4. Boss 阶段/弹幕脚本（阶段目录下，如 `data/stages/stage01/phase/non_mid01/`）改完同样重启工作台看
5. **改某颗弹的飞行规律** → 见「六 · 弹幕行为」（`BulletData.trajectory(lc)` 直接挂现成 preset，或自己用 builder 拼相位）

> 工作台**不是编辑器**：不写数据、不热重载，是「跑真实代码看效果」的预览沙盒。
> 数据（关卡/Boss/阶段）全部以代码 + .tres 形式存在，由 AI/人直接写。

---

## 一、总体架构

```
① 关卡编排：stage01.gd（Timeline API，代码声明节奏/Boss/阶段）
② 行为层：  协程脚本 .gd（敌人行为 + Boss 移动/弹幕/入场/退场）
③ 数据层：  .tres 资源（BossData/PhaseData/敌人预设/符卡记录）
④ 预览层：  工作台 = 真实运行时沙盒（幽灵玩家 + 命中框 + 固定种子 + 书签）
```

数据关卡（wave_stage/StageTimeline/波次表）与脚本页/编排页已**移除**（2026-08 决策）：
弹幕的核心是逻辑不是数据，代码直写 + 工作台预览是当前唯一流程。

---

## 二、关卡编排（stage01.gd，Timeline API）

位置：`data/stages/stage01/stage_script/stage01.gd`（`extends CoroutineScript`）

```gdscript
const ENEMY01 = preload("res://data/stages/stage01/enemy/enemy01.gd")
const CAMORUI_MID = BossCatalog.boss(1, 0)   # 道中 Boss 数据（BossCatalog 单源）
const CAMORUI     = BossCatalog.boss(1, 1)   # 关底 Boss 数据（完整阶段链）

var _dir: StageDirector   # 场景导演：bgm/boss/dialogue/on —— 场景动词唯一 owner
var _mid: BossHandle      # 道中 Boss 句柄（reveal/phase/retreat）
var _final: BossHandle    # 关底 Boss 句柄

func start(p_ctx: StageContext, p_target: Node2D = null):
	ctx = p_ctx
	_dir = StageDirector.new(ctx)          # 导演：场景动词 + 事件路由
	var timeline := start_timeline()       # 纯排程器：无 ctx、无导演依赖
	timeline.at(0.0).do(func(): _dir.bgm("stage1"))   # 按 key（走 _dir.bgm；_dir 是唯一实现）
	timeline.at(1.0).do(func(): ctx.enemies.spawn(EnemyData.new().with_script(ENEMY01)...
		.pos(Vector2(...)).red_little_fairy().param("target_y", 200)))
	# Boss 进场：spawn + register + 隐藏名 + tween —— 全在 _dir.boss 里
	timeline.at(35.0).do(func():
		_mid = _dir.boss("boss_mid", CAMORUI_MID, Vector2(-50, 500), Vector2(FIELD_CENTER_X, 250))
	)
	# 时轴驱动的阶段（保留 start_phase 的 wait 偏移继承）
	timeline.at(38.0).start_phase(func(): return _mid.resolve(), CAMORUI_MID.phases_normal[0])  # 非符1
	# 战前对话事件路由（取代 _on_dialogue_event 大 match）：只调动词
	_dir.on("boss_enter",   func(): _final = _dir.boss("boss_final", CAMORUI, Vector2(1000, 500), Vector2(FIELD_CENTER_X, 250)))
	_dir.on("display_name", func(): _final.reveal("卡摩瑞"))
	_dir.on("boss_fight",   func(): _final.phase(0, true))
	super.start(ctx, target)
```

> **一次性初始化更轻的写法**：要在**首次 `_tick` 之前**建弹型 / 注册钩子时，覆写 `_on_start()` 即可 ——
> `start()` 会先设好 `ctx`/`target` 再调它，**不必**再覆写 `start()` + `super.start(...)`。
> 只有需要自定义启动时序（如在这里建 timeline、算 `_dir`）时才覆写 `start()`。

Timeline 链式 API：`at(t)` 绝对时刻 · `wait(n)` 相对上一 blocking 结束 · `do(cb)` 任意逻辑 ·
`start_phase(boss_getter, PhaseData)` 起阶段（保留时符等待：击破后激活后续 wait） · `every(t).times(n)` 重复。
**场景动词（bgm/boss/dialogue/事件路由）由 `StageDirector` 承担**；Timeline 是**纯排程器**，动作一律 `do(func(): ctx.*)` / `do(func(): _dir.xxx())`。
Timeline 只保留 `at/every/times/wait/do` + `start_phase`（相对时间 wait 的锚点）—— **不为任何底层方法配包装**。

> ⚠️ start_phase 链注意：`wait()` 后接 `start_phase()` 必须直接链（`timeline.wait(1.0).start_phase(...)`），
> 中间插 `do(pass)` 会破坏 wait 偏移继承（阶段会立即触发）。

---

## 三、敌人

### 敌人数据（构造链硬编码）

`EnemyData` 提供构造链：`red_little_fairy() / blue_middle_fairy() / red_middle_fairy() / ...`
（外观/血量/判定/掉落直接写死，`enemy_presets/*.tres` 已移除——数据即代码）。

生成走 **`ctx.enemies.spawn(data)`**（与 `ctx.bullets.shoot_spread` 对称的服务动词；实例化/挂载协程/入场景在 `StageRuntime`）。

### 行为脚本

位置：`data/stages/stage01/enemy/`（enemy01/02/03/04、fly_away 等）。
**直接引用**：关卡脚本 `preload()` 敌人行为，`EnemyData.new().with_script(ENEMY01)...` 构建——
无注册表、无中间层（EnemyTemplateRegistry/BossScriptRegistry 已随编辑器移除，2026-08）。

---

## 四、Boss（阶段数据 + 脚本目录）

### BossData / PhaseData（.tres）

- `BossData`（`data/stages/stage01/phase/` 参照）：`boss_name` / `visual` / `phases_normal`（Normal 组）/ `phases_easy/hard/lunatic/extra`（各难度独立、不回退） / `enter_script` / `exit_script` / `score_value`
- `PhaseData`：`name`（空串 = 非符）、`uid`（0 = 非符不记；真符卡全局唯一）、`hp` / `time_limit` / `bonus`、`is_timeout_only`、`move_script` / `shoot_script`、掉落 item 系列、`params`

阶段示例（`data/stages/stage03B/phase/spell03/spell055.tres`——黄粱「不可测之梦」）：
```gdscript
[gd_resource type="Resource" script_class="PhaseData" format=3]
...
name = "黄粱「不可测之梦」"
uid = 55
time_limit = 40.0
hp = 4000
move_script = ExtResource("...random_dir_move.gd")
shoot_script = ExtResource("...spell053_shoot.gd")
```

**`params`（阶段级脚本参数覆盖）—— 「分化三选一」的最后手段，不是首选。**

> **分化优先级（2026-09-22 立）**：
> **① `diff_pick()`（难度轴，首选）→ ② 另写一个脚本（内容轴，最直白）→ ③ `params`（只在"脚本几乎相同、复制很浪费"时）**
>
> 实测（2026-09-22）：全项目 53 个 `.tres` **没有一个用 `params`**；难度轴有 29 处 `diff_pick`。
> 内容轴**确实存在脚本复用**（`random_dir_move.gd` 撑 9 个阶段、`spell053_shoot.gd` 与 `spell001_shoot.gd` 各撑 4 张），
> 但**从未用 `params` 去分化它们** —— 也就是说这条通路至今一次都没派上用场。

**为什么排最后**：值离逻辑远（脚本里默认 175、`.tres` 里覆盖 400，得两头看）、键名写错要到运行期才报、
手感散在 `.tres` 里不进 diff —— 而 `diff_pick` 把这些值放在**逻辑旁边**。**能内联就别外置。**

**它唯一的独门能力**（`diff_pick` 表达不了）：同一脚本 × 多张 PhaseData × 只差两三个数值
—— 也就是"脚本不知道自己正跑在哪张符卡上"的那一维。

**机制**：`Boss.start_phase` 把该阶段的 `params` 注入到 move/shoot 脚本的**同名属性**（`key in target` 才设）。

```gdscript
# phase/第二符卡.tres（复用 spell053_shoot）
shoot_script = ...spell053_shoot.gd
params = {
	"发弹点角速度": 8.0,     # 覆盖脚本里的 var 发弹点角速度
	"保持旋转时间": 3.0,     # 覆盖 保持旋转时间
	"个数": 8,
}
```

**三条隐性约束（违反时都不报错，只是"没生效"）**：

1. **只认 `var`，不认 `const`**：`const` 键的 `"X" in target` 为 **true**、但 `set()` **静默无效**
   —— 可调项必须是 `var`（实测：`BulletLifecycle.MAX_SLOTS` 应用后值不变、无任何报错）。
2. **move / shoot 共用同一个字典**（`boss.gd` 对两者都传 `data.params`）→ **两边不能有同名 var**，否则一个键同时改两边。
3. **注入发生在 `start()` 之前**（`boss.gd`：`new()` → `apply` → `start()`）；
   若脚本在 `_on_start()` 里建弹型（如 `spell053_shoot.gd`），把注入挪到 `start()` 之后会让
   `_on_start()` 读的那批变量**静默失效**（而 `_tick()` 读的那批照旧生效 → 一半失灵最难查）。

### Boss 阶段脚本（协程 .gd + .tres 显式引用）

> ⚠️ 纠正（2026-08 目录重组后）：**没有"目录自动发现"**。阶段脚本由 `PhaseData.tres` 的
> `move_script` / `shoot_script` 字段**显式引用**，脚本与 `.tres` 放同一阶段的目录下就行。
> `data/boss_scripts/` 只是个别可复用移动脚本的存放处，不是自动扫描目录。

**惯例**：每个 Boss 阶段（非符/符卡）一个子目录，含 `.tres` + 它引用的 `*_move.gd` / `*_shoot.gd`（弹丸逻辑用 `bullet/` 或同目录脚本）：

```
data/stages/stage01/phase/
├── non01/           卡摩瑞的非符1
│   └── non01.tres
├── non_mid01/       道中非符1
│   ├── non_mid01.tres
│   ├── non_mid01_move.gd      # move_script
│   ├── non_mid01_shoot.gd     # shoot_script
│   └── non_mid01_bullet.gd    # 弹丸行为（被 shoot 引用）
└── spell01/
    └── spell001.tres
data/stages/stage03B/phase/spell03/      # 测试符卡（3 面 Boss「梦外见/黄粱」）
├── spell053~056.tres
└── spell053_shoot.gd                     # shoot_script（环绕发射器 + 往返探测弹描述符）
```

**加新阶段 = 建目录 + 写 .gd + 建 .tres，`.tres` 里用 `move_script=ExtResource(...)` 指脚本**，
再在关卡脚本 `timeline.start_phase(getter, that_tres)`（时轴驱动）或 `handle.phase(index)`（事件驱动）引用。脚本文件即复用单元 —— 想复用同一脚本时，**先看难度轴能否用 `diff_pick`，再考虑另写一个脚本，`params` 是最后手段**（见上「分化三选一」）。

---

## 五、难度差分

- **Boss 阶段**：`BossData` 四组 phases（E/N/H/L），协程脚本里 `diff_pick()` 按难度取
- **敌人强度**：行为脚本内 `diff_pick([1, 3, 5, 8])` 运行时取参
- **分化手段优先级**：难度轴 → `diff_pick()`（首选，值放脚本里）；内容轴 → 另写脚本；`params` 最后（见 §四）
- **UID 规则**：真符卡全局唯一（建议 1 面 100-199、2 面 200-299…）；非符 uid=0；角色共用 UID，SpellRecordBook 主键区分

---

## 六、脚本层约定

> 全部继承 `CoroutineScript`（`scripts/coroutine/base/coroutine_script.gd`）。

### 协程返回值约定

```gdscript
return ctx.clock.wait(2.0)  # 等待 2 秒后再次调用
return true                  # 下物理帧立即再次调用
return false                 # 结束协程
```

### 弹型实例复用（M2 起）

发射弹时**复用 `BulletData` 实例**，不要每发 `BulletData.new()`：内核弹型（`BulletType`）缓存在 `BulletData` **实例**上，每发 new 会让内核弹型表每发长一个。

```gdscript
var _bullet_data: BulletData   # 成员：建一次

func _fire(ctx):
	if _bullet_data == null:
		_bullet_data = BulletData.new().tex("小玉").speed(300).enemy()
	_bullet_data.velocity = Vector2(0, 300 + i * 50)   # 速度 / params 每发写（不属弹型）
	ctx.bullets.shoot_spread(_bullet_data, count, TAU, dir, pos)
```

> 类型级字段（贴图 / 阵营 / 判定 / 伤害 / 命中特效）在**首次发射时快照**；运行期改型需 `invalidate_bullet_type()`。
>
> 内核**延后发射**（`emit` / `at_end` 落点等）在**入队瞬间**快照速度 / 染色，所以「复用实例 + 每发改速度」是安全的；但别在**入队之后、flush 之前**再改同一实例。

### 脚本文件地图

```
敌人行为   data/stages/<stage>/enemy/     *.gd（关卡脚本 preload 即用）
Boss 阶段  data/stages/<stage>/phase/*/   每阶段一个目录：*.tres + *_{move,shoot}.gd（.tres 显式引用）
关卡专属   data/stages/<stage>/           stage_script/ + phase/ + enemy/ + background/ + stage_data/
```

> 弹丸行为**不再单列目录**：`data/**/*_bullet.gd` 已删，飞行规律直接挂在发射脚本的 `BulletData` 上（见「弹幕行为」）。

### 行为脚本示例

```gdscript
extends CoroutineScript
## 红杂鱼: 向下减速 + 自机狙 + 散射

var target_y: float = 300
var heavy_wave: bool = true
var rate: int = 1

func _ready() -> void:
	call_deferred("_init_enemy")

func _init_enemy() -> void:
	var parent := get_parent()
	# 移动 tween + 发弹（ctx.bullets.shoot_spread / ctx.clock.wait / timeline.at ...）
```

### 目录注解（创作台自动索引，2026-08+）

协程脚本会被**自动扫描**进创作台目录（`ContentCatalog`，只扫 `res://data/`、只收 `extends CoroutineScript/CoroutineRunner`）。
角色默认按**路径/命名约定**判定（`*_move.gd`→Boss移动 · `*_shoot.gd`→弹幕发射 ·
`enemy/`→敌人行为 · `stage_script/`→关卡编排 · `background/`→背景演出）；约定判不出时按**真实引用**反推（阶段 .tres 的 move/shoot 字段）。
`*_bullet.gd` / `bullet/` 约定仍在代码里，但 `data/**` 已无文件使用（飞行规律直接挂在发射脚本的 `BulletData` 上）。

**注解可选，优先级最高**（写在文件头部注释块，与普通描述行混排即可）：

```gdscript
extends CoroutineScript
## 非符一：三向扇形
## @name: 非符一                 # 目录显示名（默认=注释首行）
## @desc: 扇开三向、每向 5 连      # 描述（默认=其余注释行；@name 存在时=全部注释行）
## @role: boss_shoot             # 角色覆盖（约定判错时才用；打架会出 warning）
```

### 弹幕行为（由浅入深）

一颗弹的飞行规律**只有一个入口**：`BulletData.trajectory(lc)`（`lc` = `BulletLifecycle`，fluent builder）。
**不改 C++** 就能拼出绝大多数弹幕 —— 下面从"直接用现成 preset"讲到"自己排相位"。
> 完整字典（每个函数的精确签名 / 原生语义 / 素材 key 表 / 陷阱清单）见 **[docs/DANMAKU_API.md](docs/DANMAKU_API.md)**；本节是教学路径。

#### ① 最简：挂一个现成 preset

```gdscript
var _bullet: BulletData          # 成员：复用实例（见「弹型实例复用」）

func _fire(p_ctx: StageContext) -> void:
	if _bullet == null:
		_bullet = BulletData.new().tex("小玉").speed(300).enemy() \
			.trajectory(BulletLifecycle.homing())     # ← 追踪最近敌人
	p_ctx.bullets.shoot_spread(_bullet, 8, TAU, Vector2.RIGHT, global_position)
```

#### ② 常用：9 个命名 preset

| preset | 参数（括号内为默认） | 说明 |
|---|---|---|
| `world_accel(v)` | `v: Vector2` | 恒定世界加速度 |
| `accel(a)` | `a: float` | 沿当前方向加速 |
| `curve(w, limit)` | `w`（角速度）、`limit`（累计转角上限，0=无限） | 边飞边转 |
| `homing(...)` | `angle_per_sec`(720°)、`accel_time`(2)、`min_speed`(500)、`max_speed`(2000)、`duration`(2)、`proximity_boost`(150) | 追踪最近敌人 |
| `bounce(accel_rate, bounce_angle, spawn_speed, spawn, sfx, sfx_db)` | `spawn: BulletData`（替换弹）、`sfx`("kira")、`sfx_db`(-8) | 碰框朝 Boss 转 `bounce_angle` 后换弹 |
| `radial_accel(accel_rate, spawn, sfx, sfx_db)` | `spawn: BulletData`、`sfx`("")、`sfx_db`(0) | 沿初向加速 + 碰顶换向下弹 |
| `avoid_player(proximity, jump, flee_time)` | — | 靠近自机逃 |
| `marisa_laser(...)` / `laser_follow(...)` | `anchor_id`、`offset`、`angle`、`drift_speed`、`initial_drift` | 子机锚定激光（前者 World 兄弟用 global，后者子节点用局部） |

> **权威真相 = `scripts/kernel_bridge/lifecycle/lifecycle_catalog.gd` 的 `build()`**（组合定义唯一在此）；上表是它的类型化薄包装。
> **新增 preset** = 在 `build()` 加分支、用已有原语拼，**不用写 `*_bullet.gd`，也不用改 C++**。

#### ③ 不够用：自己拼相位

```gdscript
# 边转 0.5 弧度 → 转满后沿当前方向加速 1 秒 → 消失
func _sharp_turn() -> BulletLifecycle:
	var lc := BulletLifecycle.new()
	lc.rotate(2.0, 0.5)      # 相位1：边飞边转（limit=0.5 弧度）
	lc.until_turned()        # 转满 → 进下一相位
	lc.then()                # ← 流程控制：开新相位
	lc.accel_heading(300.0)  # 相位2：沿当前方向加速
	lc.until_elapsed(1.0)
	lc.despawn()
	return lc

_bullet.trajectory(_sharp_turn())    # 直接挂，不经端口
```

#### ④ 全词汇（Move / Until / Action / 方向糖）

| 类 | 成员 |
|---|---|
| Move | `accel_world` `accel_heading` `rotate` `steer` `speed_lerp` `scale_speed` `set_heading` `set_speed` `anchor_drift` |
| Until | `until_never` `until_elapsed` `until_near` `until_at_wall` `until_speed` `until_state` `until_turned`；`then()` 开新相位 |
| Action | `sfx` `emit` `emit_variant` `despawn` `on_end_heading` `on_end_call` |
| 方向糖 | `heading(angle)` / `toward(target, angle)` / `away(target, angle)` / `forward(angle)` / `random_dir(spread)` / `chance_toward(target, p, spread)` |

> - `target` = `T_PLAYER` / `T_BOSS` / `T_NEAREST_ENEMY`。
> - **`emit`**：相位结束时生成替换弹。第一参 = `BulletData`（推荐）／`Callable（）-> BulletData`（旧写法）／数组（变体发射）。
> - **`emit_variant([未命中, 命中], chance_toward(T_PLAYER, p, spread), speed)`**：内核按概率分支抽签，0 = 未中取第 1 个、1 = 命中取第 2 个。
>   自机狙转红的例子：`lc.emit_variant([_青玉, _红玉], BulletLifecycle.chance_toward(T_PLAYER, 0.1, a), 60.0)`。
>   **模板永远留在宿主**（内核只回传一个分支号），所以换色 / 换贴图 / 换大小都行。
> - **`on_end_call(hook)`**：低频内容回调。`hook` 传**已注册的 hook 名**（`StringName`，先 `LIFECYCLE_HOOKS_SCRIPT.register()`）或 `Callable`（旧写法）。
> - **锚定型弹道**（激光）用第二参数传 per-shot 锚点：`b.trajectory(lc, {&"id": node.get_instance_id(), &"offset": Vector2.ZERO, &"use_global": true})`。

#### ⑤ 什么时候才动 C++

只有要**新的数学原语**（现 Move 9 / Until 5 / Action 6 之外）时才动 `gdextension/src/danmaku_store.cpp`：
新增一个 op 要同时改**原生执行分支**与**编译端编码**（若回传事件，还要加事件数组项），并补 parity 测试。
其余一切 —— 新 preset、新组合、新颜色分支 —— 都在宿主侧完成。

#### ⑥ 旧通路：`kernel_port` / `*_bullet.gd`（已弃用）

`data/**` 里**已经没有** `*_bullet.gd` 载体了：飞行规律一律直接 `trajectory(lc)`。
桥接层仍保留 `kernel_port` 通路（返回 `{"move": ..., "params": ...}` 或 `{"lifecycle": ...}`），但它**只服务测试夹具**
（`test/fixtures/lifecycle_port_behavior.gd` + `test/test_lifecycle_port.gd`），新内容不要再用；待清（TODO b2c）。

---

## 七、调试（工作台工具链）

| 工具 | 用法 |
|------|------|
| 固定种子 | 播放区开关：重跑弹幕序列可复现（调参必备） |
| 命中框 | 播放区开关：红=敌弹判定、绿=敌人、青=自机、蓝=擦弹 |
| 逐帧 | 暂停中按 F：精确走 1/60s |
| 跳转 | 点时间轴/书签/←→ = 12x 快进到目标（真实关卡无任意 seek） |
| 书签 | 时间轴右键/快捷键 B 打点；协程关卡静态提取 timeline.at() 时刻 + 人工打点 |
| 幽灵玩家 | 自机狙目标（不攻击，看弹幕用） |

快捷键：`Space` 暂停/继续 · `R` 重跑 · `F` 逐帧 · `1~7` 速度 · `←/→` ±1s（Ctrl ±5s）·
`B` 书签 · `Home` 回开头

> 改代码后**重启工作台**生效（无热重载）。写代码在 Godot 编辑器，看效果在工作台。

---

## 八、挂到游戏

1. MainMenu → Start → 选难度 → 选角色 → `GameManager.change_scene("game_scene")`
2. `GameScene._ready()` → `_resolve_stage_data()` → `StageRuntime.load_stage(data)`
   （`data/registry/stage_registry.tres`：Stage 1 → `stage01.tres` 协程版）
3. 练习模式：从符卡记录（`user://spell_records.tres` 解锁后内联存的 phase_data + boss_scene）构建单 phase Boss，
   走 `SaveData.start_practice()` → `_start_practice_game()`

---

## 九、符卡练习 / 菜单 / 对话

- **符卡簿**：`user://spell_records.tres`（R14 运行期档；res:// 已无出厂种子，首启空簿），见到即记（unlock_spell），自动按 UID 记录尝试/捕获/最佳
- **符卡练习（单驱动）**：练习菜单 = 符卡簿记录决定"能练哪张"，记录里**内联存战斗配置**
  （phase_data + boss_scene，见 `spell_record.gd` 注释"无需 CardDef"）。已解锁的符卡可选任意难度进入。
  `CardDef` / `spell_registry.tres` 早已移除（2026-08，放弃"双驱动"）。练习入口默认锁定：
  MainMenu 的 Spell Practice 在符卡簿为空时锁定，有记录（解锁过符卡）才可进入。
- **菜单页**：`scenes/ui/*_menu.tscn` 继承 BasePage（`scripts/scenes/menu_nav.gd` 导航）
- **对话（DSL 台词内联，2026-08 重构）**：`DialogueSteps` 流程 DSL，**台词直接写在代码里**（与弹幕编排同构）：
  `enter/say/line/move/flip/dim/portrait/bubble/event/wait` → `ctx.play_dialogue_steps(steps)`。
  `line()` 延续上一说话者、`say(profile, text)` 换人；`d.event(key)` 是行间事件，时机精确。
  参考：`data/stages/stage01/stage_script/stage01.gd` 战前对话、`docs/DIALOGUE_SYSTEM.md`、剧本归档 `docs/DIALOGUE.md`

---

## 十、已知边界

- 运行时保存 .tres 依赖 res:// 可写（开发模式）；导出包只读，符卡簿保存会失败（待数据迁移方案）
- **弹丸协程脚本**（gravity_bullet.gd 等，被行为脚本 preload）与所有脚本改动都需**重启工作台**生效
- 敌人/Boss 脚本零注册：preload/直接引用即用

## 发动符卡前的走位（`PhaseData.pre_move_script`）

符卡宣言（报幕 / `card` 音效 / 符卡背景）默认**立刻**发生。想让 Boss「先走到位、再发表宣言」，
把走位脚本挂到该阶段的 `pre_move_script`：

```gdscript
# 符卡001.tres
pre_move_script = <走位脚本>     # 它跑完 → 才宣言 → 再进入这张卡自己的 move/shoot
```

**现成示例**：[`data/boss_scripts/move/move_to_point.gd`](data/boss_scripts/move/move_to_point.gd)
—— 走到指定站位后自己结束，站位/耗时可用 `params` 覆盖：

```gdscript
# PhaseData.params
{"dest": Vector2(448, 240), "move_time": 1.2}
```

✅ 已验证生效（`_run_pre_move()` 在 `start()` 之前注入，错键名/类型由 `ParamValidator` 响亮报错）。

⚠️ **但 `params` 是同一阶段**共用的一份字典** —— `pre_move_script` / `move_script` / `shoot_script`
拿到的是**同一个 `data.params`**。所以**键名会互相干扰**：本示例的 `move_time` 与
`random_dir_move.gd` 的 `move_time` 同名，同一阶段同时用这两个脚本时，它们会拿到**同一个值**。
要么避开重名（如改叫 `glide_time`），要么接受这个共享语义。

⚠️ **写 pre_move 脚本的铁律：必须能结束。** 它不结束，这张符卡就永远不会发动
（`Boss.start_phase` 会一直等它的 `finished`）。注意 `CoroutineScript.auto_stop` **默认是 `false`**
（持续运行语义），要在 `_init()` 里 `auto_stop = true`，`_tick` 返回 `false` 才真的会停。

**第二个示例**：[`data/boss_scripts/move/corner_sweep.gd`](data/boss_scripts/move/corner_sweep.gd)
—— 从游戏框**右上角**扫到**左下角**，**快→慢→快**（两段 tween 接力：`EASE_OUT` 到中点 + `EASE_IN` 到终点，中点即场地中心）。
参数：`move_time`(1.6s) / `hold_middle`(中点停留) / `from_corner`(是否先瞬移到右上角)。

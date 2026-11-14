# NativeBehavior Pack 设计

> **状态**：linear + homing + accel 已落地，enemy01/02/03 的重力弹已迁到 accel；EmitTemplate / Registry + `BulletBehaviors` 具名构造器已落地；bounce_emit Outcome（emit/despawn/sfx）已接入；卡摩瑞一非 / 二非已从 lifecycle 迁到 bounce_emit；哆来咪三符的往返弹已迁到 split_after；卡摩瑞二非 / 一非 / 二符 / 哆来咪三符已改用独立 SpawnSpec；简单敌人批次也已迁移；enemy04 已迁到 top_emit；内容与 SpawnSpec 均不再调用 to_bullet_data()；`BulletData.with_behavior()` 已接入内容桥；测试覆盖自动绑定、转向与属性 API。
> **目标**：把“每颗弹生命周期内的运动控制”从内核里的固定 opcode / DSL，迁到可独立增删的 C++ behavior pack；内核只保留存储、碰撞、积分、渲染同步和注册表。
> **非目标**：运行期加载不可信 `.so`、每颗弹一个对象、GDScript 每帧回调。

## 1. 为什么要做

当前 `BulletLifecycle` 的形态是：

```text
GDScript builder
  → LifecycleCompiler
  → packed program
  → DanmakuStore::_run_behavior_pass
```

它已经在内核里执行，不是每帧 GDScript；但它仍然是一套**固定词汇的 VM**：

```text
Move / Until / Action
```

问题是：

- 表达力被 opcode 限制；
- 新运动逻辑要同时改编译器、内核、参考实现、测试；
- 内核会逐渐积累“某种弹幕专用”的分支；
- 内容与内核的边界越来越模糊。

NativeBehavior Pack 把边界改成：

```text
内核：不认识任何具体运动
pack：认识 homing / orbit / linear / ...
GDScript：只负责选择和传参
```

## 2. 目标结构

```text
gdextension/
  src/
    danmaku_store.*        # SoA + 积分 + 碰撞 + 渲染快照
    native_behavior.*      # registry + 调度
  behaviors/
    linear/
    homing/
    orbit/

content_packs/
  behaviors/
    linear/
    homing/
```

`behaviors/` 是**编译期内容包**：源码随主 GDExtension 一起构建，不动态加载。

## 3. 数据布局

### 每行新增

```cpp
std::vector<int32_t> _behavior_id;   // -1 = 不使用 native behavior
std::vector<float>   _bstate;        // _capacity * STATE_STRIDE
std::vector<int32_t> _bparams;       // 参数池下标 / 或固定参数槽
```

原则：

```text
每颗弹只存 behavior_id + 固定 state + 参数
不存对象指针
不存 std::function
不 new
```

### Behavior 定义

```cpp
struct NativeBehaviorDef {
    StringName id;             // "homing"
    int state_size;            // 固定槽数
    int param_count;
    void (*init)(float* state, const float* params);
    void (*tick)(float* state, const float* params,
                 NativeBehaviorContext& ctx, float dt);
};
```

`NativeBehaviorContext` 只暴露只读 / 受控写：

```cpp
struct NativeBehaviorContext {
    Vector2 player;
    Vector2 boss;
    bool has_boss;
    const PackedVector2Array& enemies;
    // 当前行可写通道
    Vector2& velocity;
    float& heading_x;
    float& heading_y;
    float& render_rot;
    float& life;
};
```

不把整个 `DanmakuStore` 暴露给 pack，避免 pack 绕过边界。

## 4. 调度顺序

当前顺序：

```text
integrate(delta)          # 位置 += 速度 * dt
_run_behavior_pass(dt)    # lifecycle 改速度 / 朝向
```

Native behavior 第一版保持同样顺序：

```text
integrate(delta)
if behavior_id >= 0:
    behavior.tick(state, params, ctx, dt)
else:
    lifecycle program
```

这样 `homing` 与现有 lifecycle 版可以逐帧对比。
如果后续需要“行为自己决定位置”，再增加显式通道，不偷偷改顺序。

## 5. GDScript API

```gdscript
var spec := BehaviorSpec.new()
spec.id = &"homing"
spec.params = [2.4, 0.25]       # 固定 float 参数

var data := BulletData.new().enemy().tex("小玉")
data.behavior = spec
```

或者：

```gdscript
data.behavior = NativeBehavior.homing(turn_rate = 2.4, lead = 0.25)
```

`NativeBehavior` 只是**名字 → ID / 参数打包**的薄封装，不承载逻辑。

## 6. 注册

### 编译期

```cpp
// behaviors/homing/homing.cpp
static const NativeBehaviorDef HOMING = {
    "homing", 4, 2, &homing_init, &homing_tick
};
REGISTER_NATIVE_BEHAVIOR(HOMING);
```

注册表在扩展初始化时构建：

```text
behavior name → stable id
```

ID 必须稳定；内容存档 / replay 记录用 ID，不存函数指针。

### GDScript 侧

```gdscript
NativeBehavior.has(&"homing")   # 构建期是否编入
NativeBehavior.id(&"homing")    # 稳定 id
```

未编入时在内容加载阶段报错，而不是运行到一半静默。

## 7. 和 Lifecycle 的关系

不要把两者做成两套互相竞争的移动系统。

```text
通用 / 组合 / 参数化     → BulletLifecycle
特殊 / DSL 写不出         → NativeBehavior
```

迁移顺序：

```text
1. 加 registry + 行字段 + spawn/set_behavior
2. linear 作为第一个 pack（基准）
3. 全量测试 parity
4. homing 作为第二个 pack
5. 只迁一张卡
```

`linear` 先做，是因为它最简单，能验证：

```text
spawn 可设置 behavior
integrate + behavior tick 顺序正确
swap_remove / batch / reset 新字段没漏
```

## 8. 对“项目干净”的真实影响

### 会变干净

```text
1. 内核不再认识 homing / orbit
2. 新行为在 pack 目录内闭环
3. behavior 源码、参数、测试放在一起
4. 内容可以选择 behavior，而不是复制 lifecycle 组合
5. 删除一个行为 = 删除一个 pack，不挖内核
```

### 不会自动变干净

```text
1. 代码行数短期可能增加（registry + pack 骨架）
2. 构建复杂度增加（pack 发现 / 编译）
3. 测试矩阵增加（每个 pack 的 parity）
4. 内容不能热改，改 behavior 必须重建
```

所以“干净”不是行数，而是：

```text
内核稳定
内容可插拔
依赖方向单一
新增行为不需要改内核
```

## 8.1 C++ 作者 helper

`gdextension/src/behaviors_core/behavior_common.h` 提供 `heading` / `accelerate` / `steer_toward` / `emit` / `kill` / `play_sfx`，只收机械操作，不隐藏 behavior 逻辑。

## 9. 成本与风险

| 项 | 成本 | 风险 |
|---|---|---|
| registry + 行字段 | 1–2 人日 | swap_remove / batch / reset 漏字段 |
| linear pack | 0.5–1 人日 | 与现有默认行为不一致 |
| homing pack | 1–2 人日 | 与 lifecycle 版位置/速度不一致 |
| 构建发现 | 0.5–1 人日 | 新 pack 忘记编入 |
| 测试 / parity | 1–2 人日 | 只测数量不测轨迹 |
| replay / 状态哈希 | 1 人日 | behavior state 没进哈希 |

总预估：**4–7 人日** 做到“linear + homing + registry + parity”。

## 10. 验收

- `linear` pack 与现有默认直线弹逐帧位置一致。
- `homing` pack 与一张现有 lifecycle 卡逐帧位置/速度一致。
- 同一输入跑两次，behavior state 哈希一致。
- 8k / 20k / 50k 基准不退化。
- `swap_remove`、`spawn_batch`、`clear`、`reset` 都覆盖新字段。
- 删除 homing pack 后主扩展仍可构建（未使用时不链接）。

## 11. 暂不做

```text
运行期 native .so 加载
每弹对象 / 虚函数
GDScript 每帧回调
自动生成 C++ 代码
把 pattern 组合也塞进 behavior
```

## 12. 一句话

```text
内核负责“怎么存、怎么撞、怎么画”；
pack 负责“怎么飞”；
GDScript 负责“用什么飞”。
```

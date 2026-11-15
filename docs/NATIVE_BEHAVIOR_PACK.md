# NativeBehavior Pack

> **状态**：所有内容弹道已迁移到 C++ behavior pack；`BulletData` / `BulletLifecycle` / packed program 执行器均已删除。
> **目标**：每颗弹的运动逻辑 = 一个可独立增删的 C++ pack；内核只保留存储、积分、碰撞、渲染同步与注册表。

## 1. 模型

```text
SpawnSpec.with_behavior(BehaviorSpec)
  → KernelBulletHost.prepare_shot()
  → KernelNativeSystem.spawn() + set_behavior()
  → DanmakuStore.integrate(dt)
  → behavior_tick(dt)          # 只跑这一颗弹的 C++ pack
```

- 一颗弹只有一个 behavior；组合写在一个 pack 内。
- state / params 都是固定 8 个 float 槽，不存对象、不存引用。
- 随机只走内核单通道 RNG；回放可复现。
- 行为请求（emit / sfx / laser / clear_fx / despawn）先写进 `NativeBehaviorOutcome`，遍历结束后由内核统一落地。

## 2. 目录与命名

```text
gdextension/src/behaviors_core/
  behavior_common.h          heading / accelerate / steer_toward / emit / kill / clear_fx / play_sfx / emit_laser / random
  registry.cpp               register_behaviors_core()
  shared/                    跨卡通用：linear / homing / accel / accel_heading / bounce_emit /
                             split_after / seed_burst / spin_accel / anchor_drift
  <stage>/<owner>/<verb>.cpp 单卡专属：stage01.enemy04.top_emit / stage02.enemy02.spin_then_slow /
                             stage03B.mid01.rain_stage / stage01.mid01.sonar
```

注册名 = 文件路径去掉 `.cpp` 后的点分形式；单卡专属 behavior 用 `stage.owner.verb`，通用 behavior 用机制名。

## 3. 写一个 pack

```cpp
struct XxxState { float age = 0.0f; };
struct XxxParams { float speed = 0.0f; float turn = 0.0f; };

static void xxx_init(float *p_state, const float *p_params) {
    (void)p_params;
    behavior::State<XxxState> state(p_state);
    *state = XxxState{};
}

static void xxx_tick(float *p_state, const float *p_params,
        NativeBehaviorContext &p_ctx, NativeBehaviorOutcome &p_out, float p_dt) {
    behavior::State<XxxState> state(p_state);
    const auto p = behavior::params_as<XxxParams>(p_params);
    state->age += p_dt;
    behavior::accelerate(p_ctx, behavior::heading(p_ctx), p.speed * p_dt);
    if (state->age >= p.turn) {
        behavior::kill(p_out);
    }
}

void register_xxx() {
    REGISTER_BEHAVIOR("xxx", XxxState, XxxParams, &xxx_init, &xxx_tick);
}
```

然后在 `registry.cpp` 加声明与调用，在 `scripts/data/bullet_behaviors.gd` 加具名构造器：

```gdscript
static func xxx(speed: float, turn: float) -> BehaviorSpec:
	return BehaviorSpec.new(&"xxx", PackedFloat32Array([speed, turn]))
```

## 4. 上下文与 Outcome

`NativeBehaviorContext` 暴露：`player` / `boss` / `has_boss` / `enemies` / `position(+position_out)` /
`velocity` / `heading` / `render_rot` / `spin_rot` / `color` / `life` / `anchor` / `field_*` / `rng_float`。

`NativeBehaviorOutcome` 支持：`despawn`、`emits[64]`、`sfx_id`、`clear_fx`、`laser_template_id` / position / direction。

> 行为循环中途禁止 spawn/despawn；`emit` 只是请求，宿主在循环结束后统一落地。

## 5. 内容 API

| builder | 用途 |
|---|---|
| `linear()` | 匀速直线 |
| `accel(Vector2)` | 世界方向匀加速 |
| `accel_heading(accel, lifetime=0, clear=false)` | 沿朝向加速；可选到点回收 + 消散 |
| `homing(speed, turn, target_mode=0, speed_end=0, speed_ramp=0, turn_ramp=0, dist_weight=0, steer_until=0)` | 追踪 / 最近敌人 / 速度插值 |
| `bounce_emit(template, child_speed=0, accel=0, angle=0, despawn=true, reflect=false)` | 撞墙换弹 / 镜面反射 |
| `split_after(template_a, template_b, duration, accel, chance, child_speed=0, spread=0)` | 到点概率分裂 |
| `seed_burst(template, duration, speed, count, child_speed, spread)` | 到点炸一圈 |
| `spin_accel(spin, accel)` | 自转 + 沿朝向加速 |
| `anchor_drift(angle, speed, initial=0, render_heading=true)` | 锚定节点漂移（激光） |

`EmitTemplate` 在内容层注册后，behavior 只引用 `numeric_id`；模板对象永不进 C++。

## 6. 预览

`DanmakuStore.preview_behavior()` 用同一份 pack 的 `tick` 在临时 state 上跑 N 帧，返回位置折线。
`ctx.telegraph` 的 `BehaviorPreview` 直接调用它，所以预览与实战不会分叉。
没有 behavior 的弹走直线兜底；预览不生成真弹、不消耗游戏 RNG。

## 7. 测试

- `test_native_behaviors.gd`：逐帧语义（lifetime / reflect / homing / anchor）。
- `test_behavior_preview.gd`：预览路径与停止条件。
- 卡片形状测试（如 `test_probe_descriptor.gd`）只锁 behavior id / 关键参数，不锁具体数值。

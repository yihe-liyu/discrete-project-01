# 一颗弹幕的完整路径（内容 → 原生内核 → 渲染）

> 口径：**宿主（GDScript）负责内容 / 规则 / 渲染；内核（原生 `DanmakuStore`）负责存储 / 积分 / 行为 / 判定几何。**
> 行号会漂，**以函数名为准**。配套：`docs/GDEXTENSION_KERNEL_DESIGN.md`、`docs/ARCHITECTURE.md`、`docs/DANMAKU_API.md`。

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
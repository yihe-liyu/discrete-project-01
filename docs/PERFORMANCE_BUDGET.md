# 性能预算

> 预算单位：60 Hz 帧预算 **16.67 ms**。本文件只声明可测上限与判据；GPU / overdraw 未实测前不得写成“已满足 60fps”。

## CPU（headless，仅脚本侧热路径）

测量命令：

```bash
godot --headless --path . res://tools/bench_danmaku.tscn
# 门禁（超预算退出码 1）
godot --headless --path . res://tools/bench_danmaku.tscn -- --assert
```

测量内容：

```text
内核积分 + 原生 behavior_tick
+ 原生宽相 query_circle
+ GDScript 快照 + MultiMesh 同步
```

不含 GPU 绘制。

| 弹数档 | CPU 上限 | 2026-11-14 实测 total（含渲染同步） | 余量 | 判定 |
|---:|---:|---:|---:|---|
| 8,000 | 3.0 ms | 2.09–2.16 ms | +0.84 ~ +0.91 ms | PASS |
| 20,000 | 6.0 ms | 5.57–5.64 ms | +0.36 ~ +0.43 ms | PASS |
| 50,000 | 13.0 ms | 13.81–14.05 ms | −0.81 ~ −1.05 ms | **OVER** |

两轮实测的拆分（同一台机器，debug 扩展）：

```text
8,000   积分+行为 0.53–0.58 / 宽相 0.02 / 渲染同步 1.54–1.56
20,000  积分+行为 1.41–1.43 / 宽相 0.05 / 渲染同步 4.11–4.15
50,000  积分+行为 3.50–3.73 / 宽相 0.13 / 渲染同步 10.18–10.20
```

当前瓶颈是 **CPU 渲染同步**（`BulletMultiMesh._sync_native` → 原生 group/fill → MultiMesh），不是积分或 behavior。
50,000 档已超过 13.0 ms 上限，`bench --assert` 会红；在优化渲染同步或重新评估该档预算之前，不把它写成 PASS。

判定规则：

```text
CPU 合计 > 该档上限 → bench --assert 退出码 1
未列入的档位：默认 fail-closed（不允许悄悄扩量）
```

机器与日期：2026-11-14，开发机 headless，Godot 4.7.2（debug 扩展）；换机器/换构建后必须重测。

## GPU

当前**没有可复现的 GPU 计时**；`background_capture` 的测量也不能代表主视口。

暂定目标（仅设计预算，不算达成）：

```text
Stage04 background GPU ≤ 8.0 ms
主视口 GPU ≤ 4.0 ms
```

在接入 GPU timestamp / 实机 3 张最高密度卡之前，状态是 **未验证**，不能写“满载 60fps 已成立”。

## Overdraw

暂定上限：

```text
平均 ≤ 8×
峰值 ≤ 20×
```

当前没有 overdraw 热力图或统计工具，状态 **未验证**；开 HDR/bloom 前必须先测。

## 判定边界

- CPU 预算只覆盖 headless 脚本侧；GPU 不计。
- 任何“预算通过”都必须带机器、日期、命令。
- 任何一项 `未验证`，都不能把整体性能标成“已达标”。

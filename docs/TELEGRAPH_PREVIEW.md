# 路径预览（实验）

## 定位

这是 Boss「看见未来」的演出能力候选，不是 STG 核心机制，也不是玩家默认能力。

当前状态：

- 内容可选开启
- 只在少数内容上试验
- 不进入普通敌弹默认表现

## 现在能做什么

- 每颗真实弹按稳定 uid 跟踪
- 从当前弹位置裁出剩余路径
- `emit` 子代按 lifecycle 过滤后跟踪
- 路径在敌弹图层之下
- MultiMesh 合批 + shader 外发光
- 路径时长可配置

## 明确不做的

- 不模拟 `steer` / 目标相关转向
- 不模拟 `emit` 的子代子代（除非再次注册 lifecycle）
- 不保证真实弹提前死亡时路径立刻消失
- 不做玩家通用能力

## 关键边界

| 项目 | 当前行为 |
|---|---|
| 路径生成 | phase 起点一次生成 |
| 默认上限 | 12 秒，可配置 |
| 更新 | 每 tick 裁前缀，不重算 chain |
| 身份 | 稳定 uid，不随 swap-remove 跳 |
| 图层 | 低于敌弹 |
| 性能 | MultiMesh 一次 draw，RDP 简化 |

## 何时升级为「作品特色」

至少满足：

1. 有一张完整 Boss 卡把它作为固定演出
2. 不只出现在调试 / 临时探针里
3. 玩家能感知到「看见未来」的叙事意义

在那之前，它应记录为实验能力，不写成宣传卖点。

## 相关文档

- API 与用法：`docs/DANMAKU_API.md` §3.12
- 测试：`test/test_lifecycle_preview.gd`、`test/test_telegraph_path.gd`、`test/test_telegraph_service.gd`

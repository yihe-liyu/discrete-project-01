extends CoroutineScript
## 往返探测弹 v2（匀减速滑行版）
## 青弹以初速发射，加速度恒为 -decel（沿初方向反向）：减速滑行到停 → 反向加速飞回 →
## 沿初方向位移过零（回到生成位置）→ 分裂 90° 红弹 → 自身消失。
##
## **暂无内核端口**：旧池协程体（`_tick` / `_spawn_split`）已随删旧池移除；
## 内核等价物（减速往返 + 分裂）尚未实现，见 `docs/archive/NEW_KERNEL_REFACTOR_PLAN.md`「本轮不做」。
## 当前挂到 `BulletData.coroutine_script` 时按**未映射**处理（直线发射并计数）。

var decel: float = 150.0     # 反向加速度（px/s²）：越大滑行越短、往返越快
var split_speed: float = 60.0    # 分裂弹初速（慢，配合缓慢加速出屏）
var split_accel: float = 40.0    # 分裂弹加速度（缓慢加速）
var split_dir: Array = [TAU/4, TAU/8, TAU/12, TAU/20]      # 分裂方向：相对初方向旋转角度
var split_aim_chance: float = 0.1 # 分裂弹 10% 变自机狙
var hold_aim_probe: bool = false  # 由发射方注入（orbit_spiral hold 阶段 + H/L 才为 true）

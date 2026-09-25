extends CoroutineScript
## 组合台「参数面板」夹具敌人脚本：覆盖 float / int / Vector2 / Color 四类可调 + 零值提醒。
## **不承担行为** —— 只为让面板「枚举 / 默认值 / 收集」有稳定输入。
## 用它的理由：内容是会改名/重写的东西，机制测试不该跟着红（契约见 docs/TEST_INDEX.md「内容绑定契约」）。

var target_y: float = 300.0
var rate: int = 1
var target_pos: Vector2 = Vector2.ZERO   # (0,0) 陷阱：面板应给橙色提醒
var bullet_color: Color = Color.RED
var start_time: float = 2.0

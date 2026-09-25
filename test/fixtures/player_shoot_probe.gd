extends PlayerShootScript
## 夹具机体射击脚本：满足 `Player._init_shoot_script` 的 `is PlayerShootScript` 断言，
## 但**不发射任何东西**（基类默认 `_main_shoot` / `_option_shoot` 返回 0，且未按射击键时 `_main_step` 直接返回）。
## 用它的理由：移动 / 换机体 / 碰撞这些**机制**测试不需要真弹幕 —— 也就不该绑内容射击脚本。

class_name BackgroundCameraHome
extends RefCounted
## 背景相机初始姿态的**唯一来源**。
##
## 使用方：
##   - `StageBackground._own_camera()`：背景自建相机（宿主没放相机 / 删掉宿主相机后的默认路径）
##   - `StageBackground` 的 `camera_home_*` 默认值（未开 `override_camera_home` 时就是这套）
##   - `tools/background_capture.gd`：抓图工具必须与真游戏同构图
##
## ⚠️ `.tscn` 里的 Camera3D 节点无法引用脚本常量；两个宿主场景已移除冗余相机，
##    由 `StageBackground` 在入树时按这套常量创建 ⇒ 不再有第 3、4 份字面量。

const POSITION := Vector3(0.0, 10.0, 6.0)
const ROTATION_DEGREES := Vector3(-30.0, 0.0, 0.0)
const FOV := 90.0

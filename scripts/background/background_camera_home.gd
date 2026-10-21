## 背景相机初始姿态的唯一来源。
##
## 使用方：
##   - [code]StageBackground._own_camera()[/code]：背景自建相机（宿主没放相机 / 删掉宿主相机后的默认路径）
##   - [code]StageBackground[/code] 的 [code]camera_home_*[/code] 默认值（未开 [code]override_camera_home[/code] 时就是这套）
##   - [code]tools/background_capture.gd[/code]：抓图工具必须与真游戏同构图
##
## [code].tscn[/code] 里的 Camera3D 节点无法引用脚本常量；两个宿主场景已移除冗余相机，
##    由 [code]StageBackground[/code] 在入树时按这套常量创建 ⇒ 不再有第 3、4 份字面量。
class_name BackgroundCameraHome
extends RefCounted

const POSITION := Vector3(0.0, 10.0, 6.0)
const ROTATION_DEGREES := Vector3(-30.0, 0.0, 0.0)
const FOV := 90.0

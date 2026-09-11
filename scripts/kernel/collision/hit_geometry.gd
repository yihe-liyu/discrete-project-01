## 弹判定几何的唯一实现（圆-圆 / 圆-旋转矩形）。纯静态、无状态。
## BulletSystem.hit_test（窄相位）与 query_circle 的矩形分支都走这里；圆-圆在查询热路径上另有一份内联展开。
## 矩形 = 以判定中心为中心、按弹朝向旋转、尺寸 hitbox_size 的 OBB（宽×高，弹本地坐标）。
class_name HitGeometry
extends RefCounted


## 圆(center, radius) 是否与圆(other_center, other_radius)相交；radius = 0 即点测试。
static func circle_hits_circle(center: Vector2, radius: float, other_center: Vector2, other_radius: float) -> bool:
	var offset: Vector2 = center - other_center
	var r: float = radius + other_radius
	return offset.length_squared() <= r * r


## 圆(center, radius) 是否与旋转矩形相交；radius = 0 即点测试。
## 做法：圆心转回矩形本地系 → 按半宽半高取最近点 → 比距离平方（免开方）。
static func circle_hits_rect(center: Vector2, radius: float, rect_center: Vector2, rot: float, size: Vector2) -> bool:
	var local: Vector2 = (center - rect_center).rotated(-rot)
	var half: Vector2 = size * 0.5
	var dx: float = maxf(0.0, absf(local.x) - half.x)
	var dy: float = maxf(0.0, absf(local.y) - half.y)
	return dx * dx + dy * dy <= radius * radius

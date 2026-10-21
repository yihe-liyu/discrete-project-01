## 激光骨架 —— 统一形态抽象（直线 / 曲线 / 程序化）
## 点数组 = 世界坐标；带弧长表，按弧长均匀采样，渲染与判定共用
class_name LaserSkeleton
extends RefCounted

## 骨架顶点（世界坐标折线）。构建后不要原地改点；改形状请重新调 from_points / from_curve / from_line。
var points: PackedVector2Array = PackedVector2Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()  # 每点累积弧长
## 骨架总弧长（由最近一次构建自动算出；采样越界时按它钳制）。
var total_length: float = 0.0


## 从世界坐标点数组构建（自动算弧长表）
func from_points(pts: PackedVector2Array) -> void:
	points = pts
	_rebuild_lengths()


## 从 Curve2D 构建（沿弧长均匀采样，段长 ≈ seg_len，任意曲线）
func from_curve(curve: Curve2D, seg_len: float = 32.0) -> void:
	var total := curve.get_baked_length()
	if total <= 0.0:
		points = PackedVector2Array()
		total_length = 0.0
		_lengths = PackedFloat32Array()
		return
	var n := maxi(2, int(ceil(total / maxf(seg_len, 1.0))))
	var pts := PackedVector2Array()
	for i in n + 1:
		pts.append(curve.sample_baked(total * float(i) / float(n)))
	from_points(pts)


## 两点直线骨架
func from_line(a: Vector2, b: Vector2) -> void:
	from_points(PackedVector2Array([a, b]))


func _rebuild_lengths() -> void:
	_lengths.resize(points.size())
	var acc := 0.0
	for i in points.size():
		if i > 0:
			acc += points[i].distance_to(points[i - 1])
		_lengths[i] = acc  # 累积弧长必须"先累加后赋值"
	total_length = acc


## 沿骨架按弧长采样（世界坐标，越界钳制）
func sample_at(dist: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var d := clampf(dist, 0.0, total_length)
	for i in range(1, points.size()):
		if _lengths[i] >= d:
			var seg_len := _lengths[i] - _lengths[i - 1]
			var t := 0.0 if seg_len <= 0.0 else (d - _lengths[i - 1]) / seg_len
			return points[i - 1].lerp(points[i], t)
	return points[points.size() - 1]


## 切线方向（单位向量，用 ±4px 差分近似）
func tangent_at(dist: float) -> Vector2:
	if points.size() < 2:
		return Vector2.UP
	var a := sample_at(maxf(0.0, dist - 4.0))
	var b := sample_at(minf(total_length, dist + 4.0))
	var v := b - a
	return v.normalized() if v.length_squared() > 0.0001 else Vector2.UP


## 骨架上的均匀采样（供渲染/判定共用；count=1 安全）
func sample_range(from_d: float, to_d: float, count: int) -> PackedVector2Array:
	var n := maxi(1, count)
	var pts := PackedVector2Array()
	pts.resize(n)
	if n == 1:
		pts[0] = sample_at(from_d)
		return pts
	for i in n:
		var d := from_d + (to_d - from_d) * float(i) / float(n - 1)
		pts[i] = sample_at(d)
	return pts

## 图集布局（内容资源，R17）：atlas 尺寸 + 「形状 key → 像素 Rect2」表。
## 数据存 data/atlas/*.tres，改布局不必动代码；key 是**内容槽**（可中文），只被 `bullet_configs` 的 `shape` 引用。
## ATTENTION: atlas_size 必须与贴图实际尺寸一致——换图/重排后忘了改，UV 会整片错位且不报错（test_atlas_layout 是哨兵）。
## @tool：@tool 查看器/弹型在编辑器里要调这里的**实例方法**（非 @tool → placeholder instance 报错）。
@tool
class_name AtlasLayout
extends Resource

## 图集贴图实际尺寸（像素）；uv_rect() 用它归一化。
## **默认 ZERO = 未配置**：必须由 .tres 显式给（否则资源会因"等于默认"而不写盘，尺寸又藏回代码）。
@export var atlas_size: Vector2 = Vector2.ZERO
## 形状 key → 像素矩形。
@export var shapes: Dictionary = {}


## 是否有该 key。
func has_shape(key: StringName) -> bool:
	return shapes.has(key)


## 该格的像素矩形；未定义 → 空 + 告警。
func pixel_rect(key: StringName) -> Rect2:
	if not shapes.has(key):
		push_warning("AtlasLayout: 未定义形状 key=%s" % key)
		return Rect2()
	return shapes[key]


## 归一化 UV（0..1），渲染器取格用。atlas_size 未配置 → 空 + 告警（防除零）。
func uv_rect(key: StringName) -> Rect2:
	if atlas_size.x <= 0.0 or atlas_size.y <= 0.0:
		push_warning("AtlasLayout: atlas_size 未配置（应为贴图实际尺寸）")
		return Rect2()
	var r: Rect2 = pixel_rect(key)
	return Rect2(r.position / atlas_size, r.size / atlas_size)


## 全部形状 key（工具/查看器遍历用）。
func shape_keys() -> Array:
	return shapes.keys()

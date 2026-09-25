## 弹幕图集访问点（机制层）：布局在 data/atlas/bullet_shapes.tres，贴图在 assets/Textures/bullet/bullet.png。
## 只服务机制层（渲染插座 / 查看器 / 测试）；数据资源不自己解析 UV（避免「数据依赖全局」）。
## ATTENTION: 换图/重排后改资源里的 atlas_size 与 Rect2；test_atlas_layout 是"数据与素材脱节"的哨兵。
## @tool：@tool 查看器/弹型在编辑器里会经这里调 AtlasLayout 的实例方法（非 @tool → placeholder instance 报错）。
@tool
class_name BulletShapes

## 弹幕图集布局资源（唯一来源）。
const BULLET_ATLAS: AtlasLayout = preload("res://data/atlas/bullet_shapes.tres")
## 图集贴图本体（1024²，与 BULLET_ATLAS.atlas_size 必须一致）。
const BULLET_ATLAS_TEXTURE: Texture2D = preload("res://assets/Textures/bullet/bullet.png")

## 形状 key → AtlasTexture 缓存（同 key 复用同一实例，供渲染插座按 1 格 = 1 纹理取用）。
static var _tex_cache: Dictionary = {}


## 该格的像素矩形；未定义 → 空 + 告警。
static func pixel_rect(key: StringName) -> Rect2:
	return BULLET_ATLAS.pixel_rect(key)


## 归一化 UV（0..1）。
static func uv_rect(key: StringName) -> Rect2:
	return BULLET_ATLAS.uv_rect(key)


## 该格的 AtlasTexture（图集 + region）；未定义 key → 空 region（渲染为 0 尺寸）。
static func atlas_texture(key: StringName) -> AtlasTexture:
	if _tex_cache.has(key):
		return _tex_cache[key]
	var t := AtlasTexture.new()
	t.atlas = BULLET_ATLAS_TEXTURE
	t.region = pixel_rect(key)
	_tex_cache[key] = t
	return t

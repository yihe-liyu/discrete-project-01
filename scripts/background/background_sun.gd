class_name BackgroundSun
extends Node3D

## 日食太阳组件。**可见部分全部场景声明**（2026-10-04）：
##   Sun（本节点 Node3D —— **位置就是太阳位置**，编辑器里直接拖）
##   └── SunSprite（Sprite3D，billboard）+ 圆盘纹理 + ShaderMaterial(sun_sprite.gdshader)
## 参数在 Inspector 里调（节点位置 / `pixel_size` / 材质 `shader_parameter/*`）。
##
## ⚠️ **声明即显示**：没有 `setup()`，也不需要任何人调用。
## 旧实现（`setup()` 里 `Sprite3D.new()` + 运行时 `load()` 纹理 + `_ready` 藏起来等调用）
## 有两个后果：① 编辑器里**空白**（无纹理的 Sprite3D 什么都不画）⇒ 连"把太阳拖进画面"都做不到；
## ② **忘了调 `setup()` 就永远隐形、且零报错** —— stage02 2026-10-04 实况（作者摆好了节点却看不见）。
## 教训：**别把"显示"绑在"记得调用"上**（练习模式要不要它也定了：要）。
## ⚠️ `SunSprite` 是子节点 ⇒ 它的**局部位移叠加**在本节点上（两处都能摆，合并即最终位置）。

@export var texture_size: int = 256      ## **仅预生成工具用**（运行时纹理在场景里，见文件头）

@onready var sprite: Sprite3D = get_node_or_null("SunSprite") as Sprite3D


func _ready() -> void:
	if sprite == null:
		push_error("BackgroundSun: 场景里没声明 SunSprite —— 太阳不会出现（见本文件头）")


## **被画出来的**太阳位置 = `SunSprite` 的全局位置。
## ⚠️ 与 `global_position`（本节点）**可能不同**：`SunSprite` 带自己的局部位移，而在编辑器里
## 拖得动的正是那个 sprite。**要对准太阳的地方（如蒙眼雾的太阳雾团/亮环）必须用这个** ——
## 2026-10-04 作者实测：「一改太阳的 y 坐标，黑雾的对准就不准了」（旧实现投影的是本节点）。
func drawn_position() -> Vector3:
	if sprite and is_instance_valid(sprite):
		return sprite.global_position
	return global_position


## 规则圆太阳纹理：中心亮暖白、边缘柔和、外圈光晕——干净的正圆（黑雾层负责遮）
## 供预生成工具 tools/regenerate_fog_tex.gd 使用
func _make_sun_disc(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var p := Vector2((x + 0.5) / size, (y + 0.5) / size) - Vector2(0.5, 0.5)
			var d: float = p.length() * 2.0
			var disc: float = 1.0 - smoothstep(0.40, 0.48, d)      # 规则圆盘
			var glow: float = exp(-max(d - 0.46, 0.0) * 6.0) * 0.5  # 外圈光晕
			var c := Color(1.0, 0.96, 0.84) * (0.45 + 0.55 * disc) + Color(1.0, 0.85, 0.55) * glow
			var a: float = clampf(disc + glow, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	return img

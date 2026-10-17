extends SceneTree
## 蒙眼雾/太阳纹理预生成工具（一次性脚本）
## 用法: godot --headless --path . -s tools/regenerate_fog_tex.gd
## 改 `ScreenFogFX.texture_size`/`texture_contrast` 或 `BackgroundSun.texture_size` 后重跑本脚本
## ⚠️ 本脚本**读的就是那两个 `@export`**（2026-10-04 修）：此前它们写死在参数里，
##    于是上面那句是**假的** —— 改 `@export` 完全不影响产物。
## ⚠️ 存的是 **`ImageTexture`**（不是裸 `Image`）：这样 `.tscn` 能把它当 `ExtResource` 直接引用
##    ⇒ **编辑器里就看得见**雾/太阳。裸 `Image` 只能运行时 `create_from_image()`，编辑器里是白的。

const CLOUD_PATH := "res://assets/Textures/background/stage01/cloud_noise.tres"
const DISC_PATH := "res://assets/Textures/background/stage01/sun_disc.tres"

func _init() -> void:
	var fx := ScreenFogFX.new()
	var img: Image = fx._make_cloud_image(fx.texture_size, fx.texture_contrast)
	var err := ResourceSaver.save(ImageTexture.create_from_image(img), CLOUD_PATH)
	print("cloud_noise.tres saved: err=", err, "（", fx.texture_size, "², 对比度 ", fx.texture_contrast, "）")

	var sun := BackgroundSun.new()
	var disc: Image = sun._make_sun_disc(sun.texture_size)
	err = ResourceSaver.save(ImageTexture.create_from_image(disc), DISC_PATH)
	print("sun_disc.tres saved: err=", err, "（", sun.texture_size, "²）")
	fx.free()    # 未入树的 Node 要手动释放，否则退出时报 "instances were leaked"
	sun.free()
	quit(0)

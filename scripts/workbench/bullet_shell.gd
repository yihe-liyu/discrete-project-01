class_name BulletShell
extends RefCounted
## 弹幕试验台 —— 子弹"壳"（临时试验道具，不落盘）。
## 对应 BulletData 的"外形侧"；贴图 ≡ 判定（AssetRegistry 一站式提供）。
## 魂（行为脚本）由组合台选择，二者独立组合。

## 方位下标 → 方向（0=下，顺时针 8 方位）
## 注：Godot 2D 正角度=视觉顺时针（Y 向下坐标系），故取负角使 0=下→1=右下→2=右…
const DIR_ANGLES: Array[float] = [
	-TAU / 8.0 * 0.0,
	-TAU / 8.0 * 1.0,
	-TAU / 8.0 * 2.0,
	-TAU / 8.0 * 3.0,
	-TAU / 8.0 * 4.0,
	-TAU / 8.0 * 5.0,
	-TAU / 8.0 * 6.0,
	-TAU / 8.0 * 7.0,
]

var tex_key: String = "小玉"
var tint: Color = Color.WHITE
var blend: bool = false          ## 加色混合（视觉效果：弹幕质感差异大）
var speed: float = 300.0         ## 初速 px/s
var dir_index: int = 0           ## 0=下 1=右下 2=右 …（顺时针）

const DIR_LABELS: Array[String] = ["下", "右下", "右", "右上", "上", "左上", "左", "左下"]


## 组装 BulletData（外形侧 + 可选行为脚本）
## 贴图≡判定：enemy() 不覆盖 hitbox（引擎现行为）→ tex 配置的判定/偏移生效，
## 与游戏内敌弹一致（测试锁定 6.0）
func build(behavior_script: Script = null) -> BulletData:
	var d := BulletData.new()
	d.tex(tex_key)               # 贴图 + 判定 + 偏移 一体
	d.color(tint)
	d.blend(blend)
	d.speed(speed)
	d.enemy()
	if behavior_script:
		d.behavior(behavior_script)
	return d


## 当前方位向量
func get_dir() -> Vector2:
	return Vector2.DOWN.rotated(DIR_ANGLES[dir_index])
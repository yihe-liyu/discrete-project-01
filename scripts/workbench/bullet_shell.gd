class_name BulletShell
extends RefCounted
## 弹幕试验台 —— 子弹"壳"（临时试验道具，不落盘）。
## 对应 BulletData 的"外形侧"；贴图 ≡ 判定（AssetRegistry 一站式提供）。
## 魂（行为脚本）由组合台选择，二者独立组合。

## 8 方位预设（顺时针：下→右下→右→右上→上→左上→左→左下）
## 注：const 数组必须是常量表达式 → 用函数返回（normalized() 不能进 const）
const DIR_NAMES: Array[String] = ["下", "右下", "右", "右上", "上", "左上", "左", "左下"]


static func preset(idx: int) -> Vector2:
	return Vector2.DOWN.rotated(-deg_to_rad(float(idx) * 45.0))

var tex_key: String = "小玉"
var tint: Color = Color.WHITE
var blend: bool = false          ## 加色混合（视觉效果：弹幕质感差异大）
var speed: float = 300.0         ## 初速 px/s
var dir: Vector2 = Vector2.DOWN  ## 发射方向（自由角度；右键场地设指向 / 8 方位预设快捷）


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


## 当前发射方向向量
func get_dir() -> Vector2:
	return dir


## 方位显示名：最接近的 8 方位名；非正方位加"自选"前缀
static func dir_name(v: Vector2) -> String:
	if v.length() < 0.001:
		return "（未设）"
	var best := 0
	var best_dot := -2.0
	for i in DIR_NAMES.size():
		var d: float = dir_dot(v, preset(i))
		if d > best_dot:
			best_dot = d
			best = i
	var exact := best_dot > 0.999
	return DIR_NAMES[best] if exact else "自选·" + DIR_NAMES[best]


static func dir_dot(a: Vector2, b: Vector2) -> float:
	return a.normalized().dot(b.normalized())


## 角度（自"下"顺时针，0~360，用于面板显示）
static func angle_text(v: Vector2) -> String:
	if v.length() < 0.001:
		return "—"
	# angle_to 是数学符号（逆时针正）→ 翻转成"自下顺时针"（视觉方向）
	var a := rad_to_deg(Vector2.DOWN.angle_to(v))
	if a < 0.0:
		a += 360.0
	a = fmod(360.0 - a, 360.0)
	return "%d°" % roundi(a)
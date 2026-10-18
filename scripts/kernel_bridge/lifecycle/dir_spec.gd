class_name DirSpec
extends RefCounted
## 方向表达式词汇与静态构造器。
##
## 现仍是 Dictionary schema（DSL1 的类型化是下一步），但**词汇/构造/求值语义**集中在这里；
## BulletLifecycle 只保留同名静态方法做兼容别名，运行时（原生 / 参考解释器）按 kind 分发。

const HEADING := &"heading"
const TOWARD := &"toward"
const AWAY := &"away"
const FORWARD := &"forward"
const RANDOM := &"random"
const CHANCE := &"chance"
## 镜面：把当前速度按发射点所在场边翻分量（左右翻 x / 上翻 y；角落两边都翻）。
const REFLECT := &"reflect"


## 世界角：0 = 上，正 = 顺时针（屏幕 y 向下）。结果 = (sin a, -cos a)。
static func heading(angle: float) -> Dictionary:
	return {&"kind": HEADING, &"target": &"", &"angle": angle}


## 朝 target 方向再转 angle。**target 不可用时退化为向下 (0,1)** 再转 angle。
static func toward(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": TOWARD, &"target": target, &"angle": angle}


## 背对 target 再转 angle（逃离 / 回卷）。
static func away(target: StringName, angle: float = 0.0) -> Dictionary:
	return {&"kind": AWAY, &"target": target, &"angle": angle}


## 沿弹**自身朝向**（出生朝向 / set_heading 改过的）再转 angle；与 heading(世界角) 正交。
static func forward(angle: float = 0.0) -> Dictionary:
	return {&"kind": FORWARD, &"target": &"", &"angle": angle}


## 沿自身朝向 ± spread 内**随机**（内核确定性 RNG，单通道；种子由宿主 RNG 派生）。
static func random_dir(spread: float) -> Dictionary:
	return {&"kind": RANDOM, &"target": &"", &"angle": spread}


## 以概率 p 朝 target，否则沿自身朝向再转 spread。
## **命中时精确朝 target，spread 只服务未命中的 fallback。**
## 也是 emit_variant 唯一的分支来源（0 = 未命中，1 = 命中）。
static func chance_toward(target: StringName, p: float, spread: float = 0.0) -> Dictionary:
	return {&"kind": CHANCE, &"target": target, &"angle": spread, &"p": p}


## **镜面反射**：把弹的**当前速度**按发射点所在的场边翻分量 —— 左右边翻 x、上边翻 y，
## 角落（pos 同时贴两条边）两边都翻 = 原路返回；再叠加 `angle`（可选，用来做"镜面 + 微散"）。
##
## ⚠️ 必须配 `at = AT_PHASE_END`：镜面判据是**发射点**贴没贴场边，而 `at_wall` 不改弹自身位置，
## 只有它的相位结束落点（夹紧到边上）才算"撞到了"。用 `AT_CURRENT` 且没贴边 → 不翻，退化为自身朝向。
static func reflect(angle: float = 0.0) -> Dictionary:
	return {&"kind": REFLECT, &"target": &"", &"angle": angle}


## 该 kind 是否必须有 target（编译期与工作台提示共用）。
static func requires_target(kind: StringName) -> bool:
	return kind == TOWARD or kind == AWAY or kind == CHANCE

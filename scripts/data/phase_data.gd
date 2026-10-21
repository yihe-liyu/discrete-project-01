# PhaseData.gd
## 一个战斗阶段（非符/符卡）的配置：血量、时限、脚本、掉落
extends Resource
class_name PhaseData

const PARAM_VALIDATOR_SCRIPT = preload("res://scripts/data/param_validator.gd")

## 符卡名（空串=非符）
@export var name: String = ""
## 全局唯一符卡编号，0=非符不记
@export var uid: int = 0
## 时限（秒）
@export var time_limit: float = 30.0
## 血量
@export var hp: int = 4000
## 时符
@export var is_timeout_only: bool = false
## Boss 移动协程脚本（[code]CoroutineScript[/code]）：宣言后与 [code]shoot_script[/code] 同时实例化启动。
## 空 = 本阶段不移动（Boss 保持原位）。
@export var move_script: Script
## Boss 弹幕协程脚本（[code]CoroutineScript[/code]）：宣言后与 [code]move_script[/code] 同时启动。
## 空 = 本阶段无弹幕（纯演出 / 纯走位阶段允许）。
@export var shoot_script: Script
## 发动前走位：符卡宣言（报幕 / [code]card[/code] 音效 / 符卡背景）之前跑完的移动脚本。
## 用来做「先走到位、再发表宣言」的演出；空 = 不等待，宣言立即发生。
## 它会推迟宣言：脚本不结束这张卡就不会发动 —— 别写死循环。
@export var pre_move_script: Script
## 击破掉落 P 点
@export var item_power: int = 0
## 击破掉落蓝点
@export var item_point: int = 0
## 击破掉落残机碎片
@export var item_life: int = 0
## 击破掉落 Bomb 碎片
@export var item_bomb: int = 0
## 击破掉落整残
@export var item_life_full: int = 0
## 击破掉落整 B
@export var item_bomb_full: int = 0
## 移动/弹幕脚本参数（工作台编辑，运行时注入脚本同名属性）
@export var params: Dictionary = {}
## 开局减伤时长（秒；0 = 关闭）。阶段开始后这段时间内受伤害减免
@export var open_reduce_time: float = 3.0
## 开局减伤比例（0~1；0.9 = 只受 10% 伤害）
@export var open_reduce_ratio: float = 0.9


## 配置校验：返回错误列表（空 = 合法）。加载/开战前调用，防除零
## 注意：不校验脚本类型（纯移动/演示阶段可能无脚本，属合法）
## [code]params[/code]：按 pre_move/move/shoot 三脚本属性并集校验未知键（同名键仍会互相干扰，见 CONTENT_GUIDE §四）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if time_limit <= 0.0:
		errs.append("PhaseData[%s].time_limit = %s 必须 > 0（会除零/立即超时）" % [name, time_limit])
	if hp <= 0:
		errs.append("PhaseData[%s].hp = %s 必须 > 0" % [name, hp])
	if not params.is_empty():
		var param_scripts: Array = []
		for param_script in [pre_move_script, move_script, shoot_script]:
			if param_script != null:
				param_scripts.append(param_script)
		for warning in PARAM_VALIDATOR_SCRIPT.validate_unknown_keys_union(param_scripts, params):
			errs.append("PhaseData[%s].params: %s" % [name, warning])
	return errs

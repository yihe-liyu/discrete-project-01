# PhaseData.gd
## 一个战斗阶段（非符/符卡）的配置：血量、时限、脚本、掉落
extends Resource
class_name PhaseData

@export var name: String = ""            ## 符卡名（空串=非符）
@export var uid: int = 0                  ## 全局唯一符卡编号，0=非符不记
@export var time_limit: float = 30.0     ## 时限（秒）
@export var hp: int = 4000               ## 血量
@export var is_timeout_only: bool = false ## 时符
@export var move_script: Script
@export var shoot_script: Script
## **发动前走位**：符卡宣言（报幕 / `card` 音效 / 符卡背景）**之前**跑完的移动脚本。
## 用来做「先走到位、再发表宣言」的演出；空 = 不等待，宣言立即发生。
## ⚠️ 它会**推迟宣言**：脚本不结束这张卡就不会发动 —— 别写死循环。
@export var pre_move_script: Script
@export var background: PackedScene      ## 可选换背景
@export var item_power: int = 0         ## 击破掉落 P 点
@export var item_point: int = 0         ## 击破掉落蓝点
@export var item_life: int = 0          ## 击破掉落残机碎片
@export var item_bomb: int = 0          ## 击破掉落 Bomb 碎片
@export var item_life_full: int = 0     ## 击破掉落整残
@export var item_bomb_full: int = 0     ## 击破掉落整 B
## 移动/弹幕脚本参数（工作台编辑，运行时注入脚本同名属性）
@export var params: Dictionary = {}
@export var open_reduce_time: float = 3.0  ## 开局减伤时长（秒；0 = 关闭）。阶段开始后这段时间内受伤害减免
@export var open_reduce_ratio: float = 0.9 ## 开局减伤比例（0~1；0.9 = 只受 10% 伤害）


## 配置校验：返回错误列表（空 = 合法）。加载/开战前调用，防除零
## 注意：不校验脚本（纯移动/演示阶段可能无脚本，属合法）
func validate() -> Array[String]:
	var errs: Array[String] = []
	if time_limit <= 0.0:
		errs.append("PhaseData[%s].time_limit = %s 必须 > 0（会除零/立即超时）" % [name, time_limit])
	if hp <= 0:
		errs.append("PhaseData[%s].hp = %s 必须 > 0" % [name, hp])
	return errs

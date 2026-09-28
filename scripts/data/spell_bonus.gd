class_name SpellBonus
extends RefCounted

## 符卡奖励分（bonus）规则 —— **唯一 owner**（内容不再手填，见 `PhaseData`）。
##
## 东方原作口径 + 本作定调（作者 2026-09-26 实测 + 多轮核对）：
## - **初始值** = **难度权重 × 面序号 × 500,000**（乘法，不是加法）。
##   难度权重：**E/N/H/L = 1/2/3/4，EX = 2**（Extra 单独破例）；面序号 1..6 / EX 面 = **7**。
##   → 例：1 面 Easy = 1×1 = 50 万、1 面 Normal = 2×1 = 100 万、3 面 Lunatic = 4×3 = 600 万、
##     6 面 Lunatic = 4×6 = 1,200 万、EX 面 = 2×7 = 700 万。
## - **只有符卡有奖励分**（`PhaseData.uid != 0`）；非符一律 0（原作非符不报奖励分、不计这笔分）。
## - **衰减**：非时符在**时限内均匀（线性）衰减到初始值的 30%** —— 走满时限正好落 30%，故速率
##   = (初始 − 30%) / `time_limit`，**不是固定值**（时长不同、卡不同，速率就不同）。
##   **时符（`PhaseData.is_timeout_only`）完全不衰减**。
##
## ⚠️ 面序号 ≠ 记录主键 `StageData.stage_id`：后者为存档唯一会把 3B 面取 4、EX 取 9，
## 而奖励分要的是 3A/3B 都算 3、EX 算 7 → 取自 `StageData.stage_no`。

## 初始值倍率：公式里 1 点 = 50 万。
const INITIAL_UNIT: int = 500000
## 衰减下限比例：最多衰减到初始奖励分的 30%（走满时限正好到这）。
const DECAY_FLOOR_RATIO: float = 0.3


## 难度权重：E/N/H/L = 1/2/3/4；**EX = 2**（`SpellRecord.Difficulty` 是 0 基枚举）。
## EX 单独破例是原作口径：Extra 面不吃「第 5 档」加成（否则 EX 会乘出离谱的大数字）。
static func difficulty_weight(difficulty: int) -> int:
	if difficulty == SpellRecord.Difficulty.EXTRA:
		return 2
	return difficulty + 1


## 符卡初始奖励分 = 难度权重 × 面序号 × 50 万；非符（`p_is_spell == false`）→ 0。
## 面序号非法（<= 0，如没挂面的合成 Boss）→ 0：没有面就没有奖励分，别凭空造。
static func initial(stage_no: int, difficulty: int, p_is_spell: bool = true) -> int:
	if not p_is_spell or stage_no <= 0:
		return 0
	return difficulty_weight(difficulty) * stage_no * INITIAL_UNIT


## 衰减下限 = 初始奖励分 × 30%。
static func decay_floor(initial_bonus: int) -> int:
	return int(initial_bonus * DECAY_FLOOR_RATIO)


## 每秒衰减量：把「初始 → 30%」在**时限内均匀**走完（线性）。
## 时符不衰减；`time_limit` 非法（<= 0）→ 0（防除零）。
static func decay_per_second(initial_bonus: int, time_limit: float, is_timeout_only: bool) -> float:
	if is_timeout_only or time_limit <= 0.0:
		return 0.0
	return float(initial_bonus - decay_floor(initial_bonus)) / time_limit


## 一帧的衰减量：时符 / 非法时限 → 0；否则按速率算，至少 1（防小 delta 卡住）。
static func decay_tick(delta: float, initial_bonus: int, time_limit: float, is_timeout_only: bool) -> int:
	var rate := decay_per_second(initial_bonus, time_limit, is_timeout_only)
	if rate <= 0.0:
		return 0
	return maxi(1, int(rate * delta))


## 一帧之后的奖励分（Boss 直接用它）：
## 时符 → 原样不动；非时符 → 按时限均匀衰减，且**不低于初始值的 30%**（浮点截断的兜底）。
static func decayed(current: int, initial_bonus: int, time_limit: float, delta: float,
		is_timeout_only: bool) -> int:
	if is_timeout_only:
		return current
	return maxi(decay_floor(initial_bonus),
		current - decay_tick(delta, initial_bonus, time_limit, is_timeout_only))

extends RefCounted
## 无头工具共享默认值（唯一来源）。
##
## 固定种子用于可复现截图 / 基准：树的位置与尺寸走 RNG，不固定种子两次跑的画面不可比。
## 改这里，不要在各工具里抄字面量（`tools/check_structure.sh` 会检查只出现一次）。

const FIXED_SEED := 20260801

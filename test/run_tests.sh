#!/usr/bin/env bash
# 一键运行全部测试（GUT）
# 用法: ./test/run_tests.sh [GUT 参数...]
#   全量:  ./test/run_tests.sh
#   单文件: ./test/run_tests.sh -gtest=res://test/test_boss_indicator.gd（约 1.4s）
#   单测试: ./test/run_tests.sh -gtest=res://test/test_x.gd -gtest_func=test_xxx
set -e
cd "$(dirname "$0")/.."

echo "═══════════════════════════════════════"
echo "  🧪 1st Touhou Star — 运行测试套件"
echo "═══════════════════════════════════════"

# 测试隔离：临时 user:// 目录（XDG_DATA_HOME 重定向，save_data.cfg 等写入不碰真实存档）
TMP_USER="$(mktemp -d)"
export XDG_DATA_HOME="$TMP_USER"
# 预建 logs 子目录：避免 godot 打不开 user://logs → SIGSEGV 崩溃出 coredump（与 check_syntax/verify 一致）
mkdir -p "$TMP_USER/logs"
# 默认扫 res://test 全量；指定了 -gtest（单文件/单测试）时不叠加默认目录
if [[ "$*" == *"-gtest"* ]]; then
	GUT_ARGS=("$@")
else
	GUT_ARGS=(-gdir=res://test "$@")
fi
# 测试是只读的：GUT 写 user:// 已被 XDG_DATA_HOME 隔离到 /tmp；res:// 不再有可变存档。
if GUT_OUT="$(godot --headless --path "$PWD" -s addons/gut/gut_cmdln.gd "${GUT_ARGS[@]}" -gexit "$@" 2>&1)"; then
	GUT_EXIT=0
else
	GUT_EXIT=$?
fi
echo "$GUT_OUT"
# 有测试脚本加载失败 → GUT 只 warning + 跳过（套件仍可能「绿」）→ 门禁必须红
if echo "$GUT_OUT" | grep -q "Failed to load script"; then
	echo "❌ 有测试脚本加载失败（被 GUT 静默跳过）"
	GUT_EXIT=1
fi
# 门禁不许「静默跳过」：GUT 对 pending/risky **不返回非 0**（不计入失败），
# 于是「其实没跑」会伪装成全绿 —— 原生测试在无扩展时会集体 pending，必须变红。
# 注：0 pending 时 GUT **不打印** Risky/Pending 行，故「该行出现」即代表有 pending。
if echo "$GUT_OUT" | grep -qE "^Risky/Pending"; then
	echo "❌ 有用例 pending/risky（GUT 对 pending 返回 0，会伪装成全绿）："
	echo "$GUT_OUT" | grep -E "^Risky/Pending"
	echo "$GUT_OUT" | grep -E "\[Pending\]" | head -5
	echo "   ↳ 若为「无扩展」：先构建 ./tools/build_gdextension.sh（README 步骤 0）；否则修好或删掉该用例。"
	GUT_EXIT=1
fi

rm -rf "$TMP_USER"

echo "═══════════════════════════════════════"

echo "  ✅ 测试结束（exit=$GUT_EXIT，记录已还原）"
echo "═══════════════════════════════════════"
exit $GUT_EXIT

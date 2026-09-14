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
# 测试是只读的：备份符卡记录，跑完恢复（测试内 unlock/record 的 save 副作用不落盘——res:// 写入不受 user 隔离影响）
RECORDS_BACKUP="$(mktemp)"
HAD_RECORDS=0
if [ -f "$PWD/data/registry/spell_records.tres" ]; then
	cp "$PWD/data/registry/spell_records.tres" "$RECORDS_BACKUP"
	HAD_RECORDS=1
fi

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

# 恢复必须在任何退出路径前执行（set -e 会因 GUT 失败中止，这里用 if 结构兜底）
if [ "$HAD_RECORDS" = "1" ]; then
	cp "$RECORDS_BACKUP" "$PWD/data/registry/spell_records.tres"
fi
rm -f "$RECORDS_BACKUP"
rm -rf "$TMP_USER"

echo "═══════════════════════════════════════"

echo "  ✅ 测试结束（exit=$GUT_EXIT，记录已还原）"
echo "═══════════════════════════════════════"
exit $GUT_EXIT

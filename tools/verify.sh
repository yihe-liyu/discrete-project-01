#!/usr/bin/env bash
# 一键验证：命名契约 + 语法 + 真实启动零错误 + GUT 全绿 + 文件所有权恢复 + git 状态
# 用法: ./tools/verify.sh [可选: 启动验证的场景]
#   默认验证 res://scenes/game_scene.tscn
#   例:  ./tools/verify.sh res://scenes/workbench.tscn
#        ./tools/verify.sh scenes/workbench.tscn
set -e
cd "$(dirname "$0")/.."

TARGET_SCENE="${1:-res://scenes/game_scene.tscn}"
if [[ "$TARGET_SCENE" != res://* ]]; then
	TARGET_SCENE="res://$TARGET_SCENE"
fi

echo "═══════════════════════════════════════"
echo "  🔧 一键验证（场景: $TARGET_SCENE）"
echo "═══════════════════════════════════════"

echo ""
echo "== [1/5] 秒级语法检查 =="
./tools/check_syntax.sh

echo ""
echo "== [2/5] 命名契约（含形参/局部/循环遮蔽成员） =="
./tools/check_naming.sh --fail

echo ""
echo "== [3/5] 真实启动验证（$TARGET_SCENE） =="
# 隔离 user://（与 run_tests.sh 一致）：启动会写 user://logs 日志，不隔离会污染真实玩家目录。
# 预建 logs 子目录：避免 godot 打不开 user://logs → SIGSEGV 崩溃出 coredump。
TMP_USER="$(mktemp -d)"
mkdir -p "$TMP_USER/logs"
START_ERR=$(XDG_DATA_HOME="$TMP_USER" godot --headless --path "$PWD" "$TARGET_SCENE" --quit 2>&1 | grep -E "SCRIPT ERROR|Compile Error|^ERROR:" | grep -vE "resources still in use|RID allocations" || true)
rm -rf "$TMP_USER"
if [ -n "$START_ERR" ]; then
	echo "❌ 启动有错误："
	echo "$START_ERR"
	exit 1
fi
echo "✅ 启动零错误"

echo ""
echo "== [4/5] GUT 全量测试 =="
if ! ./test/run_tests.sh; then
	echo "❌ GUT 测试失败"
	exit 1
fi
echo "✅ GUT 全绿"

echo ""
echo "== [5/5] 文件所有权恢复 =="
if [ "$(id -u)" = "0" ]; then
	chown -R cirno:cirno .godot/ scripts/ data/ test/ tools/ scenes/ 2>/dev/null || true
	echo "✅ 已恢复 cirno 所有权（root 运行，防污染）"
else
	echo "✅ 非 root 运行，跳过 chown"
fi

echo ""
echo "== git 状态 =="
git status --short | head -15
echo "═══════════════════════════════════════"
echo "  ✅ 验证完成"
echo "═══════════════════════════════════════"

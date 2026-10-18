#!/usr/bin/env bash
# 一键验证：文档哨兵 + 语法 + 命名契约 + 结构契约 + 真实启动零错误 + GUT 全绿 + 文件所有权恢复 + git 状态
# 用法: ./tools/verify.sh [选项] [可选: 启动验证的场景]
#   默认全量 GUT（并行分片，~15s）；--serial 串行；--fast 只跑冒烟（~8s，不全量）
#   例:  ./tools/verify.sh
#        ./tools/verify.sh --fast
#        ./tools/verify.sh --serial
#        ./tools/verify.sh --shards=4
#        ./tools/verify.sh res://scenes/workbench.tscn
set -e
cd "$(dirname "$0")/.."

FAST=0
SERIAL=0
TARGET_SCENE=""
for arg in "$@"; do
	case "$arg" in
		--fast) FAST=1 ;;
		--serial) SERIAL=1 ;;
		--shards=*) export GUT_SHARDS="${arg#*=}" ;;
		--help|-h)
			echo "用法: ./tools/verify.sh [--fast|--serial|--shards=N] [场景]"
			echo "  --fast      只跑文档/语法/命名/结构/启动 + 4 个冒烟测试（不全量，~8s）"
			echo "  --serial    全量 GUT 串行（默认按 min(nproc,8) 并行分片）"
			echo "  --shards=N  指定并行片数（<3 自动串行）"
			exit 0
			;;
		res://*|scenes/*|*.tscn) TARGET_SCENE="$arg" ;;
		*)
			echo "❌ 未知参数: $arg（--help 看用法）"
			exit 2
			;;
	esac
done
TARGET_SCENE="${TARGET_SCENE:-res://scenes/game_scene.tscn}"
if [[ "$TARGET_SCENE" != res://* ]]; then
	TARGET_SCENE="res://$TARGET_SCENE"
fi

if [ "$FAST" = 1 ]; then
	MODE="快速冒烟（不全量）"
elif [ "$SERIAL" = 1 ]; then
	MODE="全量串行"
else
	MODE="全量并行分片（GUT_SHARDS=${GUT_SHARDS:-auto}）"
fi

echo "═══════════════════════════════════════"
echo "  🔧 一键验证（场景: $TARGET_SCENE）"
echo "  GUT: $MODE"
echo "═══════════════════════════════════════"

echo ""
echo "== [1/7] 文档哨兵（文档 ↔ 代码/数据） =="
python3 ./tools/check_docs.py

echo ""
echo "== [2/7] 秒级语法检查 =="
./tools/check_syntax.sh

echo ""
echo "== [3/7] 命名契约（含形参/局部/循环遮蔽成员） =="
./tools/check_naming.sh --fail

echo ""
echo "== [4/7] 结构契约（组合台同名场景 / 测试白盒预算 / 唯一来源常量 / 舞台接线唯一） =="
./tools/check_structure.sh --fail

echo ""
echo "== [5/7] 真实启动 + 原生 API 对齐（$TARGET_SCENE） =="
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

# NK9：有原生二进制时，运行时 ClassDB 方法必须与 C++ _bind_methods 对齐。
API_USER="$(mktemp -d)"
mkdir -p "$API_USER/logs"
API_OUT=$(XDG_DATA_HOME="$API_USER" godot --headless --path "$PWD" --script res://tools/check_native_api.gd 2>&1 || true)
rm -rf "$API_USER"
if echo "$API_OUT" | grep -q "❌"; then
	echo "$API_OUT" | grep -E "❌"
	exit 1
fi
echo "$API_OUT" | grep -E "✅ 原生 API|⚠️ 未构建原生扩展" || true

echo ""
if [ "$FAST" = 1 ]; then
	echo "== [6/7] GUT 快速冒烟（--fast，不全量） =="
	SMOKE="res://test/test_data_validity.gd,res://test/test_param_validator.gd,res://test/test_lifecycle_primitives.gd,res://test/test_native_storage.gd"
	if ! ./test/run_tests.sh -gtest="$SMOKE"; then
		echo "❌ GUT 冒烟测试失败"
		exit 1
	fi
	echo "⚠️ 快速模式只跑 4 个冒烟文件；提交前请跑 ./tools/verify.sh（全量）"
else
	echo "== [6/7] GUT 全量测试 =="
	if [ "$SERIAL" = 1 ]; then
		if ! ./test/run_tests.sh; then
			echo "❌ GUT 测试失败"
			exit 1
		fi
	else
		if ! ./test/run_tests_sharded.sh; then
			echo "❌ GUT 分片测试失败"
			exit 1
		fi
	fi
fi
echo "✅ GUT 全绿"

echo ""
echo "== [7/7] 文件所有权恢复 =="
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

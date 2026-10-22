#!/usr/bin/env bash
# 内容契约检查：注册表 / 引用 / BGM / 难度变体 / 目录类型。
# 用法：./tools/check_content.sh
set -e
cd "$(dirname "$0")/.."
TMP_USER="$(mktemp -d)"
mkdir -p "$TMP_USER/logs"
set +e
XDG_DATA_HOME="$TMP_USER" godot --headless --path "$PWD" res://tools/check_content.tscn
RC=$?
set -e
rm -rf "$TMP_USER"
exit $RC

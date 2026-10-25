#!/usr/bin/env bash
# 内容预检：对话事件闭环 / 无人 Boss / 未登记 / 孤儿阶段 / 参数键。
# 用法：./tools/content_preflight.sh
set -e
cd "$(dirname "$0")/.."
TMP_USER="$(mktemp -d)"
mkdir -p "$TMP_USER/logs"
set +e
XDG_DATA_HOME="$TMP_USER" godot --headless --path "$PWD" res://tools/content_preflight.tscn
RC=$?
set -e
rm -rf "$TMP_USER"
exit $RC

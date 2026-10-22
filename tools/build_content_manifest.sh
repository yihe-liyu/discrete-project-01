#!/usr/bin/env bash
# 生成只读内容清单 JSON（user://content_manifest.json）。
# 用法：./tools/build_content_manifest.sh
set -e
cd "$(dirname "$0")/.."
TMP_USER="$(mktemp -d)"
mkdir -p "$TMP_USER/logs"
set +e
XDG_DATA_HOME="$TMP_USER" godot --headless --path "$PWD" res://tools/build_content_manifest.tscn
RC=$?
set -e
rm -rf "$TMP_USER"
exit $RC

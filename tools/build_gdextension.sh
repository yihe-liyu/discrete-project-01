#!/usr/bin/env bash
# 构建原生弹幕内核（GDExtension）。
# 首次需先拉子模块：git submodule update --init --recursive
# 用法: ./tools/build_gdextension.sh [target...]   默认 template_debug + template_release
#
# .gdextension 与 .so 都是**构建产物、不入库**：
#   没构建 → 没扩展 → 游戏照跑 GDScript（零报错）；构建了才加载原生。
set -euo pipefail
cd "$(dirname "$0")/.."

GDX="gdextension"
if [ ! -f "$GDX/godot-cpp/SConstruct" ]; then
	echo "❌ 缺少 $GDX/godot-cpp —— 先跑：git submodule update --init --recursive"
	exit 1
fi

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
	targets=(template_debug template_release)
fi

for t in "${targets[@]}"; do
	echo "== 构建 $t =="
	(cd "$GDX" && scons -j"$(nproc)" target="$t")
done

# 多平台条目：只构建当前平台的产物，其它平台的路径指向不存在的文件（Godot 只加载匹配平台/架构那条）。
cat > "$GDX/danmaku_kernel.gdextension" <<'EOF'
[configuration]

entry_symbol = "danmaku_kernel_library_init"
compatibility_minimum = "4.7"
reloadable = false

[libraries]

linux.debug.x86_64 = "res://gdextension/bin/libdanmaku_kernel.linux.template_debug.x86_64.so"
linux.release.x86_64 = "res://gdextension/bin/libdanmaku_kernel.linux.template_release.x86_64.so"
windows.debug.x86_64 = "res://gdextension/bin/libdanmaku_kernel.windows.template_debug.x86_64.dll"
windows.release.x86_64 = "res://gdextension/bin/libdanmaku_kernel.windows.template_release.x86_64.dll"
macos.debug = "res://gdextension/bin/libdanmaku_kernel.macos.template_debug.universal.dylib"
macos.release = "res://gdextension/bin/libdanmaku_kernel.macos.template_release.universal.dylib"
EOF

echo "✅ 产物："
ls -la "$GDX/bin/" 2>/dev/null || true
echo "✅ 已生成 $GDX/danmaku_kernel.gdextension"

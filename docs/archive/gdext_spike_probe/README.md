# 原生内核探针存档（gdext_spike_probe）

> 2026-09-22 归档。由 `_gdext_spike/`（216M，已删）与误建的
> `1-st-touhou-star-~-broadest-and-narrowesttools/`（20K，已删）中抽取的**纯源码**。

## 这是什么

原生弹幕内核（GDExtension）立项前的**可行性探针** —— 证明「SoA 存储 + 积分 + 剔除 +
MultiMesh 写入」在 godot-cpp 下可跑通，结论已写进
[`docs/GDEXTENSION_KERNEL_DESIGN.md`](../../GDEXTENSION_KERNEL_DESIGN.md)（第 48 行引用）。

原目录 216M 里绝大部分是 `godot-cpp` 的**第二份副本**与 `.os` / `.sconsign.dblite`
构建产物，均已删除；本目录只留可读的源码与工程描述文件。

## 内容

| 路径 | 说明 |
|---|---|
| `src/danmaku_store.{h,cpp}` | 探针主体：最小 SoA 存储 + 积分 + 剔除（114 行）。**已被 `gdextension/src/danmaku_store.cpp`（1227 行）完全取代** |
| `src/hello.{h,cpp}` | godot-cpp 最小扩展样例（先跑通工具链用） |
| `src/register_types.{h,cpp}` | 扩展注册入口 |
| `SConstruct` | 探针构建脚本（显式 `api_version=4.7`，godot-cpp v10） |
| `testproj/` | 探针测试工程（`.gd` / `.tscn` / `.gdextension` / `project.godot`，无构建产物） |
| `stray_tools_probe/` | 误建目录里的渲染探针脚本 |

## 两个警告（别直接拿去跑）

- **`stray_tools_probe/` 是死代码**：脚本依赖的 `KernelBulletBackend` 类在主工程
  **已不存在**（内核迁原生后删除）；其 `.tscn` 里的 `res://tools/...` 路径也是误建前的
  残留。仅作历史留证，**不可直接运行**。
- 探针代码为 2026-09-13 快照，与现代码语义**不保证一致**；要对照请以
  `test/reference/`（冻结 oracle）为准。

## 为什么不再需要

- 生产内核已是原生 C++（`gdextension/`），探针使命完成
- 主工程代码 / 工具 / CI 对原 `_gdext_spike/` 与误建目录**零引用**（仅设计文档一句文字引用）
- 本目录含 `.gdignore` —— Godot 不会扫描/导入其中脚本，不影响 `./tools/verify.sh`

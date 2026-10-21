# 原生弹幕内核（GDExtension）

N2-real 起点：原生 SoA 存储 + 积分 + 剔除 + 实例缓冲写入（机制层）。
内容 / 外壳 / 宿主规则仍在 GDScript。

## 构建

```bash
git submodule update --init --recursive   # 首次：拉 godot-cpp（子模块）
./tools/build_gdextension.sh              # 默认 debug + release
```

## 说明

- `godot-cpp/` 是 **git 子模块**（不提交内容）；构建前必须 init。
- 产物在 `gdextension/bin/`，`.gdextension` 由 Godot 自动扫描。
- **新增/改动 `.gdextension` 后需编辑器导入一次**（`godot --editor --quit`）才会被加载。
- `doc_classes/*.xml` 是原生类的 Help 文档：`editor` / `template_debug` 构建时由 `SConstruct` 编进扩展；改 XML 后要重建才能在 Godot Help 里看到。C++ 的 `//` 注释不会自动进 Help。
- 设计 / 路线见 `docs/archive/GDEXTENSION_KERNEL_DESIGN.md`；基准见 `tools/bench_danmaku.gd`。

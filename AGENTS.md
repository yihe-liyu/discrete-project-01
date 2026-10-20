# AGENTS.md

Godot 4.7 + GDScript + 原生 GDExtension 的东方 STG。先读：

- `README.md`
- `CONTENT_GUIDE.md`（内容创作）
- `docs/TEST_INDEX.md`（测试入口）
- `docs/BEST_PRACTICES_BASELINE.md`（硬契约）

## 规则

- **内容 code-first**：`data/**` 是真实脚本/资源，不是编辑器数据；不要恢复数据关卡或工作台写回。
- 改代码前先读相关文件；保持现有中文命名/注释风格。
- 公开 API 用 `##` 文档；长教程放 `docs/`，不要搬进代码。
- 白盒访问预算 **327/327**，只减不增；GDScript 警告视为错误。
- **不要提交** `.godot/`、`user://`、临时截图/日志。
- 原生改动只在 `gdextension/`，非必要不改 C++。
- 默认只本地提交，**不要自动 push**。

## 验证

```bash
./tools/verify.sh --shards=8
./test/run_tests.sh -gtest=res://test/test_xxx.gd
```

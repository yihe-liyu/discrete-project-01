# AGENTS.md

Godot 4.7 + GDScript + 原生 GDExtension 的东方 STG。先读：

- `README.md`
- `CONTENT_GUIDE.md`（内容创作）
- `docs/TEST_INDEX.md`（测试入口）
- `docs/BEST_PRACTICES_BASELINE.md`（硬契约）

## 规则

- **内容 code-first**：`data/**` 是真实脚本/资源，不是编辑器数据；不要恢复数据关卡，也不要让工具写回 `data/**`。
- `data/**` 不写 `get_parent()` / `create_tween()`；内容时间用 `ctx.clock` / `Timeline`，不用 `Timer`。
- 改代码前先读相关文件；保持现有中文命名/注释风格。
- 改内容后至少跑对应符卡练习 / 整关冒烟；GUT 不验手感。
- 公开 API 用 Godot 文档注释（`##`）+ BBCode（`b` / `br` / `code` / `codeblock` / `method` / `member` / `signal` / `constant` / `enum`）；私有实现用 `#`。
- 文档注释不用 Markdown 粗体、反引号或内部版本号；长教程只留 `docs/` 链接。
- 新增 `class_name` 后跑 `godot --headless --import`；`.uid` 文件入库。
- 改测试后同步 `docs/TEST_INDEX.md` + README 徽章（`check_docs` 会校验）。
- 白盒访问预算 **327/327**，只减不增；GDScript 警告视为错误。
- **不要提交** `.godot/`、`user://`、临时截图/日志。
- 原生改动只在 `gdextension/`；C++ 改动要重建，原生指纹必须匹配。
- 默认只本地提交，**不要自动 push**。

## 验证

提交前跑：

```bash
./tools/verify.sh --shards=8
./test/run_tests.sh -gtest=res://test/test_xxx.gd
./tools/check_content.sh
./tools/content_preflight.sh
```

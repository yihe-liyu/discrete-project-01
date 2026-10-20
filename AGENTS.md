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

## API 文档格式（Godot）

- `##` 紧贴声明：类、公开方法、`@export`、`signal`、公开常量。
- 私有实现用 `#`，不要用 `##` 污染 Help。
- 类头：一句话职责 → `[b]模型[/b]` → `[b]用法[/b]` → `[b]边界[/b]`。
- 分段用 `[br]`；单独一行 `##` 不产生可见段落。
- 行内代码 `[code]x[/code]`；代码块 `[codeblock]...[/codeblock]`。
- 引用 `[method foo]` / `[member foo]` / `[signal foo]` / `[constant FOO]` / `[enum Foo]`。
- 强调用 `[b]...[/b]`；**不要**用 `**...**`、反引号、`V18` / `DSL7` 这类内部版本号。
- 长教程不复制，只留链接：`[code]docs/DANMAKU_API.md[/code]`。

```gdscript
## 一句话职责。
##
## [b]用法[/b][br]
## [codeblock]
## var x := Foo.new()
## [/codeblock]
## [br]
## [b]边界[/b][br]
## - 失败时返回 false。
class_name Foo
```


## 验证

```bash
./tools/verify.sh --shards=8
./test/run_tests.sh -gtest=res://test/test_xxx.gd
```

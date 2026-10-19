#!/usr/bin/env python3
"""死代码报告（只报告，不判红）。

用途：列出 `scripts/`、`data/`、`tools/` 里**在声明处之外没有任何引用**的函数。
参考语料包含 `.gd` / `.tscn` / `.tres` / `.cfg` / `.json` / `.sh` / `.py`（含 `test/`），
所以信号连接、`Callable("name")`、测试用例都会算「有人用」。

用法: python3 tools/report_dead_code.py
退出码恒为 0 —— 这是审计工具，不做门禁（公开内容动词可能有仓外使用者）。

已知局限：
  - 按名字匹配，不解析调用图；重名函数可能互相“续命”。
  - `test/reference/**` 是冻结 vendor，不参与声明与引用。
  - 只查函数，不查常量/场景节点。
"""

from __future__ import annotations

import collections
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCTION_ROOTS = ("scripts", "data", "tools")
REFERENCE_ROOTS = ("scripts", "data", "tools", "test", "scenes")
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".cfg", ".json", ".sh", ".py"}
SKIP_DIRS = {".git", ".godot", "__pycache__"}
VIRTUAL_FUNCS = {
	"_ready", "_process", "_physics_process", "_input", "_unhandled_input",
	"_unhandled_key_input", "_shortcut_input", "_gui_input", "_enter_tree",
	"_exit_tree", "_draw", "_notification", "_init", "_initialize", "_get_configuration_warnings",
}
FUNC_RE = re.compile(r"^func\s+(\w+)\s*\(", re.M)
TOKEN_RE = re.compile(r"[^\W\d]\w*", re.UNICODE)


def _iter_files(roots: tuple[str, ...], suffixes: set[str]):
	for root_name in roots:
		root = ROOT / root_name
		if not root.is_dir():
			continue
		for path in root.rglob("*"):
			if not path.is_file() or path.suffix not in suffixes:
				continue
			if any(part in SKIP_DIRS for part in path.parts):
				continue
			if "reference" in path.parts:
				continue
			yield path


def main() -> int:
	# 参考语料：只扫代码/场景/配置目录，避免遍历 .git。
	corpus: list[str] = []
	for path in _iter_files(REFERENCE_ROOTS, TEXT_SUFFIXES):
		try:
			corpus.append(path.read_text(encoding="utf-8"))
		except (UnicodeDecodeError, OSError):
			pass
	token_counts = collections.Counter(TOKEN_RE.findall("\n".join(corpus)))

	declarations: dict[str, list[tuple[str, int]]] = {}
	for path in _iter_files(PRODUCTION_ROOTS, {".gd"}):
		text = path.read_text(encoding="utf-8")
		for match in FUNC_RE.finditer(text):
			name = match.group(1)
			if name in VIRTUAL_FUNCS or name.startswith("_on_"):
				continue
			line = text.count("\n", 0, match.start()) + 1
			declarations.setdefault(name, []).append(
				(str(path.relative_to(ROOT)).replace("\\", "/"), line)
			)

	dead: list[tuple[str, int, str]] = []
	for name, locations in sorted(declarations.items()):
		if token_counts[name] - len(locations) <= 0:
			for file_path, line in locations:
				dead.append((file_path, line, name))

	print(f"死代码报告：{len(declarations)} 个生产函数，{len(dead)} 个零引用声明")
	print("（只报告，不判红；公开内容动词可能有仓外使用者，删前先确认）")
	for file_path, line, name in dead:
		kind = "private" if name.startswith("_") else "public "
		print(f"  {kind}  {file_path}:{line}  {name}")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

#!/usr/bin/env python3
"""文档哨兵 —— 把"手工数字 / 手工清单"变成机械判据。

只查**能被机械验证**的对应关系（文档 ↔ 代码/数据），不查文风、不查正文：

  [1] TEST_INDEX 登记的测试文件 == `test/*.gd`（1:1：不缺、不多、不重复）
  [2] TEST_INDEX 分层表「文件 / 用例」合计 == 抬头「N 脚本 / N 用例」
  [3] README 测试徽章数字 == TEST_INDEX 抬头
  [4] DANMAKU_API §7.2 音效 key == `AssetRegistry.sounds`
  [5] DANMAKU_API §7.1 弹型 key == `data/bullets/*.tres`
  [6] README 里的相对链接都指向真实存在的路径
  [7] 滚动日志体检（`tools/log_archive.py --check`）

来历：2026-09-27 文档体检发现**烂的全是手工数字**（徽章 310→608、TEST_INDEX 抬头、sfx key 行），
而"顺手改"的表体反而准 —— 所以只给手工数字装门禁。

用法：`python3 tools/check_docs.py`（`./tools/verify.sh` 的第 1 步）
退出码 0 = 全过；1 = 有失败（每条都告诉你改哪儿）。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBLEMS: list[str] = []


def fail(check: str, msg: str) -> None:
	PROBLEMS.append(f"[{check}] {msg}")


def read(rel: str) -> str:
	return (ROOT / rel).read_text(encoding="utf-8")


def actual_test_files() -> list[str]:
	return sorted(p.name for p in (ROOT / "test").glob("*.gd"))


# ── [1][2] TEST_INDEX：文件集合 + 抬头数字 ────────────────────────────


def check_test_index() -> tuple[int, int] | None:
	text = read("docs/TEST_INDEX.md")
	actual = actual_test_files()

	listed = re.findall(r"\(\.\./test/([^)]+\.gd)\)", text)
	listed_set = set(listed)
	for name in sorted(set(actual) - listed_set):
		fail("TEST_INDEX", f"测试文件没登记：test/{name}（去它所属层的表里加一行）")
	for name in sorted(listed_set - set(actual)):
		fail("TEST_INDEX", f"登记了不存在的测试：test/{name}（改名/删除后没同步）")
	for name in sorted({n for n in listed if listed.count(n) > 1}):
		fail("TEST_INDEX", f"重复登记：test/{name}")

	head = re.search(r"\*\*现状\*\*：(\d+)\s*脚本\s*/\s*\**(\d+)\s*用例", text)
	if head is None:
		fail("TEST_INDEX", "抬头格式变了：找不到「**现状**：N 脚本 / N 用例」这一行")
		return None
	head_scripts, head_cases = int(head.group(1)), int(head.group(2))

	if "## 分层" not in text:
		fail("TEST_INDEX", "找不到「## 分层」小节")
		return head_scripts, head_cases
	body = text.split("## 分层", 1)[1].split("\n## ", 1)[0]
	rows = re.findall(r"^\|\s*\*\*(.+?)\*\*\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|", body, re.M)
	if not rows:
		fail("TEST_INDEX", "分层表解析不到（表头 / 列序变了）")
		return head_scripts, head_cases

	files = sum(int(r[1]) for r in rows)
	cases = sum(int(r[2]) for r in rows)
	if files != len(actual):
		fail("TEST_INDEX", f"分层表文件合计 {files} ≠ 实际 test/*.gd {len(actual)}")
	if files != head_scripts:
		fail("TEST_INDEX", f"分层表文件合计 {files} ≠ 抬头「{head_scripts} 脚本」")
	if cases != head_cases:
		fail("TEST_INDEX", f"分层表用例合计 {cases} ≠ 抬头「{head_cases} 用例」")
	return head_scripts, head_cases


# ── [3] README 徽章 == TEST_INDEX 抬头 ────────────────────────────────


def check_readme_badge(head: tuple[int, int] | None) -> None:
	if head is None:
		return
	text = read("README.md")
	m = re.search(r"GUT-(\d+)%20tests%20(?:%2F|/)%20(\d+)%20scripts", text)
	if m is None:
		fail("README", "测试徽章格式变了：找不到 `GUT-<N>%20tests%20/%20<N>%20scripts`")
		return
	badge_tests, badge_scripts = int(m.group(1)), int(m.group(2))
	if (badge_scripts, badge_tests) != head:
		fail(
			"README",
			f"测试徽章 {badge_tests} tests / {badge_scripts} scripts "
			f"≠ TEST_INDEX 抬头 {head[1]} 用例 / {head[0]} 脚本",
		)


# ── [4][5] DANMAKU_API 的 key 清单 == 代码/数据 ────────────────────────


def check_danmaku_keys() -> None:
	doc = read("docs/DANMAKU_API.md")

	if "### 7.1" not in doc or "### 7.2" not in doc:
		fail("DANMAKU_API", "找不到 §7.1 / §7.2 小节")
		return

	# [5] 弹型 key == data/bullets/*.tres
	sec_bullets = doc.split("### 7.1", 1)[1].split("### 7.2", 1)[0]
	doc_bullets: set[str] = set()
	for line in sec_bullets.splitlines():
		if not line.startswith("|"):
			continue
		cells = [c.strip() for c in line.strip("|").split("|")]
		if len(cells) < 3 or cells[0] in ("key", "") or set(cells[0]) <= set("-: "):
			continue
		doc_bullets.add(cells[0].strip("`"))
	tres_bullets = {p.stem for p in (ROOT / "data" / "bullets").glob("*.tres")}
	for key in sorted(tres_bullets - doc_bullets):
		fail("DANMAKU_API §7.1", f"弹型没写进表：{key}（data/bullets/{key}.tres）")
	for key in sorted(doc_bullets - tres_bullets):
		fail("DANMAKU_API §7.1", f"表里有、但 data/bullets/ 没这个弹型：{key}")

	# [4] 音效 key == AssetRegistry.sounds
	registry = read("scripts/asset_registry.gd")
	block = registry.split("const sounds := {", 1)
	if len(block) < 2:
		fail("AssetRegistry", "找不到 `const sounds := {`")
		return
	sfx_actual = set(re.findall(r'^\s*"([a-z_0-9]+)"\s*:', block[1].split("\n}", 1)[0], re.M))

	sec_sfx = doc.split("### 7.2", 1)[1].split("### 7.3", 1)[0]
	key_line = max(
		(line for line in sec_sfx.splitlines() if "`" in line),
		key=lambda line: len(re.findall(r"`[a-z_0-9]+`", line)),
		default=None,
	)
	if key_line is None:
		fail("DANMAKU_API §7.2", "找不到音效 key 清单那一行（应以反引号开头）")
		return
	sfx_doc = set(re.findall(r"`([a-z_0-9]+)`", key_line))

	for key in sorted(sfx_actual - sfx_doc):
		fail("DANMAKU_API §7.2", f"音效 key 没写进清单：{key}（asset_registry.gd sounds）")
	for key in sorted(sfx_doc - sfx_actual):
		fail("DANMAKU_API §7.2", f"清单里有、但 AssetRegistry.sounds 没这个 key：{key}")


# ── [6] README 链接可解析 ─────────────────────────────────────────────


def check_readme_links() -> None:
	for m in re.finditer(r"\]\(([^)\s]+)\)", read("README.md")):
		target = m.group(1)
		if target.startswith(("http://", "https://", "#", "mailto:")):
			continue
		path = target.split("#", 1)[0]
		if path and not (ROOT / path).exists():
			fail("README", f"链接指向不存在的路径：{target}")


# ── [7] 滚动日志体检 ──────────────────────────────────────────────────


def check_log() -> None:
	proc = subprocess.run(
		[sys.executable, str(ROOT / "tools" / "log_archive.py"), "--check"],
		capture_output=True,
		text=True,
	)
	if proc.returncode != 0:
		fail("LOG", "log_archive.py --check 失败：\n" + (proc.stdout + proc.stderr).strip())


def main() -> int:
	print("== 文档哨兵（文档 ↔ 代码/数据） ==")
	head = check_test_index()
	check_readme_badge(head)
	check_danmaku_keys()
	check_readme_links()
	check_log()

	if PROBLEMS:
		print(f"❌ 文档哨兵：{len(PROBLEMS)} 处不一致")
		for problem in PROBLEMS:
			print(f"   • {problem}")
		return 1
	print("✅ 文档哨兵全过（TEST_INDEX / README 徽章 / DANMAKU_API key 表 / README 链接 / 日志）")
	return 0


if __name__ == "__main__":
	sys.exit(main())

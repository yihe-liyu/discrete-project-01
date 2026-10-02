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


# ── [2b] 分层小节的小计 == 它自己的行（2026-09-30 加；此前没人看，烂了 19 个用例）──
#
# 为什么加：分层表与抬头只是"总数对得上"，**段落小计烂了也看不出来**——
# 当时 `test_spell_practice_menu` 那行的「白盒」列被写成 `**45**`（加粗），任何朴素解析器都读不到它，
# 于是那一行 19 个用例整行"隐身"，D 段小计与行合计差 19 而无人发现。
# 判据三条：① 每行都得能解析（列数/数字格式）；② 小节小计 == 行合计；③ 分层表那一行 == 小节小计。

ROW = re.compile(
	r"^\|\s*\[test_[^\]]+\]\(\.\./test/[^)]+\.gd\)\s*\|.*?\|\s*\**(\d+)\**\s*\|\s*\**(\d+)\**\s*\|\s*$",
	re.M,
)
SECTION = re.compile(r"^## ([A-G]) · .*?（\s*\**(\d+)\**\s*/\s*\**(\d+)\**\s*）", re.M)
LAYER_ROW = re.compile(r"^\|\s*\*\*(.+?)\*\*\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|", re.M)


def check_test_index_sections() -> None:
	text = read("docs/TEST_INDEX.md")
	layer_body = text.split("## 分层", 1)[1].split("\n## ", 1)[0]
	layer_table = {m.group(1).strip()[:1]: (int(m.group(2)), int(m.group(3)))
		for m in LAYER_ROW.finditer(layer_body)}

	for chunk in re.split(r"\n## ", text):
		title = chunk.split("\n", 1)[0]
		sec = SECTION.match("## " + title)
		if sec is None:
			continue
		letter, head_files, head_cases = sec.group(1), int(sec.group(2)), int(sec.group(3))
		rows = ROW.findall(chunk)
		row_files, row_cases = len(rows), sum(int(r[0]) for r in rows)

		# ① 小节里每条 `| [test_x](...) |` 链接都必须落在一行**能解析**的行里
		bad_rows = []
		for line in chunk.splitlines():
			if line.startswith("| [test_") and not ROW.match(line):
				m = re.search(r"\(\.\./test/([^)]+\.gd)\)", line)
				bad_rows.append(m.group(1) if m else line[:40])
		if bad_rows:
			fail("TEST_INDEX", f"{letter} 段有 {len(bad_rows)} 行解析不到（列数 / 漏列 / 列序变了）："
				f"{', '.join(bad_rows[:3])}")

		# ② 小节小计 == 行合计
		if (row_files, row_cases) != (head_files, head_cases):
			fail("TEST_INDEX", f"{letter} 段小计 {head_files}/{head_cases} ≠ 行合计 {row_files}/{row_cases}")

		# ③ 分层表那一行 == 小节小计
		if letter in layer_table and layer_table[letter] != (head_files, head_cases):
			fail("TEST_INDEX", f"分层表 {letter} {layer_table[letter][0]}/{layer_table[letter][1]} "
				f"≠ 小节小计 {head_files}/{head_cases}")


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


# ── [6] 视觉计划清单：✅ 必须有出处；✅ 提到的文件必须存在（"回退也要更新清单"）──

PLAN = "docs/BACKGROUND_VISUAL_PLAN.md"
COMMIT_RE = re.compile(r"\b[0-9a-f]{7}\b")
DOC_PATH_RE = re.compile(r"((?:[\w.-]+/)*[\w.-]+\.(?:gdshader|tscn|tres|gd|py|sh|png|md))(?![\w])")


def _path_exists(rel: str) -> bool:
	if (ROOT / rel).exists():
		return True
	if "/" not in rel:  # 裸文件名 → 全仓库找（文档里常省略目录），但**跳过隐藏目录**：
		# `.godot/` 里有构建产物（如 shader 缓存），会把已删除的源文件判成"存在" ⇒ 漏报
		for hit in ROOT.rglob(rel):
			if not any(part.startswith(".") for part in hit.relative_to(ROOT).parts):
				return True
	return False


def check_visual_plan() -> None:
	"""BG9 两条硬规矩：① 未划掉的 ✅ 必须带 7 位提交哈希（出处）；
	② ✅ 提到的文件必须存在 —— 东西被回退/删除后要就地划掉（`~~✅ …~~`）并追加 ⛔ 说明回退提交。"""
	for lineno, line in enumerate(read(PLAN).splitlines(), 1):
		if "~~" in line or "⛔" in line:
			continue
		# 只认「条目行」= 去掉列表标记后**以 ✅ 开头**的行（避免把"如何阅读/规矩说明"这类散文误判）
		body = re.sub(r"^\s*(?:[-*+>]\s*|\d+\.\s*)*", "", line)
		if not body.startswith("✅"):
			continue
		if not COMMIT_RE.search(line):
			fail("VISUAL_PLAN", f"{PLAN}:{lineno} ✅ 条目没有出处 —— 补 7 位提交哈希（或划掉它）")
		for rel in DOC_PATH_RE.findall(line):
			if not _path_exists(rel):
				fail("VISUAL_PLAN", f"{PLAN}:{lineno} ✅ 条目提到不存在的文件：{rel}（回退/删除后要划掉并加 ⛔）")


def main() -> int:
	print("== 文档哨兵（文档 ↔ 代码/数据） ==")
	head = check_test_index()
	check_test_index_sections()
	check_readme_badge(head)
	check_danmaku_keys()
	check_readme_links()
	check_log()
	check_visual_plan()

	if PROBLEMS:
		print(f"❌ 文档哨兵：{len(PROBLEMS)} 处不一致")
		for problem in PROBLEMS:
			print(f"   • {problem}")
		return 1
	print("✅ 文档哨兵全过（TEST_INDEX / README 徽章 / DANMAKU_API key 表 / README 链接 / 日志 / 视觉计划清单）")
	return 0


if __name__ == "__main__":
	sys.exit(main())

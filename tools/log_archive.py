#!/usr/bin/env python3
"""最佳实践日志维护：**索引** + **滚动窗口** + **按月归档**。

背景：`docs/BEST_PRACTICES_LOG.md` 是"唯一历史记录"，但它只该留**近期**条目
（见文件头部的约定）。攒到上百条 / 20 万字符后，找东西只能翻半本书 —— 于是：

  * **索引**：文件顶部自动生成"日期 — 标题"一览（新→旧），扫一眼就能定位；
  * **滚动窗口**：只把最近 `--days` 天（且至少留 `--keep-min` 条）留在正文；
  * **归档**：更早的条目按**月**追加进 `docs/archive/LOG_<YYYY-MM>.md`（**不删任何东西**，
    归档内保持**时间正序**，可 grep / 可点开）。

用法：
  python3 tools/log_archive.py --check          # 体检（条目数 / 体积 / 格式），不改文件
  python3 tools/log_archive.py --dry-run        # 看这次会搬走哪些条目
  python3 tools/log_archive.py --index          # 只重建索引
  python3 tools/log_archive.py --archive        # 归档 + 重建索引（默认留最近 2 天）
  python3 tools/log_archive.py --archive --days=7 --keep-min=20

约定（工具会校验）：
  * 每条以 `### YYYY-MM-DD — 标题` 起头（**正文顺序：新 → 旧**）；
  * `## 记录` 之前是文件头（含模板），工具原样保留；
  * 索引由工具维护（`## 索引` 段），手改会被下次覆盖。
"""
import argparse
import datetime
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
LOG = ROOT / "docs/BEST_PRACTICES_LOG.md"
ARCHIVE_DIR = ROOT / "docs/archive"
ENTRY_RE = re.compile(r"^### (\d{4}-\d{2}-\d{2}) — (.+)$", re.M)   # re.M：条目文本是多行，$ 要按行匹配
RECORDS = "## 记录"
INDEX = "## 索引"


def load() -> tuple[str, list[tuple[str, str, str]]]:
    """返回 (文件头, [(日期, 标题, 全文), ...])；正文条目按文件顺序（新→旧）。"""
    text = LOG.read_text(encoding="utf-8")
    head, _, body = text.partition(RECORDS)
    if not body:
        sys.exit(f"找不到 `{RECORDS}` 段：{LOG}")
    # 丢掉旧的索引段（**头和正文都要丢**：索引在 `## 记录` 之前，只清 body 会让它越跑越多）
    head = head.split(INDEX, 1)[0].rstrip() + "\n\n"
    body = body.split(INDEX, 1)[0]
    entries: list[tuple[str, str, str]] = []
    cur: list[str] = []
    for line in body.splitlines():
        m = ENTRY_RE.match(line)
        if m:
            if cur:
                entries.append(_pack(cur))
            cur = [line]
        elif cur:
            cur.append(line)
    if cur:
        entries.append(_pack(cur))
    # 正文历史上混过"早期追加 / 后期前插"两种顺序 → 一律**按日期新→旧**重排（同日稳定）
    entries.sort(key=lambda e: e[0], reverse=True)
    return head, entries


def _pack(lines: list[str]) -> tuple[str, str, str]:
    m = ENTRY_RE.match(lines[0])
    date, title = m.group(1), m.group(2)
    return date, title, "\n".join(lines).rstrip() + "\n"


def render_index(entries: list[tuple[str, str, str]], kept: int) -> str:
    """索引：新→旧；留在正文的标「本文」，归档的给出归档文件链接。"""
    out = [INDEX, "",
           f"> 共 {len(entries)} 条（本文件留最近 {kept} 条，其余在 `docs/archive/`；"
           "本段由 `tools/log_archive.py` 生成，手改会被覆盖）。", ""]
    for i, (date, title, _text) in enumerate(entries):
        if i < kept:
            out.append(f"- {date} — {title}")
        else:
            month = date[:7]
            out.append(f"- {date} — {title}  ·  [归档](archive/LOG_{month}.md)")
    out.append("")
    return "\n".join(out)


def write_log(head: str, entries: list[tuple[str, str, str]], kept: int) -> None:
    parts = [head.rstrip() + "\n", "", render_index(entries, kept), RECORDS, ""]
    for _date, _title, text in entries[:kept]:
        parts.append(text)
    LOG.write_text("\n".join(parts).rstrip() + "\n", encoding="utf-8")


def archive(entries: list[tuple[str, str, str]], kept: int, dry: bool) -> dict[str, int]:
    """把 kept 之后的条目按**月**追加进归档（归档内保持时间正序）。"""
    moved: dict[str, int] = {}
    by_month: dict[str, list[tuple[str, str, str]]] = {}
    for date, title, text in entries[kept:]:
        by_month.setdefault(date[:7], []).append((date, title, text))
    for month, batch in sorted(by_month.items()):
        moved[month] = len(batch)
        if dry:
            continue
        path = ARCHIVE_DIR / f"LOG_{month}.md"
        head = (f"# 最佳实践日志 · 归档 {month}\n\n"
                f"> 由 `tools/log_archive.py` 从 `docs/BEST_PRACTICES_LOG.md` 迁出；"
                "**内文时间正序**（越往下越新），可 grep / 可检索。\n\n---\n")
        old = path.read_text(encoding="utf-8") if path.exists() else head
        # 本批整体比归档里已有的更新 ⇒ 反转后（正序）接在末尾，整体仍是正序
        chunk = "\n".join(t.rstrip() for _d, _t, t in reversed(batch))
        path.write_text(old.rstrip() + "\n\n" + chunk + "\n", encoding="utf-8")
    return moved


def report(entries: list[tuple[str, str, str]]) -> None:
    size = LOG.stat().st_size
    print(f"条目 {len(entries)} 条 · {LOG.stat().st_size / 1024:.0f} KB · "
          f"最新 {entries[0][0]} · 最旧 {entries[-1][0]}" if entries else "空日志")
    bad = [t for _d, _t, t in entries if not ENTRY_RE.match(t)]
    if bad:
        sys.exit(f"❌ {len(bad)} 条不符合 `### YYYY-MM-DD — 标题` 格式")
    print(f"✅ 格式统一（每条都有日期与标题）；正文 {size / 1024:.0f} KB")


def main() -> int:
    ap = argparse.ArgumentParser(description="最佳实践日志：索引 / 滚动窗口 / 按月归档")
    ap.add_argument("--days", type=int, default=2, help="正文保留最近多少天（默认 2）")
    ap.add_argument("--keep-min", type=int, default=12, help="至少保留多少条（默认 12）")
    ap.add_argument("--check", action="store_true", help="只体检，不改文件")
    ap.add_argument("--dry-run", action="store_true", help="只报告会搬走哪些条目")
    ap.add_argument("--index", action="store_true", help="只重建索引")
    ap.add_argument("--archive", action="store_true", help="归档 + 重建索引")
    args = ap.parse_args()

    head, entries = load()
    if args.check:
        report(entries)
        return 0

    cutoff = datetime.date.today() - datetime.timedelta(days=args.days)
    # 语义：**取最近 N 天**，但如果那一窗口少于 keep_min 条，就放宽到 keep_min 条
    # （长时间没写日志时，正文不至于空成一片）
    recent = sum(1 for date, _t, _x in entries if datetime.date.fromisoformat(date) >= cutoff)
    kept = max(min(len(entries), max(recent, args.keep_min)), 1)

    if args.dry_run:
        report(entries)
        print(f"\n留正文 {kept} 条（最近 {args.days} 天，且不少于 {args.keep_min} 条）：")
        for date, title, _t in entries[kept:]:
            print(f"  → {date} — {title}")
        return 0

    # `--index` = **只重建索引**（见文件头与 README 的约定）：正文一个字都不许动。
    # ⚠️ 曾经这里也走 `write_log(..., kept)`，于是"只重建索引"会**按滚动窗口截断正文、却不归档**
    #    —— 正文里那几十条直接被删掉（只有 `--archive` 才该动正文）。2026-09-30 踩到：容器时钟比
    #    项目日期快 2 天 ⇒ `kept` 从 44 掉到 12，一次 `--index` 就吞掉 32 条（幸而 HEAD 里有）。
    if args.index:
        write_log(head, entries, len(entries))
        report(entries)
        print(f"索引已重建（正文 {len(entries)} 条原样保留）✅")
        return 0

    moved: dict[str, int] = {}
    if args.archive:
        moved = archive(entries, kept, dry=False)
    write_log(head, entries, kept)
    report(entries)
    for month, n in sorted(moved.items()):
        print(f"归档 {n} 条 → docs/archive/LOG_{month}.md")
    print(f"正文保留 {kept} 条；索引已重建 ✅")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

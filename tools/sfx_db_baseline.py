#!/usr/bin/env python3
"""音效均衡基准表：量 wav 的 RMS 算出「起点值」，并与当前 SFX_DB 对照。

用途（RMS 的正确定位是**起点**，不是终局）：
  * 新增音效时，先用它算一个起点，别从 0 开始猜
  * 想看「哪些是手调的」时，跑一下 —— 偏离基准的就是耳朵定过的

用法：python3 tools/sfx_db_baseline.py
"""
import wave, array, math, pathlib, re, sys

TARGET_DBFS = -20.0     # 对齐目标（RMS）
CLAMP = 12.0            # 单音最大增益量（防某个源文件电平异常被拉爆）

ROOT = pathlib.Path(__file__).resolve().parent.parent


def level(path: pathlib.Path):
    """返回 (峰值dBFS, RMS dBFS)。支持 8-bit（无符号）与 16-bit（有符号）PCM。"""
    w = wave.open(str(path), "rb")
    n, sw = w.getnframes(), w.getsampwidth()
    raw = w.readframes(n)
    w.close()
    if sw == 1:
        a = array.array("B"); a.frombytes(raw)
        vals = [(x - 128) / 128.0 for x in a]
    elif sw == 2:
        a = array.array("h"); a.frombytes(raw)
        vals = [x / 32768.0 for x in a]
    else:
        return None
    if not vals:
        return None
    peak = max(abs(v) for v in vals)
    rms = math.sqrt(sum(v * v for v in vals) / len(vals))
    return (20 * math.log10(peak) if peak > 0 else -99.0,
            20 * math.log10(rms) if rms > 0 else -99.0)


def main() -> int:
    src = (ROOT / "scripts/asset_registry.gd").read_text(encoding="utf-8")
    keys = re.findall(r'"([a-z_0-9]+)":\s*preload\("res://assets/Sound/([^"]+)"\)', src)
    block = re.search(r"const SFX_DB := \{(.*?)\n\}", src, re.S)
    current = {k: float(v) for k, v in re.findall(r'"(\w+)":\s*([+-]?[\d.]+)', block.group(1))} if block else {}
    if not keys:
        print("没解析到 AssetRegistry.sounds，检查文件格式", file=sys.stderr)
        return 1

    raw = {}
    for key, fname in keys:
        lv = level(ROOT / "assets/Sound" / fname)
        raw[key] = 0.0 if lv is None else max(-CLAMP, min(CLAMP, TARGET_DBFS - lv[1]))
    mean = sum(raw.values()) / max(len(raw), 1)
    base = {k: round(v - mean, 1) for k, v in raw.items()}

    print(f"{'音效':<16}{'RMS基准':>9}{'当前值':>8}{'差':>7}   状态")
    tuned = 0
    for key in sorted(base):
        cur = current.get(key)
        if cur is None:
            print(f"{key:<16}{base[key]:>+9.1f}{'—':>8}{'—':>7}   ⚠️ 表里还没有，建议填 {base[key]:+.1f}")
            continue
        diff = cur - base[key]
        note = "手调" if abs(diff) >= 0.5 else "= 基准"
        if note == "手调":
            tuned += 1
        print(f"{key:<16}{base[key]:>+9.1f}{cur:>+8.1f}{diff:>+7.1f}   {note}")
    print(f"\n共 {len(base)} 个：手调 {tuned} 个，其余等于 RMS 基准。")
    print("含义：RMS 只负责把源文件之间 ~13 dB 的电平差拉平（起点）；")
    print("      短促/高频音的听感偏差（kira 偏响、菜单点击偏小）只能靠耳朵终调。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

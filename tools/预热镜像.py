#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""发布后"烫热"国内加速镜像的边缘缓存。

为什么值得做（2026-09-18 实测，同一台机器、同一个 82 MB 附件）：
  · 冷缓存（镜像回源取第一次）：0.2 – 1.0 MB/s
  · 热缓存（镜像边缘已存住）：5 – 17 MB/s
  ⇒ 发布后本机把每条线路各拉一遍，后面拿到链接的朋友直接吃热缓存，从"几分钟"变"几秒~几十秒"。

用法：
  python3 tools/预热镜像.py                      # 预热 install.ps1 里列的全部线路（默认最新 Release 的包）
  python3 tools/预热镜像.py --asset <url>        # 指定要预热的文件
  python3 tools/预热镜像.py --dry-run            # 只列出将请求的 URL
它只读、不写任何文件（数据直接丢弃），失败不影响发布。
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PS = ROOT / "install.ps1"
UA = "makabaka-warmup"


def read_mirrors() -> list[str]:
    """从 install.ps1 读 $MirrorPrefixes（唯一真源，避免两处清单漂移）。"""
    text = PS.read_text(encoding="utf-8-sig", errors="replace")
    m = re.search(r"\$MirrorPrefixes\s*=\s*@\((.*?)\)", text, re.S)
    if not m:
        raise SystemExit("[x] install.ps1 里找不到 $MirrorPrefixes")
    out = re.findall(r'"([^"]*)"', m.group(1))
    return [x for x in out]          # "" 表示直连，保留（放最后）


def read_repo() -> str:
    text = PS.read_text(encoding="utf-8-sig", errors="replace")
    m = re.search(r'\$ReleasesRepo\s*=\s*"([^"]+)"', text)
    if not m:
        raise SystemExit("[x] install.ps1 里找不到 $ReleasesRepo")
    return m.group(1)


def latest_asset(repo: str) -> str:
    url = f"https://github.com/{repo}/releases/latest/download/SHA256SUMS.txt"
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=25) as r:
        text = r.read().decode("utf-8", "replace")
    m = re.search(r"^file\s*=\s*(.+?)\s*$", text, re.M)
    if not m:
        raise SystemExit("[x] SHA256SUMS.txt 里没有 file= 行")
    return f"https://github.com/{repo}/releases/latest/download/{m.group(1)}"


def warm(url: str, timeout: int = 300) -> tuple[bool, str]:
    """整段拉一遍并丢弃，返回 (是否成功, 速度说明)。"""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    t0 = time.time()
    n = 0
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            total = r.headers.get("Content-Length")
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                n += len(chunk)
                if time.time() - t0 > timeout:
                    return False, f"超时（已收 {n/1e6:.1f} MB）"
    except Exception as e:                       # noqa: BLE001
        return False, f"{type(e).__name__}: {e}"
    dt = max(time.time() - t0, 0.001)
    tail = ""
    if total and int(total) != n:
        tail = f"（注意：收到 {n} 字节，声明 {total} 字节）"
    return True, f"{n/1e6:.1f} MB / {dt:.1f}s = {n/1e6/dt:.2f} MB/s{tail}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--asset", default="", help="要预热的完整 URL（默认：最新 Release 的安装包）")
    ap.add_argument("--timeout", type=int, default=300, help="单条线路超时秒数")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    mirrors = read_mirrors()
    repo = read_repo()
    asset = args.asset or latest_asset(repo)
    print(f"仓库：{repo}")
    print(f"预热：{asset}")
    print(f"线路：{len(mirrors)} 条（含直连）\n")

    ok_n = 0
    for p in mirrors:
        name = p or "（直连 github.com）"
        url = p + asset
        if args.dry_run:
            print(f"  {name:28s} → {url}")
            continue
        t0 = time.time()
        ok, note = warm(url, args.timeout)
        ok_n += ok
        flag = "✓" if ok else "×"
        print(f"  {flag} {name:28s} {note}   （{time.time()-t0:.1f}s）", flush=True)

    if not args.dry_run:
        print(f"\n完成：{ok_n}/{len(mirrors)} 条线路已请求过（缓存由各镜像自己决定保留多久；")
        print("      热缓存效果实测 5–17 MB/s，冷缓存 0.2–1 MB/s）")
    return 0


if __name__ == "__main__":
    sys.exit(main())

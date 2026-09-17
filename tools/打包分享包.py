#!/usr/bin/env python3
# -*- coding: utf-8 -*-
r"""
打包分享包（MAKABAKA 一键安装包）—— 自动排除"不该发给别人"的东西

用法（在仓库根目录）：
    python3 tools/打包分享包.py                      # 按 版本号.txt 里的版本打包
    python3 tools/打包分享包.py --dry-run            # 只看会打什么/排除什么，不生成
    python3 tools/打包分享包.py --version v1.1 --date 20260920
    python3 tools/打包分享包.py --share "/mnt/i/000工作台/英灵神殿mod分享_MAKABAKA"

它做的事：
  1) 先跑一遍 tools/同步到分享包.sh 的等价动作（把仓库里的脚本/文档同步进分享包），可用 --no-sync 跳过
  2) 按排除规则收集文件，生成 zip（root 里就是 install.ps1 / MAKABAKA\ / 各文档）
  3) 打印：文件数、原始大小、zip 大小、MD5/SHA256，以及"排除了哪些"（不静默丢东西）
  4) 打包完成后再跑一次发布：GITHUB_TOKEN=*** python3 tools/发布新版.py --version vX.Y --zip <zip>

模型分离（2026-09-17 起，默认）
  · 角色模型**不再进安装包**：模型放在私有仓库的 Release 附件里，安装脚本按 Models\models.json 按需下载
    （models.json 随包/仓库走；模型 zip 用 tools/发布模型.py --pack / --upload 生成与上传）
  · 默认**只**排模型，其它一律照原样。想更瘦可选加：
    --strip-ui-backgrounds(≈27MB) / --strip-old-payload(≈3MB) / --strip-mmhook(≈7MB)
    想要"整包带模型"的老行为：--with-models

排除规则（关键：给朋友的包里不能有你的个人数据）
  · *_player_*.dat        —— 各玩家 SteamID 的状态文件（QuickStackStore / Recycle_N_Reclaim 等）
  · *.box                 —— SafeBox 柜档（文件名里带玩家ID + 角色名）
  · *.fch / *.db / *.fwl  —— 角色档 / 世界档（不管什么原因出现在这里都不该发）
  · ValheimVRM_手动安装/ValheimVRM.zip —— 旧版模型包（含旧角色名；新版用 Models\）
  · MAKABAKA_backup-* / *.bak*          —— 升级备份
  · install-path.txt      —— 本机记住的路径
  · *.log / 日志*.txt     —— 运行日志
  · MAKABAKA_profile_*.zip / 英灵神殿mod分享_*.zip —— 嵌套的旧包
  · __pycache__ / .DS_Store / Thumbs.db
"""
import argparse
import datetime as dt
import hashlib
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_SHARE = Path("/mnt/i/000工作台/英灵神殿mod分享_MAKABAKA")

# 文件名（含路径）命中这些规则就排除
EXCLUDE_RE = [
    (re.compile(r"_player_[-\d]+\.dat$", re.I), "各玩家 SteamID 状态文件"),
    (re.compile(r"\.box$", re.I), "SafeBox 柜档（含玩家ID+角色名）"),
    (re.compile(r"\.(fch|db|fwl)$", re.I), "角色档/世界档"),
    (re.compile(r"ValheimVRM_手动安装/ValheimVRM\.zip$"), "旧版模型包（含旧角色名）"),
    (re.compile(r"MAKABAKA_backup-"), "升级备份目录"),
    (re.compile(r"\.bak(-|$)", re.I), "备份文件"),
    (re.compile(r"^install-path\.txt$"), "本机记住的路径"),
    (re.compile(r"(^|/)(日志|log).*\.txt$", re.I), "日志"),
    (re.compile(r"MAKABAKA_profile_.*\.zip$"), "嵌套的旧安装包"),
    (re.compile(r"英灵神殿mod分享_.*\.zip$"), "外层打包 zip"),
    (re.compile(r"(^|/)(__pycache__|\.git)(/|$)"), "开发目录"),
    (re.compile(r"(^|/)(\.DS_Store|Thumbs\.db)$", re.I), "系统垃圾文件"),
    (re.compile(r"(^|/)_旧模型_"), "旧模型备份目录"),
    # ---- 模型分离（2026-09-17 起）：模型不再进安装包，改走"私有仓库附件 + 按需下载" ----
    (re.compile(r"(^|/)ValheimVRM_手动安装/Models/.*\.vrm$", re.I), "角色模型（改为按需下载）"),
    (re.compile(r"^Models/.*\.vrm$", re.I), "角色模型（改为按需下载）"),
    (re.compile(r"^Models/_dist/", re.I), "模型发布 zip（本机产物，不上传 git/包）"),
    (re.compile(r"(^|/)模型凭据\.txt$"), "模型下载凭据（绝不能进包）"),
]
# 模型目录内容：默认排除（--with-models 可改回"整包带模型"）——注意不能误伤 Models/models.json
EXCLUDE_MODELS = (re.compile(r"^Models/[^/]+/", re.I), "模型目录内容（模型改走按需下载）")
# 额外瘦身项：**默认不排除**，想更瘦就加对应 --strip-* 开关
EXCLUDE_STRIP = {
    "ui_backgrounds": (re.compile(r"(^|/)BepInEx/config/Azumatt\.MinimalUI_Backgrounds/", re.I), "MinimalUI 背景包"),
    "old_payload": (re.compile(r"\.old$", re.I), "禁用 mod 的 .old 载荷"),
    "mmhook": (re.compile(r"(^|/)BepInEx/plugins/MMHOOK/", re.I), "MMHOOK（首次启动会自动生成）"),
}
# 顶层这些文档/脚本必须存在（缺了说明分享包目录不对）
REQUIRED = ["install.ps1", "ModelLib.ps1", "一键安装.bat", "换模型.bat", "MAKABAKA/mods.yml",
            "版本号.txt", "安装步骤.txt", "Models/models.json"]


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024.0


def sync_from_repo(share: Path) -> None:
    sh = REPO / "tools" / "同步到分享包.sh"
    if not sh.exists():
        print("  [跳过] 没有 tools/同步到分享包.sh")
        return
    print("== 1) 同步仓库 → 分享包 ==")
    r = subprocess.run(["bash", str(sh), str(share)], capture_output=True, text=True)
    out = (r.stdout or "").strip().splitlines()
    for line in out[-6:]:
        print("  " + line)


def read_version(share: Path, override: str | None) -> tuple[str, str]:
    ver, date = "v0.0", dt.datetime.now().strftime("%Y%m%d")
    vf = share / "版本号.txt"
    if vf.exists():
        text = vf.read_text(encoding="utf-8-sig", errors="replace")
        m = re.search(r"版本[:：]\s*(v[\d.]+)", text)
        if m:
            ver = m.group(1)
        m = re.search(r"日期[:：]\s*(\d{4})[-.年]?(\d{2})[-.月]?(\d{2})", text)
        if m:
            date = "".join(m.groups())
    if override:
        ver = override
    return ver, date


def collect(share: Path, with_models: bool = False, strip: set[str] | None = None):
    keep, skipped = [], []
    strip = strip or set()
    rules = list(EXCLUDE_RE)
    if not with_models:              # 默认：模型不进包
        rules.append(EXCLUDE_MODELS)
    for key in strip:                # 额外瘦身：只有显式指定才排除
        if key in EXCLUDE_STRIP:
            rules.append(EXCLUDE_STRIP[key])
    for root, dirs, files in os.walk(share):
        dirs[:] = [d for d in dirs if d not in ("__pycache__", ".git")]
        for name in files:
            p = Path(root) / name
            rel = p.relative_to(share).as_posix()
            reason = None
            for rx, why in rules:
                if rx.search(rel):
                    reason = why
                    break
            if reason:
                skipped.append((rel, p.stat().st_size, reason))
            else:
                keep.append((p, rel))
    return keep, skipped


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--share", default=str(DEFAULT_SHARE))
    ap.add_argument("--version", default=None, help="覆盖版本号（如 v1.1）")
    ap.add_argument("--date", default=None, help="覆盖日期（yyyyMMdd）")
    ap.add_argument("--out", default=None, help="输出 zip 路径（默认放分享包目录）")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-sync", action="store_true")
    # 默认只做模型分离；下面三个是可选的额外瘦身（不加就保持原样）
    ap.add_argument("--with-models", action="store_true",
                    help="把模型也打进安装包（恢复成「整包带模型」的老行为）")
    ap.add_argument("--strip-ui-backgrounds", action="store_true", help="额外排除 MinimalUI 背景包（≈27 MB）")
    ap.add_argument("--strip-old-payload", action="store_true", help="额外排除禁用 mod 的 .old 载荷（≈3 MB）")
    ap.add_argument("--strip-mmhook", action="store_true", help="额外排除 MMHOOK（≈7 MB，首次启动会自动生成）")
    args = ap.parse_args()

    share = Path(args.share)
    if not (share / "MAKABAKA").is_dir():
        print(f"[x] 找不到分享包目录（里面要有 MAKABAKA 文件夹）：{share}", file=sys.stderr)
        return 1

    if not args.no_sync:
        sync_from_repo(share)

    print("\n== 2) 必检项 ==")
    missing = [r for r in REQUIRED if not (share / r).exists()]
    if missing:
        print("  [!] 缺关键文件：" + "、".join(missing) + "（分享包目录不完整？）")
    else:
        print("  ✓ install.ps1 / 一键安装.bat / MAKABAKA\\mods.yml / 版本号.txt 都在")

    strip = set()
    if args.strip_ui_backgrounds:
        strip.add("ui_backgrounds")
    if args.strip_old_payload:
        strip.add("old_payload")
    if args.strip_mmhook:
        strip.add("mmhook")
    keep, skipped = collect(share, with_models=args.with_models, strip=strip)
    total = sum(p.stat().st_size for p, _ in keep)
    print(f"\n== 3) 收集结果：{len(keep)} 个文件，原始 {human(total)} ==")
    by_reason: dict[str, list] = {}
    for rel, size, why in skipped:
        by_reason.setdefault(why, []).append((rel, size))
    if by_reason:
        print("  排除（不会进包）：")
        for why, items in sorted(by_reason.items(), key=lambda kv: -sum(s for _, s in kv[1])):
            print(f"    · {why}：{len(items)} 个，共 {human(sum(s for _, s in items))}")
            for rel, size in items[:3]:
                print(f"        - {rel}  ({human(size)})")
            if len(items) > 3:
                print(f"        … 还有 {len(items) - 3} 个")
    else:
        print("  没有需要排除的文件 ✓")

    ver, date = read_version(share, args.version)
    if args.date:
        date = args.date
    out = Path(args.out) if args.out else share / f"MAKABAKA_profile_{ver}_{date}.zip"
    print(f"\n== 4) 输出：{out}（版本 {ver} / 日期 {date}）==")
    if args.dry_run:
        print("  （--dry-run：没有真的生成）")
        return 0
    if out.exists():
        print(f"  [!] 已存在同名 zip，先移走：{out.name}", file=sys.stderr)
        return 1

    part = out.with_suffix(".zip.part")
    with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p, rel in keep:
            z.write(p, rel)
    part.replace(out)

    data = out.read_bytes()
    print(f"  生成完成：{len(keep)} 个文件 / {human(len(data))}"
          f"（压缩率 {len(data)/max(total,1)*100:.0f}%）")
    print(f"  MD5    : {hashlib.md5(data).hexdigest()}")
    print(f"  SHA256 : {hashlib.sha256(data).hexdigest()}")
    print("\n下一步（发布）：")
    print(f'  GITHUB_TOKEN=$(cat ~/.config/valheim-makabaka/token) python3 tools/发布新版.py '
          f'--version {ver} --zip "{out}" --notes 更新说明_xxx.txt --date {date}')
    return 0


if __name__ == "__main__":
    sys.exit(main())

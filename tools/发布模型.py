#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""发布角色模型（Models\\）到【私有】GitHub 仓库的 Release 附件，并生成 Models\\models.json 清单。

背景：整合包以前把模型塞进 git 和安装包，导致每次更新都要重下几百 MB。
现在模型走"私有仓库 Release 附件 + 清单按需下载"：
  · 公开仓库（kanziguai/valheim-makabaka-pack）里**不再有模型**，只有 Models\\models.json（几 KB）
  · 模型 zip 传到私有仓库（默认 kanziguai/valheim-makabaka-models）的 Release（默认 tag=models-v1）
  · 安装脚本按 models.json 里的 asset 名去私有仓库取，sha256 校验后进本机缓存

用法（在仓库根目录）：
    # 1) 打包 + 生成清单（纯本地，不联网、不上传）
    python3 tools/发布模型.py --pack

    # 2) 上传附件到私有仓库（需要 token；只补缺失的，已存在同大小就跳过）
    GITHUB_TOKEN=ghp_xxx python3 tools/发布模型.py --upload

    # 3) 校验：清单 vs 本地 zip / 本地 vrm 的 sha256
    python3 tools/发布模型.py --check

常用参数：
    --repo <owner/repo>   私有模型仓库（默认读 models.json 里的 repo，其次内置默认）
    --tag  <tag>          Release 标签（默认 models-v1）
    --only 金乌,辰星       只处理这几个模型
    --force               重打已有 zip（默认按 sha256 跳过没变的）
只用标准库；token 走环境变量 GITHUB_TOKEN，不写进文件。
"""
import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import re
import zipfile
from pathlib import Path
from typing import NoReturn

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / "Models"
DIST = MODELS / "_dist"
MANIFEST = MODELS / "models.json"
DEFAULT_REPO = "kanziguai/valheim-makabaka-models"
DEFAULT_TAG = "models-v1"
ZIP_DATE = (2026, 1, 1, 0, 0, 0)   # 固定时间戳 → 同样内容打出的 zip 字节一致


def log(m=""):
    print(m, flush=True)


def die(m, code=1) -> NoReturn:
    log("[×] " + m)
    sys.exit(code)


def sha256_file(p, buf=1 << 22):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        while True:
            b = f.read(buf)
            if not b:
                break
            h.update(b)
    return h.hexdigest()


def desc_of(name):
    """从目录名生成一句话说明：<角色> · <服装/主题>"""
    parts = re.split(r"[-_]\s*", name, maxsplit=1)
    if len(parts) == 2:
        return "%s · %s" % (parts[0], parts[1].replace("_", " "))
    return name


def slug_of(vrm_name):
    """附件名用 ASCII：GitHub 的 Release 附件名对非 ASCII 不友好（中文会被吞成 "-.zip"）。
    jinwu_armfix_v3_compat_v053.vrm -> jinwu ; anka_ye_wei_armfix_v1_compat_v053.vrm -> anka_ye_wei"""
    stem = Path(vrm_name).stem
    stem = re.sub(r"_(armfix_v\d+|compat_v?\d+|ds|tpose)$", "", stem, flags=re.I)
    stem = re.sub(r"_+$", "", stem)
    return stem or "model"


def discover(only=None):
    out = []
    if not MODELS.is_dir():
        die("没有 Models 目录：%s" % MODELS)
    for d in sorted(MODELS.iterdir(), key=lambda x: x.name):
        if not d.is_dir() or d.name.startswith("_"):
            continue
        if only and d.name not in only:
            continue
        vrms = sorted(d.glob("*.vrm"), key=lambda p: p.stat().st_size, reverse=True)
        if not vrms:
            log("  [跳过] %s 里没有 .vrm" % d.name)
            continue
        vrm = vrms[0]
        sets = sorted(d.glob("settings*.txt"))
        slug = slug_of(vrm.name)
        out.append({"name": d.name, "slug": slug, "asset": slug + ".zip",
                    "vrm": vrm, "settings": sets[0] if sets else None})
    return out


def build_zip(item, force=False):
    """打成 Models/_dist/<名>.zip，内含 <名>/<xxx.vrm>（+ settings.txt）。返回 (zip路径, 是否新建)"""
    DIST.mkdir(exist_ok=True)
    zpath = DIST / item["asset"]
    vrm_sha = sha256_file(item["vrm"])
    if zpath.exists() and not force:
        try:
            with zipfile.ZipFile(zpath) as z:
                inner = [n for n in z.namelist() if n.lower().endswith(".vrm")]
                if inner:
                    info = z.getinfo(inner[0])
                    if info.file_size == item["vrm"].stat().st_size:
                        h = hashlib.sha256()
                        with z.open(inner[0]) as f:
                            while True:
                                b = f.read(1 << 22)
                                if not b:
                                    break
                                h.update(b)
                        if h.hexdigest() == vrm_sha:
                            return zpath, False
        except Exception:
            pass
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        info = zipfile.ZipInfo("%s/%s" % (item["slug"], item["vrm"].name), date_time=ZIP_DATE)
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        with open(item["vrm"], "rb") as f:
            z.writestr(info, f.read())
        if item["settings"]:
            si = zipfile.ZipInfo("%s/settings.txt" % item["slug"], date_time=ZIP_DATE)
            si.compress_type = zipfile.ZIP_DEFLATED
            si.external_attr = 0o644 << 16
            z.writestr(si, item["settings"].read_bytes())
    return zpath, True


def write_manifest(items, repo, tag, default=None):
    models = []
    for it in items:
        zpath = DIST / it["asset"]
        models.append({
            "name": it["name"],
            "vrm": it["vrm"].name,
            "asset": it["asset"],
            "dir": it["slug"],
            "size": it["vrm"].stat().st_size,          # .vrm 本体大小（显示用）
            "zipSize": zpath.stat().st_size if zpath.exists() else None,
            "sha256": sha256_file(it["vrm"]),          # 解压后校验用
            "desc": desc_of(it["name"]),
        })
    man = {
        "manifestVersion": 1,
        "repo": repo,
        "tag": tag,
        "note": "模型仅供本地自用（禁二次配布）；经私有仓库 Release 附件按需下载，安装脚本会校验 sha256。",
        "default": default or (models[0]["name"] if models else ""),
        "models": models,
    }
    MANIFEST.write_text(json.dumps(man, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return man


# ---------------- GitHub ----------------
def api(path, token, method="GET", payload=None, raw=None, ctype="application/json", ok404=False):
    url = path if path.startswith("http") else "https://api.github.com" + path
    data = json.dumps(payload).encode() if payload is not None else raw
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("User-Agent", "makabaka-models")
    if data is not None:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            body = r.read()
            return json.loads(body.decode()) if body else {}
    except urllib.error.HTTPError as e:
        if ok404 and e.code == 404:
            return {}
        die("GitHub API %s %s → %s：%s" % (method, url, e.code, e.read().decode("utf-8", "replace")[:400]))


def ensure_release(repo, tag, token, notes):
    rel = api("/repos/%s/releases/tags/%s" % (repo, tag), token, ok404=True)
    if rel.get("id"):
        return rel
    log("  创建 Release：%s（%s）" % (tag, repo))
    return api("/repos/%s/releases" % repo, token, "POST", {
        "tag_name": tag, "name": "角色模型库 " + tag,
        "body": notes, "draft": False, "prerelease": False,
    })


def upload_assets(items, repo, tag, token, force=False):
    rel = ensure_release(repo, tag, token,
                         "MAKABAKA 整合档的角色模型附件（私有）。\n"
                         "安装脚本按 Models/models.json 里的 asset 名按需下载，并校验 sha256。")
    have = {a["name"]: a for a in rel.get("assets", []) or []}
    for it in items:
        zpath = DIST / it["asset"]
        if not zpath.exists():
            die("先跑 --pack（缺 %s）" % zpath)
        name = zpath.name
        size = zpath.stat().st_size
        a = have.get(name)
        if a and a.get("size") == size and not force:
            log("  [跳过] %s 已在 Release 上（%.1f MB）" % (name, size / 1e6))
            continue
        if a:
            log("  替换旧附件 %s（%s → %s 字节）" % (name, a.get("size"), size))
            api("/repos/%s/releases/assets/%d" % (repo, a["id"]), token, "DELETE")
        up = "https://uploads.github.com/repos/%s/releases/%d/assets?name=%s" % (
            repo, rel["id"], urllib.parse.quote(name))
        log("  上传 %s（%.1f MB）…" % (name, size / 1e6))
        t0 = time.time()
        blob = zpath.read_bytes()
        api(up, token, "POST", raw=blob, ctype="application/octet-stream")
        log("    完成（%.1fs，%.2f MB/s）" % (time.time() - t0, len(blob) / 1e6 / max(time.time() - t0, .001)))
        # 上传后立即核对附件名（曾出现 GitHub 把中文名吞成 "-.zip" 的情况）
        rel2 = api("/repos/%s/releases/tags/%s" % (repo, tag), token)
        got = {a["name"]: a.get("size", 0) for a in (rel2.get("assets") or [])}
        if got.get(name) != size:
            same = [n for n, s in got.items() if s == size]
            die("附件名没对上：期望 %s（%d 字节）；Release 上同大小的名字是 %s\n"
                "  附件名保持 ASCII（中文名会被 GitHub 改坏）" % (name, size, same or "无"))
    log("  Release：https://github.com/%s/releases/tag/%s" % (repo, tag))


def check(items, man):
    ok = True
    by_name = {m["name"]: m for m in man["models"]}
    for it in items:
        m = by_name.get(it["name"])
        zpath = DIST / it["asset"]
        if not m:
            log("  [×] %s 不在清单里" % it["name"]); ok = False; continue
        sha = sha256_file(it["vrm"])
        s1 = "✓" if sha == m["sha256"] else "×"
        s2 = "✓" if zpath.exists() else "×"
        log("  %s %-28s vrm %6.1f MB  sha256%s  zip%s" % (
            "OK " if (sha == m["sha256"] and zpath.exists()) else "BAD", it["name"],
            it["vrm"].stat().st_size / 1048576, s1, s2))
        if sha != m["sha256"] or not zpath.exists():
            ok = False
    total = sum(m["size"] for m in man["models"]) / 1048576
    ztotal = sum((m["zipSize"] or 0) for m in man["models"]) / 1048576
    log("\n  清单 %d 个模型；vrm 合计 %.1f MB；zip 合计 %.1f MB" % (len(man["models"]), total, ztotal))
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pack", action="store_true", help="打 zip（Models/_dist/）并生成 models.json")
    ap.add_argument("--upload", action="store_true", help="上传附件到私有仓库 Release")
    ap.add_argument("--check", action="store_true", help="校验清单 vs 本地 zip/vrm")
    ap.add_argument("--repo", default="")
    ap.add_argument("--tag", default="")
    ap.add_argument("--only", default="", help="只处理这些模型（逗号分隔）")
    ap.add_argument("--default", default="", help="写进清单的默认模型名")
    ap.add_argument("--force", action="store_true", help="重打已有 zip / 强制重传")
    a = ap.parse_args()
    if not (a.pack or a.upload or a.check):
        ap.print_help()
        die("至少给一个动作：--pack / --upload / --check")

    man_disk = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    repo = a.repo or man_disk.get("repo") or DEFAULT_REPO
    tag = a.tag or man_disk.get("tag") or DEFAULT_TAG
    only = set(x.strip() for x in a.only.split(",") if x.strip()) or None

    items = discover(only)
    log("仓库：%s   tag：%s   模型：%d 个" % (repo, tag, len(items)))

    if a.pack:
        log("\n-- 打包 --")
        new = 0
        for it in items:
            z, created = build_zip(it, force=a.force)
            new += 1 if created else 0
            log("  %s %-30s %6.1f MB%s" % ("新建" if created else "已存在", z.name, z.stat().st_size / 1048576,
                                           "" if created else "（内容一致，跳过）"))
        log("  → Models/_dist/（共 %d 个 zip，本次新建 %d）" % (len(items), new))
        man = write_manifest(items, repo, tag, default=a.default or None)
        log("  已写 %s（%d 个模型）" % (MANIFEST.relative_to(ROOT), len(man["models"])))

    if a.upload:
        token = os.environ.get("GITHUB_TOKEN", "").strip()
        if not token:
            die("没设 GITHUB_TOKEN。示例：GITHUB_TOKEN=ghp_xxx python3 tools/发布模型.py --upload")
        log("\n-- 上传到 %s --" % repo)
        upload_assets(items, repo, tag, token, force=a.force)

    if a.check:
        log("\n-- 校验 --")
        if not man_disk and not MANIFEST.exists():
            die("没有 models.json，先 --pack")
        man = json.loads(MANIFEST.read_text(encoding="utf-8"))
        sys.exit(0 if check(items, man) else 1)


if __name__ == "__main__":
    main()

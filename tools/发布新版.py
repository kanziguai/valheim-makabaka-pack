#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""发布英灵神殿 MAKABAKA 整合档的新版本到 GitHub Release。

在仓库根目录运行：
    GITHUB_TOKEN=ghp_xxx python3 tools/发布新版.py \
        --version v1.1 \
        --zip "/mnt/i/000工作台/英灵神殿mod分享_MAKABAKA/MAKABAKA_profile_v1.1_20260920.zip" \
        --notes "更新说明_20260920.txt"

它会：
  1) 算 zip 的 字节数 / MD5 / SHA256，写仓库根的 SHA256SUMS.txt（固定名，安装脚本按它校验）
  2) 往 校验值.txt 追加一条历史记录（已存在同版本就改写）
  3) 把 install.ps1 里的内置兜底版本（$FallbackAsset / $FallbackMd5）改成新版本
  4) git 提交 + 推送，然后创建 Release（tag = 版本号）并上传 zip 与 SHA256SUMS.txt

只用标准库；token 走环境变量，不写进文件。
"""
import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUMS_NAME = "SHA256SUMS.txt"


def log(msg=""):
    print(msg, flush=True)


def die(msg, code=1):
    log("[×] " + msg)
    sys.exit(code)


def git(*args, check=True):
    p = subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True)
    if check and p.returncode != 0:
        die("git %s 失败：%s%s" % (" ".join(args), p.stdout, p.stderr))
    return p.stdout.strip()


def api(repo, token, path, method="GET", payload=None, raw=None, ctype="application/json"):
    url = path if path.startswith("http") else "https://api.github.com" + path
    data = None
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
    if raw is not None:
        data = raw
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Authorization", "Bearer " + token)
    req.add_header("User-Agent", "makabaka-release")
    if data is not None:
        req.add_header("Content-Type", ctype)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            body = r.read()
            return json.loads(body.decode("utf-8")) if body else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")[:500]
        die("GitHub API %s %s 返回 %s：%s" % (method, url, e.code, detail))
    except Exception as e:  # noqa: BLE001
        die("调用 %s 失败：%s" % (url, e))


def hashes(path):
    md5 = hashlib.md5()
    sha = hashlib.sha256()
    size = 0
    with open(path, "rb") as f:
        while True:
            b = f.read(1024 * 1024)
            if not b:
                break
            size += len(b)
            md5.update(b)
            sha.update(b)
    return size, md5.hexdigest(), sha.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="新版本号，如 v1.1")
    ap.add_argument("--zip", required=True, help="要发布的安装包 zip 路径")
    ap.add_argument("--notes", default="", help="Release 正文：直接用这个文件的内容（如 更新说明_20260920.txt）")
    ap.add_argument("--repo", default="", help="owner/repo；不给就从 git remote 推出来")
    ap.add_argument("--date", default=time.strftime("%Y%m%d"), help="打包日期 YYYYMMDD（默认今天）")
    args = ap.parse_args()

    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if not token:
        die("没设 GITHUB_TOKEN。用法：GITHUB_TOKEN=ghp_xxx python3 tools/发布新版.py --version v1.1 --zip <zip路径>")

    ver = args.version.strip()
    if not re.fullmatch(r"v\d+\.\d+", ver):
        die("版本号格式应为 v主.次（如 v1.1），你给的是 %r" % ver)

    zpath = Path(args.zip).expanduser().resolve()
    if not zpath.exists():
        die("找不到 zip：%s" % zpath)
    zname = zpath.name
    if not re.fullmatch(r"MAKABAKA_profile_v\d+(\.\d+)*(?:_\d{8})?\.zip", zname):
        die("包名不符合命名规则 MAKABAKA_profile_v<主.次>_<YYYYMMDD>.zip：%s" % zname)
    if ("_v" + ver[1:]) not in zname:
        die("包名里的版本号和 --version 不一致：%s vs %s" % (zname, ver))

    repo = args.repo.strip()
    if not repo:
        url = git("remote", "get-url", "origin")
        m = re.search(r"github\.com[:/]+([^/]+/[^/.]+)", url)
        if not m:
            die("从 origin 里解析不出 owner/repo，请用 --repo 指定")
        repo = m.group(1)
    log("仓库：%s   版本：%s   包：%s" % (repo, ver, zname))

    # ---- 0) 先确认 install.ps1 里的仓库地址跟要发布的仓库一致（防止发了包但脚本还指着占位符）----
    psfile = ROOT / "install.ps1"
    pstext0 = psfile.read_text(encoding="utf-8")
    m = re.search(r'\$ReleasesRepo\s*=\s*"([^"]+)"', pstext0)
    if not m:
        die("install.ps1 里找不到 $ReleasesRepo，无法确认在线下载指向哪个仓库")
    if m.group(1).strip().lower() != repo.lower():
        die("install.ps1 里的 $ReleasesRepo = %r，与目标仓库 %r 不一致 —— 先改对再发（否则安装脚本会 404）"
            % (m.group(1), repo))
    log("install.ps1 的 $ReleasesRepo 与目标仓库一致 ✓")

    # ---- 1) 算哈希，写 SHA256SUMS.txt ----
    size, md5, sha = hashes(zpath)
    log("包：%s  %d 字节  MD5 %s" % (zname, size, md5))
    sums = (ROOT / SUMS_NAME)
    sums.write_text(
        "version=%s\ndate=%s\nfile=%s\nsize=%d\nmd5=%s\nsha256=%s\n" % (
            ver, "%s-%s-%s" % (args.date[:4], args.date[4:6], args.date[6:8]), zname, size, md5, sha),
        encoding="utf-8")
    log("已写 %s" % sums.name)

    # ---- 2) 校验值.txt 追加/改写 ----
    hist = ROOT / "校验值.txt"
    entry = ("\n[ %s ]  %s-%s-%s\n  文件：%s\n  大小：%d 字节\n  MD5 ：%s\n  SHA256：%s\n"
             % (ver, args.date[:4], args.date[4:6], args.date[6:8], zname, size, md5, sha))
    text = hist.read_text(encoding="utf-8") if hist.exists() else "MAKABAKA 整合档 —— 安装包校验值\n============================\n"
    if ("[ %s ]" % ver) in text:
        # 只替换这一条（到下一个空行为止），不要吃掉后面的说明段落
        text = re.sub(r"\[ %s \].*?(?=\n[ \t]*\n|\Z)" % re.escape(ver), entry.strip() + "\n", text, flags=re.S)
    else:
        text = text.rstrip() + "\n" + entry
    hist.write_text(text, encoding="utf-8")
    log("已更新 校验值.txt")

    # ---- 3) install.ps1 内置兜底版本 ----
    ps = ROOT / "install.ps1"
    pstext = ps.read_text(encoding="utf-8")
    pstext, n1 = re.subn(r'\$FallbackAsset\s*=\s*"[^"]+"', '$FallbackAsset   = "%s"' % zname, pstext)
    pstext, n2 = re.subn(r'\$FallbackMd5\s*=\s*"[^"]+"', '$FallbackMd5     = "%s"' % md5, pstext)
    if n1 != 1 or n2 != 1:
        die("install.ps1 里的 $FallbackAsset/$FallbackMd5 没替换成功（n1=%d n2=%d），请手改" % (n1, n2))
    ps.write_text(pstext, encoding="utf-8")
    log("已更新 install.ps1 内置兜底版本")

    # ---- 4) git 提交推送 ----
    git("add", "-A")
    if git("status", "--porcelain"):
        git("commit", "-m", "发布 %s：%s（%s 字节）" % (ver, zname, size))
        git("push", "origin", "HEAD")
        log("已提交并推送")
    else:
        log("仓库没有改动，跳过提交")

    # ---- 5) 建 Release 并上传附件 ----
    tag = ver
    body = ""
    if args.notes:
        nf = Path(args.notes)
        body = nf.read_text(encoding="utf-8") if nf.exists() else args.notes
    rel = api(repo, token, "/repos/%s/releases" % repo, "POST", {
        "tag_name": tag,
        "name": "%s  %s" % (ver, zname),
        "body": body or ("安装包：`%s`（%d 字节）\n\n装法见仓库 README。" % (zname, size)),
        "draft": False,
        "prerelease": False,
    })
    log("已建 Release：%s" % rel.get("html_url", tag))

    for path, label in ((zpath, "安装包"), (sums, "校验清单")):
        name = path.name
        log("上传 %s（%s，%.1f MB）…" % (name, label, path.stat().st_size / 1e6))
        # 已存在同名附件就先删掉（重跑同一版本时用）
        for a in rel.get("assets", []) or []:
            if a.get("name") == name:
                api(repo, token, "/repos/%s/releases/assets/%d" % (repo, a["id"]), "DELETE")
        up = "https://uploads.github.com/repos/%s/releases/%d/assets?name=%s" % (
            repo, rel["id"], urllib.parse.quote(name))
        blob = path.read_bytes()          # 117MB 量级，直接整块传，带 Content-Length 最稳
        t0 = time.time()
        api(repo, token, up, "POST", raw=blob, ctype="application/octet-stream")
        log("  上传完成（%.1fs，%.2f MB/s）" % (time.time() - t0, len(blob) / 1e6 / max(time.time() - t0, 0.001)))

    log("")
    log("全部完成。Release 页面：%s" % rel.get("html_url", ""))
    log("提醒：确认 https://github.com/%s/releases/latest/download/SHA256SUMS.txt 能下载、内容是 %s。" % (repo, ver))


if __name__ == "__main__":
    main()
